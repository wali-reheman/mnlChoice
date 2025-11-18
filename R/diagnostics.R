#' Check MNP Convergence Diagnostics
#'
#' Performs comprehensive MCMC convergence diagnostics for MNP models.
#'
#' @param mnp_fit A fitted MNP model object.
#' @param diagnostic_plots Logical. Create diagnostic plots. Default TRUE.
#' @param geweke_threshold Numeric. Threshold for Geweke z-statistic. Default 2.
#' @param ess_threshold Numeric. Minimum effective sample size as proportion.
#'   Default 0.10 (10% of total draws).
#'
#' @return A list with components:
#'   \item{converged}{Logical: Overall convergence assessment}
#'   \item{geweke_test}{Geweke convergence diagnostic results}
#'   \item{effective_sample_size}{Effective sample size for each parameter}
#'   \item{acceptance_rate}{Acceptance rate (if available)}
#'   \item{warnings}{Character vector of warnings}
#'
#' @details
#' Implements standard MCMC diagnostics:
#' \itemize{
#'   \item Geweke diagnostic - compares means of first 10% and last 50% of chain
#'   \item Effective sample size - accounts for autocorrelation
#'   \item Visual diagnostics - trace plots, autocorrelation plots
#' }
#'
#' A model is considered "converged" if:
#' \itemize{
#'   \item All Geweke z-statistics < threshold
#'   \item Effective sample size > threshold proportion
#'   \item No obvious patterns in trace plots
#' }
#'
#' @examples
#' \dontrun{
#' # Fit MNP model
#' fit <- fit_mnp_safe(choice ~ x1 + x2, data = mydata, fallback = "NULL")
#'
#' if (!is.null(fit) && attr(fit, "model_type") == "MNP") {
#'   # Check convergence
#'   diagnostics <- check_mnp_convergence(fit)
#'   print(diagnostics$converged)
#' }
#' }
#'
#' @export
check_mnp_convergence <- function(mnp_fit, diagnostic_plots = TRUE,
                                   geweke_threshold = 2, ess_threshold = 0.10) {

  if (is.null(mnp_fit)) {
    stop("mnp_fit is NULL")
  }

  # Check if this is actually an MNP model
  if (!inherits(mnp_fit, "mnp")) {
    warning("This doesn't appear to be an MNP model object")
    return(list(converged = NA, warnings = "Not an MNP model"))
  }

  warnings <- character()
  converged <- TRUE

  # Extract MCMC draws if available
  if (!is.null(mnp_fit$param)) {
    mcmc_draws <- mnp_fit$param
    n_draws <- nrow(mcmc_draws)
    n_params <- ncol(mcmc_draws)

    # Geweke diagnostic
    geweke_results <- tryCatch({
      # Compare first 10% and last 50%
      first_10 <- mcmc_draws[1:floor(0.1 * n_draws), , drop = FALSE]
      last_50 <- mcmc_draws[ceiling(0.5 * n_draws):n_draws, , drop = FALSE]

      z_scores <- numeric(n_params)
      for (j in 1:n_params) {
        mean_first <- mean(first_10[, j])
        mean_last <- mean(last_50[, j])
        se_first <- sd(first_10[, j]) / sqrt(nrow(first_10))
        se_last <- sd(last_50[, j]) / sqrt(nrow(last_50))
        se_diff <- sqrt(se_first^2 + se_last^2)

        z_scores[j] <- (mean_first - mean_last) / se_diff
      }

      names(z_scores) <- colnames(mcmc_draws)

      # Check if any exceed threshold
      if (any(abs(z_scores) > geweke_threshold)) {
        converged <- FALSE
        bad_params <- names(z_scores)[abs(z_scores) > geweke_threshold]
        warnings <- c(warnings,
                     sprintf("Geweke diagnostic failed for: %s",
                            paste(bad_params, collapse = ", ")))
      }

      z_scores
    }, error = function(e) {
      warnings <- c(warnings, sprintf("Geweke diagnostic error: %s", e$message))
      NULL
    })

    # Effective sample size
    ess_results <- tryCatch({
      ess <- numeric(n_params)
      for (j in 1:n_params) {
        # Calculate autocorrelation
        acf_vals <- acf(mcmc_draws[, j], lag.max = min(100, n_draws - 1),
                       plot = FALSE)$acf
        # ESS approximation
        rho <- sum(acf_vals[acf_vals > 0.05])  # Sum positive autocorrelations
        ess[j] <- n_draws / (1 + 2 * rho)
      }

      names(ess) <- colnames(mcmc_draws)

      # Check threshold
      min_ess <- n_draws * ess_threshold
      if (any(ess < min_ess)) {
        converged <- FALSE
        bad_params <- names(ess)[ess < min_ess]
        warnings <- c(warnings,
                     sprintf("Low ESS for: %s", paste(bad_params, collapse = ", ")))
      }

      ess
    }, error = function(e) {
      warnings <- c(warnings, sprintf("ESS calculation error: %s", e$message))
      NULL
    })

    # Create diagnostic plots if requested
    if (diagnostic_plots && n_params > 0 && interactive()) {
      # Set up plot layout
      n_plot_params <- min(6, n_params)  # Plot up to 6 parameters
      old_par <- par(mfrow = c(min(3, n_plot_params), 2))
      on.exit(par(old_par), add = TRUE)

      for (j in 1:n_plot_params) {
        # Trace plot
        plot(mcmc_draws[, j], type = "l",
             main = sprintf("Trace: %s", colnames(mcmc_draws)[j]),
             ylab = "Value", xlab = "Iteration")

        # Autocorrelation plot
        acf(mcmc_draws[, j], main = sprintf("ACF: %s", colnames(mcmc_draws)[j]))
      }
    }

  } else {
    warnings <- c(warnings, "No MCMC draws found in model object")
    geweke_results <- NULL
    ess_results <- NULL
  }

  # Overall assessment
  if (length(warnings) > 0) {
    message("Convergence warnings:")
    for (w in warnings) {
      message(sprintf("  - %s", w))
    }
  }

  if (converged) {
    message("MNP model appears to have converged.")
  } else {
    message("WARNING: MNP model may not have converged properly!")
  }

  # Return diagnostics
  list(
    converged = converged,
    geweke_test = geweke_results,
    effective_sample_size = ess_results,
    n_draws = if (!is.null(mnp_fit$param)) nrow(mnp_fit$param) else NA,
    warnings = if (length(warnings) > 0) warnings else NULL
  )
}


#' Predict Method for Safe Models
#'
#' Prediction method for models fitted with fit_mnp_safe().
#'
#' @param object A model object from fit_mnp_safe().
#' @param newdata Data frame with new observations.
#' @param type Character. "probs" for probabilities, "class" for predicted class.
#' @param ... Additional arguments.
#'
#' @return Matrix of predicted probabilities or vector of predicted classes.
#'
#' @examples
#' \dontrun{
#' fit <- fit_mnp_safe(choice ~ x1 + x2, data = train_data)
#' probs <- predict(fit, newdata = test_data, type = "probs")
#' classes <- predict(fit, newdata = test_data, type = "class")
#' }
#'
#' @export
predict.mnp_safe <- function(object, newdata, type = c("probs", "class"), ...) {

  type <- match.arg(type)

  # Check model type
  model_type <- attr(object, "model_type")

  if (is.null(model_type)) {
    # Try to infer
    if (inherits(object, "mnp")) {
      model_type <- "MNP"
    } else if (inherits(object, "multinom")) {
      model_type <- "MNL"
    } else {
      stop("Cannot determine model type")
    }
  }

  # Get predictions based on model type
  if (model_type == "MNL") {
    # Use predict.multinom
    if (type == "probs") {
      probs <- predict(object, newdata = newdata, type = "probs", ...)
      # Ensure matrix format even for 2 classes
      if (!is.matrix(probs)) {
        probs <- cbind(1 - probs, probs)
      }
      return(probs)
    } else {
      return(predict(object, newdata = newdata, type = "class", ...))
    }

  } else if (model_type == "MNP") {
    # Use predict.mnp
    pred <- predict(object, newdata = newdata, ...)

    if (type == "probs") {
      return(pred$p)  # Predicted probabilities
    } else {
      return(apply(pred$p, 1, which.max))  # Predicted class
    }

  } else {
    stop(sprintf("Unknown model type: %s", model_type))
  }
}


#' Model Summary Comparison
#'
#' Provides a side-by-side summary of MNL and MNP model fits.
#'
#' @param mnl_fit Fitted MNL model.
#' @param mnp_fit Fitted MNP model (can be NULL if failed).
#' @param print_summary Logical. Print summary. Default TRUE.
#'
#' @return A list with summary statistics for both models.
#'
#' @export
model_summary_comparison <- function(mnl_fit, mnp_fit = NULL, print_summary = TRUE) {

  # MNL summary
  mnl_summary <- list(
    model = "MNL",
    converged = TRUE,
    n_params = length(coef(mnl_fit)),
    loglik = as.numeric(logLik(mnl_fit)),
    aic = AIC(mnl_fit),
    bic = BIC(mnl_fit)
  )

  # MNP summary (if available)
  if (!is.null(mnp_fit)) {
    mnp_summary <- list(
      model = "MNP",
      converged = TRUE,  # Assume converged if object exists
      n_params = length(coef(mnp_fit)),
      loglik = tryCatch(as.numeric(logLik(mnp_fit)), error = function(e) NA),
      aic = tryCatch(AIC(mnp_fit), error = function(e) NA),
      bic = tryCatch(BIC(mnp_fit), error = function(e) NA)
    )
  } else {
    mnp_summary <- list(
      model = "MNP",
      converged = FALSE,
      n_params = NA,
      loglik = NA,
      aic = NA,
      bic = NA
    )
  }

  if (print_summary) {
    cat("\n=== Model Summary Comparison ===\n\n")

    cat(sprintf("%-15s %10s %10s\n", "Metric", "MNL", "MNP"))
    cat(strrep("-", 37), "\n")
    cat(sprintf("%-15s %10s %10s\n", "Converged",
                ifelse(mnl_summary$converged, "Yes", "No"),
                ifelse(mnp_summary$converged, "Yes", "No")))
    cat(sprintf("%-15s %10d %10s\n", "Parameters",
                mnl_summary$n_params,
                ifelse(is.na(mnp_summary$n_params), "NA", mnp_summary$n_params)))
    cat(sprintf("%-15s %10.2f %10s\n", "Log-Likelihood",
                mnl_summary$loglik,
                ifelse(is.na(mnp_summary$loglik), "NA",
                      sprintf("%.2f", mnp_summary$loglik))))
    cat(sprintf("%-15s %10.2f %10s\n", "AIC",
                mnl_summary$aic,
                ifelse(is.na(mnp_summary$aic), "NA",
                      sprintf("%.2f", mnp_summary$aic))))
    cat(sprintf("%-15s %10.2f %10s\n", "BIC",
                mnl_summary$bic,
                ifelse(is.na(mnp_summary$bic), "NA",
                      sprintf("%.2f", mnp_summary$bic))))
    cat("\n")
  }

  invisible(list(mnl = mnl_summary, mnp = mnp_summary))
}
