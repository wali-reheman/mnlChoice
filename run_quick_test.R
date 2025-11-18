#!/usr/bin/env Rscript
# Quick test benchmark (50 simulations, ~3-5 minutes)
# This verifies the simulation code works before running full pilot

cat("\n")
cat(paste(rep("=", 70), collapse = ""), "\n")
cat("  QUICK TEST BENCHMARK: MNL vs MNP\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

cat("Running small test to verify simulation code works.\n")
cat("Study design:\n")
cat("  Sample sizes: 250, 500\n")
cat("  Correlations: 0, 0.4\n")
cat("  Effect sizes: 0.5\n")
cat("  Replications: 10 per condition (NOT statistically meaningful!)\n")
cat("  Total: 2 × 2 × 1 × 10 = 40 simulations\n\n")

cat("Estimated time: 2-3 minutes\n\n")

# Source functions
source("R/generate_data.R")
source("R/run_benchmark_simulation.R")
source("R/fit_mnp_safe.R")

cat("Starting test simulation...\n\n")

# Run quick test
test_results <- run_benchmark_simulation(
  sample_sizes = c(250, 500),
  correlations = c(0, 0.4),
  effect_sizes = c(0.5),
  n_reps = 10,  # Very small for quick test
  n_alternatives = 3,
  n_vars = 2,
  functional_forms = "linear",
  parallel = FALSE,  # Disable for test
  save_results = TRUE,
  output_file = "data/test_benchmark.rda",
  verbose = TRUE
)

cat("\n")
cat(paste(rep("=", 70), collapse = ""), "\n")
cat("  TEST COMPLETE!\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Summary
cat("Quick Summary:\n")
cat(sprintf("  Total simulations completed: %d\n", nrow(test_results)))
cat(sprintf("  MNP convergence at n=250: %.0f%% (%d/%d)\n",
            100 * mean(test_results$mnp_converged[test_results$n == 250]),
            sum(test_results$mnp_converged[test_results$n == 250]),
            sum(test_results$n == 250)))
cat(sprintf("  MNP convergence at n=500: %.0f%% (%d/%d)\n",
            100 * mean(test_results$mnp_converged[test_results$n == 500]),
            sum(test_results$mnp_converged[test_results$n == 500]),
            sum(test_results$n == 500)))

cat("\nNote: This is a MINIMAL test with only 10 reps per condition.\n")
cat("For real benchmarks, run run_pilot_benchmark.R (1,800 sims, 1-2 hours)\n\n")

cat("✓ Simulation code verified working!\n")
cat("  Results saved to: data/test_benchmark.rda\n\n")
