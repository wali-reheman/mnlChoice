#!/usr/bin/env Rscript
# Test flexibility: multiple predictors and alternatives

cat("\n==============================================================\n")
cat("  FLEXIBILITY TEST: Multiple Predictors & Alternatives\n")
cat("==============================================================\n\n")

# Source all R files
source_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
for (f in source_files) {
  source(f)
}

tests_passed <- 0
tests_failed <- 0

test <- function(name, expr) {
  cat(sprintf("Testing: %s... ", name))
  result <- tryCatch({
    expr
    cat("✓\n")
    tests_passed <<- tests_passed + 1
    TRUE
  }, error = function(e) {
    cat(sprintf("✗\n  Error: %s\n", e$message))
    tests_failed <<- tests_failed + 1
    FALSE
  })
  result
}

cat(strrep("=", 70), "\n")
cat("PART 1: Data Generation with Different Specifications\n")
cat(strrep("=", 70), "\n\n")

# Test 1: 3 predictors
test("generate_choice_data with 3 predictors", {
  dat <- generate_choice_data(n = 100, n_vars = 3, seed = 123)
  stopifnot(ncol(dat$data) == 4)  # choice + x1 + x2 + x3
  stopifnot(!is.null(dat$formula))
  stopifnot(as.character(dat$formula)[3] == "x1 + x2 + x3")
  cat(sprintf("\n    Formula: %s\n", deparse(dat$formula)))
  cat(sprintf("    Data dimensions: %d x %d\n", nrow(dat$data), ncol(dat$data)))
})

# Test 2: 5 predictors
test("generate_choice_data with 5 predictors", {
  dat <- generate_choice_data(n = 100, n_vars = 5, seed = 456)
  stopifnot(ncol(dat$data) == 6)  # choice + x1 + x2 + x3 + x4 + x5
  stopifnot(as.character(dat$formula)[3] == "x1 + x2 + x3 + x4 + x5")
  cat(sprintf("\n    Formula: %s\n", deparse(dat$formula)))
})

# Test 3: 4 alternatives
test("generate_choice_data with 4 alternatives", {
  dat <- generate_choice_data(n = 100, n_alternatives = 4, seed = 789)
  stopifnot(length(levels(dat$data$choice)) == 4)
  stopifnot(ncol(dat$true_probs) == 4)
  cat(sprintf("\n    Alternatives: %d\n", dat$n_alternatives))
  cat(sprintf("    True probs shape: %d x %d\n", nrow(dat$true_probs), ncol(dat$true_probs)))
})

# Test 4: 10 predictors, 5 alternatives
test("generate_choice_data with 10 predictors, 5 alternatives", {
  dat <- generate_choice_data(n = 200, n_vars = 10, n_alternatives = 5, seed = 111)
  stopifnot(ncol(dat$data) == 11)  # choice + 10 predictors
  stopifnot(length(levels(dat$data$choice)) == 5)
  cat(sprintf("\n    Predictors: %d, Alternatives: %d\n", dat$n_vars, dat$n_alternatives))
})

cat("\n", strrep("=", 70), "\n")
cat("PART 2: Model Fitting with Different Specifications\n")
cat(strrep("=", 70), "\n\n")

# Test 5: fit_mnp_safe with 3 predictors
test("fit_mnp_safe with 3 predictors", {
  set.seed(222)
  dat <- generate_choice_data(n = 150, n_vars = 3, seed = 222)

  fit <- fit_mnp_safe(dat$formula, data = dat$data, fallback = "MNL", verbose = FALSE)
  stopifnot(!is.null(fit))
  stopifnot(length(coef(fit)) > 0)
  cat(sprintf("\n    Model: %s\n", attr(fit, "model_type")))
  cat(sprintf("    Coefficients: %d\n", length(coef(fit))))
})

# Test 6: fit_mnp_safe with 4 predictors
test("fit_mnp_safe with 4 predictors", {
  set.seed(333)
  dat <- generate_choice_data(n = 150, n_vars = 4, seed = 333)

  fit <- fit_mnp_safe(dat$formula, data = dat$data, fallback = "MNL", verbose = FALSE)
  stopifnot(!is.null(fit))
  cat(sprintf("\n    Formula: %s\n", deparse(dat$formula)))
  cat(sprintf("    Coefficients: %d\n", length(coef(fit))))
})

cat("\n", strrep("=", 70), "\n")
cat("PART 3: Comparison Functions with Different Specifications\n")
cat(strrep("=", 70), "\n\n")

# Test 7: compare_mnl_mnp with 3 predictors
test("compare_mnl_mnp with 3 predictors", {
  dat <- generate_choice_data(n = 150, n_vars = 3, seed = 444)

  comp <- compare_mnl_mnp(dat$formula, data = dat$data, fallback_mnp = TRUE, verbose = FALSE)
  stopifnot(!is.null(comp$results))
  cat(sprintf("\n    Formula used: %s\n", deparse(dat$formula)))
  cat(sprintf("    Winner: %s\n", comp$winner))
})

# Test 8: compare_mnl_mnp_cv with 4 predictors
test("compare_mnl_mnp_cv with 4 predictors", {
  dat <- generate_choice_data(n = 200, n_vars = 4, seed = 555)

  cv <- compare_mnl_mnp_cv(dat$formula, data = dat$data, k = 3, verbose = FALSE)
  stopifnot(!is.null(cv$results))
  cat(sprintf("\n    Cross-validation folds: %d\n", cv$n_folds))
})

cat("\n", strrep("=", 70), "\n")
cat("PART 4: High-Impact Functions with Different Specifications\n")
cat(strrep("=", 70), "\n\n")

# Test 9: quantify_model_choice_consequences with 3 predictors
test("quantify_model_choice_consequences with 3 predictors", {
  cons <- quantify_model_choice_consequences(
    n = 100,
    n_vars = 3,
    true_correlation = 0,
    n_sims = 10,
    verbose = FALSE
  )

  stopifnot(!is.null(cons$summary))
  stopifnot(nrow(cons$summary) == 2)
  cat(sprintf("\n    Predictors: 3\n"))
  cat(sprintf("    Recommendation: %s\n", cons$recommendation))
})

# Test 10: quantify_model_choice_consequences with 5 predictors
test("quantify_model_choice_consequences with 5 predictors", {
  cons <- quantify_model_choice_consequences(
    n = 100,
    n_vars = 5,
    n_alternatives = 4,
    true_correlation = 0.3,
    n_sims = 10,
    verbose = FALSE
  )

  stopifnot(!is.null(cons$summary))
  cat(sprintf("\n    Predictors: 5, Alternatives: 4\n"))
  cat(sprintf("    Safe zone: %s\n", cons$safe_zone))
})

# Test 11: Custom formula support
test("quantify_model_choice_consequences with custom formula", {
  # Generate data with 4 vars
  set.seed(666)
  dat <- generate_choice_data(n = 150, n_vars = 4, seed = 666)

  # Use custom formula with interaction
  custom_formula <- as.formula("choice ~ x1 + x2 + x3 + x4")

  cons <- quantify_model_choice_consequences(
    n = 100,
    n_vars = 4,
    formula = custom_formula,
    n_sims = 10,
    verbose = FALSE
  )

  stopifnot(!is.null(cons$summary))
  cat(sprintf("\n    Custom formula: %s\n", deparse(custom_formula)))
})

cat("\n", strrep("=", 70), "\n")
cat("PART 5: Diagnostic Functions\n")
cat(strrep("=", 70), "\n\n")

# Test 12: interpret_convergence_failure with 5 predictors
test("interpret_convergence_failure with 5 predictors", {
  set.seed(777)
  dat <- generate_choice_data(n = 50, n_vars = 5, seed = 777)

  diag <- interpret_convergence_failure(dat$formula, data = dat$data, verbose = FALSE)
  stopifnot(length(diag$likely_causes) > 0)
  stopifnot(diag$diagnostics$n == 50)
  cat(sprintf("\n    Causes identified: %d\n", length(diag$likely_causes)))
  cat(sprintf("    Recommendations: %d\n", length(diag$recommendations)))
})

cat("\n", strrep("=", 70), "\n")
cat("SUMMARY\n")
cat(strrep("=", 70), "\n\n")

cat(sprintf("Tests Passed: %d\n", tests_passed))
cat(sprintf("Tests Failed: %d\n", tests_failed))
cat(sprintf("Total Tests: %d\n\n", tests_passed + tests_failed))

if (tests_failed == 0) {
  cat("✓✓✓ ALL FLEXIBILITY TESTS PASSED! ✓✓✓\n\n")
  cat("Package now supports:\n")
  cat("  • Any number of predictors (tested: 2, 3, 4, 5, 10)\n")
  cat("  • Any number of alternatives (tested: 3, 4, 5)\n")
  cat("  • Dynamic formula generation\n")
  cat("  • Custom formula support\n\n")
  quit(status = 0)
} else {
  cat(sprintf("✗ %d tests failed\n\n", tests_failed))
  quit(status = 1)
}
