# Tests for flexible_mnl()

test_that("flexible_mnl works with basic specifications", {
  skip_if_not_installed("nnet")

  set.seed(789)
  n <- 100
  data <- data.frame(
    x1 = rnorm(n),
    x2 = rnorm(n)
  )

  # Generate choice with quadratic relationship
  u1 <- 0.5 * data$x1 + 0.3 * data$x1^2 + rnorm(n)
  u2 <- -0.3 * data$x2 + rnorm(n)
  u3 <- rnorm(n)

  utilities <- cbind(u1, u2, u3)
  data$choice <- factor(apply(utilities, 1, which.max),
                       levels = 1:3,
                       labels = c("A", "B", "C"))

  # Test flexible_mnl
  result <- flexible_mnl(
    choice ~ x1 + x2,
    data = data,
    forms = c("linear", "quadratic"),
    selection_criterion = "AIC",
    cross_validate = FALSE,
    verbose = FALSE
  )

  # Check output structure
  expect_type(result, "list")
  expect_true("best_model" %in% names(result))
  expect_true("best_form" %in% names(result))
  expect_true("comparison_table" %in% names(result))
  expect_s3_class(result$best_model, "multinom")
  expect_true(result$best_form %in% c("linear", "quadratic"))
})

test_that("flexible_mnl handles log transform correctly", {
  skip_if_not_installed("nnet")

  set.seed(101)
  n <- 80
  data <- data.frame(
    x_positive = exp(rnorm(n)),  # Strictly positive
    x_mixed = rnorm(n)           # Can be negative
  )

  u1 <- 0.5 * log(data$x_positive) + rnorm(n)
  u2 <- 0.3 * data$x_mixed + rnorm(n)
  u3 <- rnorm(n)

  utilities <- cbind(u1, u2, u3)
  data$choice <- factor(apply(utilities, 1, which.max),
                       levels = 1:3,
                       labels = c("A", "B", "C"))

  # Should handle positive variable only
  result <- flexible_mnl(
    choice ~ x_positive,
    data = data,
    forms = c("linear", "log"),
    selection_criterion = "AIC",
    cross_validate = FALSE,
    verbose = FALSE
  )

  expect_true("log" %in% result$comparison_table$Form)

  # Should skip log for mixed variable
  result2 <- flexible_mnl(
    choice ~ x_mixed,
    data = data,
    forms = c("linear", "log"),
    selection_criterion = "AIC",
    cross_validate = FALSE,
    verbose = FALSE
  )

  # Log form should not be in comparison table if x_mixed has negative values
  # (unless it's the only form, in which case function should handle gracefully)
})

test_that("flexible_mnl comparison table has expected columns", {
  skip_if_not_installed("nnet")

  set.seed(202)
  n <- 60
  data <- data.frame(
    x = rnorm(n),
    choice = factor(sample(1:3, n, replace = TRUE), labels = c("A", "B", "C"))
  )

  result <- flexible_mnl(
    choice ~ x,
    data = data,
    forms = "linear",
    selection_criterion = "AIC",
    cross_validate = FALSE,
    verbose = FALSE
  )

  expect_true("Form" %in% colnames(result$comparison_table))
  expect_true("AIC" %in% colnames(result$comparison_table))
  expect_equal(nrow(result$comparison_table), 1)  # Only linear form
})
