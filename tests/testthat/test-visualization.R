test_that("plot_convergence_rates runs without error", {

  # Basic plot
  expect_silent({
    result <- plot_convergence_rates(
      sample_sizes = c(100, 250, 500),
      add_benchmark = FALSE
    )
  })

  # Check return value
  expect_s3_class(result, "data.frame")
  expect_named(result, c("n", "convergence_rate"))
})


test_that("plot_win_rates runs without error", {

  expect_silent({
    result <- plot_win_rates(
      sample_sizes = c(100, 250, 500),
      correlation = 0.3
    )
  })

  expect_s3_class(result, "data.frame")
  expect_true(all(result$win_rate >= 0 & result$win_rate <= 1))
})


test_that("plot_recommendation_regions runs without error", {

  expect_silent({
    result <- plot_recommendation_regions(
      n_range = c(100, 500),
      correlation_range = c(0, 0.5)
    )
  })

  expect_type(result, "list")
  expect_true("n" %in% names(result))
  expect_true("correlation" %in% names(result))
  expect_true("recommendation" %in% names(result))
})
