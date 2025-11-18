#' Flexible MNL with Automatic Functional Form Selection
#'
#' Implements the paper's finding that functional form matters MORE than relaxing IIA.
#' Automatically tries multiple MNL specifications and returns the best-performing one.
#'
#' @param formula Base formula (e.g., vote ~ ideology + income).
#' @param data Data frame containing the variables.
#' @param forms Character vector. Functional forms to test: "linear", "quadratic",
#'   "log", "interactions", or "all". Default c("linear", "quadratic").
#' @param selection_criterion Character. How to select best model: "RMSE", "Brier",
#'   "AIC", "BIC", or "CV" (cross-validation). Default "RMSE".
#' @param cross_validate Logical. Use k-fold cross-validation. Default TRUE.
#' @param n_folds Integer. Number of CV folds. Default 5.
#' @param verbose Logical. Print progress and results. Default TRUE.
#' @param ... Additional arguments passed to nnet::multinom().
#'
#' @return A list with components:
#'   \item{best_model}{Fitted model object with best performance}
#'   \item{best_form}{Character: which functional form won}
#'   \item{comparison_table}{Data frame comparing all specifications}
#'   \item{recommendation}{Text recommendation}
#'   \item{all_models}{List of all fitted models}
#'   \item{formulas}{List of formulas tested}
#'
#' @details
#' This function operationalizes the paper's key finding: **flexible MNL often beats
#' inflexible MNP**.
#'
#' **Functional forms tested:**
#' \itemize{
#'   \item **linear**: y ~ x
#'   \item **quadratic**: y ~ x + I(x^2)
#'   \item **log**: y ~ log(x) (for positive variables only)
#'   \item **interactions**: y ~ x1 * x2 (all two-way interactions)
#'   \item **all**: Tries all above combinations
#' }
#'
#' **Selection criteria:**
#' \itemize{
#'   \item RMSE: Root mean squared error (lower is better)
#'   \item Brier: Brier score (lower is better)
#'   \item AIC: Akaike Information Criterion (lower is better)
#'   \item BIC: Bayesian Information Criterion (lower is better)
#'   \item CV: Cross-validated prediction error
#' }
#'
#' @examples
#' \dontrun{
#' # Automatic functional form selection
#' result <- flexible_mnl(
#'   vote ~ ideology + income,
#'   data = election_data,
#'   forms = c("linear", "quadratic", "log")
#' )
#'
#' # View comparison
#' print(result$comparison_table)
#'
#' # Use best model
#' best_fit <- result$best_model
#' summary(best_fit)
#' }
#'
#' @export
flexible_mnl <- function(formula, data,
                        forms = c("linear", "quadratic"),
                        selection_criterion = "RMSE",
                        cross_validate = TRUE,
                        n_folds = 5,
                        verbose = TRUE,
                        ...) {

  # Input validation
  if (!requireNamespace("nnet", quietly = TRUE)) {
    stop("nnet package required. Install with: install.packages('nnet')")
  }

  valid_forms <- c("linear", "quadratic", "log", "interactions", "all")
  if ("all" %in% forms) {
    forms <- c("linear", "quadratic", "log", "interactions")
  }

  if (!all(forms %in% valid_forms)) {
    stop(sprintf("forms must be subset of: %s", paste(valid_forms, collapse = ", ")))
  }

  valid_criteria <- c("RMSE", "Brier", "AIC", "BIC", "CV")
  if (!selection_criterion %in% valid_criteria) {
    stop(sprintf("selection_criterion must be one of: %s",
                paste(valid_criteria, collapse = ", ")))
  }

  if (verbose) {
    cat("\n")
    cat(paste(rep("=", 70), collapse = ""), "\n")
    cat("  FLEXIBLE MNL: Functional Form Selection\n")
    cat(paste(rep("=", 70), collapse = ""), "\n\n")
    cat(sprintf("Testing forms: %s\n", paste(forms, collapse = ", ")))
    cat(sprintf("Selection criterion: %s\n", selection_criterion))
    if (cross_validate) {
      cat(sprintf("Using %d-fold cross-validation\n\n", n_folds))
    } else {
      cat("Using in-sample fit\n\n")
    }
  }

  # Extract variable names
  response_var <- all.vars(formula)[1]
  predictor_vars <- all.vars(formula)[-1]

  # Build formulas for each functional form
  formulas_list <- list()

  # Linear (baseline)
  if ("linear" %in% forms) {
    formulas_list$linear <- formula
  }

  # Quadratic
  if ("quadratic" %in% forms) {
    quad_terms <- paste0("I(", predictor_vars, "^2)")
    quad_formula_str <- paste(response_var, "~",
                             paste(c(predictor_vars, quad_terms), collapse = " + "))
    formulas_list$quadratic <- as.formula(quad_formula_str)
  }

  # Log (only for positive variables)
  if ("log" %in% forms) {
    # Check which variables are positive
    positive_vars <- predictor_vars[sapply(predictor_vars, function(v) {
      all(data[[v]] > 0, na.rm = TRUE)
    })]

    if (length(positive_vars) > 0) {
      log_terms <- paste0("log(", positive_vars, ")")
      non_positive <- setdiff(predictor_vars, positive_vars)

      if (length(non_positive) > 0) {
        log_formula_str <- paste(response_var, "~",
                                paste(c(log_terms, non_positive), collapse = " + "))
      } else {
        log_formula_str <- paste(response_var, "~",
                                paste(log_terms, collapse = " + "))
      }

      formulas_list$log <- as.formula(log_formula_str)
    } else {
      if (verbose) {
        message("  Skipping log form: no strictly positive variables")
      }
    }
  }

  # Interactions
  if ("interactions" %in% forms && length(predictor_vars) >= 2) {
    interact_formula_str <- paste(response_var, "~",
                                  paste(predictor_vars, collapse = " * "))
    formulas_list$interactions <- as.formula(interact_formula_str)
  }

  # Fit all models
  if (verbose) message("Fitting models...")

  models_list <- list()
  comparison_df <- data.frame(
    Form = character(),
    Formula = character(),
    stringsAsFactors = FALSE
  )

  for (form_name in names(formulas_list)) {
    if (verbose) message(sprintf("  - %s", form_name))

    form_obj <- formulas_list[[form_name]]

    # Fit model
    fit <- tryCatch({
      nnet::multinom(form_obj, data = data, trace = FALSE, ...)
    }, error = function(e) {
      if (verbose) message(sprintf("    Failed: %s", e$message))
      NULL
    })

    if (!is.null(fit)) {
      models_list[[form_name]] <- fit

      comparison_df <- rbind(comparison_df, data.frame(
        Form = form_name,
        Formula = deparse(form_obj, width.cutoff = 60)[1],
        stringsAsFactors = FALSE
      ))
    }
  }

  if (length(models_list) == 0) {
    stop("No models successfully fitted")
  }

  # Evaluate models
  if (verbose) message("\nEvaluating models...")

  y_true <- data[[response_var]]
  if (!is.factor(y_true)) {
    y_true <- factor(y_true)
  }

  # Calculate metrics
  for (form_name in names(models_list)) {
    fit <- models_list[[form_name]]

    # In-sample metrics
    if (selection_criterion %in% c("AIC", "BIC")) {
      if (selection_criterion == "AIC") {
        comparison_df$AIC[comparison_df$Form == form_name] <- AIC(fit)
      } else {
        comparison_df$BIC[comparison_df$Form == form_name] <- BIC(fit)
      }
    }

    # Prediction metrics
    if (selection_criterion %in% c("RMSE", "Brier", "CV")) {
      if (cross_validate) {
        # Cross-validation
        n <- nrow(data)
        fold_ids <- sample(rep(1:n_folds, length.out = n))

        cv_probs <- matrix(NA, n, length(levels(y_true)))

        for (fold in 1:n_folds) {
          test_idx <- which(fold_ids == fold)
          train_idx <- which(fold_ids != fold)

          train_data <- data[train_idx, ]
          test_data <- data[test_idx, ]

          # Refit on training data
          cv_fit <- tryCatch({
            nnet::multinom(formulas_list[[form_name]], data = train_data,
                          trace = FALSE, ...)
          }, error = function(e) NULL)

          if (!is.null(cv_fit)) {
            pred <- predict(cv_fit, newdata = test_data, type = "probs")
            if (!is.matrix(pred)) {
              pred <- cbind(1 - pred, pred)
            }
            cv_probs[test_idx, ] <- pred
          }
        }

        # Calculate CV metrics
        y_dummy <- model.matrix(~ y_true - 1)
        if (ncol(y_dummy) < ncol(cv_probs)) {
          y_dummy <- cbind(1 - rowSums(y_dummy), y_dummy)
        }

        cv_rmse <- sqrt(mean((y_dummy - cv_probs)^2, na.rm = TRUE))
        cv_brier <- mean((y_dummy - cv_probs)^2, na.rm = TRUE)

        comparison_df$RMSE_CV[comparison_df$Form == form_name] <- cv_rmse
        comparison_df$Brier_CV[comparison_df$Form == form_name] <- cv_brier

      } else {
        # In-sample
        probs <- fitted(fit)
        if (!is.matrix(probs)) {
          probs <- cbind(1 - probs, probs)
        }

        y_dummy <- model.matrix(~ y_true - 1)
        if (ncol(y_dummy) < ncol(probs)) {
          y_dummy <- cbind(1 - rowSums(y_dummy), y_dummy)
        }

        rmse <- sqrt(mean((y_dummy - probs)^2, na.rm = TRUE))
        brier <- mean((y_dummy - probs)^2, na.rm = TRUE)

        comparison_df$RMSE[comparison_df$Form == form_name] <- rmse
        comparison_df$Brier[comparison_df$Form == form_name] <- brier
      }
    }
  }

  # Select best model
  if (selection_criterion == "RMSE") {
    metric_col <- if (cross_validate) "RMSE_CV" else "RMSE"
    best_idx <- which.min(comparison_df[[metric_col]])
  } else if (selection_criterion == "Brier") {
    metric_col <- if (cross_validate) "Brier_CV" else "Brier"
    best_idx <- which.min(comparison_df[[metric_col]])
  } else if (selection_criterion == "AIC") {
    best_idx <- which.min(comparison_df$AIC)
  } else if (selection_criterion == "BIC") {
    best_idx <- which.min(comparison_df$BIC)
  } else if (selection_criterion == "CV") {
    best_idx <- which.min(comparison_df$RMSE_CV)
  }

  best_form <- comparison_df$Form[best_idx]
  best_model <- models_list[[best_form]]

  # Create recommendation
  if (selection_criterion %in% c("RMSE", "Brier", "CV")) {
    metric_col <- if (cross_validate) paste0(selection_criterion, "_CV") else selection_criterion
    best_value <- comparison_df[[metric_col]][best_idx]
    baseline_value <- comparison_df[[metric_col]][comparison_df$Form == "linear"]

    if (length(baseline_value) > 0) {
      improvement <- 100 * (baseline_value - best_value) / baseline_value
      recommendation <- sprintf(
        "Use %s specification (%s=%.4f, %.1f%% improvement over linear)",
        best_form, selection_criterion, best_value, improvement
      )
    } else {
      recommendation <- sprintf(
        "Use %s specification (%s=%.4f)",
        best_form, selection_criterion, best_value
      )
    }
  } else {
    best_value <- comparison_df[[selection_criterion]][best_idx]
    recommendation <- sprintf(
      "Use %s specification (%s=%.1f)",
      best_form, selection_criterion, best_value
    )
  }

  # Print results
  if (verbose) {
    cat("\n")
    cat(paste(rep("=", 70), collapse = ""), "\n")
    cat("  RESULTS: Functional Form Comparison\n")
    cat(paste(rep("=", 70), collapse = ""), "\n\n")

    print(comparison_df, row.names = FALSE, digits = 4)

    cat("\n")
    cat(sprintf("✓ Best specification: %s\n", best_form))
    cat(sprintf("  %s\n", recommendation))
    cat(paste(rep("=", 70), collapse = ""), "\n\n")

    if (best_form != "linear") {
      cat("Key finding: Flexible MNL outperforms linear specification.\n")
      cat("This aligns with the paper's result that functional form matters\n")
      cat("more than relaxing IIA assumption.\n\n")
    }
  }

  invisible(list(
    best_model = best_model,
    best_form = best_form,
    comparison_table = comparison_df,
    recommendation = recommendation,
    all_models = models_list,
    formulas = formulas_list,
    selection_criterion = selection_criterion
  ))
}
