#!/usr/bin/env Rscript
# Generate documentation using roxygen2

if (!requireNamespace("roxygen2", quietly = TRUE)) {
  cat("ERROR: roxygen2 package not installed\n")
  cat("Install with: install.packages('roxygen2')\n")
  quit(status = 1)
}

cat("Generating documentation with roxygen2...\n")
roxygen2::roxygenize()
cat("\nDocumentation generated successfully!\n")
