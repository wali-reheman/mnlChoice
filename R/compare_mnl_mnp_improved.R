#' Compare MNL and MNP with Cross-Validation (Improved)
#'
#' Enhanced version with actual cross-validation implementation.
#'
#' @param formula Formula object specifying the model.
#' @param data Data frame containing the variables.
#' @param metrics Character vector. Metrics to compute.
#' @param cross_validate Logical. Use k-fold cross-validation. Default FALSE.
#' @param n_folds Integer. Number of folds for cross-validation. Default 5.
#' @param verbose Logical. Print progress messages. Default TRUE.
#' @param ... Additional arguments passed to fitting functions.
#'
#' @return A list with comparison results.
#'
#' @export
compare_mnl_mnp_cv <- function(formula, data, metrics = c("RMSE", "Brier", "Accuracy"),
                               cross_validate = TRUE, n_folds = 5,
                               verbose = TRUE, ...) {

  valid_metrics <- c("RMSE", "Brier", "AIC", "BIC", "LogLik", "Accuracy", "LogLoss")
  if (!all(metrics %in% valid_metrics)) {
    stop(sprintf("metrics must be subset of: %s", paste(valid_metrics, collapse = ", ")))
  }

  if (verbose) {
    cat("\n=== MNL vs MNP Comparison ===\n")
    if (cross_validate) {
      cat(sprintf("Using %d-fold cross-validation\n\n", n_folds))
    } else {
      cat("Using in-sample fit\n\n")
    }
  }

  # Extract response variable name
  response_var <- all.vars(formula)[1]
  y_true <- data[[response_var]]

  # Ensure y_true is a factor for proper handling
  if (!is.factor(y_true)) {
    y_true <- factor(y_true)
    data[[response_var]] <- y_true
    if (verbose) {
      message("Note: Response variable converted to factor")
    }
  }

  results <- data.frame(
    Metric = character(),
    MNL = numeric(),
    MNP = numeric(),
    Winner = character(),
    stringsAsFactors = FALSE
  )

  # If cross-validation requested
  if (cross_validate && any(c("RMSE", "Brier", "Accuracy", "LogLoss") %in% metrics)) {

    if (verbose) message("Performing cross-validation...")

    # Create folds
    n <- nrow(data)
    fold_size <- floor(n / n_folds)
    fold_ids <- sample(rep(1:n_folds, length.out = n))

    # Storage for CV predictions
    mnl_cv_probs <- matrix(NA, n, length(levels(y_true)))
    mnp_cv_probs <- matrix(NA, n, length(levels(y_true)))
    mnp_cv_failures <- 0

    # Cross-validation loop
    for (fold in 1:n_folds) {
      if (verbose) message(sprintf("  Fold %d/%d...", fold, n_folds))

      # Split data
      test_idx <- which(fold_ids == fold)
      train_idx <- which(fold_ids != fold)

      train_data <- data[train_idx, ]
      test_data <- data[test_idx, ]

      # Fit MNL
      mnl_fold <- tryCatch({
        nnet::multinom(formula = formula, data = train_data, trace = FALSE, ...)
      }, error = function(e) NULL)

      if (!is.null(mnl_fold)) {
        mnl_pred <- predict(mnl_fold, newdata = test_data, type = "probs")
        if (!is.matrix(mnl_pred)) {
          mnl_pred <- cbind(1 - mnl_pred, mnl_pred)
        }
        mnl_cv_probs[test_idx, ] <- mnl_pred
      }

      # Fit MNP
      mnp_fold <- fit_mnp_safe(formula, data = train_data, fallback = "NULL",
                               verbose = FALSE, ...)

      if (!is.null(mnp_fold)) {
        mnp_pred <- tryCatch({
          pred_obj <- predict(mnp_fold, newdata = test_data)
          if (is.list(pred_obj) && !is.null(pred_obj$p)) {
            pred_obj$p
          } else {
            NULL
          }
        }, error = function(e) NULL)

        if (!is.null(mnp_pred)) {
          mnp_cv_probs[test_idx, ] <- mnp_pred
        } else {
          mnp_cv_failures <- mnp_cv_failures + 1
        }
      } else {
        mnp_cv_failures <- mnp_cv_failures + 1
      }
    }

    # Calculate CV metrics
    if ("RMSE" %in% metrics) {
      # Create dummy matrix for true outcomes
      y_dummy <- model.matrix(~ y_true - 1)
      if (ncol(y_dummy) < ncol(mnl_cv_probs)) {
        y_dummy <- cbind(1 - rowSums(y_dummy), y_dummy)
      }

      mnl_rmse <- sqrt(mean((y_dummy - mnl_cv_probs)^2, na.rm = TRUE))

      if (mnp_cv_failures < n_folds) {
        mnp_rmse <- sqrt(mean((y_dummy - mnp_cv_probs)^2, na.rm = TRUE))
      } else {
        mnp_rmse <- NA
      }

      results <- rbind(results, data.frame(
        Metric = "RMSE (CV)",
        MNL = mnl_rmse,
        MNP = ifelse(is.na(mnp_rmse), NA, mnp_rmse),
        Winner = ifelse(is.na(mnp_rmse), "MNL", ifelse(mnl_rmse < mnp_rmse, "MNL", "MNP")),
        stringsAsFactors = FALSE
      ))
    }

    if ("Brier" %in% metrics) {
      y_dummy <- model.matrix(~ y_true - 1)
      if (ncol(y_dummy) < ncol(mnl_cv_probs)) {
        y_dummy <- cbind(1 - rowSums(y_dummy), y_dummy)
      }

      mnl_brier <- mean((y_dummy - mnl_cv_probs)^2, na.rm = TRUE)

      if (mnp_cv_failures < n_folds) {
        mnp_brier <- mean((y_dummy - mnp_cv_probs)^2, na.rm = TRUE)
      } else {
        mnp_brier <- NA
      }

      results <- rbind(results, data.frame(
        Metric = "Brier (CV)",
        MNL = mnl_brier,
        MNP = ifelse(is.na(mnp_brier), NA, mnp_brier),
        Winner = ifelse(is.na(mnp_brier), "MNL", ifelse(mnl_brier < mnp_brier, "MNL", "MNP")),
        stringsAsFactors = FALSE
      ))
    }

    if ("Accuracy" %in% metrics) {
      mnl_pred_class <- apply(mnl_cv_probs, 1, which.max)
      mnl_acc <- mean(mnl_pred_class == as.numeric(y_true), na.rm = TRUE)

      if (mnp_cv_failures < n_folds) {
        mnp_pred_class <- apply(mnp_cv_probs, 1, which.max)
        mnp_acc <- mean(mnp_pred_class == as.numeric(y_true), na.rm = TRUE)
      } else {
        mnp_acc <- NA
      }

      results <- rbind(results, data.frame(
        Metric = "Accuracy (CV)",
        MNL = mnl_acc,
        MNP = ifelse(is.na(mnp_acc), NA, mnp_acc),
        Winner = ifelse(is.na(mnp_acc), "MNL", ifelse(mnl_acc > mnp_acc, "MNL", "MNP")),
        stringsAsFactors = FALSE
      ))
    }

    if (verbose && mnp_cv_failures > 0) {
      message(sprintf("\nWarning: MNP failed in %d/%d folds\n", mnp_cv_failures, n_folds))
    }
  }

  # Fit full models for in-sample metrics
  if (verbose) message("\nFitting full models...")

  mnl_fit <- tryCatch({
    nnet::multinom(formula = formula, data = data, trace = FALSE, ...)
  }, error = function(e) {
    stop(sprintf("MNL fitting failed: %s", e$message))
  })

  mnp_fit <- fit_mnp_safe(formula, data, fallback = "NULL", verbose = FALSE, ...)
  mnp_converged <- !is.null(mnp_fit)

  # In-sample metrics
  if (!cross_validate || any(c("AIC", "BIC", "LogLik") %in% metrics)) {

    if ("AIC" %in% metrics) {
      aic_mnl <- AIC(mnl_fit)
      aic_mnp <- if (mnp_converged) tryCatch(AIC(mnp_fit), error = function(e) NA) else NA

      if (!is.na(aic_mnp)) {
        results <- rbind(results, data.frame(
          Metric = "AIC",
          MNL = aic_mnl,
          MNP = aic_mnp,
          Winner = ifelse(aic_mnl < aic_mnp, "MNL", "MNP"),
          stringsAsFactors = FALSE
        ))
      }
    }

    if ("BIC" %in% metrics) {
      bic_mnl <- BIC(mnl_fit)
      bic_mnp <- if (mnp_converged) tryCatch(BIC(mnp_fit), error = function(e) NA) else NA

      if (!is.na(bic_mnp)) {
        results <- rbind(results, data.frame(
          Metric = "BIC",
          MNL = bic_mnl,
          MNP = bic_mnp,
          Winner = ifelse(bic_mnl < bic_mnp, "MNL", "MNP"),
          stringsAsFactors = FALSE
        ))
      }
    }

    if ("LogLik" %in% metrics) {
      ll_mnl <- as.numeric(logLik(mnl_fit))
      ll_mnp <- if (mnp_converged) tryCatch(as.numeric(logLik(mnp_fit)), error = function(e) NA) else NA

      if (!is.na(ll_mnp)) {
        results <- rbind(results, data.frame(
          Metric = "LogLik",
          MNL = ll_mnl,
          MNP = ll_mnp,
          Winner = ifelse(ll_mnl > ll_mnp, "MNL", "MNP"),
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
    cat(strrep("-", 50), "\n")
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
    converged = c(MNL = TRUE, MNP = mnp_converged),
    cv_performed = cross_validate,
    n_folds = if (cross_validate) n_folds else NA
  ))
}
