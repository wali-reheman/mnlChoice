# MNLNP - AI Assistant Guide

## Project Overview

**MNLNP** is a research project comparing **Multinomial Logit (MNL)** and **Multinomial Probit (MNP)** models through systematic Monte Carlo simulations. The goal is to provide empirical evidence about when each method performs best.

### Research Questions
1. When does MNL outperform MNP in prediction accuracy?
2. What are the empirical MNP convergence rates by sample size?
3. How do functional form specifications affect model performance?
4. What practical guidance can we provide for model selection?

### Key Findings (Preliminary)
- **n < 100**: Always use MNL (MNP convergence ≈ 2%)
- **n = 100-250**: MNL preferred (MNP convergence ≈ 74%, but worse RMSE)
- **n > 500**: Either model acceptable (MNP convergence ≈ 85-95%)
- **Functional form**: Nonlinear MNL improves over linear in 88.7% of quadratic cases
- **MNL win rate**: 52-63% even when MNP converges (at n=250)

## Repository Status

**Current State**: Newly initialized repository
- Single README.md file
- No source code yet
- No package structure
- Research/analysis phase

**Expected Development Path**:
1. Complete Monte Carlo simulation analysis
2. Document findings in research paper
3. Consider R package development (see Package Considerations below)

## Planned Directory Structure

```
MNLNP/
├── R/                          # R source code
│   ├── simulation/             # Monte Carlo simulation functions
│   │   ├── generate_data.R     # Data generation with controlled correlation
│   │   ├── fit_models.R        # MNL and MNP fitting functions
│   │   └── evaluate_performance.R  # RMSE, Brier score calculations
│   ├── diagnostics/            # Model diagnostic functions
│   │   ├── mnp_convergence.R   # MNP convergence checking
│   │   └── model_comparison.R  # Head-to-head comparisons
│   └── utils/                  # Utility functions
│       ├── get_probs_mnp.R     # MNP prediction logic
│       └── safe_wrappers.R     # Error handling for MNP
├── analysis/                   # Analysis scripts
│   ├── phase1_core_simulation.R
│   ├── phase2_robustness.R
│   └── visualization.R
├── data/                       # Simulation results and benchmarks
│   └── mnl_mnp_benchmark.rda   # Empirical convergence/performance data
├── tests/                      # Unit tests
│   └── testthat/
├── vignettes/                  # Documentation and tutorials
│   ├── when_to_use_mnl_vs_mnp.Rmd
│   └── functional_form_selection.Rmd
├── paper/                      # Research paper materials
│   ├── manuscript.tex
│   ├── figures/
│   └── tables/
├── DESCRIPTION                 # R package metadata (if package developed)
├── NAMESPACE                   # R package namespace
├── README.md                   # Project overview
└── CLAUDE.md                   # This file
```

## Technology Stack

### Core Technologies
- **Language**: R (≥ 4.0.0)
- **Key Packages**:
  - `MNP` - Multinomial probit estimation via MCMC
  - `mlogit` - Multinomial logit models
  - `nnet` - Neural networks and multinomial log-linear models

### Statistical Methods
- Monte Carlo simulation (3,000+ replications per condition)
- MCMC diagnostics (Geweke, effective sample size)
- Performance metrics: RMSE, Brier score, log-loss
- Cross-validation for model comparison

### Development Tools
- Git for version control with signed commits
- Planned: testthat for testing, roxygen2 for documentation
- Planned: devtools for package development

## Development Workflows

### Research Workflow
1. **Design simulation conditions** (sample size, correlation, functional form)
2. **Generate synthetic data** with known ground truth probabilities
3. **Fit both MNL and MNP models**
4. **Handle MNP convergence failures** (common issue)
5. **Evaluate prediction performance** against true probabilities
6. **Aggregate results** across replications
7. **Visualize and interpret findings**

### Known Issues to Handle
- **MNP convergence failures**: Very common at small n
  - Error: "TruncNorm: lower bound > upper bound"
  - Requires robust error handling and retry logic
- **MCMC diagnostics**: Need careful convergence checking
- **Computational intensity**: MNP is slow (MCMC sampling)
- **Choice-specific variables**: Require special handling in prediction

### Code Style Conventions
- **Function naming**: `snake_case` for all functions
- **File naming**: Match primary function name (e.g., `get_probs_mnp.R`)
- **Documentation**: Roxygen2 style with `@param`, `@return`, `@examples`
- **Error handling**: Use `tryCatch()` extensively for MNP operations
- **Reproducibility**: Always set seeds for random number generation

## Package Development Considerations

### Critical Questions Before Package Development

**Is this a genuine methodological contribution or incremental work?**

Consider:
1. Are the empirical convergence rates novel to the field?
2. Does the guidance generalize beyond specific simulation conditions?
3. Is there demand for automated model selection tools?
4. Could this be a paper appendix instead of a standalone package?

### Potential Package Approaches

#### Option 1: Full mnlChoice Package
**Scope**: Comprehensive model selection and diagnostic tools
**Risk**: May be too specific; could encourage cookbook application
**Better if**: Findings are robust across many DGPs and truly novel

#### Option 2: Companion Package to Paper
**Scope**: Replication tools + benchmark dataset + basic utilities
**Risk**: Lower impact if paper isn't high-profile
**Better if**: Goal is reproducibility and supporting main research

#### Option 3: MNP Improvement Package
**Assessment**: Likely not a real contribution
**Why**: If easy improvements existed, they'd already be in MNP package
**Unless**: You have novel MCMC algorithm or initialization strategy

### Recommended Path
1. **Write the paper first** - establish the contribution
2. **Get peer review feedback** - validate importance
3. **Then decide on package** - based on community interest
4. **Package supports paper** - not the contribution itself

## Key Functions to Implement

### Core Simulation Functions
```r
generate_choice_data(n, n_alternatives, correlation, functional_form, effect_size)
# Generate synthetic multinomial choice data with controlled properties

fit_mnp_safe(formula, data, fallback = "MNL", max_attempts = 3)
# Fit MNP with robust error handling and automatic fallback

evaluate_prediction_performance(predicted_probs, true_probs, metrics)
# Calculate RMSE, Brier score, log-loss

compare_mnl_mnp(formula, data, metrics, cross_validate = TRUE)
# Head-to-head comparison with statistical tests
```

### Diagnostic Functions
```r
check_mnp_convergence(mnp_fit, n_draws, diagnostic_plots = TRUE)
# MCMC convergence diagnostics (Geweke, trace plots, ESS)

recommend_model(n, correlation = NULL, functional_form = "linear")
# Evidence-based recommendation: "MNL", "MNP", or "Either"

required_sample_size(model = "MNP", target_convergence = 0.90)
# Minimum n for reliable MNP convergence
```

### Utility Functions
```r
get_probs_mnp(mnp_fit, newdata, n_draws = 1000)
# Extract predicted probabilities from MNP with uncertainty

test_functional_form(y, x, data, forms = c("linear", "quadratic", "log"))
# Test multiple specifications and recommend best
```

## Performance Benchmarks

### Expected MNP Convergence Rates
| Sample Size | Convergence Rate | Notes |
|-------------|------------------|-------|
| n = 50      | ~0%              | Not recommended |
| n = 100     | ~2%              | Rarely converges |
| n = 250     | ~74%             | Often fails, worse RMSE when succeeds |
| n = 500     | ~90%             | Reliable convergence |
| n = 1000    | ~95%             | Very reliable |

### When MNL Beats MNP (Empirical)
- **Small samples (n < 250)**: MNL wins ~100% due to MNP failures
- **Medium samples (n = 250)**: MNL wins 52-63% even when MNP converges
- **Large samples (n > 500)**: Competitive, MNP slight edge with correlation
- **Quadratic functional form**: Quadratic MNL improves 88.7% over linear

## Testing Strategy

### Unit Tests
- Data generation produces correct dimensions and correlations
- MNL fitting returns valid coefficient estimates
- MNP wrapper handles convergence failures gracefully
- Performance metrics calculate correctly

### Integration Tests
- Full simulation pipeline runs end-to-end
- Results aggregate correctly across replications
- Comparison functions produce consistent rankings

### Validation Tests
- Reproduce known results from literature
- Verify against benchmark datasets
- Cross-validation stability

## Common Pitfalls for AI Assistants

### When Working with MNP
1. **Don't assume MNP will converge** - Always wrap in `tryCatch()`
2. **Don't ignore convergence diagnostics** - Check Geweke, ESS, trace plots
3. **Don't use default starting values blindly** - May need smart initialization
4. **Don't compare unconverged models** - Only compare successful fits

### When Developing the Package
1. **Don't oversimplify recommendations** - Include uncertainty and caveats
2. **Don't claim universal rules** - Findings are simulation-based
3. **Don't ignore edge cases** - Ordinal outcomes, count data, etc.
4. **Don't skip validation** - Test on real data, not just simulations

### When Writing Documentation
1. **Do explain WHY MNP fails** - Not just that it fails
2. **Do provide decision trees** - Visual guidance for users
3. **Do include examples of failures** - Show what goes wrong
4. **Do cite limitations** - Simulation conditions, generalizability

## Git Workflows

### Branch Strategy
- `main` - Stable, paper-ready code
- `claude/*` - AI assistant development branches
- Feature branches for specific analyses or package components

### Commit Guidelines
- Use signed commits (SSH GPG signing enabled)
- Clear, descriptive messages
- Reference issues/findings in commits
- Separate data generation, analysis, and documentation commits

### Before Pushing
1. Ensure all tests pass (when tests exist)
2. Check that simulations are reproducible
3. Validate that benchmark data is current
4. Update documentation to reflect changes

## Research Paper Integration

### Citation for Package
```
[Your names] (202X). When Multinomial Logit Outperforms Multinomial Probit:
A Monte Carlo Comparison. Political Analysis.
```

### Key Results to Document
1. MNP convergence rates by sample size
2. RMSE and Brier score comparisons
3. Functional form impact on performance
4. Practical decision rules for applied researchers

### Figures to Generate
- Figure 1: MNP convergence rates vs. sample size
- Figure 2: RMSE comparison (MNL vs MNP)
- Figure 3: Brier score comparison
- Figure 4: Functional form performance
- Figure 5: Win rate visualization

## External Resources

### R Packages
- MNP documentation: https://CRAN.R-project.org/package=MNP
- mlogit documentation: https://CRAN.R-project.org/package=mlogit
- nnet documentation: https://CRAN.R-project.org/package=nnet

### Methodological References
- MCMC convergence diagnostics (Geweke, Gelman-Rubin)
- Multinomial choice model theory
- Monte Carlo simulation best practices
- Cross-validation for model selection

### Package Development
- R Packages book: https://r-pkgs.org/
- Writing R Extensions: https://cran.r-project.org/doc/manuals/R-exts.html
- rOpenSci packaging guide: https://devguide.ropensci.org/

## Questions for Human Researchers

When an AI assistant is uncertain, consult humans on:

1. **Methodological choices**:
   - Which DGPs to test?
   - What correlation structures to include?
   - Which performance metrics matter most?

2. **Package scope**:
   - Is this a real contribution or incremental?
   - Should we build full package or minimal companion?
   - What features do applied researchers actually need?

3. **Interpretation**:
   - Why does MNL outperform despite being "wrong model"?
   - Is MNP failure due to MCMC or deeper issues?
   - Do findings generalize beyond simulations?

4. **Presentation**:
   - How to frame recommendations without oversimplifying?
   - What caveats and limitations to emphasize?
   - Target audience: methodologists or applied researchers?

## Summary for AI Assistants

**What this project IS**:
- Systematic empirical comparison of MNL vs MNP
- Monte Carlo evidence about convergence and performance
- Practical guidance for applied researchers
- Potential foundation for methodological paper

**What this project IS NOT (yet)**:
- A novel statistical method
- A guaranteed academic contribution (depends on novelty to field)
- An improvement to MNP algorithm itself
- A production-ready R package

**Primary goal**: Establish whether MNL vs MNP choice matters empirically and provide evidence-based guidance.

**Secondary goal**: If findings are novel/robust, develop supporting R package for replication and practical application.

---

*This document will evolve as the project develops. Update it when major decisions are made or structure changes.*
