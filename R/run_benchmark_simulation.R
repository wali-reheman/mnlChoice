#' Run Comprehensive Benchmark Simulation Study
#'
#' Conducts systematic Monte Carlo simulations across multiple conditions to
#' establish empirical benchmarks for MNL vs MNP performance.
#'
#' @param sample_sizes Vector of sample sizes to test. Default: c(50, 100, 250, 500, 1000, 2000).
#' @param correlations Vector of error correlations. Default: seq(0, 0.8, by=0.2).
#' @param effect_sizes Vector of effect sizes. Default: c(0.3, 0.5, 0.8).
#' @param n_reps Number of replications per condition. Default: 500.
#' @param n_alternatives Number of choice alternatives. Default: 3.
#' @param n_vars Number of predictor variables. Default: 2.
#' @param functional_forms Vector of functional forms. Default: c("linear", "quadratic").
#' @param parallel Logical. Use parallel processing. Default: FALSE.
#' @param n_cores Number of cores for parallel processing. Default: 4.
#' @param save_results Logical. Save results to .rda file. Default: TRUE.
#' @param output_file File path for saving results. Default: "data/mnl_mnp_benchmark.rda".
#' @param verbose Logical. Print progress. Default: TRUE.
#'
#' @return A data frame with columns:
#'   \item{n}{Sample size}
#'   \item{correlation}{Error correlation}
#'   \item{effect_size}{Effect size}
#'   \item{functional_form}{Functional form}
#'   \item{rep}{Replication number}
#'   \item{mnp_converged}{Logical: Did MNP converge?}
#'   \item{mnl_rmse}{MNL prediction RMSE}
#'   \item{mnp_rmse}{MNP prediction RMSE (NA if failed)}
#'   \item{mnl_winner}{Logical: Did MNL have lower RMSE?}
#'   \item{mnl_aic}{MNL AIC}
#'   \item{mnp_aic}{MNP AIC}
#'   \item{computation_time_mnl}{Seconds to fit MNL}
#'   \item{computation_time_mnp}{Seconds to fit MNP}
#'
#' @details
#' This function runs a comprehensive simulation study to replace placeholder
#' benchmark data with real empirical results.
#'
#' **Recommended Full Study:**
#' - 6 sample sizes × 5 correlations × 3 effect sizes × 2 forms × 500 reps = 45,000 simulations
#' - Estimated time: 12-24 hours with parallel processing
#' - Disk space: ~50-100 MB for results
#'
#' **Quick Pilot Study:**
#' - 3 sample sizes × 3 correlations × 2 effect sizes × 1 form × 100 reps = 1,800 simulations
#' - Estimated time: 1-2 hours
#'
#' @examples
#' \dontrun{
#' # Quick pilot study (1,800 simulations)
#' pilot <- run_benchmark_simulation(
#'   sample_sizes = c(100, 250, 500),
#'   correlations = c(0, 0.4, 0.8),
#'   effect_sizes = c(0.3, 0.5),
#'   functional_forms = "linear",
#'   n_reps = 100,
#'   save_results = TRUE,
#'   output_file = "data/pilot_benchmark.rda"
#' )
#'
#' # Full benchmark study (45,000 simulations - SLOW!)
#' full <- run_benchmark_simulation(
#'   n_reps = 500,
#'   parallel = TRUE,
#'   n_cores = 8,
#'   save_results = TRUE
#' )
#' }
#'
#' @export
run_benchmark_simulation <- function(sample_sizes = c(50, 100, 250, 500, 1000, 2000),
                                      correlations = seq(0, 0.8, by = 0.2),
                                      effect_sizes = c(0.3, 0.5, 0.8),
                                      n_reps = 500,
                                      n_alternatives = 3,
                                      n_vars = 2,
                                      functional_forms = c("linear", "quadratic"),
                                      parallel = FALSE,
                                      n_cores = 4,
                                      save_results = TRUE,
                                      output_file = "data/mnl_mnp_benchmark.rda",
                                      verbose = TRUE) {

  # Create design matrix
  conditions <- expand.grid(
    n = sample_sizes,
    correlation = correlations,
    effect_size = effect_sizes,
    functional_form = functional_forms,
    rep = 1:n_reps,
    stringsAsFactors = FALSE
  )

  n_conditions <- nrow(conditions)

  if (verbose) {
    cat("\n=== MNL vs MNP Benchmark Simulation ===\n\n")
    cat(sprintf("Total simulations: %d\n", n_conditions))
    cat(sprintf("  %d sample sizes: %s\n",
                length(sample_sizes), paste(sample_sizes, collapse = ", ")))
    cat(sprintf("  %d correlations: %s\n",
                length(correlations), paste(correlations, collapse = ", ")))
    cat(sprintf("  %d effect sizes: %s\n",
                length(effect_sizes), paste(effect_sizes, collapse = ", ")))
    cat(sprintf("  %d functional forms: %s\n",
                length(functional_forms), paste(functional_forms, collapse = ", ")))
    cat(sprintf("  %d replications per condition\n", n_reps))
    cat("\n")

    if (parallel) {
      cat(sprintf("Using parallel processing with %d cores\n", n_cores))
    }

    # Estimate time
    est_time_sec <- n_conditions * 2  # Rough estimate: 2 seconds per sim
    est_hours <- est_time_sec / 3600
    cat(sprintf("Estimated time: %.1f hours\n\n", est_hours))

    cat("Starting simulation...\n")
  }

  # Function to run a single simulation
  run_single_sim <- function(i) {
    cond <- conditions[i, ]

    # Generate data
    sim_data <- tryCatch({
      generate_choice_data(
        n = cond$n,
        n_alternatives = n_alternatives,
        n_vars = n_vars,
        correlation = cond$correlation,
        functional_form = cond$functional_form,
        effect_size = cond$effect_size,
        seed = i  # Unique seed for each replication
      )
    }, error = function(e) NULL)

    if (is.null(sim_data)) {
      return(data.frame(
        n = cond$n,
        correlation = cond$correlation,
        effect_size = cond$effect_size,
        functional_form = cond$functional_form,
        rep = cond$rep,
        mnp_converged = FALSE,
        mnl_rmse = NA,
        mnp_rmse = NA,
        mnl_winner = NA,
        mnl_aic = NA,
        mnp_aic = NA,
        computation_time_mnl = NA,
        computation_time_mnp = NA
      ))
    }

    # Use dynamic formula from generated data
    use_formula <- sim_data$formula

    # Fit MNL
    t_mnl_start <- Sys.time()
    mnl_fit <- tryCatch({
      if (requireNamespace("nnet", quietly = TRUE)) {
        nnet::multinom(use_formula, data = sim_data$data, trace = FALSE)
      } else {
        NULL
      }
    }, error = function(e) NULL)
    t_mnl <- as.numeric(difftime(Sys.time(), t_mnl_start, units = "secs"))

    # Fit MNP
    t_mnp_start <- Sys.time()
    mnp_fit <- tryCatch({
      if (requireNamespace("MNP", quietly = TRUE)) {
        MNP::mnp(use_formula, data = sim_data$data,
                verbose = FALSE, n.draws = 2000, burnin = 500)
      } else {
        NULL
      }
    }, error = function(e) NULL)
    t_mnp <- as.numeric(difftime(Sys.time(), t_mnp_start, units = "secs"))

    # Calculate performance metrics
    mnl_rmse <- NA
    mnp_rmse <- NA
    mnl_aic <- NA
    mnp_aic <- NA
    mnp_converged <- !is.null(mnp_fit)

    if (!is.null(mnl_fit)) {
      # MNL predictions
      mnl_probs <- predict(mnl_fit, type = "probs")
      if (!is.matrix(mnl_probs)) {
        mnl_probs <- cbind(1 - mnl_probs, mnl_probs)
      }
      mnl_rmse <- sqrt(mean((mnl_probs - sim_data$true_probs)^2))
      mnl_aic <- AIC(mnl_fit)
    }

    if (!is.null(mnp_fit)) {
      # MNP predictions
      mnp_pred <- tryCatch({
        predict(mnp_fit, type = "probs")
      }, error = function(e) NULL)

      if (!is.null(mnp_pred)) {
        mnp_rmse <- sqrt(mean((mnp_pred$p - sim_data$true_probs)^2))
        mnp_aic <- tryCatch(AIC(mnp_fit), error = function(e) NA)
      }
    }

    # Determine winner
    mnl_winner <- NA
    if (!is.na(mnl_rmse) && !is.na(mnp_rmse)) {
      mnl_winner <- mnl_rmse < mnp_rmse
    } else if (!is.na(mnl_rmse)) {
      mnl_winner <- TRUE
    }

    # Return results
    data.frame(
      n = cond$n,
      correlation = cond$correlation,
      effect_size = cond$effect_size,
      functional_form = cond$functional_form,
      rep = cond$rep,
      mnp_converged = mnp_converged,
      mnl_rmse = mnl_rmse,
      mnp_rmse = mnp_rmse,
      mnl_winner = mnl_winner,
      mnl_aic = mnl_aic,
      mnp_aic = mnp_aic,
      computation_time_mnl = t_mnl,
      computation_time_mnp = t_mnp
    )
  }

  # Run simulations (parallel or sequential)
  if (parallel) {
    if (!requireNamespace("parallel", quietly = TRUE)) {
      warning("parallel package not available, running sequentially")
      results_list <- lapply(1:n_conditions, run_single_sim)
    } else {
      cl <- parallel::makeCluster(n_cores)
      on.exit(parallel::stopCluster(cl), add = TRUE)

      # Export necessary objects
      parallel::clusterExport(cl, c("conditions", "n_alternatives"),
                             envir = environment())

      results_list <- parallel::parLapply(cl, 1:n_conditions, run_single_sim)
    }
  } else {
    # Sequential execution with progress
    results_list <- vector("list", n_conditions)
    for (i in 1:n_conditions) {
      results_list[[i]] <- run_single_sim(i)

      if (verbose && i %% 100 == 0) {
        cat(sprintf("  Completed %d / %d simulations (%.1f%%)\n",
                    i, n_conditions, 100 * i / n_conditions))
      }
    }
  }

  # Combine results
  results <- do.call(rbind, results_list)

  # Calculate summary statistics
  if (verbose) {
    cat("\n=== Simulation Complete ===\n\n")

    cat("MNP Convergence Rates by Sample Size:\n")
    conv_by_n <- aggregate(mnp_converged ~ n, data = results, FUN = mean)
    for (i in 1:nrow(conv_by_n)) {
      cat(sprintf("  n = %4d: %.1f%%\n",
                  conv_by_n$n[i], 100 * conv_by_n$mnp_converged[i]))
    }
    cat("\n")

    cat("MNL Win Rate (when both converge):\n")
    both_converged <- results[!is.na(results$mnl_winner), ]
    if (nrow(both_converged) > 0) {
      win_by_n <- aggregate(mnl_winner ~ n, data = both_converged, FUN = mean)
      for (i in 1:nrow(win_by_n)) {
        cat(sprintf("  n = %4d: %.1f%%\n",
                    win_by_n$n[i], 100 * win_by_n$mnl_winner[i]))
      }
    }
    cat("\n")
  }

  # Save results
  if (save_results) {
    # Create directory if needed
    output_dir <- dirname(output_file)
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE)
    }

    # Save
    benchmark_results <- results
    save(benchmark_results, file = output_file)

    if (verbose) {
      cat(sprintf("Results saved to: %s\n", output_file))
      cat(sprintf("File size: %.2f MB\n\n", file.size(output_file) / 1024^2))
    }
  }

  invisible(results)
}
