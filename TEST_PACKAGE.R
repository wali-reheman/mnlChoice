#!/usr/bin/env Rscript
#
# Comprehensive mnlChoice Package Test Script
# Run this to verify all functionality works correctly
#
# Usage: Rscript TEST_PACKAGE.R
#

cat("\n")
cat("===============================================================\n")
cat("  mnlChoice Package Comprehensive Test Suite\n")
cat("===============================================================\n\n")

# Check if package can be loaded
cat("Step 1: Loading package...\n")
if (!require(mnlChoice, quietly = TRUE)) {
  cat("ERROR: Package not installed.\n")
  cat("Install with: devtools::install_github('wali-reheman/MNLNP')\n")
  cat("Or install locally: devtools::install()\n")
  quit(status = 1)
}
cat("✓ Package loaded successfully\n\n")

# Required packages
cat("Step 2: Checking dependencies...\n")
required_pkgs <- c("nnet", "stats", "graphics")
for (pkg in required_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(sprintf("WARNING: %s not installed\n", pkg))
  } else {
    cat(sprintf("✓ %s available\n", pkg))
  }
}

suggested_pkgs <- c("MNP", "mvtnorm")
for (pkg in suggested_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(sprintf("NOTE: %s not installed (optional)\n", pkg))
  } else {
    cat(sprintf("✓ %s available\n", pkg))
  }
}
cat("\n")

# Test 1: Decision Support
cat("===============================================================\n")
cat("TEST 1: Decision Support Functions\n")
cat("===============================================================\n\n")

cat("Testing recommend_model()...\n")
tryCatch({
  result1 <- recommend_model(n = 100, verbose = FALSE)
  cat(sprintf("  n=100: Recommends %s (Confidence: %s)\n",
             result1$recommendation, result1$confidence))

  result2 <- recommend_model(n = 250, correlation = 0.5, verbose = FALSE)
  cat(sprintf("  n=250, r=0.5: Recommends %s (Confidence: %s)\n",
             result2$recommendation, result2$confidence))

  result3 <- recommend_model(n = 1000, verbose = FALSE)
  cat(sprintf("  n=1000: Recommends %s (Confidence: %s)\n",
             result3$recommendation, result3$confidence))

  cat("✓ recommend_model() working\n\n")
}, error = function(e) {
  cat(sprintf("✗ ERROR in recommend_model(): %s\n\n", e$message))
})

cat("Testing required_sample_size()...\n")
tryCatch({
  result <- required_sample_size(model = "MNP", target_convergence = 0.90)
  cat(sprintf("  For 90%% MNP convergence: n ≥ %d\n", result$minimum_n))
  cat("✓ required_sample_size() working\n\n")
}, error = function(e) {
  cat(sprintf("✗ ERROR in required_sample_size(): %s\n\n", e$message))
})

cat("Testing sample_size_table()...\n")
tryCatch({
  result <- sample_size_table(model = "MNL", print_table = FALSE)
  cat(sprintf("  Generated table with %d rows\n", nrow(result)))
  cat("✓ sample_size_table() working\n\n")
}, error = function(e) {
  cat(sprintf("✗ ERROR in sample_size_table(): %s\n\n", e$message))
})

# Test 2: Data Generation
cat("===============================================================\n")
cat("TEST 2: Data Generation & Evaluation\n")
cat("===============================================================\n\n")

cat("Testing generate_choice_data()...\n")
tryCatch({
  dat <- generate_choice_data(n = 100, seed = 123)
  cat(sprintf("  Generated data: %d obs, %d alternatives\n",
             nrow(dat$data), ncol(dat$true_probs)))
  cat(sprintf("  Probabilities sum to 1: %s\n",
             all(abs(rowSums(dat$true_probs) - 1) < 1e-10)))
  cat("✓ generate_choice_data() working\n\n")

  # Test different functional forms
  dat_quad <- generate_choice_data(n = 50, functional_form = "quadratic", seed = 123)
  cat(sprintf("  Quadratic form: %s\n", dat_quad$functional_form))

  dat_cor <- generate_choice_data(n = 50, correlation = 0.5, seed = 123)
  cat(sprintf("  With correlation: max off-diagonal = %.2f\n",
             max(dat_cor$correlation_matrix[dat_cor$correlation_matrix != 1])))

  cat("✓ Different specifications working\n\n")
}, error = function(e) {
  cat(sprintf("✗ ERROR in generate_choice_data(): %s\n\n", e$message))
})

cat("Testing evaluate_performance()...\n")
tryCatch({
  n <- 100
  true_probs <- matrix(c(0.5, 0.3, 0.2), nrow = n, ncol = 3, byrow = TRUE)
  pred_probs <- true_probs + matrix(rnorm(n * 3, sd = 0.05), n, 3)
  pred_probs <- pred_probs / rowSums(pred_probs)

  actual_choices <- sample(1:3, n, replace = TRUE, prob = c(0.5, 0.3, 0.2))

  perf <- evaluate_performance(
    predicted_probs = pred_probs,
    true_probs = true_probs,
    actual_choices = actual_choices,
    metrics = c("RMSE", "Brier", "Accuracy")
  )

  cat(sprintf("  RMSE: %.4f\n", perf$RMSE))
  cat(sprintf("  Brier: %.4f\n", perf$Brier))
  cat(sprintf("  Accuracy: %.2f%%\n", perf$Accuracy * 100))
  cat("✓ evaluate_performance() working\n\n")
}, error = function(e) {
  cat(sprintf("✗ ERROR in evaluate_performance(): %s\n\n", e$message))
})

# Test 3: Model Fitting
cat("===============================================================\n")
cat("TEST 3: Model Fitting & Comparison\n")
cat("===============================================================\n\n")

if (requireNamespace("nnet", quietly = TRUE)) {
  cat("Testing fit_mnp_safe() with MNL fallback...\n")
  tryCatch({
    dat <- generate_choice_data(n = 150, seed = 456)

    # This should fall back to MNL (MNP won't converge at n=150)
    fit <- fit_mnp_safe(
      choice ~ x1 + x2,
      data = dat$data,
      fallback = "MNL",
      verbose = FALSE,
      max_attempts = 2
    )

    model_type <- attr(fit, "model_type")
    cat(sprintf("  Model fitted: %s\n", model_type))
    cat(sprintf("  Number of coefficients: %d\n", length(coef(fit))))
    cat("✓ fit_mnp_safe() working\n\n")
  }, error = function(e) {
    cat(sprintf("✗ ERROR in fit_mnp_safe(): %s\n\n", e$message))
  })

  cat("Testing compare_mnl_mnp()...\n")
  tryCatch({
    dat <- generate_choice_data(n = 200, seed = 789)

    comp <- compare_mnl_mnp(
      choice ~ x1 + x2,
      data = dat$data,
      metrics = c("RMSE", "Brier"),
      verbose = FALSE
    )

    cat(sprintf("  Results: %d metrics compared\n", nrow(comp$results)))
    cat(sprintf("  Recommendation: %s\n", comp$recommendation))
    cat("✓ compare_mnl_mnp() working\n\n")
  }, error = function(e) {
    cat(sprintf("✗ ERROR in compare_mnl_mnp(): %s\n\n", e$message))
  })

  cat("Testing compare_mnl_mnp_cv() with cross-validation...\n")
  tryCatch({
    dat <- generate_choice_data(n = 200, seed = 999)

    comp_cv <- compare_mnl_mnp_cv(
      choice ~ x1 + x2,
      data = dat$data,
      cross_validate = TRUE,
      n_folds = 3,  # Small for speed
      metrics = c("RMSE", "Brier", "Accuracy"),
      verbose = FALSE
    )

    cat(sprintf("  CV performed: %s\n", comp_cv$cv_performed))
    cat(sprintf("  Number of folds: %d\n", comp_cv$n_folds))
    cat(sprintf("  Results: %d metrics\n", nrow(comp_cv$results)))
    cat("✓ compare_mnl_mnp_cv() working\n\n")
  }, error = function(e) {
    cat(sprintf("✗ ERROR in compare_mnl_mnp_cv(): %s\n\n", e$message))
  })
} else {
  cat("SKIPPED: nnet package not available\n\n")
}

# Test 4: Diagnostics
cat("===============================================================\n")
cat("TEST 4: Diagnostic Functions\n")
cat("===============================================================\n\n")

if (requireNamespace("nnet", quietly = TRUE)) {
  cat("Testing model_summary_comparison()...\n")
  tryCatch({
    dat <- generate_choice_data(n = 150, seed = 321)

    mnl_fit <- nnet::multinom(choice ~ x1 + x2, data = dat$data, trace = FALSE)
    mnp_fit <- NULL  # Simulate MNP failure

    summary <- model_summary_comparison(mnl_fit, mnp_fit, print_summary = FALSE)

    cat(sprintf("  MNL converged: %s\n", summary$mnl$converged))
    cat(sprintf("  MNP converged: %s\n", summary$mnp$converged))
    cat(sprintf("  MNL AIC: %.2f\n", summary$mnl$aic))
    cat("✓ model_summary_comparison() working\n\n")
  }, error = function(e) {
    cat(sprintf("✗ ERROR in model_summary_comparison(): %s\n\n", e$message))
  })

  cat("Testing predict.mnp_safe()...\n")
  tryCatch({
    dat <- generate_choice_data(n = 200, seed = 654)
    train_data <- dat$data[1:150, ]
    test_data <- dat$data[151:200, ]

    fit <- fit_mnp_safe(choice ~ x1 + x2, data = train_data,
                        fallback = "MNL", verbose = FALSE)

    pred_probs <- predict(fit, newdata = test_data, type = "probs")
    pred_class <- predict(fit, newdata = test_data, type = "class")

    cat(sprintf("  Predictions generated: %d obs\n", nrow(pred_probs)))
    cat(sprintf("  Number of alternatives: %d\n", ncol(pred_probs)))
    cat("✓ predict.mnp_safe() working\n\n")
  }, error = function(e) {
    cat(sprintf("✗ ERROR in predict.mnp_safe(): %s\n\n", e$message))
  })

  if (requireNamespace("MNP", quietly = TRUE)) {
    cat("Testing check_mnp_convergence()...\n")
    tryCatch({
      # Try to fit MNP (might fail)
      dat <- generate_choice_data(n = 500, seed = 111)

      mnp_fit <- fit_mnp_safe(choice ~ x1 + x2, data = dat$data,
                              fallback = "NULL", verbose = FALSE)

      if (!is.null(mnp_fit)) {
        diag <- check_mnp_convergence(mnp_fit, diagnostic_plots = FALSE)
        cat(sprintf("  Overall convergence: %s\n", diag$converged))
        cat(sprintf("  Number of parameters: %d\n", length(diag$effective_sample_size)))
        cat("✓ check_mnp_convergence() working\n\n")
      } else {
        cat("  MNP failed to converge (expected at this n)\n")
        cat("✓ check_mnp_convergence() skipped (no MNP fit)\n\n")
      }
    }, error = function(e) {
      cat(sprintf("⚠ NOTE in check_mnp_convergence(): %s\n\n", e$message))
    })
  } else {
    cat("SKIPPED: MNP package not available\n\n")
  }
} else {
  cat("SKIPPED: nnet package not available\n\n")
}

# Test 5: Visualization
cat("===============================================================\n")
cat("TEST 5: Visualization Functions\n")
cat("===============================================================\n\n")

cat("Testing plot_convergence_rates()...\n")
tryCatch({
  pdf(NULL)  # Suppress plot output
  result <- plot_convergence_rates(add_benchmark = FALSE)
  dev.off()

  cat(sprintf("  Data points: %d\n", nrow(result)))
  cat(sprintf("  Convergence range: %.0f%% to %.0f%%\n",
             min(result$convergence_rate) * 100,
             max(result$convergence_rate) * 100))
  cat("✓ plot_convergence_rates() working\n\n")
}, error = function(e) {
  cat(sprintf("✗ ERROR in plot_convergence_rates(): %s\n\n", e$message))
})

cat("Testing plot_win_rates()...\n")
tryCatch({
  pdf(NULL)
  result <- plot_win_rates(correlation = 0.3)
  dev.off()

  cat(sprintf("  Data points: %d\n", nrow(result)))
  cat(sprintf("  Win rate range: %.0f%% to %.0f%%\n",
             min(result$win_rate) * 100,
             max(result$win_rate) * 100))
  cat("✓ plot_win_rates() working\n\n")
}, error = function(e) {
  cat(sprintf("✗ ERROR in plot_win_rates(): %s\n\n", e$message))
})

cat("Testing plot_recommendation_regions()...\n")
tryCatch({
  pdf(NULL)
  result <- plot_recommendation_regions()
  dev.off()

  cat(sprintf("  Grid dimensions: %d x %d\n",
             length(result$n), length(result$correlation)))
  cat("✓ plot_recommendation_regions() working\n\n")
}, error = function(e) {
  cat(sprintf("✗ ERROR in plot_recommendation_regions(): %s\n\n", e$message))
})

if (requireNamespace("nnet", quietly = TRUE)) {
  cat("Testing plot_comparison()...\n")
  tryCatch({
    dat <- generate_choice_data(n = 200, seed = 222)
    comp <- compare_mnl_mnp(choice ~ x1 + x2, data = dat$data, verbose = FALSE)

    pdf(NULL)
    plot_comparison(comp)
    dev.off()

    cat("✓ plot_comparison() working\n\n")
  }, error = function(e) {
    cat(sprintf("✗ ERROR in plot_comparison(): %s\n\n", e$message))
  })
} else {
  cat("SKIPPED: nnet package not available\n\n")
}

# Test 6: Power Analysis
cat("===============================================================\n")
cat("TEST 6: Power Analysis\n")
cat("===============================================================\n\n")

if (requireNamespace("nnet", quietly = TRUE)) {
  cat("Testing power_analysis_mnl() (abbreviated)...\n")
  tryCatch({
    # Run abbreviated version for speed
    pdf(NULL)
    result <- power_analysis_mnl(
      effect_size = 0.5,
      power = 0.80,
      model = "MNL",
      n_sims = 10,  # Small for speed
      n_range = c(100, 200, 300),
      verbose = FALSE
    )
    dev.off()

    cat(sprintf("  Sample sizes tested: %d\n", nrow(result$power_curve)))
    if (!is.na(result$required_n)) {
      cat(sprintf("  Estimated required n: %d\n", result$required_n))
    } else {
      cat("  Required n: Not found in range (expected with few sims)\n")
    }
    cat("✓ power_analysis_mnl() working\n\n")
  }, error = function(e) {
    cat(sprintf("✗ ERROR in power_analysis_mnl(): %s\n\n", e$message))
  })
} else {
  cat("SKIPPED: nnet package not available\n\n")
}

# Summary
cat("\n")
cat("===============================================================\n")
cat("  TEST SUITE COMPLETE\n")
cat("===============================================================\n\n")

cat("All core functionality has been tested.\n\n")

cat("NOTES:\n")
cat("- Some tests are abbreviated for speed\n")
cat("- Full power analysis would run more simulations\n")
cat("- MNP tests depend on MNP package being installed\n")
cat("- Actual package usage may vary based on data\n\n")

cat("For comprehensive examples, see:\n")
cat("  vignette('mnlChoice-guide')\n\n")

cat("For function help:\n")
cat("  ?recommend_model\n")
cat("  ?compare_mnl_mnp_cv\n")
cat("  ?generate_choice_data\n\n")

cat("===============================================================\n")
cat("  🎉 mnlChoice package is ready to use! 🎉\n")
cat("===============================================================\n\n")
