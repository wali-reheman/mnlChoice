#' Test Multiple Functional Forms and Recommend Best
#'
#' Systematically tests multiple functional forms for predictors and recommends
#' the best specification based on cross-validation or information criteria.
#'
#' @param formula Base formula (e.g., y ~ x1 + x2).
#' @param data Data frame containing the variables.
#' @param test_forms Character vector. Forms to test: "linear", "quadratic", "log",
#'   "sqrt", "inverse", "interactions". Default c("linear", "quadratic", "log").
#' @param metric Character. Selection criterion: "RMSE", "Brier", "AIC", "BIC". Default "RMSE".
#' @param cross_validate Logical. Use cross-validation. Default TRUE.
#' @param n_folds Integer. Number of CV folds. Default 5.
#' @param verbose Logical. Print results. Default TRUE.
#' @param ... Additional arguments passed to fitting function.
#'
#' @return A list with components:
#'   \item{best_form}{Character: winning functional form}
#'   \item{best_model}{Fitted model with best form}
#'   \item{ranked_results}{Data frame with all forms ranked by performance}
#'   \item{improvement}{Percentage improvement over linear baseline}
#'   \item{recommendation}{Text recommendation}
#'
#' @details
#' This function implements the paper's finding that functional form specification
#' matters more than choice between MNL and MNP.
#'
#' **Functional forms tested:**
#' \itemize{
#'   \item linear: y ~ x
#'   \item quadratic: y ~ x + x^2
#'   \item log: y ~ log(x) (positive variables only)
#'   \item sqrt: y ~ sqrt(x) (non-negative variables only)
#'   \item inverse: y ~ 1/x (positive variables only)
#'   \item interactions: y ~ x1 * x2
#' }
#'
#' @examples
#' \dontrun{
#' result <- functional_form_test(
#'   vote ~ ideology + income,
#'   data = election_data,
#'   test_forms = c("linear", "quadratic", "log")
#' )
#'
#' print(result$ranked_results)
#' }
#'
#' @export
functional_form_test <- function(formula, data,
                                 test_forms = c("linear", "quadratic", "log"),
                                 metric = "RMSE",
                                 cross_validate = TRUE,
                                 n_folds = 5,
                                 verbose = TRUE,
                                 ...) {

  if (!requireNamespace("nnet", quietly = TRUE)) {
    stop("nnet package required. Install with: install.packages('nnet')")
  }

  # This is essentially a wrapper around flexible_mnl with different interface
  result <- flexible_mnl(
    formula = formula,
    data = data,
    forms = test_forms,
    selection_criterion = metric,
    cross_validate = cross_validate,
    n_folds = n_folds,
    verbose = FALSE,
    ...
  )

  # Reformat output
  ranked_results <- result$comparison_table
  ranked_results <- ranked_results[order(ranked_results[[paste0(metric, if(cross_validate) "_CV" else "")]]), ]

  # Calculate improvement over linear
  if ("linear" %in% ranked_results$Form) {
    metric_col <- paste0(metric, if(cross_validate) "_CV" else "")
    baseline <- ranked_results[[metric_col]][ranked_results$Form == "linear"]
    best <- ranked_results[[metric_col]][1]

    improvement <- 100 * (baseline - best) / baseline
  } else {
    improvement <- NA
  }

  if (verbose) {
    cat("\n")
    cat(paste(rep("=", 70), collapse = ""), "\n")
    cat("  FUNCTIONAL FORM TEST RESULTS\n")
    cat(paste(rep("=", 70), collapse = ""), "\n\n")

    cat("Ranked by", metric, if(cross_validate) "(Cross-validated)" else "(In-sample)", ":\n\n")

    print(ranked_results, row.names = FALSE, digits = 4)

    cat("\n")
    cat(sprintf("✓ Best form: %s\n", result$best_form))

    if (!is.na(improvement) && improvement > 0) {
      cat(sprintf("  %.1f%% improvement over linear baseline\n", improvement))
    }

    cat("\n")
    cat(result$recommendation)
    cat("\n")
    cat(paste(rep("=", 70), collapse = ""), "\n\n")
  }

  invisible(list(
    best_form = result$best_form,
    best_model = result$best_model,
    ranked_results = ranked_results,
    improvement = improvement,
    recommendation = result$recommendation,
    metric = metric,
    cross_validated = cross_validate
  ))
}
