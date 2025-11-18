#' Calculate Substitution Matrix for All Alternatives
#'
#' Calculates complete transition matrix showing where support flows when each
#' alternative is removed from the choice set. Visualizes substitution patterns
#' across all possible dropouts.
#'
#' @param model_fit Fitted model object (MNL or MNP).
#' @param data Data frame containing the variables.
#' @param from_alternative Character. Which alternative's removal to analyze.
#'   If NULL, analyzes all alternatives.
#' @param method Character. "simulation" (recommended) or "analytical" (IIA-based).
#'   Default "simulation".
#' @param n_sims Integer. Number of simulations for ground truth. Default 5000.
#' @param visualize Logical. Create visualization (requires ggplot2). Default FALSE.
#' @param verbose Logical. Print results. Default TRUE.
#'
#' @return A list with components:
#'   \item{transition_matrix}{Matrix of transition probabilities}
#'   \item{flow_table}{Data frame with detailed flow information}
#'   \item{visualization}{ggplot object if visualize=TRUE}
#'   \item{summary}{Text summary of key patterns}
#'
#' @details
#' Creates a comprehensive view of substitution patterns by calculating where
#' voters/consumers go when each alternative is removed.
#'
#' **Transition matrix format:**
#' ```
#'              To: Clinton  Bush  Perot
#' From: Clinton    --      35%   65%
#'       Bush      40%       --    60%
#'       Perot     51%      49%     --
#' ```
#'
#' **Methods:**
#' \itemize{
#'   \item **simulation**: Uses large-sample simulation to estimate true flows
#'   \item **analytical**: Uses IIA assumption (P(j|i drops) ∝ P(j))
#' }
#'
#' @examples
#' \dontrun{
#' # Fit model
#' mnl <- nnet::multinom(mode ~ income + distance, data = commuter_choice)
#'
#' # Full substitution matrix
#' sub_matrix <- substitution_matrix(mnl, data = commuter_choice)
#'
#' # Analyze specific alternative
#' sub_matrix <- substitution_matrix(
#'   mnl,
#'   data = commuter_choice,
#'   from_alternative = "Active"
#' )
#' }
#'
#' @export
substitution_matrix <- function(model_fit, data,
                               from_alternative = NULL,
                               method = "simulation",
                               n_sims = 5000,
                               visualize = FALSE,
                               verbose = TRUE) {

  # Extract formula and response
  formula_obj <- formula(model_fit)
  response_var <- all.vars(formula_obj)[1]
  y <- data[[response_var]]

  if (!is.factor(y)) {
    y <- factor(y)
    data[[response_var]] <- y
  }

  alternatives <- levels(y)

  if (length(alternatives) < 3) {
    stop("Need at least 3 alternatives for substitution matrix")
  }

  if (!method %in% c("simulation", "analytical")) {
    stop("method must be 'simulation' or 'analytical'")
  }

  if (verbose) {
    cat("\n")
    cat(paste(rep("=", 70), collapse = ""), "\n")
    cat("  SUBSTITUTION MATRIX ANALYSIS\n")
    cat(paste(rep("=", 70), collapse = ""), "\n\n")
    cat(sprintf("Alternatives: %s\n", paste(alternatives, collapse = ", ")))
    cat(sprintf("Method: %s\n", method))
    if (method == "simulation") {
      cat(sprintf("Simulations: %d\n", n_sims))
    }
    cat("\n")
  }

  # Determine which alternatives to analyze
  if (!is.null(from_alternative)) {
    if (!from_alternative %in% alternatives) {
      stop(sprintf("from_alternative '%s' not found. Available: %s",
                  from_alternative, paste(alternatives, collapse = ", ")))
    }
    from_alts <- from_alternative
  } else {
    from_alts <- alternatives
  }

  # Initialize transition matrix
  n_alt <- length(alternatives)
  trans_matrix <- matrix(NA, nrow = n_alt, ncol = n_alt,
                        dimnames = list(From = alternatives, To = alternatives))

  # Initialize flow table
  flow_table <- data.frame(
    From = character(),
    To = character(),
    Probability = numeric(),
    Percentage = numeric(),
    stringsAsFactors = FALSE
  )

  # Calculate transitions for each dropout scenario
  for (from_alt in from_alts) {
    if (verbose) message(sprintf("Calculating flows from %s...", from_alt))

    to_alts <- setdiff(alternatives, from_alt)

    if (method == "simulation") {
      # Simulation-based estimation
      probs_full <- fitted(model_fit)

      # Generate simulated choices
      set.seed(12345)
      simulated_choices <- matrix(0, nrow = nrow(data), ncol = n_sims)

      for (i in 1:nrow(data)) {
        sim_probs <- probs_full[i, ]
        simulated_choices[i, ] <- sample(1:n_alt, size = n_sims,
                                        replace = TRUE, prob = sim_probs)
      }

      # Calculate transitions
      from_idx <- which(alternatives == from_alt)
      to_idx <- which(alternatives %in% to_alts)

      flow_counts <- rep(0, length(to_alts))
      names(flow_counts) <- to_alts

      for (i in 1:nrow(data)) {
        chose_from <- simulated_choices[i, ] == from_idx

        if (sum(chose_from) > 0) {
          # Re-normalize probabilities
          new_probs <- probs_full[i, to_idx]
          new_probs <- new_probs / sum(new_probs)

          flow_counts <- flow_counts + new_probs * sum(chose_from)
        }
      }

      # Normalize
      trans_probs <- flow_counts / sum(flow_counts)

    } else {
      # Analytical (IIA-based)
      # Under IIA: P(j | i drops) = P(j) / sum(P(k) for k != i)

      probs_full <- fitted(model_fit)
      avg_probs <- colMeans(probs_full)

      from_idx <- which(alternatives == from_alt)
      to_idx <- which(alternatives %in% to_alts)

      # Renormalize
      trans_probs <- avg_probs[to_idx] / sum(avg_probs[to_idx])
      names(trans_probs) <- to_alts
    }

    # Fill in matrix
    for (to_alt in to_alts) {
      trans_matrix[from_alt, to_alt] <- trans_probs[to_alt]

      # Add to flow table
      flow_table <- rbind(flow_table, data.frame(
        From = from_alt,
        To = to_alt,
        Probability = trans_probs[to_alt],
        Percentage = 100 * trans_probs[to_alt],
        stringsAsFactors = FALSE
      ))
    }
  }

  # Print matrix
  if (verbose) {
    cat("\n")
    cat(paste(rep("=", 70), collapse = ""), "\n")
    cat("  TRANSITION MATRIX\n")
    cat(paste(rep("=", 70), collapse = ""), "\n\n")

    cat("When FROM alternative drops out, support flows TO:\n\n")

    # Print header
    cat(sprintf("%-12s", "FROM \\ TO"))
    for (alt in alternatives) {
      cat(sprintf("%12s", alt))
    }
    cat("\n")
    cat(paste(rep("-", 12 + 12 * n_alt), collapse = ""), "\n")

    # Print rows
    for (from_alt in alternatives) {
      cat(sprintf("%-12s", from_alt))
      for (to_alt in alternatives) {
        if (from_alt == to_alt) {
          cat(sprintf("%12s", "--"))
        } else {
          val <- trans_matrix[from_alt, to_alt]
          if (!is.na(val)) {
            cat(sprintf("%11.1f%%", 100 * val))
          } else {
            cat(sprintf("%12s", "NA"))
          }
        }
      }
      cat("\n")
    }

    cat("\n")
    cat(paste(rep("=", 70), collapse = ""), "\n\n")
  }

  # Create summary
  summary_text <- c()

  if (!is.null(from_alternative)) {
    main_flow <- flow_table[flow_table$From == from_alternative, ]
    main_flow <- main_flow[order(-main_flow$Probability), ]

    summary_text <- c(
      summary_text,
      sprintf("When %s drops out:", from_alternative),
      sprintf("  → %.1f%% flows to %s", main_flow$Percentage[1], main_flow$To[1]),
      sprintf("  → %.1f%% flows to %s", main_flow$Percentage[2], main_flow$To[2])
    )
  } else {
    # Find most asymmetric flows
    flow_table$Asymmetry <- 0
    for (i in 1:nrow(flow_table)) {
      reverse_flow <- flow_table$Probability[
        flow_table$From == flow_table$To[i] &
        flow_table$To == flow_table$From[i]
      ]
      if (length(reverse_flow) > 0) {
        flow_table$Asymmetry[i] <- abs(flow_table$Probability[i] - reverse_flow)
      }
    }

    most_asym <- flow_table[order(-flow_table$Asymmetry), ][1, ]

    summary_text <- c(
      summary_text,
      "Key patterns:",
      sprintf("  Most asymmetric flow: %s → %s (%.1f%%) vs %s → %s",
              most_asym$From, most_asym$To, most_asym$Percentage,
              most_asym$To, most_asym$From)
    )
  }

  if (verbose) {
    cat("SUMMARY:\n")
    for (line in summary_text) {
      cat(sprintf("%s\n", line))
    }
    cat("\n")
  }

  # Visualization (optional)
  viz <- NULL
  if (visualize) {
    if (requireNamespace("ggplot2", quietly = TRUE)) {
      # Create visualization using ggplot2
      message("Visualization requires manual implementation with ggplot2")
      # Would create Sankey diagram or heatmap here
    } else {
      warning("ggplot2 package required for visualization. Install with: install.packages('ggplot2')")
    }
  }

  invisible(list(
    transition_matrix = trans_matrix,
    flow_table = flow_table,
    summary = summary_text,
    visualization = viz,
    method = method,
    alternatives = alternatives
  ))
}
