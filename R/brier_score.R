#' Calculate Brier Score with Decomposition
#'
#' Standalone function for Brier score calculation with optional decomposition
#' into calibration, refinement, and uncertainty components. Helps diagnose
#' WHY a model performs poorly.
#'
#' @param predicted_probs Matrix of predicted probabilities (n x K alternatives).
#' @param actual_choices Factor or integer vector of actual choices.
#' @param decompose Logical. Decompose into components. Default TRUE.
#' @param by_alternative Logical. Calculate score separately for each alternative. Default FALSE.
#' @param verbose Logical. Print detailed results. Default TRUE.
#'
#' @return A list with components:
#'   \item{brier_score}{Overall Brier score}
#'   \item{calibration}{Calibration component (if decompose=TRUE)}
#'   \item{refinement}{Refinement component (if decompose=TRUE)}
#'   \item{uncertainty}{Uncertainty component (if decompose=TRUE)}
#'   \item{by_alternative}{Brier scores by alternative (if by_alternative=TRUE)}
#'   \item{interpretation}{Text interpretation of results}
#'
#' @details
#' **Brier score** measures accuracy of probabilistic predictions:
#' BS = (1/n) * sum((p_ij - y_ij)^2)
#'
#' Lower is better (perfect predictions = 0, worst = 2 for binary).
#'
#' **Decomposition:**
#' \itemize{
#'   \item **Calibration**: Are predicted probabilities well-calibrated?
#'   \item **Refinement**: Does model distinguish between easy and hard cases?
#'   \item **Uncertainty**: Inherent unpredictability in data
#' }
#'
#' This decomposition helps diagnose model problems:
#' - High calibration → probabilities systematically wrong
#' - Low refinement → model can't distinguish cases
#' - High uncertainty → inherently noisy data
#'
#' @examples
#' \dontrun{
#' # Fit model
#' mnl <- nnet::multinom(choice ~ x1 + x2, data = mydata)
#'
#' # Get predictions
#' probs <- fitted(mnl)
#'
#' # Calculate Brier score
#' brier <- brier_score(probs, mydata$choice, decompose = TRUE)
#'
#' # Diagnose issues
#' print(brier$interpretation)
#' }
#'
#' @export
brier_score <- function(predicted_probs, actual_choices,
                       decompose = TRUE,
                       by_alternative = FALSE,
                       verbose = TRUE) {

  # Input validation
  if (!is.matrix(predicted_probs) && !is.data.frame(predicted_probs)) {
    # Convert vector to matrix (binary case)
    predicted_probs <- cbind(1 - predicted_probs, predicted_probs)
  }

  predicted_probs <- as.matrix(predicted_probs)

  # Ensure actual_choices is factor
  if (!is.factor(actual_choices)) {
    actual_choices <- factor(actual_choices)
  }

  n <- nrow(predicted_probs)
  K <- ncol(predicted_probs)

  # Convert actual choices to dummy matrix
  y_dummy <- model.matrix(~ actual_choices - 1)

  # Handle dimension mismatch
  if (ncol(y_dummy) < K) {
    # Add reference category
    y_dummy <- cbind(1 - rowSums(y_dummy), y_dummy)
  } else if (ncol(y_dummy) > K) {
    y_dummy <- y_dummy[, 1:K]
  }

  # Calculate overall Brier score
  brier <- mean((y_dummy - predicted_probs)^2)

  if (verbose) {
    cat("\n")
    cat(paste(rep("=", 70), collapse = ""), "\n")
    cat("  BRIER SCORE ANALYSIS\n")
    cat(paste(rep("=", 70), collapse = ""), "\n\n")
    cat(sprintf("Overall Brier Score: %.4f\n", brier))
    cat("(Lower is better; 0 = perfect, ~1 = poor for multinomial)\n\n")
  }

  # Decomposition
  calibration <- NA
  refinement <- NA
  uncertainty <- NA

  if (decompose) {
    # Murphy decomposition
    # BS = Uncertainty - Resolution + Reliability

    # Group observations by predicted probability bins
    n_bins <- min(10, ceiling(n / 20))  # At least 20 obs per bin

    # For simplicity, use predicted probability of actual choice
    actual_idx <- as.numeric(actual_choices)
    pred_for_actual <- predicted_probs[cbind(1:n, actual_idx)]

    # Bin predictions
    bins <- cut(pred_for_actual, breaks = n_bins, include.lowest = TRUE)

    # Calculate components by bin
    bin_stats <- aggregate(
      cbind(pred = pred_for_actual, actual = 1),
      by = list(bin = bins),
      FUN = function(x) c(mean = mean(x), n = length(x))
    )

    # Uncertainty component (inherent in outcomes)
    p_bar <- mean(y_dummy)  # Overall base rate
    uncertainty <- mean(p_bar * (1 - p_bar))

    # Resolution component (how well model discriminates)
    resolution <- 0
    for (b in unique(bins)) {
      idx_b <- which(bins == b)
      n_b <- length(idx_b)
      p_b <- mean(pred_for_actual[idx_b])
      resolution <- resolution + (n_b / n) * (p_b - p_bar)^2
    }

    # Reliability component (calibration error)
    reliability <- 0
    for (b in unique(bins)) {
      idx_b <- which(bins == b)
      n_b <- length(idx_b)
      o_b <- mean(actual_idx[idx_b] == actual_idx[idx_b])  # Observed frequency
      p_b <- mean(pred_for_actual[idx_b])  # Predicted probability
      reliability <- reliability + (n_b / n) * (o_b - p_b)^2
    }

    calibration <- reliability
    refinement <- resolution

    if (verbose) {
      cat("\n--- Brier Score Decomposition ---\n")
      cat("BS = Uncertainty - Refinement + Calibration\n\n")
      cat(sprintf("  Uncertainty:  %.4f  (inherent unpredictability)\n", uncertainty))
      cat(sprintf("  Refinement:   %.4f  (model's ability to discriminate)\n", refinement))
      cat(sprintf("  Calibration:  %.4f  (calibration error)\n", calibration))
      cat("\n")

      cat("Interpretation:\n")

      if (calibration > 0.1) {
        cat("  ⚠️  High calibration error - probabilities systematically wrong\n")
      } else {
        cat("  ✓ Good calibration - probabilities are well-calibrated\n")
      }

      if (refinement < 0.05) {
        cat("  ⚠️  Low refinement - model struggles to distinguish cases\n")
      } else {
        cat("  ✓ Good refinement - model discriminates well\n")
      }

      if (uncertainty > 0.2) {
        cat("  • High uncertainty - data is inherently noisy\n")
      }

      cat("\n")
    }
  }

  # By alternative
  by_alt_scores <- NULL

  if (by_alternative) {
    by_alt_scores <- numeric(K)

    for (k in 1:K) {
      by_alt_scores[k] <- mean((y_dummy[, k] - predicted_probs[, k])^2)
    }

    names(by_alt_scores) <- colnames(predicted_probs)
    if (is.null(names(by_alt_scores))) {
      names(by_alt_scores) <- paste0("Alt", 1:K)
    }

    if (verbose) {
      cat("\n--- Brier Score by Alternative ---\n")
      for (k in 1:K) {
        cat(sprintf("  %s: %.4f\n", names(by_alt_scores)[k], by_alt_scores[k]))
      }
      cat("\n")
    }
  }

  # Interpretation
  interpretation <- c()

  if (brier < 0.1) {
    interpretation <- c(interpretation, "Excellent prediction accuracy (BS < 0.1)")
  } else if (brier < 0.2) {
    interpretation <- c(interpretation, "Good prediction accuracy (BS < 0.2)")
  } else if (brier < 0.3) {
    interpretation <- c(interpretation, "Moderate prediction accuracy (BS < 0.3)")
  } else {
    interpretation <- c(interpretation, "Poor prediction accuracy (BS ≥ 0.3)")
  }

  if (decompose) {
    if (!is.na(calibration) && calibration > 0.1) {
      interpretation <- c(
        interpretation,
        "Main issue: Calibration - predicted probabilities are systematically biased"
      )
    } else if (!is.na(refinement) && refinement < 0.05) {
      interpretation <- c(
        interpretation,
        "Main issue: Refinement - model cannot distinguish between cases"
      )
    } else {
      interpretation <- c(
        interpretation,
        "Model is well-calibrated and discriminates adequately"
      )
    }
  }

  if (verbose) {
    cat("\n")
    cat(paste(rep("=", 70), collapse = ""), "\n")
    cat("SUMMARY:\n")
    for (line in interpretation) {
      cat(sprintf("  • %s\n", line))
    }
    cat(paste(rep("=", 70), collapse = ""), "\n\n")
  }

  invisible(list(
    brier_score = brier,
    calibration = calibration,
    refinement = refinement,
    uncertainty = uncertainty,
    by_alternative = by_alt_scores,
    interpretation = interpretation,
    n_observations = n,
    n_alternatives = K
  ))
}
