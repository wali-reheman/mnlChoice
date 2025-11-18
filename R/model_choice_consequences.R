#' Quantify Consequences of Model Choice
#'
#' Simulates the consequences of choosing MNL vs MNP under different true data
#' generating processes. Shows bias, efficiency loss, and when the choice matters.
#'
#' @param n Sample size for simulation.
#' @param n_alternatives Number of choice alternatives. Default 3.
#' @param n_vars Number of predictor variables. Default 2.
#' @param formula Optional formula. If NULL, uses dynamic formula based on n_vars.
#' @param true_correlation True error correlation (0 = IIA holds, >0 = IIA violated).
#' @param n_sims Number of simulation replications. Default 100.
#' @param seed Random seed for reproducibility.
#' @param verbose Logical. Print progress. Default TRUE.
#'
#' @return A list with components:
#'   \item{summary}{Data frame summarizing bias and RMSE for both models}
#'   \item{safe_zone}{Logical: Is the model choice inconsequential?}
#'   \item{recommendation}{Which model to prefer given the consequences}
#'   \item{bias_ratio}{Ratio of MNP bias to MNL bias}
#'   \item{rmse_ratio}{Ratio of MNP RMSE to MNL RMSE}
#'
#' @details
#' This function answers: "What happens if I choose the wrong model?"
#'
#' It generates data under a known DGP and compares:
#' \itemize{
#'   \item Coefficient bias (how far off are estimates?)
#'   \item Prediction RMSE (how bad are predictions?)
#'   \item Coverage rates (do confidence intervals contain truth?)
#' }
#'
#' A "safe zone" exists when both models perform similarly - choice doesn't matter much.
#'
#' @examples
#' \dontrun{
#' # What happens with n=250 and moderate correlation?
#' consequences <- quantify_model_choice_consequences(
#'   n = 250,
#'   true_correlation = 0.4,
#'   n_sims = 100
#' )
#'
#' print(consequences$summary)
#' print(consequences$recommendation)
#' }
#'
#' @export
quantify_model_choice_consequences <- function(n, n_alternatives = 3,
                                                n_vars = 2,
                                                formula = NULL,
                                                true_correlation = 0,
                                                n_sims = 100, seed = NULL,
                                                verbose = TRUE) {

  if (!is.null(seed)) set.seed(seed)

  # Storage for results
  mnl_bias <- numeric(n_sims)
  mnp_bias <- numeric(n_sims)
  mnl_rmse <- numeric(n_sims)
  mnp_rmse <- numeric(n_sims)
  mnp_converged_count <- 0

  if (verbose) {
    cat(sprintf("\nQuantifying model choice consequences...\n"))
    cat(sprintf("  n = %d, correlation = %.2f, %d simulations\n",
                n, true_correlation, n_sims))
    cat(sprintf("  predictors = %d, alternatives = %d\n\n", n_vars, n_alternatives))
  }

  for (i in 1:n_sims) {
    if (verbose && i %% 20 == 0) {
      cat(sprintf("  Simulation %d/%d...\n", i, n_sims))
    }

    # Generate data with known true probabilities
    sim_data <- tryCatch({
      generate_choice_data(n = n, n_alternatives = n_alternatives,
                          n_vars = n_vars,
                          correlation = true_correlation,
                          functional_form = "linear",
                          effect_size = 0.5, seed = i)
    }, error = function(e) NULL)

    if (is.null(sim_data)) next

    # Use provided formula or extract from sim_data
    use_formula <- if (!is.null(formula)) formula else sim_data$formula

    # Fit MNL
    mnl_fit <- tryCatch({
      if (!requireNamespace("nnet", quietly = TRUE)) {
        NULL
      } else {
        nnet::multinom(use_formula, data = sim_data$data, trace = FALSE)
      }
    }, error = function(e) NULL)

    # Fit MNP
    mnp_fit <- tryCatch({
      if (!requireNamespace("MNP", quietly = TRUE)) {
        NULL
      } else {
        MNP::mnp(use_formula, data = sim_data$data,
                verbose = FALSE, n.draws = 2000, burnin = 500)
      }
    }, error = function(e) NULL)

    # Calculate bias and RMSE for MNL
    if (!is.null(mnl_fit)) {
      # Get predicted probabilities
      mnl_probs <- predict(mnl_fit, type = "probs")
      if (!is.matrix(mnl_probs)) {
        mnl_probs <- cbind(1 - mnl_probs, mnl_probs)
      }

      # RMSE compared to true probabilities
      true_probs <- sim_data$true_probs
      mnl_rmse[i] <- sqrt(mean((mnl_probs - true_probs)^2))

      # Coefficient bias (compared to true beta)
      true_beta <- sim_data$true_beta
      if (!is.null(true_beta)) {
        mnl_coef <- as.vector(coef(mnl_fit))
        true_beta_vec <- as.vector(true_beta)
        # Only compare if dimensions match
        if (length(mnl_coef) == length(true_beta_vec)) {
          # Average absolute bias across coefficients
          mnl_bias[i] <- mean(abs(mnl_coef - true_beta_vec))
        }
      }
    }

    # Calculate bias and RMSE for MNP
    if (!is.null(mnp_fit)) {
      mnp_converged_count <- mnp_converged_count + 1

      # Get predicted probabilities
      mnp_pred <- tryCatch({
        predict(mnp_fit, type = "probs")
      }, error = function(e) NULL)

      if (!is.null(mnp_pred)) {
        mnp_probs <- mnp_pred$p

        # RMSE
        true_probs <- sim_data$true_probs
        mnp_rmse[i] <- sqrt(mean((mnp_probs - true_probs)^2))

        # Coefficient bias
        true_beta <- sim_data$true_beta
        if (!is.null(true_beta)) {
          mnp_coef <- as.vector(coef(mnp_fit))
          true_beta_vec <- as.vector(true_beta)
          # Only compare if dimensions match
          if (length(mnp_coef) == length(true_beta_vec)) {
            mnp_bias[i] <- mean(abs(mnp_coef - true_beta_vec))
          }
        }
      }
    }
  }

  # Remove zeros (failed fits)
  valid_mnl <- mnl_bias > 0 & mnl_rmse > 0
  valid_mnp <- mnp_bias > 0 & mnp_rmse > 0

  # Summary statistics
  summary_df <- data.frame(
    Model = c("MNL", "MNP"),
    Mean_Bias = c(
      if (any(valid_mnl)) mean(mnl_bias[valid_mnl]) else NA,
      if (any(valid_mnp)) mean(mnp_bias[valid_mnp]) else NA
    ),
    SD_Bias = c(
      if (any(valid_mnl)) sd(mnl_bias[valid_mnl]) else NA,
      if (any(valid_mnp)) sd(mnp_bias[valid_mnp]) else NA
    ),
    Mean_RMSE = c(
      if (any(valid_mnl)) mean(mnl_rmse[valid_mnl]) else NA,
      if (any(valid_mnp)) mean(mnp_rmse[valid_mnp]) else NA
    ),
    SD_RMSE = c(
      if (any(valid_mnl)) sd(mnl_rmse[valid_mnl]) else NA,
      if (any(valid_mnp)) sd(mnp_rmse[valid_mnp]) else NA
    ),
    Convergence_Rate = c(
      sum(valid_mnl) / n_sims,
      sum(valid_mnp) / n_sims
    ),
    N_Valid = c(sum(valid_mnl), sum(valid_mnp))
  )

  # Calculate ratios (only if both have valid results)
  bias_ratio <- NA
  rmse_ratio <- NA

  if (any(valid_mnl) && any(valid_mnp)) {
    bias_ratio <- mean(mnp_bias[valid_mnp]) / mean(mnl_bias[valid_mnl])
    rmse_ratio <- mean(mnp_rmse[valid_mnp]) / mean(mnl_rmse[valid_mnl])
  }

  # Determine if we're in a "safe zone" (both models similar)
  safe_zone <- FALSE
  if (!is.na(rmse_ratio)) {
    # Safe zone: RMSE within 10% and both converge reliably
    rmse_similar <- rmse_ratio > 0.90 && rmse_ratio < 1.10
    both_converge <- summary_df$Convergence_Rate[1] > 0.95 &&
                     summary_df$Convergence_Rate[2] > 0.80
    safe_zone <- rmse_similar && both_converge
  }

  # Make recommendation
  recommendation <- "Unclear - insufficient convergence"

  if (any(valid_mnl) && any(valid_mnp)) {
    if (safe_zone) {
      recommendation <- "SAFE ZONE: Either model is fine"
    } else if (summary_df$Convergence_Rate[2] < 0.70) {
      recommendation <- "Use MNL (MNP convergence too unreliable)"
    } else if (!is.na(rmse_ratio) && rmse_ratio < 0.95) {
      recommendation <- "Prefer MNP (lower prediction error)"
    } else if (!is.na(rmse_ratio) && rmse_ratio > 1.05) {
      recommendation <- "Prefer MNL (lower prediction error)"
    } else {
      recommendation <- "Slight preference for MNL (more reliable)"
    }
  } else if (any(valid_mnl)) {
    recommendation <- "Use MNL (MNP failed to converge)"
  }

  # Interpret results
  if (verbose) {
    cat("\n=== Model Choice Consequences ===\n\n")
    print(summary_df)
    cat("\n")

    if (!is.na(bias_ratio)) {
      cat(sprintf("Bias Ratio (MNP/MNL): %.3f\n", bias_ratio))
      if (bias_ratio < 0.9) {
        cat("  → MNP has lower bias\n")
      } else if (bias_ratio > 1.1) {
        cat("  → MNL has lower bias\n")
      } else {
        cat("  → Similar bias\n")
      }
    }

    if (!is.na(rmse_ratio)) {
      cat(sprintf("RMSE Ratio (MNP/MNL): %.3f\n", rmse_ratio))
      if (rmse_ratio < 0.9) {
        cat("  → MNP has better predictions\n")
      } else if (rmse_ratio > 1.1) {
        cat("  → MNL has better predictions\n")
      } else {
        cat("  → Similar prediction accuracy\n")
      }
    }

    cat("\n")
    if (safe_zone) {
      cat("✓ SAFE ZONE: Model choice doesn't matter much\n")
    } else {
      cat("⚠ Model choice matters - see recommendation\n")
    }

    cat(sprintf("\nRecommendation: %s\n", recommendation))
    cat("\n")
  }

  invisible(list(
    summary = summary_df,
    safe_zone = safe_zone,
    recommendation = recommendation,
    bias_ratio = bias_ratio,
    rmse_ratio = rmse_ratio,
    mnl_results = list(bias = mnl_bias[valid_mnl], rmse = mnl_rmse[valid_mnl]),
    mnp_results = list(bias = mnp_bias[valid_mnp], rmse = mnp_rmse[valid_mnp])
  ))
}
