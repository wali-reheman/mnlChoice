# mnlChoice Installation & Testing Guide

## Quick Installation

### Option 1: Install from GitHub

```r
# Install devtools if you don't have it
install.packages("devtools")

# Install mnlChoice
devtools::install_github("wali-reheman/MNLNP")

# Load package
library(mnlChoice)
```

### Option 2: Install Locally

```r
# Clone the repository first
# Then from R:
setwd("path/to/MNLNP")
devtools::install()

library(mnlChoice)
```

---

## Dependencies

### Required Packages

These are automatically installed:
- `stats` (base R)
- `utils` (base R)
- `graphics` (base R)
- `grDevices` (base R)

### Strongly Recommended

These are needed for core functionality:

```r
install.packages("nnet")  # For MNL fitting
```

### Optional (Enhance Functionality)

```r
install.packages("MNP")      # For MNP fitting
install.packages("mvtnorm")  # For correlated error generation
install.packages("mlogit")   # Alternative MNL implementation
install.packages("coda")     # Enhanced MCMC diagnostics
```

### For Documentation

```r
install.packages("knitr")
install.packages("rmarkdown")
```

---

## Verify Installation

### Quick Check

```r
library(mnlChoice)

# Get a recommendation
recommend_model(n = 250)

# Should output recommendation for MNL
```

### Comprehensive Test

Run the full test suite:

```r
# From R
source("TEST_PACKAGE.R")

# Or from terminal
Rscript TEST_PACKAGE.R
```

This tests all 20+ functions and verifies everything works.

---

## First Steps

### 1. View Documentation

```r
# Package overview
help(package = "mnlChoice")

# Comprehensive guide
vignette("mnlChoice-guide")

# Function help
?recommend_model
?compare_mnl_mnp_cv
?generate_choice_data
```

### 2. Try Examples

```r
# Get recommendation
recommend_model(n = 500, correlation = 0.4)

# Generate test data
dat <- generate_choice_data(n = 250, seed = 123)
head(dat$data)

# Compare models
comp <- compare_mnl_mnp_cv(
  choice ~ x1 + x2,
  data = dat$data,
  cross_validate = TRUE
)

print(comp$results)
```

### 3. Visualize

```r
# See convergence rates
plot_convergence_rates()

# Win rates
plot_win_rates()

# Recommendation regions
plot_recommendation_regions()
```

---

## Troubleshooting

### Package Won't Load

**Problem**: `Error: package 'mnlChoice' is not available`

**Solution**:
```r
# Make sure devtools is installed
install.packages("devtools")

# Try installation again
devtools::install_github("wali-reheman/MNLNP")
```

### MNP Functions Don't Work

**Problem**: `MNP package required`

**Solution**:
```r
# Install MNP
install.packages("MNP")

# If that fails (MNP can be tricky), use MNL fallback:
fit <- fit_mnp_safe(choice ~ x1, data = mydata, fallback = "MNL")
```

### Data Generation Fails

**Problem**: `mvtnorm package not found`

**Solution**:
```r
# Install mvtnorm for correlated errors
install.packages("mvtnorm")

# Or use correlation = 0 (independent errors)
dat <- generate_choice_data(n = 250, correlation = 0)
```

### Vignette Won't Build

**Problem**: `vignette not found`

**Solution**:
```r
# Install vignette dependencies
install.packages(c("knitr", "rmarkdown"))

# Reinstall package with vignettes
devtools::install_github("wali-reheman/MNLNP", build_vignettes = TRUE)
```

---

## System Requirements

- **R Version**: ≥ 4.0.0
- **Operating System**: Windows, macOS, or Linux
- **RAM**: 1GB minimum (more for power analysis)
- **Disk Space**: ~5MB for package + dependencies

---

## Testing Checklist

After installation, verify these work:

- [ ] `library(mnlChoice)` loads without errors
- [ ] `recommend_model(n = 250)` returns recommendation
- [ ] `generate_choice_data(n = 100)` creates data
- [ ] `plot_convergence_rates()` produces plot
- [ ] `?recommend_model` shows help
- [ ] `vignette("mnlChoice-guide")` opens (if vignettes built)

If all checked, you're good to go! 🎉

---

## Getting Help

### Documentation

```r
# List all functions
ls("package:mnlChoice")

# Help for specific function
?recommend_model

# Package documentation
help(package = "mnlChoice")

# Comprehensive guide
vignette("mnlChoice-guide")
```

### Issues

Found a bug or have a question?

1. Check existing issues: https://github.com/wali-reheman/MNLNP/issues
2. Open new issue with:
   - R version (`R.version`)
   - Package version (`packageVersion("mnlChoice")`)
   - Reproducible example
   - Error message (if applicable)

---

## Updating

```r
# Update to latest version
devtools::install_github("wali-reheman/MNLNP")

# Check current version
packageVersion("mnlChoice")
```

---

## Uninstalling

```r
remove.packages("mnlChoice")
```

---

Happy modeling! 🚀

For more information, see:
- README.md - Package overview
- TRANSFORMATION_SUMMARY.md - What's new
- Vignette - Comprehensive guide
