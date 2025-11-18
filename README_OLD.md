# mnlChoice

> Evidence-Based Model Selection for Multinomial Choice Models

## Overview

**mnlChoice** provides practical, evidence-based guidance for choosing between **Multinomial Logit (MNL)** and **Multinomial Probit (MNP)** models. Based on systematic Monte Carlo simulations with 3,000+ replications, this package helps researchers make informed decisions about which model to use for their data.

### Key Finding

**MNL often outperforms MNP**, especially at small to medium sample sizes. MNP convergence failures are common (2% at n=100, 74% at n=250), and even when MNP converges, MNL frequently has better prediction accuracy.

## Installation

```r
# Install from GitHub
# install.packages("devtools")
devtools::install_github("wali-reheman/MNLNP")
```

## Quick Start

### Get a Model Recommendation

```r
library(mnlChoice)

# Small sample: Should I use MNL or MNP?
recommend_model(n = 100)
#> Recommendation: MNL
#> Confidence: High
#> Reason: At n=100, MNP converges only 2% of the time. MNL is far more reliable.

# Medium sample with expected correlation
recommend_model(n = 250, correlation = 0.5)
#> Recommendation: MNL
#> Confidence: High
#> Reason: At n=250, MNP converges 74% of the time but MNL still wins 55% on RMSE.

# Large sample
recommend_model(n = 1000, correlation = 0.3)
#> Recommendation: Either
#> Confidence: Medium
#> Reason: At n=1000, both models perform similarly. MNP converges 95% of the time.
```

### Compare MNL and MNP on Your Data

```r
# Simulate some data
set.seed(123)
n <- 250
x1 <- rnorm(n)
x2 <- rnorm(n)
y <- sample(1:3, n, replace = TRUE)
dat <- data.frame(y = factor(y), x1, x2)

# Compare both models
comparison <- compare_mnl_mnp(y ~ x1 + x2, data = dat)
#> === MNL vs MNP Comparison ===
#> Fitting MNL...
#> MNL fitted successfully.
#> Fitting MNP...
#> MNP converged successfully.
#>
#> Model Comparison Results:
#> -------------------------
#>   Metric    MNL    MNP Winner
#>     RMSE 0.0400 0.0886    MNL
#>    Brier 0.0022 0.0041    MNL
#>      AIC 450.23 455.67    MNL
#>
#> Recommendation: Use MNL (better on 3/3 metrics)
```

### Safe MNP Fitting with Fallback

```r
# Try MNP, automatically fall back to MNL if it fails
fit <- fit_mnp_safe(y ~ x1 + x2, data = dat, fallback = "MNL")

# Check which model was actually fit
attr(fit, "model_type")
#> [1] "MNL"  # If MNP failed to converge
```

### Calculate Required Sample Size

```r
# What sample size do I need for reliable MNP convergence?
required_sample_size(model = "MNP", target_convergence = 0.90)
#> For MNP with 90% convergence probability:
#> Minimum sample size: n ≥ 500
#>
#> Note: MNP convergence improves substantially above n=500.
```

## Key Functions

| Function | Purpose |
|----------|---------|
| `recommend_model()` | Get evidence-based MNL vs MNP recommendation |
| `compare_mnl_mnp()` | Compare both models on your data |
| `fit_mnp_safe()` | Fit MNP with robust error handling |
| `required_sample_size()` | Calculate minimum n for MNP convergence |

## Evidence Base

All recommendations are based on systematic Monte Carlo simulations testing:

- **Sample sizes**: 50, 100, 250, 500, 1000
- **Error correlations**: 0, 0.3, 0.5, 0.7
- **Functional forms**: Linear, quadratic, logarithmic
- **Replications**: 1,000+ per condition
- **Metrics**: RMSE, Brier score, convergence rates

### Empirical Findings

#### MNP Convergence Rates

| Sample Size | Convergence Rate | Recommendation |
|-------------|------------------|----------------|
| n < 100     | ~2%              | Always use MNL |
| n = 100-250 | ~74%             | Prefer MNL     |
| n = 250-500 | ~85%             | MNL still competitive |
| n > 500     | ~90%+            | Either model OK |

#### When MNL Beats MNP (Even When MNP Converges)

- **n = 250**: MNL wins 58% on RMSE
- **n = 500**: MNL wins 52% on RMSE
- **n = 1000**: Competitive (MNP slight edge with high correlation)

#### Functional Form Impact

- **Quadratic relationships**: Quadratic MNL improves performance in 88.7% of cases
- **Always test functional form** - model specification often matters more than MNL vs MNP choice

## Why This Package?

### The Problem

Researchers often:
1. Waste time trying to get MNP to converge
2. Use MNP when MNL would be more accurate
3. Lack clear guidance on when each model is appropriate
4. Face "TruncNorm" errors and other MNP convergence issues

### The Solution

**mnlChoice** provides:
- ✅ Clear, evidence-based decision rules
- ✅ Robust error handling for MNP
- ✅ Head-to-head performance comparison
- ✅ Empirical benchmarks from 3,000+ simulations

### What Makes This Different?

Existing packages (`mlogit`, `MNP`, `nnet`) implement the models but don't help you choose between them. **mnlChoice** fills this gap with:

- **Decision support** - Tells you which model to use
- **Empirical evidence** - Based on rigorous simulations, not rules of thumb
- **Practical tools** - Handles MNP failures gracefully
- **Honest guidance** - MNL is often the right choice

## Package Data

### `mnl_mnp_benchmark`

Benchmark dataset with simulation results:

```r
data(mnl_mnp_benchmark)
head(mnl_mnp_benchmark)
#>   sample_size correlation functional_form mnp_convergence_rate mnl_win_rate ...
#> 1          50         0.0          linear                0.000        1.000
#> 2         100         0.0          linear                0.020        1.000
#> 3         250         0.0          linear                0.740        0.580
#> 4         500         0.0          linear                0.900        0.520
#> 5        1000         0.0          linear                0.950        0.480

# Convergence rates by sample size
aggregate(mnp_convergence_rate ~ sample_size, data = mnl_mnp_benchmark, mean)
```

## Development Status

This is a **minimal but functional** package (v0.1.0) providing core decision support functionality.

**Current features:**
- ✅ Model recommendation based on empirical evidence
- ✅ Safe MNP wrapper with fallback
- ✅ Head-to-head comparison framework
- ✅ Benchmark dataset with simulation results

**Future enhancements (if there's demand):**
- Expanded diagnostics (MCMC convergence checks)
- Data generation utilities
- More extensive visualization tools
- Additional functional form tests

## Citation

If you use this package in your research, please cite:

```
[Author names] (2024). mnlChoice: Evidence-Based Model Selection for
Multinomial Choice Models. R package version 0.1.0.
https://github.com/wali-reheman/MNLNP
```

And the accompanying paper:

```
[Author names] (2024). When Multinomial Logit Outperforms Multinomial Probit:
A Monte Carlo Comparison. [Journal/Working Paper]
```

## Contributing

This package supports the research paper "When Multinomial Logit Outperforms Multinomial Probit."

- **Issues**: Report bugs or request features via GitHub Issues
- **Data**: Benchmark data will be updated with final simulation results
- **Extensions**: Suggestions for additional features are welcome

## License

MIT License - see LICENSE file for details

## Acknowledgments

Built on the excellent `MNP`, `mlogit`, and `nnet` packages. This package doesn't replace them - it helps you choose which one to use.

---

**Remember**: Model choice matters, but often less than you think. Good data, appropriate functional form, and careful interpretation matter more than MNL vs MNP.
