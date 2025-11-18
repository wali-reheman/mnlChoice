#' Create Publication-Ready Regression Table
#'
#' Generates camera-ready tables comparing MNL and MNP models for academic papers.
#' Supports LaTeX, HTML, and markdown formats.
#'
#' @param mnl_fit Fitted MNL model (from nnet::multinom or fit_mnp_safe).
#' @param mnp_fit Fitted MNP model (from MNP::mnp or fit_mnp_safe). Can be NULL.
#' @param format Character. Output format: "latex", "html", or "markdown". Default "latex".
#' @param digits Number of decimal places. Default 3.
#' @param stars Logical. Add significance stars. Default TRUE.
#' @param se_type Character. "standard" or "parentheses". Default "parentheses".
#' @param caption Character. Table caption. Default NULL (uses title if provided).
#' @param title Character. Alias for caption. Default NULL.
#' @param label Character. LaTeX label. Default NULL.
#' @param verbose Logical. Print table to console. Default TRUE.
#'
#' @return Character vector containing formatted table.
#'
#' @details
#' Creates professional regression tables with:
#' \itemize{
#'   \item Coefficient estimates
#'   \item Standard errors (in parentheses)
#'   \item Significance stars (* p<0.05, ** p<0.01, *** p<0.001)
#'   \item Model fit statistics (Log-likelihood, AIC, BIC)
#'   \item Sample size
#' }
#'
#' **LaTeX output** is ready for copy-paste into manuscript.
#' **HTML output** works in R Markdown documents.
#' **Markdown output** is human-readable.
#'
#' @examples
#' \dontrun{
#' # Generate data and fit models
#' dat <- generate_choice_data(n = 300, seed = 123)
#' mnl <- fit_mnp_safe(choice ~ x1 + x2, data = dat$data, fallback = "MNL")
#'
#' # Create LaTeX table
#' table_latex <- publication_table(mnl, format = "latex")
#' cat(table_latex, sep = "\n")
#'
#' # Create HTML table
#' table_html <- publication_table(mnl, format = "html")
#' cat(table_html, sep = "\n")
#'
#' # Compare MNL and MNP
#' mnp <- fit_mnp_safe(choice ~ x1 + x2, data = dat$data, fallback = "NULL")
#' if (!is.null(mnp)) {
#'   table <- publication_table(mnl, mnp, format = "latex")
#'   cat(table, sep = "\n")
#' }
#' }
#'
#' @export
publication_table <- function(mnl_fit, mnp_fit = NULL, format = "latex",
                              digits = 3, stars = TRUE,
                              se_type = "parentheses",
                              caption = NULL, title = NULL, label = NULL,
                              verbose = TRUE) {

  # Check MNP availability if comparison requested
  if (is.null(mnp_fit)) {
    mnp_available <- requireNamespace("MNP", quietly = TRUE)
    if (!mnp_available && verbose) {
      message(
        "\nNote: MNP package not installed. Table will show MNL results only.\n",
        "To compare with MNP, install with: install.packages('MNP')\n"
      )
    }
  }

  # Handle title/caption (title is alias for caption)
  if (!is.null(title) && is.null(caption)) {
    caption <- title
  }

  # Extract MNL results
  mnl_coef <- coef(mnl_fit)
  mnl_se <- sqrt(diag(vcov(mnl_fit)))

  # Handle matrix vs vector
  if (is.matrix(mnl_coef)) {
    # Multiple alternatives
    alt_names <- rownames(mnl_coef)
    var_names <- colnames(mnl_coef)
    mnl_coef_vec <- as.vector(t(mnl_coef))
    names(mnl_coef_vec) <- paste(rep(alt_names, each = length(var_names)),
                                 rep(var_names, times = length(alt_names)),
                                 sep = ":")
  } else {
    mnl_coef_vec <- mnl_coef
    var_names <- names(mnl_coef_vec)
  }

  # Compute p-values
  z_scores <- mnl_coef_vec / mnl_se
  p_values <- 2 * (1 - pnorm(abs(z_scores)))

  # Stars
  stars_mnl <- rep("", length(p_values))
  if (stars) {
    stars_mnl[p_values < 0.05] <- "*"
    stars_mnl[p_values < 0.01] <- "**"
    stars_mnl[p_values < 0.001] <- "***"
  }

  # Model fit stats
  mnl_ll <- as.numeric(logLik(mnl_fit))
  mnl_aic <- AIC(mnl_fit)
  mnl_bic <- BIC(mnl_fit)

  # Get number of observations (nobs doesn't work on multinom)
  n_obs <- tryCatch({
    nobs(mnl_fit)
  }, error = function(e) {
    # Fallback: use residuals length
    length(residuals(mnl_fit))
  })

  # Extract MNP results if available
  if (!is.null(mnp_fit)) {
    mnp_coef <- coef(mnp_fit)
    mnp_se <- sqrt(diag(vcov(mnp_fit)))

    if (is.matrix(mnp_coef)) {
      mnp_coef_vec <- as.vector(t(mnp_coef))
    } else {
      mnp_coef_vec <- mnp_coef
    }

    z_scores_mnp <- mnp_coef_vec / mnp_se
    p_values_mnp <- 2 * (1 - pnorm(abs(z_scores_mnp)))

    stars_mnp <- rep("", length(p_values_mnp))
    if (stars) {
      stars_mnp[p_values_mnp < 0.05] <- "*"
      stars_mnp[p_values_mnp < 0.01] <- "**"
      stars_mnp[p_values_mnp < 0.001] <- "***"
    }

    mnp_ll <- tryCatch(as.numeric(logLik(mnp_fit)), error = function(e) NA)
    mnp_aic <- tryCatch(AIC(mnp_fit), error = function(e) NA)
    mnp_bic <- tryCatch(BIC(mnp_fit), error = function(e) NA)
  }

  # Build table based on format
  if (format == "latex") {
    lines <- c()

    # Header
    lines <- c(lines, "\\begin{table}[htbp]")
    lines <- c(lines, "\\centering")
    if (!is.null(caption)) {
      lines <- c(lines, sprintf("\\caption{%s}", caption))
    }
    if (!is.null(label)) {
      lines <- c(lines, sprintf("\\label{%s}", label))
    }

    # Tabular
    if (is.null(mnp_fit)) {
      lines <- c(lines, "\\begin{tabular}{lc}")
    } else {
      lines <- c(lines, "\\begin{tabular}{lcc}")
    }

    lines <- c(lines, "\\hline\\hline")

    # Column headers
    if (is.null(mnp_fit)) {
      lines <- c(lines, " & MNL \\\\")
    } else {
      lines <- c(lines, " & MNL & MNP \\\\")
    }

    lines <- c(lines, "\\hline")

    # Coefficients
    for (i in 1:length(mnl_coef_vec)) {
      var_label <- names(mnl_coef_vec)[i]

      if (is.null(mnp_fit)) {
        lines <- c(lines, sprintf(
          paste0("%s & %.", digits, "f%s \\\\"),
          var_label,
          mnl_coef_vec[i],
          stars_mnl[i]
        ))
        lines <- c(lines, sprintf(
          paste0(" & (%.", digits, "f) \\\\"),
          mnl_se[i]
        ))
      } else {
        lines <- c(lines, sprintf(
          paste0("%s & %.", digits, "f%s & %.", digits, "f%s \\\\"),
          var_label,
          mnl_coef_vec[i],
          stars_mnl[i],
          mnp_coef_vec[i],
          stars_mnp[i]
        ))
        lines <- c(lines, sprintf(
          paste0(" & (%.", digits, "f) & (%.", digits, "f) \\\\"),
          mnl_se[i],
          mnp_se[i]
        ))
      }
    }

    lines <- c(lines, "\\hline")

    # Fit statistics
    if (is.null(mnp_fit)) {
      lines <- c(lines, sprintf("Log-likelihood & %.2f \\\\", mnl_ll))
      lines <- c(lines, sprintf("AIC & %.2f \\\\", mnl_aic))
      lines <- c(lines, sprintf("BIC & %.2f \\\\", mnl_bic))
      lines <- c(lines, sprintf("N & %d \\\\", n_obs))
    } else {
      lines <- c(lines, sprintf("Log-likelihood & %.2f & %.2f \\\\", mnl_ll, mnp_ll))
      lines <- c(lines, sprintf("AIC & %.2f & %.2f \\\\", mnl_aic, mnp_aic))
      lines <- c(lines, sprintf("BIC & %.2f & %.2f \\\\", mnl_bic, mnp_bic))
      lines <- c(lines, sprintf("N & %d & %d \\\\", n_obs, n_obs))
    }

    lines <- c(lines, "\\hline\\hline")
    if (stars) {
      lines <- c(lines, "\\multicolumn{2}{l}{\\footnotesize{* p<0.05, ** p<0.01, *** p<0.001}} \\\\")
    }
    lines <- c(lines, "\\end{tabular}")
    lines <- c(lines, "\\end{table}")

    # Fix formatting - must happen before returning
    lines <- gsub("\\.\\{digits\\}f", paste0(".", digits, "f"), lines)

    result <- paste(lines, collapse = "\n")
    if (verbose) cat(result, "\n")
    return(result)

  } else if (format == "html") {
    # HTML format
    lines <- c()
    lines <- c(lines, "<table border='1' style='border-collapse: collapse;'>")
    if (!is.null(caption)) {
      lines <- c(lines, sprintf("<caption>%s</caption>", caption))
    }

    # Header
    if (is.null(mnp_fit)) {
      lines <- c(lines, "<tr><th></th><th>MNL</th></tr>")
    } else {
      lines <- c(lines, "<tr><th></th><th>MNL</th><th>MNP</th></tr>")
    }

    # Coefficients
    for (i in 1:length(mnl_coef_vec)) {
      var_label <- names(mnl_coef_vec)[i]

      if (is.null(mnp_fit)) {
        lines <- c(lines, sprintf(
          paste0("<tr><td>%s</td><td>%.", digits, "f%s<br/>(%.", digits, "f)</td></tr>"),
          var_label,
          mnl_coef_vec[i],
          stars_mnl[i],
          mnl_se[i]
        ))
      } else {
        lines <- c(lines, sprintf(
          paste0("<tr><td>%s</td><td>%.", digits, "f%s<br/>(%.", digits, "f)</td><td>%.", digits, "f%s<br/>(%.", digits, "f)</td></tr>"),
          var_label,
          mnl_coef_vec[i],
          stars_mnl[i],
          mnl_se[i],
          mnp_coef_vec[i],
          stars_mnp[i],
          mnp_se[i]
        ))
      }
    }

    # Fit stats
    if (is.null(mnp_fit)) {
      lines <- c(lines, sprintf("<tr><td>Log-likelihood</td><td>%.2f</td></tr>", mnl_ll))
      lines <- c(lines, sprintf("<tr><td>AIC</td><td>%.2f</td></tr>", mnl_aic))
      lines <- c(lines, sprintf("<tr><td>N</td><td>%d</td></tr>", n_obs))
    } else {
      lines <- c(lines, sprintf("<tr><td>Log-likelihood</td><td>%.2f</td><td>%.2f</td></tr>", mnl_ll, mnp_ll))
      lines <- c(lines, sprintf("<tr><td>AIC</td><td>%.2f</td><td>%.2f</td></tr>", mnl_aic, mnp_aic))
      lines <- c(lines, sprintf("<tr><td>N</td><td>%d</td><td>%d</td></tr>", n_obs, n_obs))
    }

    lines <- c(lines, "</table>")

    # Fix formatting
    lines <- gsub("\\.\\{digits\\}f", paste0(".", digits, "f"), lines)

    result <- paste(lines, collapse = "\n")
    if (verbose) cat(result, "\n")
    return(result)

  } else {
    # Markdown format
    lines <- c()

    if (!is.null(caption)) {
      lines <- c(lines, sprintf("**%s**\n", caption))
    }

    # Header
    if (is.null(mnp_fit)) {
      lines <- c(lines, "| Variable | MNL |")
      lines <- c(lines, "|----------|-----|")
    } else {
      lines <- c(lines, "| Variable | MNL | MNP |")
      lines <- c(lines, "|----------|-----|-----|")
    }

    # Coefficients
    for (i in 1:length(mnl_coef_vec)) {
      var_label <- names(mnl_coef_vec)[i]

      if (is.null(mnp_fit)) {
        lines <- c(lines, sprintf(
          paste0("| %s | %.", digits, "f%s (%.", digits, "f) |"),
          var_label,
          mnl_coef_vec[i],
          stars_mnl[i],
          mnl_se[i]
        ))
      } else {
        lines <- c(lines, sprintf(
          paste0("| %s | %.", digits, "f%s (%.", digits, "f) | %.", digits, "f%s (%.", digits, "f) |"),
          var_label,
          mnl_coef_vec[i],
          stars_mnl[i],
          mnl_se[i],
          mnp_coef_vec[i],
          stars_mnp[i],
          mnp_se[i]
        ))
      }
    }

    # Fit stats
    lines <- c(lines, "|----------|-----|-----|")
    if (is.null(mnp_fit)) {
      lines <- c(lines, sprintf("| Log-likelihood | %.2f |", mnl_ll))
      lines <- c(lines, sprintf("| AIC | %.2f |", mnl_aic))
      lines <- c(lines, sprintf("| N | %d |", n_obs))
    } else {
      lines <- c(lines, sprintf("| Log-likelihood | %.2f | %.2f |", mnl_ll, mnp_ll))
      lines <- c(lines, sprintf("| AIC | %.2f | %.2f |", mnl_aic, mnp_aic))
      lines <- c(lines, sprintf("| N | %d | %d |", n_obs, n_obs))
    }

    if (stars) {
      lines <- c(lines, "\n* p<0.05, ** p<0.01, *** p<0.001")
    }

    # Fix formatting
    lines <- gsub("\\.\\{digits\\}f", paste0(".", digits, "f"), lines)

    result <- paste(lines, collapse = "\n")
    if (verbose) cat(result, "\n")
    return(result)
  }
}
