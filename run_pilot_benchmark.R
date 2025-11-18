#!/usr/bin/env Rscript
# Run REAL pilot benchmark study
# This replaces placeholder data with actual empirical results
#
# Study design: 3 × 3 × 2 × 100 = 1,800 simulations
# Estimated time: 1-2 hours (without parallel) or 30-60 min (with parallel)

cat("\n")
cat(paste(rep("=", 70), collapse = ""), "\n")
cat("  PILOT BENCHMARK STUDY: MNL vs MNP\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

cat("This will run 1,800 REAL Monte Carlo simulations to replace\n")
cat("the illustrative placeholder data currently in the package.\n\n")

cat("Study design:\n")
cat("  Sample sizes: 100, 250, 500\n")
cat("  Correlations: 0, 0.4, 0.8\n")
cat("  Effect sizes: 0.3, 0.5\n")
cat("  Replications: 100 per condition\n")
cat("  Total: 1,800 simulations\n\n")

# Check if parallel package available
has_parallel <- requireNamespace("parallel", quietly = TRUE)
# Auto-proceed in non-interactive mode
use_parallel <- has_parallel

if (use_parallel) {
  n_cores <- min(4, parallel::detectCores() - 1)
  cat(sprintf("Using parallel processing with %d cores\n", n_cores))
} else {
  cat("Running sequentially\n")
}

cat("\nEstimated time: ")
if (use_parallel) {
  cat("30-60 minutes\n")
} else {
  cat("1-2 hours\n")
}

cat("\n")
cat("Starting automatically...\n\n")

# Source the simulation function
source("R/generate_data.R")
source("R/run_benchmark_simulation.R")
source("R/fit_mnp_safe.R")

cat("\n")
cat(paste(rep("=", 70), collapse = ""), "\n")
cat("Starting benchmark simulation...\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Run pilot benchmark
pilot_results <- run_benchmark_simulation(
  sample_sizes = c(100, 250, 500),
  correlations = c(0, 0.4, 0.8),
  effect_sizes = c(0.3, 0.5),
  n_reps = 100,
  n_alternatives = 3,
  n_vars = 2,
  functional_forms = "linear",
  parallel = use_parallel,
  n_cores = if (use_parallel) n_cores else 1,
  save_results = TRUE,
  output_file = "data/pilot_benchmark.rda",
  verbose = TRUE
)

cat("\n")
cat(paste(rep("=", 70), collapse = ""), "\n")
cat("  PILOT BENCHMARK COMPLETE!\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Summary statistics
cat("Summary of Results:\n\n")

# MNP convergence by sample size
cat("MNP Convergence Rates by Sample Size:\n")
conv_summary <- aggregate(mnp_converged ~ n, data = pilot_results, FUN = mean)
for (i in 1:nrow(conv_summary)) {
  cat(sprintf("  n = %4d: %.1f%% (%d/%d converged)\n",
              conv_summary$n[i],
              100 * conv_summary$mnp_converged[i],
              sum(pilot_results$n == conv_summary$n[i] & pilot_results$mnp_converged),
              sum(pilot_results$n == conv_summary$n[i])))
}

cat("\nMNL Win Rates (when both converge):\n")
both_converged <- pilot_results[pilot_results$mnp_converged & !is.na(pilot_results$mnl_winner), ]
if (nrow(both_converged) > 0) {
  win_summary <- aggregate(mnl_winner ~ n, data = both_converged, FUN = mean)
  for (i in 1:nrow(win_summary)) {
    cat(sprintf("  n = %4d: MNL wins %.1f%% of comparisons\n",
                win_summary$n[i],
                100 * win_summary$mnl_winner[i]))
  }
}

cat("\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

cat("Next steps:\n")
cat("  1. Review results in data/pilot_benchmark.rda\n")
cat("  2. Update package to use these REAL benchmarks instead of placeholders\n")
cat("  3. Document study design and results in package documentation\n")
cat("  4. Consider running full study (45,000 sims) for publication\n\n")

cat("To use these results:\n")
cat("  load('data/pilot_benchmark.rda')\n")
cat("  # Results are in 'pilot_results' or 'benchmark_results' object\n\n")
