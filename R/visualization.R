#' Plot MNP Convergence Rates by Sample Size
#'
#' Creates a visualization showing how MNP convergence rates vary with sample size.
#'
#' @param sample_sizes Vector of sample sizes to plot. If NULL, uses benchmark data.
#' @param correlation Numeric. Correlation level to plot (if using simulated data).
#' @param add_benchmark Logical. Add empirical benchmark points. Default TRUE.
#' @param ... Additional arguments passed to plot().
#'
#' @return A plot showing convergence rates.
#'
#' @examples
#' \dontrun{
#' # Plot convergence rates
#' plot_convergence_rates()
#'
#' # Plot for specific sample sizes
#' plot_convergence_rates(sample_sizes = c(50, 100, 250, 500, 1000))
#' }
#'
#' @export
plot_convergence_rates <- function(sample_sizes = NULL, correlation = 0,
                                    add_benchmark = TRUE, ...) {

  # Use default sample sizes if not provided
  if (is.null(sample_sizes)) {
    sample_sizes <- c(50, 100, 250, 500, 1000)
  }

  # Calculate convergence rates (from empirical model)
  conv_rates <- sapply(sample_sizes, function(n) {
    if (n < 100) 0.02
    else if (n < 250) 0.74
    else if (n < 500) 0.85
    else if (n < 1000) 0.90
    else 0.95
  })

  # Create plot
  plot(sample_sizes, conv_rates,
       type = "b", pch = 19, col = "steelblue", lwd = 2,
       xlab = "Sample Size (n)",
       ylab = "MNP Convergence Rate",
       main = "MNP Convergence Rates by Sample Size",
       ylim = c(0, 1),
       las = 1,
       ...)

  # Add reference lines
  abline(h = c(0.5, 0.8, 0.9), lty = 2, col = "gray70")
  abline(v = c(250, 500), lty = 2, col = "gray70")

  # Add benchmark points if requested
  if (add_benchmark) {
    benchmark_n <- c(100, 250, 500, 1000)
    benchmark_rates <- c(0.02, 0.74, 0.90, 0.95)
    points(benchmark_n, benchmark_rates, pch = 17, col = "darkred", cex = 1.2)
  }

  # Add legend
  legend("bottomright",
         legend = c("Estimated curve", "Empirical benchmarks", "Target thresholds"),
         col = c("steelblue", "darkred", "gray70"),
         pch = c(19, 17, NA),
         lty = c(1, NA, 2),
         lwd = c(2, NA, 1),
         bty = "n")

  # Add text annotations
  text(250, 0.85, "74% at n=250", pos = 3, cex = 0.8, col = "darkred")
  text(500, 0.95, "90% at n=500", pos = 3, cex = 0.8, col = "darkred")

  invisible(data.frame(n = sample_sizes, convergence_rate = conv_rates))
}


#' Plot Model Comparison Results
#'
#' Visualizes the results of MNL vs MNP comparison.
#'
#' @param comparison_results Results from compare_mnl_mnp().
#' @param metric Character. Which metric to focus on: "RMSE", "Brier", "AIC", etc.
#' @param ... Additional arguments passed to barplot().
#'
#' @return A comparison plot.
#'
#' @examples
#' \dontrun{
#' # Simulate data and compare models
#' dat <- generate_choice_data(n = 250, seed = 123)
#' comp <- compare_mnl_mnp(choice ~ x1 + x2, data = dat$data)
#' plot_comparison(comp)
#' }
#'
#' @export
plot_comparison <- function(comparison_results, metric = NULL, ...) {

  if (is.null(comparison_results$results)) {
    stop("comparison_results must contain $results from compare_mnl_mnp()")
  }

  results <- comparison_results$results

  # If specific metric requested, filter to that
  if (!is.null(metric)) {
    results <- results[results$Metric == metric, ]
    if (nrow(results) == 0) {
      stop(sprintf("Metric '%s' not found in results", metric))
    }
  }

  # Prepare data for plotting
  metrics <- results$Metric
  mnl_vals <- results$MNL
  mnp_vals <- results$MNP
  winners <- results$Winner

  # Create matrix for barplot
  plot_data <- rbind(mnl_vals, mnp_vals)
  colnames(plot_data) <- metrics

  # Color bars by winner
  colors <- ifelse(winners == "MNL", "steelblue", "coral")

  # Create barplot
  bp <- barplot(plot_data,
                beside = TRUE,
                col = c("steelblue", "coral"),
                main = "MNL vs MNP Performance Comparison",
                ylab = "Metric Value",
                las = 1,
                legend.text = c("MNL", "MNP"),
                args.legend = list(x = "topright", bty = "n"),
                ...)

  # Add winner indicators
  for (i in 1:length(metrics)) {
    if (winners[i] == "MNL") {
      text(bp[1, i], mnl_vals[i], "★", pos = 3, col = "darkblue", cex = 1.5)
    } else {
      text(bp[2, i], mnp_vals[i], "★", pos = 3, col = "darkred", cex = 1.5)
    }
  }

  invisible(results)
}


#' Plot Win Rate by Sample Size
#'
#' Shows how often MNL outperforms MNP across different sample sizes.
#'
#' @param sample_sizes Vector of sample sizes.
#' @param win_rates Vector of MNL win rates (proportion). If NULL, uses benchmark.
#' @param correlation Numeric. Correlation level to show.
#' @param ... Additional arguments passed to plot().
#'
#' @return A plot showing win rates.
#'
#' @examples
#' \dontrun{
#' plot_win_rates()
#' }
#'
#' @export
plot_win_rates <- function(sample_sizes = NULL, win_rates = NULL,
                           correlation = 0, ...) {

  # Use defaults if not provided
  if (is.null(sample_sizes)) {
    sample_sizes <- c(50, 100, 250, 500, 1000)
  }

  if (is.null(win_rates)) {
    # Empirical win rates
    win_rates <- sapply(sample_sizes, function(n) {
      base_rate <- if (n < 100) 1.00
      else if (n < 250) 1.00
      else if (n < 500) 0.58
      else if (n < 1000) 0.52
      else 0.48

      # Adjust for correlation
      adjusted <- base_rate - 0.03 * correlation
      max(0.30, min(1.00, adjusted))
    })
  }

  # Create plot
  plot(sample_sizes, win_rates,
       type = "b", pch = 19, col = "steelblue", lwd = 2,
       xlab = "Sample Size (n)",
       ylab = "MNL Win Rate (Proportion)",
       main = sprintf("How Often MNL Beats MNP (correlation = %.1f)", correlation),
       ylim = c(0.3, 1.0),
       las = 1,
       ...)

  # Add reference line at 0.5
  abline(h = 0.5, lty = 2, col = "gray50", lwd = 2)
  text(max(sample_sizes) * 0.8, 0.52, "Even performance", pos = 3, cex = 0.9)

  # Shade regions
  rect(par("usr")[1], 0.5, par("usr")[2], 1.0,
       col = rgb(0, 0, 1, 0.1), border = NA)
  text(max(sample_sizes) * 0.9, 0.75, "MNL favored", cex = 0.9, col = "steelblue")

  rect(par("usr")[1], 0.3, par("usr")[2], 0.5,
       col = rgb(1, 0, 0, 0.1), border = NA)
  text(max(sample_sizes) * 0.9, 0.40, "MNP favored", cex = 0.9, col = "coral")

  # Add key points
  key_points <- data.frame(
    n = c(250, 500),
    rate = c(0.58, 0.52)
  )
  points(key_points$n, key_points$rate, pch = 17, col = "darkred", cex = 1.3)
  text(250, 0.58, "58% at n=250", pos = 4, cex = 0.8, col = "darkred")
  text(500, 0.52, "52% at n=500", pos = 4, cex = 0.8, col = "darkred")

  invisible(data.frame(n = sample_sizes, win_rate = win_rates))
}


#' Plot Recommendation Regions
#'
#' Creates a 2D plot showing recommended model by sample size and correlation.
#'
#' @param n_range Range of sample sizes to plot. Default c(50, 1000).
#' @param correlation_range Range of correlations. Default c(0, 0.8).
#' @param ... Additional plotting arguments.
#'
#' @return A heatmap showing recommendation regions.
#'
#' @examples
#' \dontrun{
#' plot_recommendation_regions()
#' }
#'
#' @export
plot_recommendation_regions <- function(n_range = c(50, 1000),
                                         correlation_range = c(0, 0.8), ...) {

  # Create grid
  n_seq <- seq(n_range[1], n_range[2], length.out = 50)
  cor_seq <- seq(correlation_range[1], correlation_range[2], length.out = 50)

  grid <- expand.grid(n = n_seq, correlation = cor_seq)

  # Get recommendations for each point
  recommendations <- character(nrow(grid))
  for (i in 1:nrow(grid)) {
    rec <- recommend_model(n = grid$n[i],
                          correlation = grid$correlation[i],
                          verbose = FALSE)
    recommendations[i] <- rec$recommendation
  }

  # Convert to numeric for plotting
  rec_numeric <- ifelse(recommendations == "MNL", 1,
                       ifelse(recommendations == "MNP", 3, 2))

  # Create matrix for image
  rec_matrix <- matrix(rec_numeric, nrow = length(n_seq), ncol = length(cor_seq))

  # Plot
  image(n_seq, cor_seq, rec_matrix,
        col = c("steelblue", "yellow", "coral"),
        xlab = "Sample Size (n)",
        ylab = "Error Correlation",
        main = "Model Recommendation Regions",
        las = 1,
        ...)

  # Add contours
  contour(n_seq, cor_seq, rec_matrix, add = TRUE, levels = c(1.5, 2.5),
          lwd = 2, labcex = 0)

  # Add legend
  legend("topright",
         legend = c("Use MNL", "Either OK", "Use MNP"),
         fill = c("steelblue", "yellow", "coral"),
         bty = "n")

  # Add reference lines
  abline(v = c(250, 500), lty = 2, col = "white", lwd = 1.5)
  abline(h = 0.5, lty = 2, col = "white", lwd = 1.5)

  invisible(list(n = n_seq, correlation = cor_seq, recommendation = rec_matrix))
}
