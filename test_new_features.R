#!/usr/bin/env Rscript
# Test all new high-impact features
# Tests: test_iia(), quick_decision(), publication_table(), commuter_choice dataset

cat("\n")
cat(paste(rep("=", 70), collapse = ""), "\n")
cat("  TESTING NEW PACKAGE FEATURES\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

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

cat(paste(rep("=", 70), collapse = ""), "\n")
cat("PART 1: Real Dataset (commuter_choice)\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Test 1: Load commuter_choice dataset
test("Load commuter_choice dataset", {
  load("data/commuter_choice.rda")
  stopifnot(exists("commuter_choice"))
  stopifnot(is.data.frame(commuter_choice))
  stopifnot(nrow(commuter_choice) == 500)
  stopifnot("mode" %in% colnames(commuter_choice))
  cat(sprintf("\n    Loaded %d observations\n", nrow(commuter_choice)))
  cat(sprintf("    Variables: %s\n", paste(colnames(commuter_choice), collapse = ", ")))
  cat(sprintf("    Mode distribution: %s\n",
              paste(names(table(commuter_choice$mode)),
                    table(commuter_choice$mode), sep = "=", collapse = ", ")))
})

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("PART 2: IIA Testing (test_iia)\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Test 2: test_iia() basic functionality
test("test_iia() basic functionality", {
  load("data/commuter_choice.rda")

  # Check if nnet is available
  if (!requireNamespace("nnet", quietly = TRUE)) {
    stop("nnet package required for IIA test")
  }

  result <- test_iia(
    mode ~ income + age + distance + owns_car,
    data_obj = commuter_choice,
    omit_alternative = NULL,  # Will auto-select smallest
    verbose = FALSE
  )

  stopifnot(!is.null(result))
  stopifnot(all(c("test_statistic", "p_value", "decision", "recommendation") %in% names(result)))
  stopifnot(is.numeric(result$test_statistic))
  stopifnot(is.numeric(result$p_value))

  cat(sprintf("\n    Test statistic: %.3f\n", result$test_statistic))
  cat(sprintf("    P-value: %.4f\n", result$p_value))
  cat(sprintf("    Decision: %s\n", result$decision))
  cat(sprintf("    Recommendation: %s\n", result$recommendation))
})

# Test 3: test_iia() with specific alternative
test("test_iia() with specified alternative", {
  load("data/commuter_choice.rda")

  result <- test_iia(
    mode ~ income + age + distance,
    data_obj = commuter_choice,
    omit_alternative = "Active",  # Smallest group
    verbose = FALSE
  )

  stopifnot(result$omitted_alternative == "Active")
  cat(sprintf("\n    Omitted: %s\n", result$omitted_alternative))
  cat(sprintf("    Result: %s\n", result$decision))
})

# Test 4: test_iia() verbose output
test("test_iia() verbose output", {
  load("data/commuter_choice.rda")

  cat("\n")
  result <- test_iia(
    mode ~ income + distance + owns_car,
    data_obj = commuter_choice,
    verbose = TRUE
  )

  stopifnot(!is.null(result))
})

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("PART 3: Quick Decision Tool (quick_decision)\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Test 5: quick_decision() small sample
test("quick_decision() with small sample (n=100)", {
  result <- quick_decision(n = 100, n_predictors = 3, verbose = FALSE)

  stopifnot(!is.null(result))
  stopifnot(all(c("recommendation", "model", "reason", "confidence") %in% names(result)))
  stopifnot(result$model == "MNL")

  cat(sprintf("\n    Model: %s\n", result$model))
  cat(sprintf("    Reason: %s\n", result$reason))
  cat(sprintf("    Confidence: %s\n", result$confidence))
})

# Test 6: quick_decision() medium sample, no correlation
test("quick_decision() with n=250, no correlation", {
  result <- quick_decision(
    n = 250,
    n_predictors = 4,
    has_correlation = "no",
    verbose = FALSE
  )

  stopifnot(result$model == "MNL")
  cat(sprintf("\n    Result: %s (%s)\n", result$model, result$reason))
})

# Test 7: quick_decision() large sample with correlation
test("quick_decision() with n=1000, correlation present", {
  result <- quick_decision(
    n = 1000,
    n_predictors = 3,
    has_correlation = "yes",
    verbose = FALSE
  )

  cat(sprintf("\n    Model: %s\n", result$model))
  cat(sprintf("    Reason: %s\n", result$reason))
})

# Test 8: quick_decision() computational constraints
test("quick_decision() with computational constraints", {
  result <- quick_decision(
    n = 500,
    n_predictors = 10,
    computational_constraint = TRUE,
    verbose = FALSE
  )

  stopifnot(result$model == "MNL")
  cat(sprintf("\n    Result: %s (computational constraint)\n", result$model))
})

# Test 9: quick_decision() verbose output
test("quick_decision() verbose mode", {
  cat("\n")
  result <- quick_decision(
    n = 300,
    n_predictors = 5,
    n_alternatives = 4,
    has_correlation = "unknown",
    verbose = TRUE
  )

  stopifnot(!is.null(result))
})

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("PART 4: Publication Tables (publication_table)\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Test 10: publication_table() LaTeX format
test("publication_table() LaTeX output", {
  load("data/commuter_choice.rda")

  if (!requireNamespace("nnet", quietly = TRUE)) {
    stop("nnet required for publication table test")
  }

  # Fit MNL model
  mnl_fit <- nnet::multinom(
    mode ~ income + age + distance + owns_car,
    data = commuter_choice,
    trace = FALSE
  )

  table_latex <- publication_table(
    mnl_fit,
    format = "latex",
    title = "Transportation Mode Choice",
    verbose = FALSE
  )

  stopifnot(!is.null(table_latex))
  stopifnot(is.character(table_latex))
  stopifnot(grepl("\\\\begin\\{table\\}", table_latex))
  stopifnot(grepl("\\\\end\\{table\\}", table_latex))

  cat("\n    LaTeX table generated successfully\n")
  cat(sprintf("    Length: %d characters\n", nchar(table_latex)))
})

# Test 11: publication_table() HTML format
test("publication_table() HTML output", {
  load("data/commuter_choice.rda")

  mnl_fit <- nnet::multinom(
    mode ~ income + distance,
    data = commuter_choice,
    trace = FALSE
  )

  table_html <- publication_table(
    mnl_fit,
    format = "html",
    verbose = FALSE
  )

  stopifnot(!is.null(table_html))
  stopifnot(grepl("<table", table_html))
  stopifnot(grepl("</table>", table_html))

  cat("\n    HTML table generated successfully\n")
})

# Test 12: publication_table() markdown format
test("publication_table() markdown output", {
  load("data/commuter_choice.rda")

  mnl_fit <- nnet::multinom(
    mode ~ income + age + owns_car,
    data = commuter_choice,
    trace = FALSE
  )

  table_md <- publication_table(
    mnl_fit,
    format = "markdown",
    verbose = FALSE
  )

  stopifnot(!is.null(table_md))
  stopifnot(grepl("\\|", table_md))  # Markdown tables use |

  cat("\n    Markdown table generated successfully\n")
})

# Test 13: publication_table() with both MNL and MNP
test("publication_table() comparing MNL and MNP", {
  load("data/commuter_choice.rda")

  # Fit MNL
  mnl_fit <- nnet::multinom(
    mode ~ income + distance,
    data = commuter_choice,
    trace = FALSE
  )

  # Try MNP if available
  mnp_fit <- NULL
  if (requireNamespace("MNP", quietly = TRUE)) {
    mnp_fit <- tryCatch({
      MNP::mnp(mode ~ income + distance,
               data = commuter_choice,
               verbose = FALSE,
               n.draws = 1000,
               burnin = 200)
    }, error = function(e) NULL)
  }

  if (!is.null(mnp_fit)) {
    table_both <- publication_table(mnl_fit, mnp_fit, format = "markdown", verbose = FALSE)
    stopifnot(grepl("MNP", table_both))
    cat("\n    Comparison table with both models generated\n")
  } else {
    table_mnl <- publication_table(mnl_fit, format = "markdown", verbose = FALSE)
    cat("\n    MNP not available, MNL-only table generated\n")
  }
})

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("PART 5: Integration Tests\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Test 14: Full workflow with real data
test("Full workflow: data → IIA test → decision → table", {
  load("data/commuter_choice.rda")

  cat("\n\n    === FULL WORKFLOW DEMONSTRATION ===\n\n")

  # Step 1: Quick decision
  cat("    Step 1: Quick decision\n")
  decision <- quick_decision(
    n = nrow(commuter_choice),
    n_predictors = 4,
    verbose = FALSE
  )
  cat(sprintf("      → Recommendation: %s\n", decision$model))

  # Step 2: IIA test
  cat("\n    Step 2: IIA test\n")
  iia_result <- test_iia(
    mode ~ income + age + distance + owns_car,
    data_obj = commuter_choice,
    verbose = FALSE
  )
  cat(sprintf("      → IIA: %s (p=%.4f)\n", iia_result$decision, iia_result$p_value))

  # Step 3: Fit model
  cat("\n    Step 3: Fit recommended model\n")
  mnl_fit <- nnet::multinom(
    mode ~ income + age + distance + owns_car,
    data = commuter_choice,
    trace = FALSE
  )
  cat("      → Model fitted successfully\n")

  # Step 4: Create publication table
  cat("\n    Step 4: Generate publication table\n")
  pub_table <- publication_table(mnl_fit, format = "markdown", verbose = FALSE)
  cat("      → Table generated\n")

  cat("\n    === WORKFLOW COMPLETE ===\n")

  stopifnot(!is.null(decision))
  stopifnot(!is.null(iia_result))
  stopifnot(!is.null(mnl_fit))
  stopifnot(!is.null(pub_table))
})

# Test 15: Benchmark data warnings
test("Benchmark data has proper warnings", {
  load("data/mnl_mnp_benchmark.rda")

  # Check for warning attributes
  warning_attr <- attr(mnl_mnp_benchmark, "warning")
  stopifnot(!is.null(warning_attr))
  stopifnot(grepl("ILLUSTRATIVE", warning_attr))

  # Check data_type field
  stopifnot("data_type" %in% colnames(mnl_mnp_benchmark))
  stopifnot(mnl_mnp_benchmark$data_type[1] == "illustrative_placeholder")

  # Check n_replications = 0
  stopifnot(mnl_mnp_benchmark$n_replications[1] == 0)

  cat("\n    ✓ Warning attributes present\n")
  cat("    ✓ data_type = illustrative_placeholder\n")
  cat("    ✓ n_replications = 0\n")
})

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("SUMMARY\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

cat(sprintf("Tests Passed: %d\n", tests_passed))
cat(sprintf("Tests Failed: %d\n\n", tests_failed))

if (tests_failed == 0) {
  cat("✓✓✓ ALL TESTS PASSED! ✓✓✓\n\n")
  cat("New features validated:\n")
  cat("  ✓ test_iia() - Hausman-McFadden IIA test\n")
  cat("  ✓ quick_decision() - Rule-of-thumb recommendations\n")
  cat("  ✓ publication_table() - Camera-ready tables (LaTeX/HTML/markdown)\n")
  cat("  ✓ commuter_choice - Real dataset example\n")
  cat("  ✓ Benchmark data warnings - Honesty labels\n\n")
  quit(status = 0)
} else {
  cat(sprintf("✗ %d tests failed\n\n", tests_failed))
  quit(status = 1)
}
