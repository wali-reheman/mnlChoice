#!/usr/bin/env Rscript
# Try to install MNP package

cat("Attempting to install MNP package...\n\n")

# Try to install MNP
result <- tryCatch({
  install.packages("MNP",
                   repos = "https://cloud.r-project.org",
                   quiet = FALSE,
                   dependencies = TRUE)
  cat("\nMNP installation attempt completed\n")

  # Check if it worked
  if (requireNamespace("MNP", quietly = TRUE)) {
    cat("SUCCESS: MNP is now available!\n")
    cat("MNP version:", as.character(packageVersion("MNP")), "\n")
    TRUE
  } else {
    cat("FAILED: MNP installation did not succeed\n")
    FALSE
  }
}, error = function(e) {
  cat("ERROR during installation:\n")
  cat(conditionMessage(e), "\n")
  FALSE
})

if (result) {
  cat("\nTesting MNP basic functionality...\n")
  library(MNP)
  cat("MNP loaded successfully\n")
}
