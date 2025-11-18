#!/usr/bin/env Rscript
# Test if MNP is installed and working

cat(paste(rep("=", 70), collapse=""), "\n")
cat("MNP PACKAGE AVAILABILITY TEST\n")
cat(paste(rep("=", 70), collapse=""), "\n\n")

# Test 1: Check if MNP is available
if (requireNamespace("MNP", quietly = TRUE)) {
  cat("[OK] MNP package is INSTALLED\n")
  cat("Version:", as.character(packageVersion("MNP")), "\n\n")

  # Test 2: Load the library
  tryCatch({
    library(MNP)
    cat("[OK] MNP library loaded successfully\n\n")

    # Test 3: Check key functions
    cat("Key MNP functions available:\n")
    mnp_functions <- ls("package:MNP")
    cat("  - mnp:", "mnp" %in% mnp_functions, "\n")
    cat("  - predict.mnp:", "predict.mnp" %in% mnp_functions, "\n")
    cat("  - Total functions:", length(mnp_functions), "\n\n")

    # Test 4: Try a tiny example
    cat("Testing MNP with tiny simulated data...\n")
    set.seed(123)
    n <- 50
    x1 <- rnorm(n)
    x2 <- rnorm(n)

    # Generate 3-category outcome
    z1 <- 0.5 * x1 + 0.3 * x2 + rnorm(n, sd=0.5)
    z2 <- -0.3 * x1 + 0.5 * x2 + rnorm(n, sd=0.5)

    probs <- cbind(1, exp(z1), exp(z2))
    probs <- probs / rowSums(probs)
    y <- apply(probs, 1, function(p) sample(1:3, 1, prob = p))

    test_data <- data.frame(y = factor(y), x1 = x1, x2 = x2)

    cat("  Sample size:", nrow(test_data), "\n")
    cat("  Outcome distribution:", table(test_data$y), "\n")

    # Fit MNP with minimal draws to test
    cat("\n  Fitting MNP model (500 draws, 100 burnin)...\n")
    mnp_result <- tryCatch({
      MNP::mnp(y ~ x1 + x2, data = test_data,
               n.draws = 500, burnin = 100,
               verbose = FALSE)
    }, error = function(e) {
      cat("  ERROR:", conditionMessage(e), "\n")
      NULL
    })

    if (!is.null(mnp_result)) {
      cat("  [OK] MNP model fitted successfully!\n")
      cat("  Coefficients estimated:", length(coef(mnp_result)), "parameters\n")
      cat("\n[SUCCESS] MNP is fully functional!\n\n")
      q(status = 0)
    } else {
      cat("  [WARNING] MNP fitted but with errors\n\n")
      q(status = 1)
    }

  }, error = function(e) {
    cat("[ERROR] Failed to load MNP:\n")
    cat("  ", conditionMessage(e), "\n\n")
    q(status = 1)
  })

} else {
  cat("[FAILED] MNP package is NOT available\n")
  cat("Installation did not complete successfully\n\n")
  q(status = 1)
}
