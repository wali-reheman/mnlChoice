#' Recommend MNL or MNP Based on Empirical Evidence
#'
#' Provides evidence-based recommendations for choosing between Multinomial Logit (MNL)
#' and Multinomial Probit (MNP) models based on systematic Monte Carlo simulations.
#'
#' @param n Integer. Sample size of your dataset.
#' @param correlation Numeric. Expected correlation between error terms (0 to 1).
#'   If NULL, recommendation is based on sample size only.
#' @param functional_form Character. Expected functional form: "linear", "quadratic", or "log".
#'   Default is "linear".
#' @param verbose Logical. If TRUE, prints detailed reasoning. Default is TRUE.
#'
#' @return A list with components:
#'   \item{recommendation}{Character: "MNL", "MNP", or "Either"}
#'   \item{confidence}{Character: "High", "Medium", or "Low"}
#'   \item{reason}{Character: Explanation for the recommendation}
#'   \item{expected_mnp_convergence}{Numeric: Expected MNP convergence rate}
#'   \item{expected_mnl_win_rate}{Numeric: Expected probability MNL outperforms MNP}
#'
#' @details
#' Recommendations are based on Monte Carlo simulations with 3,000+ replications
#' showing empirical convergence rates and performance metrics (RMSE, Brier score).
#'
#' Key findings:
#' \itemize{
#'   \item n < 100: Always use MNL (MNP convergence ~2%)
#'   \item n = 100-250: MNL preferred (MNP convergence ~74%, but worse RMSE)
#'   \item n > 500: Either acceptable (MNP convergence ~90%+)
#'   \item High correlation (r > 0.5): Slight MNP advantage if it converges
#'   \item Quadratic functional form: Consider quadratic MNL specification
#' }
#'
#' @examples
#' # Small sample recommendation
#' recommend_model(n = 100)
#'
#' # Medium sample with expected correlation
#' recommend_model(n = 250, correlation = 0.5)
#'
#' # Large sample
#' recommend_model(n = 1000, correlation = 0.3)
#'
#' # Quadratic functional form
#' recommend_model(n = 250, functional_form = "quadratic")
#'
#' @export
recommend_model <- function(n, correlation = NULL, functional_form = "linear", verbose = TRUE) {

  # Check MNP availability
  mnp_available <- requireNamespace("MNP", quietly = TRUE)
  if (!mnp_available && verbose) {
    warning(
      "\n*** MNP package not installed ***\n",
      "Recommendations for MNP assume the package is available.\n",
      "Install with: install.packages('MNP')\n",
      "Without MNP, use MNL for all analyses.\n",
      call. = FALSE
    )
  }

  # Input validation
  if (!is.numeric(n) || n <= 0) {
    stop("n must be a positive integer")
  }

  if (!is.null(correlation) && (correlation < 0 || correlation > 1)) {
    stop("correlation must be between 0 and 1")
  }

  if (!functional_form %in% c("linear", "quadratic", "log")) {
    stop("functional_form must be 'linear', 'quadratic', or 'log'")
  }

  # Empirical convergence rates from simulations
  # These are based on Monte Carlo results
  mnp_convergence <- if (n < 100) {
    0.02  # ~2% convergence
  } else if (n < 250) {
    0.74  # 74% convergence
  } else if (n < 500) {
    0.85  # ~85% convergence (interpolated)
  } else if (n < 1000) {
    0.90  # ~90% convergence
  } else {
    0.95  # ~95% convergence
  }

  # MNL win rate when MNP converges
  mnl_win_rate <- if (n < 100) {
    1.00  # MNL always wins (MNP doesn't converge)
  } else if (n < 250) {
    0.58  # MNL wins 58% even when MNP converges
  } else if (n < 500) {
    0.52  # MNL wins 52% at medium n
  } else {
    0.48  # MNP slightly better at large n
  }

  # Adjust for correlation if provided
  if (!is.null(correlation) && correlation > 0.5) {
    # High correlation gives MNP slight advantage
    mnl_win_rate <- mnl_win_rate - 0.05
  }

  # Make recommendation
  if (n < 100) {
    recommendation <- "MNL"
    confidence <- "High"
    reason <- sprintf(
      "At n=%.0f, MNP converges only %.0f%% of the time. MNL is far more reliable.",
      n, mnp_convergence * 100
    )
  } else if (n < 250) {
    recommendation <- "MNL"
    confidence <- "High"
    reason <- sprintf(
      "At n=%.0f, MNP converges %.0f%% of the time but MNL still wins %.0f%% on RMSE. MNL is more reliable and often more accurate.",
      n, mnp_convergence * 100, mnl_win_rate * 100
    )
  } else if (n < 500) {
    if (!is.null(correlation) && correlation > 0.5) {
      recommendation <- "Either"
      confidence <- "Medium"
      reason <- sprintf(
        "At n=%.0f with high correlation (%.2f), MNP may perform slightly better if it converges (%.0f%% probability). However, MNL is still competitive.",
        n, correlation, mnp_convergence * 100
      )
    } else {
      recommendation <- "MNL"
      confidence <- "Medium"
      reason <- sprintf(
        "At n=%.0f, both models are viable (MNP converges %.0f%%), but MNL still wins %.0f%% of comparisons and is simpler.",
        n, mnp_convergence * 100, mnl_win_rate * 100
      )
    }
  } else {
    # n >= 500
    if (!is.null(correlation) && correlation > 0.5) {
      recommendation <- "MNP"
      confidence <- "Medium"
      reason <- sprintf(
        "At n=%.0f with high correlation (%.2f), MNP converges reliably (%.0f%%) and may capture error correlation better than MNL.",
        n, correlation, mnp_convergence * 100
      )
    } else {
      recommendation <- "Either"
      confidence <- "Medium"
      reason <- sprintf(
        "At n=%.0f, both models perform similarly. MNP converges %.0f%% of the time. Choose based on computational resources and theoretical considerations.",
        n, mnp_convergence * 100
      )
    }
  }

  # Adjust for functional form
  if (functional_form == "quadratic") {
    functional_form_note <- "\n\nNote: For quadratic relationships, consider using quadratic MNL specification, which improves performance in 88.7% of cases."
    reason <- paste0(reason, functional_form_note)
  }

  # Print output if verbose
  if (verbose) {
    cat("\n")
    cat("=== Model Recommendation ===\n")
    cat(sprintf("Recommendation: %s\n", recommendation))
    cat(sprintf("Confidence: %s\n", confidence))
    cat(sprintf("\nReason:\n%s\n", reason))
    cat(sprintf("\nExpected MNP convergence rate: %.0f%%\n", mnp_convergence * 100))
    cat(sprintf("Expected MNL win rate: %.0f%%\n", mnl_win_rate * 100))
    cat("\n")
  }

  # Return structured result
  invisible(list(
    recommendation = recommendation,
    confidence = confidence,
    reason = reason,
    expected_mnp_convergence = mnp_convergence,
    expected_mnl_win_rate = mnl_win_rate,
    n = n,
    correlation = correlation,
    functional_form = functional_form
  ))
}


#' Calculate Required Sample Size for Reliable Model Convergence
#'
#' Determines the minimum sample size needed for reliable MNP convergence based
#' on empirical Monte Carlo results.
#'
#' @param model Character. "MNL" or "MNP". Default is "MNP".
#' @param target_convergence Numeric. Desired convergence probability (0 to 1).
#'   Default is 0.90 (90%).
#' @param correlation Numeric. Expected error correlation. Currently not used
#'   in calculations but reserved for future versions.
#'
#' @return A list with components:
#'   \item{minimum_n}{Integer: Recommended minimum sample size}
#'   \item{convergence_at_n}{Numeric: Expected convergence rate at that n}
#'   \item{warning}{Character: Warning message if applicable}
#'
#' @details
#' Based on empirical convergence rates:
#' \itemize{
#'   \item n=100 → 2% convergence
#'   \item n=250 → 74% convergence
#'   \item n=500 → ~90% convergence
#'   \item n=1000 → ~95% convergence
#' }
#'
#' MNL always converges, so this function mainly applies to MNP.
#'
#' @examples
#' # Minimum n for 90% MNP convergence
#' required_sample_size(model = "MNP", target_convergence = 0.90)
#'
#' # Minimum n for 95% MNP convergence
#' required_sample_size(model = "MNP", target_convergence = 0.95)
#'
#' @export
required_sample_size <- function(model = "MNP", target_convergence = 0.90, correlation = 0) {

  # Input validation
  if (!model %in% c("MNL", "MNP")) {
    stop("model must be 'MNL' or 'MNP'")
  }

  if (target_convergence < 0 || target_convergence > 1) {
    stop("target_convergence must be between 0 and 1")
  }

  # MNL always converges
  if (model == "MNL") {
    return(list(
      minimum_n = 1,
      convergence_at_n = 1.0,
      warning = "MNL converges reliably at any sample size. No minimum required."
    ))
  }

  # For MNP, use empirical convergence rates
  # Linear interpolation between known points
  if (target_convergence <= 0.02) {
    minimum_n <- 50
    convergence <- 0.02
  } else if (target_convergence <= 0.74) {
    # Interpolate between n=100 (2%) and n=250 (74%)
    minimum_n <- round(100 + (target_convergence - 0.02) / (0.74 - 0.02) * (250 - 100))
    convergence <- target_convergence
  } else if (target_convergence <= 0.90) {
    # Interpolate between n=250 (74%) and n=500 (90%)
    minimum_n <- round(250 + (target_convergence - 0.74) / (0.90 - 0.74) * (500 - 250))
    convergence <- target_convergence
  } else if (target_convergence <= 0.95) {
    # Interpolate between n=500 (90%) and n=1000 (95%)
    minimum_n <- round(500 + (target_convergence - 0.90) / (0.95 - 0.90) * (1000 - 500))
    convergence <- target_convergence
  } else {
    # Above 95%, extrapolate
    minimum_n <- round(1000 + (target_convergence - 0.95) / 0.05 * 1000)
    convergence <- target_convergence
  }

  # Generate warning if n is too small
  warning_msg <- if (minimum_n < 250) {
    sprintf("Warning: Below n=250, MNP fails to converge %.0f%% of the time. Consider using MNL for n < 250.",
            (1 - 0.74) * 100)
  } else if (minimum_n < 500) {
    "Note: MNP convergence improves substantially above n=500."
  } else {
    NULL
  }

  cat("\n")
  cat(sprintf("For %s with %.0f%% convergence probability:\n", model, target_convergence * 100))
  cat(sprintf("Minimum sample size: n ≥ %d\n", minimum_n))
  if (!is.null(warning_msg)) {
    cat(sprintf("\n%s\n", warning_msg))
  }
  cat("\n")

  invisible(list(
    minimum_n = minimum_n,
    convergence_at_n = convergence,
    warning = warning_msg
  ))
}
