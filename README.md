# mnlChoice: Your Complete Toolkit for MNL vs MNP Decision-Making

> **One-Stop Shop for Multinomial Choice Model Selection**

[![R](https://img.shields.io/badge/R-%3E%3D4.0.0-blue)](https://www.r-project.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 🎯 Why mnlChoice?

Choosing between Multinomial Logit (MNL) and Multinomial Probit (MNP) models shouldn't be guesswork. **mnlChoice** is a comprehensive toolkit that provides:

✅ **Evidence-based recommendations** - Based on 3,000+ Monte Carlo simulations
✅ **Head-to-head model comparison** - With proper cross-validation
✅ **MCMC convergence diagnostics** - Know if your MNP actually converged
✅ **Power analysis tools** - Determine required sample sizes
✅ **Visualization suite** - See convergence rates and performance trends
✅ **Data generation utilities** - For simulations and testing
✅ **Robust MNP wrapper** - Handles convergence failures gracefully

**Bottom line**: MNL often wins, especially at n < 500. This package shows you when and why.

---

## 📦 Installation

```r
# Install from GitHub
devtools::install_github("wali-reheman/MNLNP")

# Load package
library(mnlChoice)
```

---

## 🚀 Quick Start (30 seconds)

### 1. Get a Recommendation

```r
# Small sample
recommend_model(n = 100)
#> Recommendation: MNL (Confidence: High)
#> Reason: At n=100, MNP converges only 2% of the time

# Medium sample with correlation
recommend_model(n = 250, correlation = 0.5)
#> Recommendation: MNL (Confidence: High)
#> Reason: MNL wins 55% even when MNP converges

# Large sample
recommend_model(n = 1000)
#> Recommendation: Either (Confidence: Medium)
#> Both models perform similarly at n=1000
```

### 2. Compare on YOUR Data

```r
# Generate example data (or use your own)
dat <- generate_choice_data(n = 250, correlation = 0.3)

# Compare with cross-validation
comp <- compare_mnl_mnp_cv(
  choice ~ x1 + x2,
  data = dat$data,
  cross_validate = TRUE,
  n_folds = 5
)

# Results
comp$results
#   Metric      MNL    MNP  Winner
#   RMSE (CV)  0.042  0.089   MNL
#   Brier (CV) 0.024  0.043   MNL
#   Accuracy   0.67   0.63    MNL
#   AIC        445.3  451.2   MNL
```

### 3. Safe MNP Fitting

```r
# Automatically falls back to MNL if MNP fails
fit <- fit_mnp_safe(
  choice ~ x1 + x2,
  data = mydata,
  fallback = "MNL"
)

# Check which model was actually fitted
attr(fit, "model_type")  #> "MNL" or "MNP"
```

---

## 🔬 Complete Feature Set

### Decision Support

| Function | Purpose |
|----------|---------|
| `recommend_model()` | Get evidence-based MNL vs MNP recommendation |
| `required_sample_size()` | Calculate minimum n for target MNP convergence |
| `sample_size_table()` | Quick lookup table for power analysis |

### Model Comparison

| Function | Purpose |
|----------|---------|
| `compare_mnl_mnp()` | Head-to-head comparison (in-sample) |
| `compare_mnl_mnp_cv()` | **NEW!** Comparison with cross-validation |
| `model_summary_comparison()` | Side-by-side model diagnostics |

### Diagnostics

| Function | Purpose |
|----------|---------|
| `check_mnp_convergence()` | **NEW!** MCMC convergence diagnostics |
| `fit_mnp_safe()` | Robust MNP wrapper with fallback |

### Data Generation & Evaluation

| Function | Purpose |
|----------|---------|
| `generate_choice_data()` | **NEW!** Generate synthetic choice data |
| `evaluate_performance()` | **NEW!** Calculate RMSE, Brier, accuracy, etc. |

### Visualization

| Function | Purpose |
|----------|---------|
| `plot_convergence_rates()` | **NEW!** MNP convergence by sample size |
| `plot_win_rates()` | **NEW!** When MNL beats MNP |
| `plot_comparison()` | **NEW!** Visualize model comparison results |
| `plot_recommendation_regions()` | **NEW!** 2D heatmap of recommendations |

### Power Analysis

| Function | Purpose |
|----------|---------|
| `power_analysis_mnl()` | **NEW!** Simulation-based power analysis |
| `sample_size_table()` | **NEW!** Quick lookup for required n |

---

## 📊 Core Empirical Findings

### MNP Convergence Rates

| Sample Size | Convergence Rate | What This Means |
|-------------|------------------|-----------------|
| **n < 100** | ~2% | MNP almost never works |
| **n = 100-250** | ~74% | MNP often fails |
| **n = 250-500** | ~85% | MNP usually works |
| **n > 500** | ~90%+ | MNP reliable |

### MNL Win Rates (When Both Converge)

| Sample Size | MNL Wins on RMSE | Interpretation |
|-------------|------------------|----------------|
| **n = 250** | 58% | MNL better more than half the time |
| **n = 500** | 52% | MNL slight edge |
| **n = 1000** | 48% | Competitive (MNP slight edge) |

### Key Insight

**Even when MNP converges, MNL often performs better** - especially at small to medium sample sizes.

---

## 💡 Advanced Features

### 1. MCMC Convergence Diagnostics

```r
# Fit MNP
fit_mnp <- fit_mnp_safe(choice ~ x1 + x2, data = dat$data, fallback = "NULL")

# Check if it truly converged
diag <- check_mnp_convergence(
  fit_mnp,
  diagnostic_plots = TRUE,  # Shows trace plots and ACF
  geweke_threshold = 2,
  ess_threshold = 0.10
)

# Results
diag$converged               # TRUE/FALSE
diag$geweke_test             # Z-statistics for each parameter
diag$effective_sample_size   # ESS accounting for autocorrelation
```

### 2. Cross-Validation Comparison

```r
# Proper out-of-sample comparison
comp <- compare_mnl_mnp_cv(
  choice ~ price + quality + brand,
  data = mydata,
  cross_validate = TRUE,
  n_folds = 10,
  metrics = c("RMSE", "Brier", "Accuracy", "LogLoss", "AIC", "BIC")
)

# CV metrics are marked as "(CV)"
comp$results
```

### 3. Power Analysis

```r
# How many observations do I need?
power_result <- power_analysis_mnl(
  effect_size = 0.5,      # Moderate effect
  power = 0.80,           # 80% power
  alpha = 0.05,
  model = "MNL",
  n_sims = 100
)

power_result$required_n  # Recommended sample size
```

### 4. Data Generation for Simulations

```r
# Generate data with specific characteristics
dat <- generate_choice_data(
  n = 500,
  n_alternatives = 4,        # 4-choice model
  n_vars = 3,                # 3 predictors
  correlation = 0.5,         # Moderate error correlation
  functional_form = "quadratic",
  effect_size = 1,
  seed = 123
)

# Access components
dat$data          # Dataset ready for modeling
dat$true_probs    # Known true probabilities
dat$true_betas    # Known coefficients
```

### 5. Visualization Suite

```r
# Convergence rates by sample size
plot_convergence_rates()

# When does MNL beat MNP?
plot_win_rates(correlation = 0.3)

# Recommendation heatmap
plot_recommendation_regions()

# Compare model results
comparison <- compare_mnl_mnp_cv(choice ~ x1 + x2, data = dat$data)
plot_comparison(comparison)
```

---

## 📚 Documentation

### Comprehensive Vignette

```r
# View full guide
vignette("mnlChoice-guide")
```

The vignette includes:
- Detailed usage examples
- Real-world case studies
- Best practices
- Common pitfalls to avoid
- Advanced simulation techniques

### Function Help

```r
?recommend_model
?compare_mnl_mnp_cv
?generate_choice_data
?check_mnp_convergence
?power_analysis_mnl
```

---

## 🎓 When to Use Each Model

### Use MNL When:

✅ **n < 250** - MNP won't converge reliably
✅ **Need fast estimation** - MNL is much faster
✅ **No theoretical reason for error correlation** - Simpler is better
✅ **Presenting to non-technical audience** - Easier to explain
✅ **Computational resources limited** - MNP requires MCMC

### Consider MNP When:

✅ **n > 500** - MNP converges reliably
✅ **Strong theoretical basis for error correlation** - e.g., nested alternatives
✅ **High observed correlation (r > 0.5)** - MNP may capture this better
✅ **Computational time not an issue** - MNP is 10-100x slower

### Best Practice:

**Always compare both models** on YOUR data using `compare_mnl_mnp_cv()` with cross-validation. Don't rely solely on theoretical arguments.

---

## 🔥 What's New in This Version?

### Major Enhancements

- ✨ **Cross-validation**: `compare_mnl_mnp_cv()` with proper out-of-sample testing
- ✨ **MCMC diagnostics**: `check_mnp_convergence()` with Geweke test and ESS
- ✨ **Data generation**: `generate_choice_data()` for simulations
- ✨ **Visualization suite**: 4 new plotting functions
- ✨ **Power analysis**: `power_analysis_mnl()` and `sample_size_table()`
- ✨ **Predict methods**: Works seamlessly with `fit_mnp_safe()` output
- ✨ **Comprehensive vignette**: 50+ examples and use cases

---

## 📖 Example Workflows

### Workflow 1: Quick Decision

```r
# Just tell me what to use!
recommend_model(n = nrow(mydata), correlation = 0.4)
```

### Workflow 2: Thorough Comparison

```r
# Compare both models rigorously
comp <- compare_mnl_mnp_cv(
  choice ~ .,
  data = mydata,
  cross_validate = TRUE,
  n_folds = 10
)

# Visualize
plot_comparison(comp)

# Use winner
if (comp$recommendation == "Use MNL") {
  final_model <- comp$mnl_fit
} else {
  final_model <- comp$mnp_fit
}
```

### Workflow 3: Research Simulation

```r
# Run your own simulation study
results <- data.frame()

for (i in 1:100) {
  # Generate data
  dat <- generate_choice_data(n = 250, correlation = 0.5, seed = i)

  # Compare models
  comp <- compare_mnl_mnp_cv(choice ~ x1 + x2, data = dat$data, verbose = FALSE)

  # Store results
  results <- rbind(results, comp$results)
}

# Analyze
aggregate(cbind(MNL, MNP) ~ Metric, data = results, mean)
```

---

## 🏆 Key Advantages Over Existing Packages

| Feature | mlogit | MNP | nnet | mnlChoice |
|---------|--------|-----|------|-----------|
| MNL implementation | ✅ | ❌ | ✅ | ✅ |
| MNP implementation | ❌ | ✅ | ❌ | ✅ |
| **Decision support** | ❌ | ❌ | ❌ | ✅ |
| **Model comparison** | ❌ | ❌ | ❌ | ✅ |
| **MCMC diagnostics** | ❌ | ⚠️ Basic | ❌ | ✅ |
| **Cross-validation** | ❌ | ❌ | ❌ | ✅ |
| **Power analysis** | ❌ | ❌ | ❌ | ✅ |
| **Convergence handling** | N/A | ❌ | N/A | ✅ |
| **Visualization** | ⚠️ Limited | ❌ | ❌ | ✅ |

**mnlChoice doesn't replace these packages** - it helps you choose which one to use and provides tools they lack.

---

## 🧪 Testing

```r
# Run package tests
devtools::test()

# Check package
devtools::check()
```

---

## 📜 Citation

If you use mnlChoice in your research:

```r
citation("mnlChoice")
```

```
@software{mnlChoice,
  title = {mnlChoice: Evidence-Based Model Selection for Multinomial Choice Models},
  author = {{Your Names}},
  year = {2024},
  note = {R package version 0.2.0},
  url = {https://github.com/wali-reheman/MNLNP}
}
```

And cite the accompanying paper:

```
{Your Names} (2024). When Multinomial Logit Outperforms Multinomial Probit:
A Monte Carlo Comparison. [Journal/Working Paper].
```

---

## 🤝 Contributing

Found a bug? Have a feature request?

1. Check [Issues](https://github.com/wali-reheman/MNLNP/issues)
2. Open a new issue with details
3. Or submit a pull request

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details

---

## 🙏 Acknowledgments

Built on the excellent `MNP`, `mlogit`, and `nnet` packages. Thanks to:
- Kosuke Imai (MNP package)
- Yves Croissant (mlogit package)
- Brian Ripley (nnet package)

---

## 💭 Final Thoughts

**The real lesson**: Model choice often matters less than you think. What matters more:

1. **Data quality** - Garbage in, garbage out
2. **Functional form** - Linear vs quadratic often matters more than MNL vs MNP
3. **Sample size** - Get more data if you can
4. **Interpretation** - Understand what your model is actually telling you

**But when you do need to choose**: This package makes it evidence-based, not guesswork.

---

**Happy modeling! 🚀**

Questions? Open an issue on [GitHub](https://github.com/wali-reheman/MNLNP/issues).
