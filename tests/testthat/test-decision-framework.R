# Tests for decision_framework()

test_that("decision_framework provides reasonable recommendations", {
  # Small sample should recommend MNL
  result_small <- decision_framework(
    n = 150,
    estimand = "probabilities",
    computational_limits = FALSE,
    interactive = FALSE,
    verbose = FALSE
  )

  expect_equal(result_small$recommendation, "MNL")
  expect_equal(result_small$confidence, "High")

  # Large sample with no correlation should allow either
  result_large <- decision_framework(
    n = 1000,
    estimand = "probabilities",
    correlation = "none",
    computational_limits = FALSE,
    interactive = FALSE,
    verbose = FALSE
  )

  expect_true(result_large$recommendation %in% c("MNL", "MNP", "Either"))

  # Computational constraints should favor MNL
  result_constrained <- decision_framework(
    n = 500,
    estimand = "probabilities",
    computational_limits = TRUE,
    interactive = FALSE,
    verbose = FALSE
  )

  expect_equal(result_constrained$recommendation, "MNL")
})

test_that("decision_framework output has required fields", {
  result <- decision_framework(
    n = 300,
    estimand = "probabilities",
    interactive = FALSE,
    verbose = FALSE
  )

  expect_type(result, "list")
  expect_true("recommendation" %in% names(result))
  expect_true("reasoning" %in% names(result))
  expect_true("confidence" %in% names(result))
  expect_true("next_steps" %in% names(result))

  expect_type(result$next_steps, "character")
  expect_true(length(result$next_steps) > 0)
})

test_that("decision_framework handles different estimands", {
  # Substitution estimand should favor MNL
  result_sub <- decision_framework(
    n = 400,
    estimand = "substitution",
    interactive = FALSE,
    verbose = FALSE
  )

  expect_true(result_sub$recommendation %in% c("MNL", "Either"))

  # Parameters estimand
  result_param <- decision_framework(
    n = 600,
    estimand = "parameters",
    interactive = FALSE,
    verbose = FALSE
  )

  expect_true(!is.null(result_param$recommendation))
})
