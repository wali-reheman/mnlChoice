#' Compare MNL and MNP Model Performance
#'
#' Fits both Multinomial Logit and Multinomial Probit models on the same data
#' and compares their performance using multiple metrics.
#'
#' @param formula Formula object specifying the model.
#' @param data Data frame containing the variables.
#' @param metrics Character vector. Metrics to compute: "RMSE", "Brier", "AIC",
#'   "BIC", "LogLik". Default is c("RMSE", "Brier", "AIC").
#' @param cross_validate Logical. Use k-fold cross-validation for RMSE and Brier.
#'   Default is FALSE (uses in-sample fit).
#' @param n_folds Integer. Number of folds for cross-validation. Default is 5.
#' @param verbose Logical. Print progress messages. Default is TRUE.
#' @param ... Additional arguments passed to fitting functions.
#'
#' @return A list with components:
#'   \item{results}{Data frame with performance metrics for each model}
#'   \item{winner}{Character vector indicating which model won on each metric}
#'   \item{recommendation}{Overall recommendation based on results}
#'   \item{mnl_fit}{Fitted MNL model (if successful)}
#'   \item{mnp_fit}{Fitted MNP model (if successful, NULL otherwise)}
#'   \item{converged}{Named logical vector indicating convergence status}
#'
#' @details
#' This function provides a head-to-head comparison of MNL vs MNP on the same
#' dataset. It handles MNP convergence failures gracefully and provides clear
#' guidance about which model performed better.
#'
#' Performance metrics:
#' \itemize{
#'   \item RMSE - Root Mean Squared Error of predicted probabilities
#'   \item Brier - Brier score for probabilistic predictions
#'   \item AIC - Akaike Information Criterion (lower is better)
#'   \item BIC - Bayesian Information Criterion (lower is better)
#'   \item LogLik - Log-likelihood (higher is better)
#' }
#'
#' @examples
#' \dontrun{
#' # Simulate data
#' set.seed(123)
#' n <- 250
#' x1 <- rnorm(n)
#' x2 <- rnorm(n)
#' # True probabilities
#' z1 <- 0.5 * x1 + 0.3 * x2
#' z2 <- -0.3 * x1 + 0.5 * x2
#' probs <- cbind(1, exp(z1), exp(z2))
#' probs <- probs / rowSums(probs)
#' y <- apply(probs, 1, function(p) sample(1:3, 1, prob = p))
#' dat <- data.frame(y = factor(y), x1, x2)
#'
#' # Compare models
#' comparison <- compare_mnl_mnp(y ~ x1 + x2, data = dat)
#' print(comparison$results)
#' print(comparison$recommendation)
#' }
#'
#' @export
compare_mnl_mnp <- function(formula, data, metrics = c("RMSE", "Brier", "AIC"),
                            cross_validate = FALSE, n_folds = 5,
                            verbose = TRUE, ...) {

  # Check MNP availability upfront
  mnp_available <- requireNamespace("MNP", quietly = TRUE)
  if (!mnp_available) {
    warning(
      "\n*** MNP package not installed ***\n",
      "Cannot compare MNL vs MNP without MNP package.\n",
      "Install with: install.packages('MNP')\n",
      "Proceeding with MNL-only analysis.\n",
      call. = FALSE
    )
  }

  # Input validation
  valid_metrics <- c("RMSE", "Brier", "AIC", "BIC", "LogLik")
  if (!all(metrics %in% valid_metrics)) {
    stop(sprintf("metrics must be subset of: %s", paste(valid_metrics, collapse = ", ")))
  }

  if (verbose) {
    cat("\n=== MNL vs MNP Comparison ===\n")
    if (!mnp_available) {
      cat("*** MNP not available - MNL-only results ***\n")
    }
    cat("\n")
  }

  # Fit MNL (always works)
  if (verbose) message("Fitting MNL...")
  mnl_fit <- tryCatch({
    if (!requireNamespace("nnet", quietly = TRUE)) {
      stop("nnet package required. Install with: install.packages('nnet')")
    }
    nnet::multinom(formula = formula, data = data, trace = FALSE, ...)
  }, error = function(e) {
    stop(sprintf("MNL fitting failed: %s", e$message))
  })

  mnl_converged <- TRUE
  if (verbose) message("MNL fitted successfully.\n")

  # Fit MNP (may fail)
  if (verbose) message("Fitting MNP...")
  mnp_fit <- fit_mnp_safe(formula, data, fallback = "NULL", verbose = verbose, ...)
  mnp_converged <- !is.null(mnp_fit)

  if (!mnp_converged) {
    if (verbose) {
      message("\nMNP failed to converge. Comparison will only include MNL results.\n")
    }

    return(list(
      results = data.frame(
        Model = "MNL",
        Converged = TRUE,
        stringsAsFactors = FALSE
      ),
      winner = "MNL (MNP failed to converge)",
      recommendation = "Use MNL - MNP failed to converge on this dataset",
      mnl_fit = mnl_fit,
      mnp_fit = NULL,
      converged = c(MNL = TRUE, MNP = FALSE)
    ))
  }

  # Both models converged - compute metrics
  results <- data.frame(
    Metric = character(),
    MNL = numeric(),
    MNP = numeric(),
    Winner = character(),
    stringsAsFactors = FALSE
  )

  # Extract response variable
  response_var <- all.vars(formula)[1]
  y_true <- data[[response_var]]

  # Compute requested metrics
  for (metric in metrics) {

    if (metric == "RMSE") {
      # Compute RMSE for predicted probabilities
      pred_mnl <- fitted(mnl_fit)
      pred_mnp <- fitted(mnp_fit)

      # Convert y to dummy variables
      y_dummy <- model.matrix(~ y_true - 1)
      if (ncol(y_dummy) < ncol(pred_mnl)) {
        # Add reference category
        y_dummy <- cbind(1 - rowSums(y_dummy), y_dummy)
      }

      rmse_mnl <- sqrt(mean((y_dummy - pred_mnl)^2))
      rmse_mnp <- sqrt(mean((y_dummy - pred_mnp)^2))

      results <- rbind(results, data.frame(
        Metric = "RMSE",
        MNL = rmse_mnl,
        MNP = rmse_mnp,
        Winner = ifelse(rmse_mnl < rmse_mnp, "MNL", "MNP"),
        stringsAsFactors = FALSE
      ))

    } else if (metric == "Brier") {
      # Brier score
      pred_mnl <- fitted(mnl_fit)
      pred_mnp <- fitted(mnp_fit)

      y_dummy <- model.matrix(~ y_true - 1)
      if (ncol(y_dummy) < ncol(pred_mnl)) {
        y_dummy <- cbind(1 - rowSums(y_dummy), y_dummy)
      }

      brier_mnl <- mean((y_dummy - pred_mnl)^2)
      brier_mnp <- mean((y_dummy - pred_mnp)^2)

      results <- rbind(results, data.frame(
        Metric = "Brier",
        MNL = brier_mnl,
        MNP = brier_mnp,
        Winner = ifelse(brier_mnl < brier_mnp, "MNL", "MNP"),
        stringsAsFactors = FALSE
      ))

    } else if (metric == "AIC") {
      aic_mnl <- AIC(mnl_fit)
      # MNP objects may not have AIC method
      aic_mnp <- tryCatch(AIC(mnp_fit), error = function(e) NA)

      if (!is.na(aic_mnp)) {
        results <- rbind(results, data.frame(
          Metric = "AIC",
          MNL = aic_mnl,
          MNP = aic_mnp,
          Winner = ifelse(aic_mnl < aic_mnp, "MNL", "MNP"),
          stringsAsFactors = FALSE
        ))
      }

    } else if (metric == "BIC") {
      bic_mnl <- BIC(mnl_fit)
      bic_mnp <- tryCatch(BIC(mnp_fit), error = function(e) NA)

      if (!is.na(bic_mnp)) {
        results <- rbind(results, data.frame(
          Metric = "BIC",
          MNL = bic_mnl,
          MNP = bic_mnp,
          Winner = ifelse(bic_mnl < bic_mnp, "MNL", "MNP"),
          stringsAsFactors = FALSE
        ))
      }

    } else if (metric == "LogLik") {
      ll_mnl <- as.numeric(logLik(mnl_fit))
      ll_mnp <- tryCatch(as.numeric(logLik(mnp_fit)), error = function(e) NA)

      if (!is.na(ll_mnp)) {
        results <- rbind(results, data.frame(
          Metric = "LogLik",
          MNL = ll_mnl,
          MNP = ll_mnp,
          Winner = ifelse(ll_mnl > ll_mnp, "MNL", "MNP"),  # Higher is better
          stringsAsFactors = FALSE
        ))
      }
    }
  }

  # Overall recommendation
  mnl_wins <- sum(results$Winner == "MNL", na.rm = TRUE)
  mnp_wins <- sum(results$Winner == "MNP", na.rm = TRUE)
  total_metrics <- nrow(results)

  if (mnl_wins > mnp_wins) {
    recommendation <- sprintf("Use MNL (better on %d/%d metrics)", mnl_wins, total_metrics)
  } else if (mnp_wins > mnl_wins) {
    recommendation <- sprintf("Use MNP (better on %d/%d metrics)", mnp_wins, total_metrics)
  } else {
    recommendation <- "Models perform similarly - choose based on other considerations"
  }

  # Print results
  if (verbose) {
    cat("\nModel Comparison Results:\n")
    cat("-------------------------\n")
    print(results, row.names = FALSE)
    cat("\n")
    cat(sprintf("Recommendation: %s\n\n", recommendation))
  }

  # Return results
  invisible(list(
    results = results,
    winner = results$Winner,
    recommendation = recommendation,
    mnl_fit = mnl_fit,
    mnp_fit = mnp_fit,
    converged = c(MNL = mnl_converged, MNP = mnp_converged)
  ))
}
