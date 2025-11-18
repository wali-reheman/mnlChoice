#' Power Analysis for Multinomial Choice Models
#'
#' Conducts power analysis via simulation to determine sample size requirements
#' for detecting effects of a given size.
#'
#' @param effect_size Numeric. Standardized effect size (coefficient / SE).
#' @param alpha Numeric. Significance level. Default 0.05.
#' @param power Numeric. Desired power. Default 0.80.
#' @param n_alternatives Integer. Number of choice alternatives. Default 3.
#' @param model Character. "MNL" or "MNP". Default "MNL".
#' @param n_sims Integer. Number of simulations. Default 100.
#' @param n_range Vector. Range of sample sizes to test. If NULL, uses default range.
#' @param verbose Logical. Print progress. Default TRUE.
#'
#' @return A list with:
#'   \item{required_n}{Estimated sample size needed for desired power}
#'   \item{power_curve}{Data frame with n and power estimates}
#'   \item{plot}{Power curve plot}
#'
#' @details
#' Uses simulation to estimate power: generates data with specified effect size,
#' fits the model, and checks if the effect is statistically significant.
#' Repeats this process for different sample sizes to build a power curve.
#'
#' @examples
#' \dontrun{
#' # How many observations needed to detect moderate effect with 80% power?
#' power_result <- power_analysis_mnl(effect_size = 0.5, power = 0.80)
#' print(power_result$required_n)
#' plot(power_result$power_curve)
#' }
#'
#' @export
power_analysis_mnl <- function(effect_size, alpha = 0.05, power = 0.80,
                                n_alternatives = 3, model = "MNL",
                                n_sims = 100, n_range = NULL,
                                verbose = TRUE) {

  if (is.null(n_range)) {
    # Smart default range based on effect size
    if (effect_size >= 0.8) {
      n_range <- seq(50, 300, by = 50)
    } else if (effect_size >= 0.5) {
      n_range <- seq(100, 600, by = 100)
    } else {
      n_range <- seq(200, 1000, by = 100)
    }
  }

  if (verbose) {
    cat(sprintf("\nPower Analysis for %s\n", model))
    cat(sprintf("Effect size: %.2f\n", effect_size))
    cat(sprintf("Target power: %.0f%%\n", power * 100))
    cat(sprintf("Simulations per n: %d\n\n", n_sims))
  }

  power_results <- data.frame(
    n = integer(),
    power = numeric(),
    se = numeric()
  )

  for (n in n_range) {
    if (verbose) message(sprintf("Testing n = %d...", n))

    # Run simulations
    significant_count <- 0

    for (sim in 1:n_sims) {
      # Generate data with known effect
      sim_data <- generate_choice_data(
        n = n,
        n_alternatives = n_alternatives,
        effect_size = effect_size,
        seed = NULL  # Different seed each time
      )

      # Fit model
      fit <- tryCatch({
        if (model == "MNL") {
          nnet::multinom(choice ~ ., data = sim_data$data, trace = FALSE)
        } else {
          fit_mnp_safe(choice ~ ., data = sim_data$data,
                      fallback = "NULL", verbose = FALSE)
        }
      }, error = function(e) NULL)

      # Check if effect is significant
      if (!is.null(fit)) {
        coefs <- tryCatch(summary(fit)$coefficients, error = function(e) NULL)
        std_errors <- tryCatch(summary(fit)$standard.errors, error = function(e) NULL)

        if (!is.null(coefs) && !is.null(std_errors)) {
          # Check first predictor (x1)
          if (model == "MNL" && is.matrix(coefs)) {
            z_stat <- abs(coefs[1, 1] / std_errors[1, 1])
          } else {
            z_stat <- abs(coefs[1] / std_errors[1])
          }

          if (z_stat > qnorm(1 - alpha/2)) {
            significant_count <- significant_count + 1
          }
        }
      }
    }

    # Calculate power and SE
    estimated_power <- significant_count / n_sims
    se_power <- sqrt(estimated_power * (1 - estimated_power) / n_sims)

    power_results <- rbind(power_results, data.frame(
      n = n,
      power = estimated_power,
      se = se_power
    ))

    if (verbose) {
      message(sprintf("  Power = %.2f (SE = %.3f)", estimated_power, se_power))
    }
  }

  # Find required n for target power
  if (any(power_results$power >= power)) {
    required_n <- min(power_results$n[power_results$power >= power])
  } else {
    required_n <- NA
    warning("Target power not achieved in tested range. Try larger sample sizes.")
  }

  # Create power curve plot
  plot(power_results$n, power_results$power,
       type = "b", pch = 19, col = "steelblue", lwd = 2,
       xlab = "Sample Size (n)",
       ylab = "Statistical Power",
       main = sprintf("Power Curve for %s (effect size = %.2f)", model, effect_size),
       ylim = c(0, 1),
       las = 1)

  # Add reference lines
  abline(h = power, lty = 2, col = "darkred", lwd = 2)
  if (!is.na(required_n)) {
    abline(v = required_n, lty = 2, col = "darkred", lwd = 2)
    text(required_n, 0.1,
         sprintf("n = %d", required_n),
         pos = 4, col = "darkred")
  }

  text(max(power_results$n) * 0.7, power + 0.05,
       sprintf("Target power = %.0f%%", power * 100),
       col = "darkred")

  # Add confidence bands
  lines(power_results$n, power_results$power + 1.96 * power_results$se,
        lty = 3, col = "steelblue")
  lines(power_results$n, power_results$power - 1.96 * power_results$se,
        lty = 3, col = "steelblue")

  if (verbose) {
    cat("\n")
    if (!is.na(required_n)) {
      cat(sprintf("Required sample size: n = %d\n", required_n))
    } else {
      cat("Required sample size: Not found in tested range\n")
    }
    cat("\n")
  }

  invisible(list(
    required_n = required_n,
    power_curve = power_results,
    effect_size = effect_size,
    target_power = power,
    model = model
  ))
}


#' Quick Sample Size Lookup Table
#'
#' Provides a lookup table of sample sizes needed for different effect sizes
#' and power levels.
#'
#' @param model Character. "MNL" or "MNP". Default "MNL".
#' @param n_alternatives Integer. Number of alternatives. Default 3.
#' @param print_table Logical. Print formatted table. Default TRUE.
#'
#' @return A data frame with sample size requirements.
#'
#' @export
sample_size_table <- function(model = "MNL", n_alternatives = 3, print_table = TRUE) {

  # Rough approximations based on typical patterns
  effect_sizes <- c(0.2, 0.35, 0.5, 0.65, 0.8)
  power_levels <- c(0.70, 0.80, 0.90)

  results <- expand.grid(
    effect_size = effect_sizes,
    power = power_levels
  )

  # Approximate sample sizes (based on simulation experience)
  # These are rough guidelines - actual power analysis recommended
  results$n_required <- with(results, {
    base_n <- (qnorm(power) + qnorm(0.975))^2 / effect_size^2

    # Adjust for multinomial (more parameters than binary)
    adjustment <- 1 + 0.2 * (n_alternatives - 2)

    # MNP needs larger samples due to convergence
    if (model == "MNP") {
      adjustment <- adjustment * 1.5
    }

    round(base_n * adjustment / 10) * 10  # Round to nearest 10
  })

  if (print_table) {
    cat(sprintf("\n=== Sample Size Requirements for %s ===\n", model))
    cat(sprintf("(Number of alternatives: %d)\n\n", n_alternatives))

    # Pivot table format
    table_wide <- reshape(results,
                         idvar = "effect_size",
                         timevar = "power",
                         direction = "wide")

    colnames(table_wide) <- c("Effect Size",
                              paste0("Power=", power_levels * 100, "%"))

    print(table_wide, row.names = FALSE)
    cat("\nNote: These are approximations. Run power_analysis_mnl() for precise estimates.\n\n")
  }

  invisible(results)
}
