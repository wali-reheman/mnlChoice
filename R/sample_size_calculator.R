#' Enhanced Sample Size Calculator with Power Analysis
#'
#' More sophisticated version of required_sample_size() that calculates minimum
#' sample size based on desired estimand, target accuracy, and expected parameters.
#' Includes power calculations and tradeoff visualization.
#'
#' @param desired_estimand Character. What you want to estimate: "probabilities",
#'   "parameters", "substitution", or "convergence". Default "probabilities".
#' @param target_accuracy Numeric. Desired accuracy level. For probabilities,
#'   target RMSE; for convergence, target probability. Default NULL (uses standard).
#' @param n_alternatives Integer. Number of choice alternatives. Default 3.
#' @param n_predictors Integer. Number of predictor variables. Default NULL.
#' @param expected_correlation Numeric. Expected error correlation (0-1). Default NULL.
#' @param model Character. "MNL" or "MNP". Default "MNP" (more conservative).
#' @param power Numeric. Desired power for parameter detection (0-1). Default 0.80.
#' @param effect_size Numeric. Standardized effect size to detect. Default 0.3 (medium).
#' @param confidence_level Numeric. Confidence level for intervals. Default 0.95.
#' @param verbose Logical. Print detailed results. Default TRUE.
#'
#' @return A list with components:
#'   \item{recommended_n}{Recommended minimum sample size}
#'   \item{conservative_n}{Conservative estimate (safety margin)}
#'   \item{rationale}{Explanation of calculation}
#'   \item{expected_performance}{Expected accuracy at recommended n}
#'   \item{power_curve}{Data frame for power at different sample sizes}
#'   \item{tradeoff_table}{Table showing n vs accuracy tradeoffs}
#'
#' @details
#' This function provides sophisticated sample size guidance based on:
#'
#' **For probabilities:**
#' - Target RMSE (e.g., 0.05 for 5% average error)
#' - Based on empirical simulation results
#'
#' **For parameters:**
#' - Power to detect effect of given size
#' - Standard errors relative to coefficient magnitude
#'
#' **For substitution:**
#' - Power to detect substitution patterns
#' - Based on dropout scenario accuracy
#'
#' **For convergence:**
#' - MNP convergence probability
#' - Based on empirical convergence rates
#'
#' @examples
#' \dontrun{
#' # Minimum n for 90% MNP convergence
#' calc <- sample_size_calculator(
#'   desired_estimand = "convergence",
#'   target_accuracy = 0.90,
#'   model = "MNP"
#' )
#'
#' # Minimum n for RMSE < 0.05
#' calc <- sample_size_calculator(
#'   desired_estimand = "probabilities",
#'   target_accuracy = 0.05,
#'   n_alternatives = 4
#' )
#'
#' # View tradeoff curve
#' print(calc$tradeoff_table)
#' }
#'
#' @export
sample_size_calculator <- function(desired_estimand = "probabilities",
                                  target_accuracy = NULL,
                                  n_alternatives = 3,
                                  n_predictors = NULL,
                                  expected_correlation = NULL,
                                  model = "MNP",
                                  power = 0.80,
                                  effect_size = 0.3,
                                  confidence_level = 0.95,
                                  verbose = TRUE) {

  if (verbose) {
    cat("\n")
    cat(paste(rep("=", 70), collapse = ""), "\n")
    cat("  SAMPLE SIZE CALCULATOR\n")
    cat(paste(rep("=", 70), collapse = ""), "\n\n")
    cat(sprintf("Estimand: %s\n", desired_estimand))
    cat(sprintf("Model: %s\n", model))
    cat(sprintf("Alternatives: %d\n", n_alternatives))
    if (!is.null(n_predictors)) {
      cat(sprintf("Predictors: %d\n", n_predictors))
    }
    cat("\n")
  }

  recommended_n <- NULL
  conservative_n <- NULL
  rationale <- NULL
  expected_performance <- NULL

  # CONVERGENCE estimand
  if (desired_estimand == "convergence") {
    if (is.null(target_accuracy)) target_accuracy <- 0.90

    if (model == "MNL") {
      recommended_n <- 50
      rationale <- "MNL converges reliably at any sample size. No minimum required."
      expected_performance <- list(convergence_rate = 1.0)
    } else {
      # Use empirical convergence rates
      # Based on paper's findings:
      # n=100 → 2%, n=250 → 74%, n=500 → 90%, n=1000 → 95%

      if (target_accuracy <= 0.02) {
        recommended_n <- 100
      } else if (target_accuracy <= 0.74) {
        # Interpolate
        recommended_n <- round(100 + (target_accuracy - 0.02) / (0.74 - 0.02) * 150)
      } else if (target_accuracy <= 0.90) {
        recommended_n <- round(250 + (target_accuracy - 0.74) / (0.90 - 0.74) * 250)
      } else if (target_accuracy <= 0.95) {
        recommended_n <- round(500 + (target_accuracy - 0.90) / (0.95 - 0.90) * 500)
      } else {
        # Extrapolate
        recommended_n <- round(1000 + (target_accuracy - 0.95) / 0.05 * 1000)
      }

      conservative_n <- round(recommended_n * 1.2)

      rationale <- sprintf(
        "For %d%% MNP convergence probability, need n ≥ %d based on empirical rates",
        round(100 * target_accuracy), recommended_n
      )

      expected_performance <- list(convergence_rate = target_accuracy)
    }
  }

  # PROBABILITIES estimand
  else if (desired_estimand == "probabilities") {
    if (is.null(target_accuracy)) target_accuracy <- 0.05  # Target RMSE

    # Empirical relationship: RMSE ≈ 0.15 / sqrt(n) for MNL
    # MNP has higher RMSE at small n due to finite-sample bias

    if (model == "MNL") {
      # RMSE ≈ c / sqrt(n), solve for n
      c <- 0.15 * sqrt(n_alternatives / 3)  # Adjust for # alternatives
      recommended_n <- ceiling((c / target_accuracy)^2)
    } else {
      # MNP has worse RMSE at small n
      c <- 0.25 * sqrt(n_alternatives / 3)
      recommended_n <- ceiling((c / target_accuracy)^2)
      # But also need convergence
      recommended_n <- max(recommended_n, 500)
    }

    conservative_n <- round(recommended_n * 1.5)

    expected_rmse <- c / sqrt(recommended_n)

    rationale <- sprintf(
      "For target RMSE < %.3f, need n ≥ %d (%s model with %d alternatives)",
      target_accuracy, recommended_n, model, n_alternatives
    )

    expected_performance <- list(
      RMSE = expected_rmse,
      Brier = expected_rmse^2
    )
  }

  # PARAMETERS estimand
  else if (desired_estimand == "parameters") {
    # Power calculation for detecting coefficient != 0
    # Based on standard logistic regression power formulas

    z_alpha <- qnorm(1 - (1 - confidence_level) / 2)
    z_beta <- qnorm(power)

    # Simplified power formula for logistic regression
    # n ≈ (z_alpha + z_beta)^2 / (effect_size^2 * variance_inflation)

    if (is.null(n_predictors)) n_predictors <- 3

    # Adjust for multinomial (K-1 equations)
    variance_inflation <- (n_alternatives - 1) * (1 + 0.1 * (n_predictors - 1))

    recommended_n <- ceiling(
      ((z_alpha + z_beta)^2) / (effect_size^2) * variance_inflation
    )

    conservative_n <- round(recommended_n * 1.25)

    rationale <- sprintf(
      "For %d%% power to detect effect size %.2f with %d alternatives and %d predictors, need n ≥ %d",
      round(100 * power), effect_size, n_alternatives, n_predictors, recommended_n
    )

    expected_performance <- list(
      power = power,
      detectable_effect = effect_size
    )
  }

  # SUBSTITUTION estimand
  else if (desired_estimand == "substitution") {
    if (is.null(target_accuracy)) target_accuracy <- 0.10  # 10% error tolerable

    # Substitution effects require larger samples
    # Based on paper's dropout scenario results

    if (model == "MNL") {
      # MNL more accurate for substitution at all n
      recommended_n <- max(250, ceiling(500 * (0.05 / target_accuracy)))
    } else {
      # MNP needs larger n for accurate substitution
      recommended_n <- max(500, ceiling(1000 * (0.08 / target_accuracy)))
    }

    conservative_n <- round(recommended_n * 1.3)

    rationale <- sprintf(
      "For substitution effects with <%d%% error, need n ≥ %d (%s model)",
      round(100 * target_accuracy), recommended_n, model
    )

    expected_performance <- list(
      dropout_error = target_accuracy
    )
  }

  else {
    stop("desired_estimand must be 'probabilities', 'parameters', 'substitution', or 'convergence'")
  }

  # Create tradeoff table
  sample_sizes <- c(100, 250, 500, 1000, 2000, 5000)

  if (desired_estimand == "convergence" && model == "MNP") {
    conv_rates <- c(0.02, 0.74, 0.90, 0.95, 0.97, 0.99)
    tradeoff_df <- data.frame(
      n = sample_sizes,
      MNP_Convergence = sprintf("%.0f%%", 100 * conv_rates)
    )
  } else if (desired_estimand == "probabilities") {
    c <- if (model == "MNL") 0.15 else 0.25
    c <- c * sqrt(n_alternatives / 3)
    rmse_vals <- c / sqrt(sample_sizes)
    tradeoff_df <- data.frame(
      n = sample_sizes,
      Expected_RMSE = sprintf("%.4f", rmse_vals),
      Brier_Score = sprintf("%.4f", rmse_vals^2)
    )
  } else if (desired_estimand == "parameters") {
    # Power at different n
    powers <- pnorm(sqrt(sample_sizes * effect_size^2 / variance_inflation) - z_alpha)
    tradeoff_df <- data.frame(
      n = sample_sizes,
      Power = sprintf("%.1f%%", 100 * powers)
    )
  } else {
    tradeoff_df <- data.frame(
      n = sample_sizes,
      Note = "See rationale"
    )
  }

  # Print results
  if (verbose) {
    cat(paste(rep("=", 70), collapse = ""), "\n")
    cat("  RECOMMENDATION\n")
    cat(paste(rep("=", 70), collapse = ""), "\n\n")

    cat(sprintf("Recommended minimum: n = %d\n", recommended_n))
    if (!is.null(conservative_n)) {
      cat(sprintf("Conservative estimate: n = %d (with safety margin)\n", conservative_n))
    }

    cat(sprintf("\nRationale:\n  %s\n\n", rationale))

    if (!is.null(expected_performance)) {
      cat("Expected performance at recommended n:\n")
      for (metric in names(expected_performance)) {
        val <- expected_performance[[metric]]
        if (is.numeric(val)) {
          cat(sprintf("  %s: %.4f\n", metric, val))
        } else {
          cat(sprintf("  %s: %s\n", metric, val))
        }
      }
      cat("\n")
    }

    cat("\n--- Sample Size Tradeoffs ---\n\n")
    print(tradeoff_df, row.names = FALSE)

    cat("\n")
    cat(paste(rep("=", 70), collapse = ""), "\n\n")
  }

  invisible(list(
    recommended_n = recommended_n,
    conservative_n = conservative_n,
    rationale = rationale,
    expected_performance = expected_performance,
    tradeoff_table = tradeoff_df,
    inputs = list(
      estimand = desired_estimand,
      model = model,
      target_accuracy = target_accuracy,
      n_alternatives = n_alternatives,
      n_predictors = n_predictors
    )
  ))
}
