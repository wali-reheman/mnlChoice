#' Interactive Decision Framework for Model Selection
#'
#' Implements the paper's practical guidance as an interactive decision tool.
#' Walks users through decision tree to recommend MNL vs MNP based on their situation.
#'
#' @param n Integer. Sample size. If NULL, will prompt interactively.
#' @param estimand Character. What to estimate: "probabilities", "parameters",
#'   "substitution", or NULL for interactive prompt.
#' @param computational_limits Logical. Do you have computational constraints?
#'   If NULL, will prompt.
#' @param correlation Character. Expected error correlation: "none", "low", "medium",
#'   "high", or NULL for interactive prompt.
#' @param interactive Logical. Use interactive prompts. Default TRUE.
#' @param verbose Logical. Print detailed reasoning. Default TRUE.
#'
#' @return A list with components:
#'   \item{recommendation}{Character: "MNL", "MNP", or "Either"}
#'   \item{reasoning}{Detailed explanation of recommendation}
#'   \item{confidence}{Character: "High", "Medium", or "Low"}
#'   \item{caveats}{Important considerations}
#'   \item{alternative_options}{What to try if primary choice doesn't work}
#'   \item{next_steps}{Recommended actions}
#'
#' @details
#' This function translates the paper's findings into actionable guidance by walking
#' users through a decision tree based on:
#'
#' 1. Sample size (n)
#' 2. Estimand (what you want to estimate)
#' 3. Computational constraints
#' 4. Expected correlation structure
#'
#' **Decision logic:**
#' - n < 250: Always MNL (MNP won't converge)
#' - 250 ≤ n < 500: MNL preferred (MNP unreliable)
#' - n ≥ 500 + high correlation: MNP viable
#' - Substitution effects: Usually MNL better
#' - Computational limits: Always MNL
#'
#' @examples
#' \dontrun{
#' # Non-interactive mode
#' decision_framework(
#'   n = 300,
#'   estimand = "probabilities",
#'   computational_limits = FALSE,
#'   interactive = FALSE
#' )
#'
#' # Interactive mode (will prompt user)
#' decision_framework(interactive = TRUE)
#' }
#'
#' @export
decision_framework <- function(n = NULL,
                              estimand = NULL,
                              computational_limits = NULL,
                              correlation = NULL,
                              interactive = TRUE,
                              verbose = TRUE) {

  # Check MNP availability
  mnp_available <- requireNamespace("MNP", quietly = TRUE)

  if (verbose) {
    cat("\n")
    cat(paste(rep("=", 70), collapse = ""), "\n")
    cat("  MODEL SELECTION DECISION FRAMEWORK\n")
    cat(paste(rep("=", 70), collapse = ""), "\n\n")

    if (!mnp_available) {
      cat("⚠️  MNP package not installed\n")
      cat("   Recommendation will be MNL-only\n")
      cat("   Install MNP: install.packages('MNP')\n\n")
    }
  }

  # Interactive prompts if needed
  if (interactive && is.null(n)) {
    cat("What is your sample size?\n")
    n <- as.numeric(readline(prompt = "  n = "))
  }

  if (interactive && is.null(estimand)) {
    cat("\nWhat do you want to estimate?\n")
    cat("  1. Choice probabilities\n")
    cat("  2. Model parameters (coefficients)\n")
    cat("  3. Substitution effects (what happens when alternatives drop out)\n")
    est_choice <- as.numeric(readline(prompt = "Enter 1, 2, or 3: "))
    estimand <- c("probabilities", "parameters", "substitution")[est_choice]
  }

  if (interactive && is.null(computational_limits)) {
    cat("\nDo you have computational constraints? (MNP can take hours)\n")
    comp_choice <- tolower(readline(prompt = "  (y/n): "))
    computational_limits <- (comp_choice == "y" || comp_choice == "yes")
  }

  if (interactive && is.null(correlation)) {
    cat("\nDo you expect correlation between error terms across alternatives?\n")
    cat("  1. None (errors are independent)\n")
    cat("  2. Low correlation\n")
    cat("  3. Medium correlation\n")
    cat("  4. High correlation\n")
    cat("  5. Unknown\n")
    corr_choice <- as.numeric(readline(prompt = "Enter 1-5: "))
    correlation <- c("none", "low", "medium", "high", "unknown")[corr_choice]
  }

  # Set defaults if still NULL
  if (is.null(n)) n <- 300  # Default medium sample
  if (is.null(estimand)) estimand <- "probabilities"
  if (is.null(computational_limits)) computational_limits <- FALSE
  if (is.null(correlation)) correlation <- "unknown"

  if (verbose) {
    cat("\n")
    cat(paste(rep("-", 70), collapse = ""), "\n")
    cat("Your inputs:\n")
    cat(sprintf("  Sample size (n): %d\n", n))
    cat(sprintf("  Estimand: %s\n", estimand))
    cat(sprintf("  Computational limits: %s\n", computational_limits))
    cat(sprintf("  Expected correlation: %s\n", correlation))
    cat(paste(rep("-", 70), collapse = ""), "\n\n")
  }

  # Decision logic
  recommendation <- NULL
  reasoning <- NULL
  confidence <- NULL
  caveats <- c()
  alternative_options <- c()
  next_steps <- c()

  # Rule 1: MNP not available
  if (!mnp_available) {
    recommendation <- "MNL"
    confidence <- "High"
    reasoning <- "MNP package not installed. MNL is the only available option."
    next_steps <- c(
      "Use MNL for analysis",
      "If you need MNP: install.packages('MNP')",
      "Consider flexible MNL specifications (quadratic, interactions)"
    )
  }

  # Rule 2: Very small sample
  else if (n < 100) {
    recommendation <- "MNL"
    confidence <- "High"
    reasoning <- sprintf(
      "Sample size (n=%d) is too small for MNP. MNP converges only ~2%% of the time at this n. MNL is far more reliable.",
      n
    )
    caveats <- c(
      "Small sample limits all multinomial models",
      "Consider collecting more data if possible",
      "Be cautious about overfitting with many predictors"
    )
    next_steps <- c(
      "Use MNL with parsimony (few predictors)",
      "Test IIA assumption with test_iia()",
      "Consider collecting more data"
    )
  }

  # Rule 3: Small sample
  else if (n < 250) {
    recommendation <- "MNL"
    confidence <- "High"
    reasoning <- sprintf(
      "Sample size (n=%d) is small for MNP. MNP converges ~2-70%% at this range, and even when it converges, MNL typically outperforms it (58%% win rate).",
      n
    )
    caveats <- c(
      "MNP unlikely to converge reliably",
      "If MNP is theoretically motivated, try with caution"
    )
    next_steps <- c(
      "Use MNL",
      "Try flexible_mnl() for better functional form",
      "Run test_iia() to verify IIA assumption"
    )
  }

  # Rule 4: Computational constraints
  else if (computational_limits) {
    recommendation <- "MNL"
    confidence <- "High"
    reasoning <- "MNP requires substantial computation (hours to days for large models). MNL completes in seconds to minutes."
    caveats <- c(
      "If accuracy is critical: consider running MNP overnight",
      "Parallel processing can speed up MNP"
    )
    alternative_options <- c(
      "Use MNL for initial exploration",
      "Run MNP on subset of data first",
      "Consider mixed logit as compromise"
    )
    next_steps <- c(
      "Use MNL for rapid iteration",
      "If time permits: fit MNP in background",
      "Compare both if feasible"
    )
  }

  # Rule 5: Medium sample
  else if (n < 500) {
    if (estimand == "substitution") {
      recommendation <- "MNL"
      confidence <- "High"
      reasoning <- sprintf(
        "For substitution effects at n=%d, MNL typically outperforms MNP. MNP converges ~75-85%% but has higher dropout prediction error.",
        n
      )
      next_steps <- c(
        "Use MNL for substitution analysis",
        "Run simulate_dropout_scenario() to validate",
        "Try flexible_mnl() for better fit"
      )
    } else if (correlation %in% c("high")) {
      recommendation <- "Either"
      confidence <- "Medium"
      reasoning <- sprintf(
        "At n=%d with high correlation, both models are viable. MNP may capture correlation but converges ~85%% of time. MNL is more robust.",
        n
      )
      caveats <- c(
        "MNP convergence not guaranteed",
        "MNL may have slight bias if high correlation"
      )
      alternative_options <- c(
        "Start with MNL (faster, more reliable)",
        "Try MNP if MNL seems misspecified",
        "Compare both using compare_mnl_mnp()"
      )
      next_steps <- c(
        "Fit MNL first",
        "Run test_iia() to check for violations",
        "If IIA violated: try MNP"
      )
    } else {
      recommendation <- "MNL"
      confidence <- "High"
      reasoning <- sprintf(
        "At n=%d for %s, MNL is preferred. Simpler, faster, and typically more accurate (52-58%% win rate vs MNP).",
        n, estimand
      )
      next_steps <- c(
        "Use MNL",
        "Try flexible specifications with flexible_mnl()",
        "Validate with cross-validation"
      )
    }
  }

  # Rule 6: Large sample
  else {  # n >= 500
    if (estimand == "substitution") {
      recommendation <- "MNL"
      confidence <- "Medium"
      reasoning <- sprintf(
        "Even at n=%d, MNL typically better for substitution effects. MNP may overfit to sample-specific patterns.",
        n
      )
      caveats <- c(
        "MNP viable at this n (90%+ convergence)",
        "Worth comparing both models"
      )
      next_steps <- c(
        "Use MNL as primary model",
        "Run simulate_dropout_scenario() to compare",
        "Consider fitting MNP for comparison"
      )
    } else if (correlation %in% c("high", "medium")) {
      recommendation <- "MNP"
      confidence <- "Medium"
      reasoning <- sprintf(
        "At n=%d with %s correlation, MNP converges reliably (90-95%%) and may better capture error structure.",
        n, correlation
      )
      caveats <- c(
        "MNP is computationally expensive",
        "MNL still competitive even with correlation",
        "Flexible MNL may perform as well"
      )
      alternative_options <- c(
        "Try flexible_mnl() first (faster)",
        "Fit both and compare",
        "Use evaluate_by_estimand() to decide"
      )
      next_steps <- c(
        "Fit MNP with fit_mnp_safe()",
        "Also fit flexible MNL for comparison",
        "Use compare_mnl_mnp() to evaluate"
      )
    } else {
      recommendation <- "Either"
      confidence <- "Medium"
      reasoning <- sprintf(
        "At n=%d, both models perform similarly. Choose based on computational resources and theoretical considerations.",
        n
      )
      caveats <- c(
        "MNL is much faster",
        "MNP may overfit without strong correlation",
        "Functional form matters more than IIA"
      )
      next_steps <- c(
        "Start with MNL (faster)",
        "Try flexible_mnl() for better specification",
        "Fit MNP if theoretically motivated",
        "Compare using evaluate_by_estimand()"
      )
    }
  }

  # Print recommendation
  if (verbose) {
    cat("\n")
    cat(paste(rep("=", 70), collapse = ""), "\n")
    cat(sprintf("  RECOMMENDATION: %s\n", recommendation))
    cat(paste(rep("=", 70), collapse = ""), "\n\n")

    cat("REASONING:\n")
    cat(sprintf("  %s\n\n", reasoning))

    cat(sprintf("CONFIDENCE: %s\n\n", confidence))

    if (length(caveats) > 0) {
      cat("IMPORTANT CAVEATS:\n")
      for (cav in caveats) {
        cat(sprintf("  • %s\n", cav))
      }
      cat("\n")
    }

    if (length(alternative_options) > 0) {
      cat("ALTERNATIVE OPTIONS:\n")
      for (alt in alternative_options) {
        cat(sprintf("  • %s\n", alt))
      }
      cat("\n")
    }

    cat("NEXT STEPS:\n")
    for (step in next_steps) {
      cat(sprintf("  1. %s\n", step))
    }

    cat("\n")
    cat(paste(rep("=", 70), collapse = ""), "\n\n")
  }

  invisible(list(
    recommendation = recommendation,
    reasoning = reasoning,
    confidence = confidence,
    caveats = caveats,
    alternative_options = alternative_options,
    next_steps = next_steps,
    inputs = list(
      n = n,
      estimand = estimand,
      computational_limits = computational_limits,
      correlation = correlation
    )
  ))
}
