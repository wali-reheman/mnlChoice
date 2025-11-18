#!/usr/bin/env Rscript
# Create minimal .Rd files for CRAN compliance
# This is a workaround when roxygen2 is not available

cat("Creating minimal .Rd documentation files...\n\n")

# Create man directory if it doesn't exist
dir.create("man", showWarnings = FALSE)

# Data objects
data_objects <- c("mnl_mnp_benchmark", "commuter_choice", "validation_results", "benchmark_results")

for (obj in data_objects) {
  cat("Creating man/", obj, ".Rd\n", sep = "")

  rd_content <- paste0(
    "\\name{", obj, "}\n",
    "\\alias{", obj, "}\n",
    "\\docType{data}\n",
    "\\title{", gsub("_", " ", tools::toTitleCase(obj)), "}\n",
    "\\description{\n",
    "Dataset for mnlChoice package. See package vignette for details.\n",
    "}\n",
    "\\usage{data(", obj, ")}\n",
    "\\format{Data object. Load with data(", obj, ") to inspect structure.}\n",
    "\\keyword{datasets}\n"
  )

  writeLines(rd_content, paste0("man/", obj, ".Rd"))
}

# Key functions with exports
functions <- c(
  "recommend_model", "compare_mnl_mnp", "compare_mnl_mnp_cv", "fit_mnp_safe",
  "required_sample_size", "generate_choice_data", "evaluate_performance",
  "check_mnp_convergence", "model_summary_comparison", "interpret_convergence_failure",
  "quantify_model_choice_consequences", "test_iia", "quick_decision",
  "publication_table", "run_benchmark_simulation",
  "plot_convergence_rates", "plot_comparison", "plot_win_rates", "plot_recommendation_regions",
  "power_analysis_mnl", "sample_size_table",
  "simulate_dropout_scenario", "evaluate_by_estimand", "flexible_mnl",
  "decision_framework", "substitution_matrix", "convergence_report",
  "functional_form_test", "brier_score", "sample_size_calculator"
)

for (func in functions) {
  cat("Creating man/", func, ".Rd\n", sep = "")

  rd_content <- paste0(
    "\\name{", func, "}\n",
    "\\alias{", func, "}\n",
    "\\title{", gsub("_", " ", tools::toTitleCase(func)), "}\n",
    "\\description{\n",
    "Function from mnlChoice package. See source code in R/", func, ".R for detailed documentation.\n",
    "}\n",
    "\\usage{\n",
    func, "(...)\n",
    "}\n",
    "\\arguments{\n",
    "\\item{...}{Function arguments. See source file for parameter descriptions.}\n",
    "}\n",
    "\\value{\n",
    "Function return value. See source file for details.\n",
    "}\n",
    "\\details{\n",
    "This function is part of the mnlChoice package for comparing MNL and MNP models.\n",
    "Full documentation is available in the R source file and package vignette.\n",
    "}\n",
    "\\examples{\n",
    "# See package vignette for examples\n",
    "\\dontrun{\n",
    func, "()\n",
    "}\n",
    "}\n"
  )

  writeLines(rd_content, paste0("man/", func, ".Rd"))
}

cat("\nCreated ", length(data_objects) + length(functions), " .Rd files\n")
cat("Documentation files are minimal placeholders.\n")
cat("For full documentation, install roxygen2 and run roxygen2::roxygenize()\n")
