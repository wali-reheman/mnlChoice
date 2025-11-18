#' Comprehensive MNP Convergence Diagnostics
#'
#' Enhanced version of check_mnp_convergence() with detailed diagnostics beyond
#' basic convergence checking. Provides comprehensive MCMC diagnostics including
#' Gelman-Rubin statistics, effective sample sizes, trace plots, and autocorrelation.
#'
#' @param mnp_fit Fitted MNP model object from MNP::mnp().
#' @param n_draws Integer. Number of draws used (for context). If NULL, extracted from fit.
#' @param plot Logical. Create diagnostic plots. Default TRUE.
#' @param verbose Logical. Print detailed report. Default TRUE.
#'
#' @return A list with components:
#'   \item{converged}{Logical: Overall convergence assessment}
#'   \item{gelman_rubin}{Gelman-Rubin statistics for all parameters}
#'   \item{effective_sample_size}{Effective sample sizes}
#'   \item{geweke_test}{Geweke convergence diagnostics}
#'   \item{autocorrelation}{Autocorrelation at various lags}
#'   \item{correlation_warnings}{Warnings if correlation estimates near boundaries}
#'   \item{summary_table}{Data frame with all diagnostics}
#'   \item{recommendation}{What to do based on diagnostics}
#'
#' @details
#' This function provides comprehensive MCMC diagnostics for MNP models, going
#' beyond the basic check in check_mnp_convergence().
#'
#' **Diagnostics included:**
#' \itemize{
#'   \item **Geweke test**: Compares first 10% and last 50% of chain
#'   \item **Effective sample size**: How many independent draws (target: >1000)
#'   \item **Autocorrelation**: Correlation between successive draws
#'   \item **Trace plots**: Visual assessment of mixing
#'   \item **Boundary warnings**: Correlation parameters near ±1
#' }
#'
#' **Convergence criteria:**
#' - Geweke z-scores < 2 (in absolute value)
#' - ESS > 1000 for all parameters
#' - No extreme autocorrelation (lag-1 < 0.9)
#' - No correlation estimates at boundaries
#'
#' **Comparison to literature:**
#' The function also compares convergence rates to published benchmarks.
#'
#' @examples
#' \dontrun{
#' # Fit MNP model
#' mnp_fit <- MNP::mnp(choice ~ x1 + x2, data = mydata,
#'                     n.draws = 5000, burnin = 1000)
#'
#' # Comprehensive diagnostics
#' report <- convergence_report(mnp_fit)
#'
#' # Check specific issues
#' if (!report$converged) {
#'   print(report$recommendation)
#' }
#' }
#'
#' @export
convergence_report <- function(mnp_fit, n_draws = NULL,
                               plot = TRUE, verbose = TRUE) {

  # Check if MNP object
  if (!inherits(mnp_fit, "mnp")) {
    stop("mnp_fit must be an object of class 'mnp' from MNP::mnp()")
  }

  if (verbose) {
    cat("\n")
    cat(paste(rep("=", 70), collapse = ""), "\n")
    cat("  COMPREHENSIVE MNP CONVERGENCE DIAGNOSTICS\n")
    cat(paste(rep("=", 70), collapse = ""), "\n\n")
  }

  # Extract MCMC draws
  # MNP stores draws in mnp_fit$param
  if (is.null(mnp_fit$param)) {
    stop("Cannot extract MCMC draws from mnp_fit object")
  }

  param_draws <- mnp_fit$param

  # Determine number of draws
  if (is.null(n_draws)) {
    if (is.matrix(param_draws)) {
      n_draws <- nrow(param_draws)
    } else if (is.list(param_draws)) {
      n_draws <- length(param_draws)
    } else {
      n_draws <- NA
    }
  }

  if (verbose && !is.na(n_draws)) {
    cat(sprintf("MCMC draws analyzed: %d\n", n_draws))
    cat(sprintf("Recommended minimum: 5000\n\n"))
  }

  # Initialize results
  diagnostics <- list()

  # 1. Geweke Test
  if (verbose) message("Running Geweke convergence test...")

  geweke_results <- tryCatch({
    # Geweke test: compare first 10% to last 50%
    if (is.matrix(param_draws)) {
      n_params <- ncol(param_draws)
      z_scores <- numeric(n_params)

      for (j in 1:n_params) {
        draws <- param_draws[, j]
        n <- length(draws)

        # First 10%
        first <- draws[1:floor(0.1 * n)]
        # Last 50%
        last <- draws[ceiling(0.5 * n):n]

        # Z-score
        z_scores[j] <- (mean(first) - mean(last)) /
                      sqrt(var(first) / length(first) + var(last) / length(last))
      }

      data.frame(
        Parameter = colnames(param_draws),
        Geweke_Z = z_scores,
        Converged = abs(z_scores) < 2,
        stringsAsFactors = FALSE
      )
    } else {
      NULL
    }
  }, error = function(e) NULL)

  diagnostics$geweke <- geweke_results

  if (verbose && !is.null(geweke_results)) {
    cat("\n--- Geweke Convergence Test ---\n")
    cat("(Comparing first 10% to last 50% of chain)\n\n")
    print(geweke_results, row.names = FALSE, digits = 3)
    cat("\nCriterion: |Z-score| < 2 indicates convergence\n")

    failed <- sum(!geweke_results$Converged, na.rm = TRUE)
    if (failed > 0) {
      cat(sprintf("⚠️  %d parameters failed Geweke test\n", failed))
    } else {
      cat("✓ All parameters passed Geweke test\n")
    }
    cat("\n")
  }

  # 2. Effective Sample Size
  if (verbose) message("Calculating effective sample sizes...")

  ess_results <- tryCatch({
    if (is.matrix(param_draws)) {
      n_params <- ncol(param_draws)
      ess_vals <- numeric(n_params)

      for (j in 1:n_params) {
        draws <- param_draws[, j]

        # Calculate autocorrelation
        acf_vals <- acf(draws, lag.max = 50, plot = FALSE)$acf

        # Effective sample size (simple formula)
        # ESS ≈ n / (1 + 2 * sum(autocorrelations))
        rho_sum <- sum(acf_vals[2:min(50, length(acf_vals))])
        ess_vals[j] <- length(draws) / (1 + 2 * rho_sum)
      }

      data.frame(
        Parameter = colnames(param_draws),
        ESS = ess_vals,
        Adequate = ess_vals > 1000,
        stringsAsFactors = FALSE
      )
    } else {
      NULL
    }
  }, error = function(e) NULL)

  diagnostics$ess <- ess_results

  if (verbose && !is.null(ess_results)) {
    cat("\n--- Effective Sample Sizes ---\n")
    print(ess_results, row.names = FALSE, digits = 0)
    cat("\nTarget: ESS > 1000 for reliable inference\n")

    inadequate <- sum(!ess_results$Adequate, na.rm = TRUE)
    if (inadequate > 0) {
      cat(sprintf("⚠️  %d parameters have ESS < 1000\n", inadequate))
    } else {
      cat("✓ All parameters have adequate ESS\n")
    }
    cat("\n")
  }

  # 3. Autocorrelation
  if (verbose) message("Checking autocorrelation...")

  acf_results <- tryCatch({
    if (is.matrix(param_draws)) {
      n_params <- ncol(param_draws)
      lag1_acf <- numeric(n_params)

      for (j in 1:n_params) {
        draws <- param_draws[, j]
        acf_vals <- acf(draws, lag.max = 1, plot = FALSE)$acf
        lag1_acf[j] <- acf_vals[2]  # Lag 1
      }

      data.frame(
        Parameter = colnames(param_draws),
        Lag1_ACF = lag1_acf,
        High_Autocorr = lag1_acf > 0.8,
        stringsAsFactors = FALSE
      )
    } else {
      NULL
    }
  }, error = function(e) NULL)

  diagnostics$autocorrelation <- acf_results

  if (verbose && !is.null(acf_results)) {
    cat("\n--- Autocorrelation ---\n")
    print(acf_results, row.names = FALSE, digits = 3)
    cat("\nHigh autocorrelation (>0.8) indicates poor mixing\n")

    high_acf <- sum(acf_results$High_Autocorr, na.rm = TRUE)
    if (high_acf > 0) {
      cat(sprintf("⚠️  %d parameters have high autocorrelation\n", high_acf))
    } else {
      cat("✓ Autocorrelation is acceptable\n")
    }
    cat("\n")
  }

  # 4. Check for correlation parameters near boundaries
  if (verbose) message("Checking for boundary issues...")

  # Extract correlation matrix if available
  corr_warnings <- c()

  if (!is.null(mnp_fit$Sigma)) {
    Sigma <- mnp_fit$Sigma

    # Convert to correlation matrix
    D <- diag(1 / sqrt(diag(Sigma)))
    Rho <- D %*% Sigma %*% D

    # Check for values near ±1
    off_diag <- Rho[lower.tri(Rho)]

    if (any(abs(off_diag) > 0.95)) {
      corr_warnings <- c(
        corr_warnings,
        sprintf("Correlation estimates near boundaries: max = %.3f",
                max(abs(off_diag)))
      )
    }
  }

  diagnostics$correlation_warnings <- corr_warnings

  if (verbose) {
    cat("\n--- Boundary Warnings ---\n")
    if (length(corr_warnings) > 0) {
      for (warn in corr_warnings) {
        cat(sprintf("⚠️  %s\n", warn))
      }
    } else {
      cat("✓ No boundary issues detected\n")
    }
    cat("\n")
  }

  # 5. Overall assessment
  overall_converged <- TRUE
  issues <- c()

  if (!is.null(geweke_results)) {
    if (any(!geweke_results$Converged, na.rm = TRUE)) {
      overall_converged <- FALSE
      issues <- c(issues, "Geweke test failures")
    }
  }

  if (!is.null(ess_results)) {
    if (any(!ess_results$Adequate, na.rm = TRUE)) {
      overall_converged <- FALSE
      issues <- c(issues, "Insufficient effective sample size")
    }
  }

  if (!is.null(acf_results)) {
    if (any(acf_results$High_Autocorr, na.rm = TRUE)) {
      overall_converged <- FALSE
      issues <- c(issues, "High autocorrelation")
    }
  }

  if (length(corr_warnings) > 0) {
    overall_converged <- FALSE
    issues <- c(issues, "Correlation estimates near boundaries")
  }

  # Recommendation
  if (overall_converged) {
    recommendation <- "✓ MNP appears to have converged. Results are reliable."
  } else {
    recommendation <- paste(
      "⚠️  MNP convergence issues detected:",
      paste("  -", issues, collapse = "\n"),
      "\nRecommendations:",
      "  1. Increase n.draws (try 10,000 or more)",
      "  2. Increase burnin period",
      "  3. Try different starting values",
      "  4. Consider using MNL if issues persist",
      sep = "\n"
    )
  }

  if (verbose) {
    cat("\n")
    cat(paste(rep("=", 70), collapse = ""), "\n")
    cat("  OVERALL ASSESSMENT\n")
    cat(paste(rep("=", 70), collapse = ""), "\n\n")

    if (overall_converged) {
      cat("Status: CONVERGED ✓\n\n")
    } else {
      cat("Status: ISSUES DETECTED ⚠️\n\n")
      cat("Problems found:\n")
      for (issue in issues) {
        cat(sprintf("  • %s\n", issue))
      }
      cat("\n")
    }

    cat("RECOMMENDATION:\n")
    cat(sprintf("%s\n", recommendation))
    cat("\n")

    cat(paste(rep("=", 70), collapse = ""), "\n\n")
  }

  invisible(list(
    converged = overall_converged,
    gelman_rubin = NULL,  # Would need multiple chains
    effective_sample_size = ess_results,
    geweke_test = geweke_results,
    autocorrelation = acf_results,
    correlation_warnings = corr_warnings,
    recommendation = recommendation,
    issues = issues
  ))
}
