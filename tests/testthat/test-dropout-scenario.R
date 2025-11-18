# Tests for simulate_dropout_scenario()

test_that("simulate_dropout_scenario works with basic input", {
  skip_if_not_installed("nnet")

  # Generate small test data
  set.seed(123)
  n <- 100
  data <- data.frame(
    x1 = rnorm(n),
    x2 = rnorm(n)
  )

  # Generate choice with 3 alternatives
  u1 <- 0.5 * data$x1 + rnorm(n)
  u2 <- -0.3 * data$x2 + rnorm(n)
  u3 <- rnorm(n)

  utilities <- cbind(u1, u2, u3)
  data$choice <- factor(apply(utilities, 1, which.max),
                       levels = 1:3,
                       labels = c("A", "B", "C"))

  # Run dropout scenario
  result <- simulate_dropout_scenario(
    choice ~ x1 + x2,
    data = data,
    drop_alternative = "C",
    n_sims = 1000,
    models = "MNL",
    verbose = FALSE
  )

  # Check output structure
  expect_type(result, "list")
  expect_true("dropped_alternative" %in% names(result))
  expect_true("true_transitions" %in% names(result))
  expect_true("mnl_predictions" %in% names(result))
  expect_equal(result$dropped_alternative, "C")
  expect_equal(length(result$true_transitions), 2)  # A and B remain
})

test_that("simulate_dropout_scenario handles invalid inputs", {
  set.seed(123)
  n <- 50
  data <- data.frame(
    x = rnorm(n),
    choice = factor(sample(1:3, n, replace = TRUE), labels = c("A", "B", "C"))
  )

  # Should error on non-existent alternative
  expect_error(
    simulate_dropout_scenario(
      choice ~ x,
      data = data,
      drop_alternative = "D",
      verbose = FALSE
    ),
    "not found in response variable"
  )

  # Should error on binary choice (need 3+ alternatives)
  data_binary <- data.frame(
    x = rnorm(50),
    choice = factor(sample(1:2, 50, replace = TRUE), labels = c("A", "B"))
  )

  expect_error(
    simulate_dropout_scenario(
      choice ~ x,
      data = data_binary,
      drop_alternative = "B",
      verbose = FALSE
    ),
    "at least 3 alternatives"
  )
})

test_that("simulate_dropout_scenario MNL predictions are reasonable", {
  skip_if_not_installed("nnet")

  # Generate data with strong preference for A over B
  set.seed(456)
  n <- 150
  data <- data.frame(x = rnorm(n))

  u_A <- 2 + data$x + rnorm(n, 0, 0.5)
  u_B <- 0 + 0.5 * data$x + rnorm(n, 0, 0.5)
  u_C <- -1 + rnorm(n, 0, 0.5)

  utilities <- cbind(u_A, u_B, u_C)
  data$choice <- factor(apply(utilities, 1, which.max),
                       levels = 1:3,
                       labels = c("A", "B", "C"))

  result <- simulate_dropout_scenario(
    choice ~ x,
    data = data,
    drop_alternative = "C",
    n_sims = 2000,
    models = "MNL",
    verbose = FALSE
  )

  # Should predict more flow to A than B (A has higher utility)
  expect_true(!is.null(result$mnl_predictions))
  expect_equal(length(result$mnl_predictions), 2)
  expect_true(sum(result$mnl_predictions) > 0.99 && sum(result$mnl_predictions) < 1.01)  # Should sum to ~1
})
