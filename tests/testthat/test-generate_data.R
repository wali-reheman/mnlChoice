test_that("generate_choice_data produces valid output", {

  # Basic generation
  dat <- generate_choice_data(n = 100, seed = 123)

  expect_type(dat, "list")
  expect_named(dat, c("data", "true_probs", "true_betas", "correlation_matrix",
                      "functional_form", "n", "n_alternatives"))

  # Check data dimensions
  expect_equal(nrow(dat$data), 100)
  expect_equal(nrow(dat$true_probs), 100)
  expect_equal(ncol(dat$true_probs), 3)  # 3 alternatives

  # Check that choice is a factor
  expect_s3_class(dat$data$choice, "factor")

  # Check probabilities sum to 1
  expect_true(all(abs(rowSums(dat$true_probs) - 1) < 1e-10))
})


test_that("generate_choice_data handles different parameters", {

  # Different number of alternatives
  dat <- generate_choice_data(n = 50, n_alternatives = 4, seed = 123)
  expect_equal(ncol(dat$true_probs), 4)
  expect_equal(length(levels(dat$data$choice)), 4)

  # Different functional forms
  dat_lin <- generate_choice_data(n = 50, functional_form = "linear", seed = 123)
  dat_quad <- generate_choice_data(n = 50, functional_form = "quadratic", seed = 123)
  dat_log <- generate_choice_data(n = 50, functional_form = "log", seed = 123)

  expect_equal(dat_lin$functional_form, "linear")
  expect_equal(dat_quad$functional_form, "quadratic")
  expect_equal(dat_log$functional_form, "log")

  # With correlation
  dat_cor <- generate_choice_data(n = 50, correlation = 0.5, seed = 123)
  expect_true(all(dat_cor$correlation_matrix[dat_cor$correlation_matrix != 1] == 0.5))
})


test_that("generate_choice_data validates inputs", {

  expect_error(generate_choice_data(n = -1), "positive")
  expect_error(generate_choice_data(n = 100, n_alternatives = 1), "at least 2")
  expect_error(generate_choice_data(n = 100, correlation = 1.5), "between 0 and 1")
  expect_error(generate_choice_data(n = 100, functional_form = "cubic"), "must be")
})


test_that("evaluate_performance calculates metrics correctly", {

  # Create simple test case
  n <- 100
  true_probs <- matrix(c(0.5, 0.3, 0.2), nrow = n, ncol = 3, byrow = TRUE)
  pred_probs <- true_probs + matrix(rnorm(n * 3, sd = 0.1), n, 3)
  pred_probs <- pred_probs / rowSums(pred_probs)  # Normalize

  actual_choices <- sample(1:3, n, replace = TRUE, prob = c(0.5, 0.3, 0.2))

  # Evaluate
  perf <- evaluate_performance(
    predicted_probs = pred_probs,
    true_probs = true_probs,
    actual_choices = actual_choices,
    metrics = c("RMSE", "Brier", "Accuracy")
  )

  expect_type(perf, "list")
  expect_true("RMSE" %in% names(perf))
  expect_true("Brier" %in% names(perf))
  expect_true("Accuracy" %in% names(perf))

  # Check values are reasonable
  expect_true(perf$RMSE > 0 && perf$RMSE < 1)
  expect_true(perf$Brier > 0 && perf$Brier < 1)
  expect_true(perf$Accuracy >= 0 && perf$Accuracy <= 1)
})
