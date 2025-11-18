# Functions to Add Based on Paper's Innovations

## HIGH-IMPACT ADDITIONS (Aligned with Paper's Core Contributions)

### 1. **simulate_dropout_scenario()** - THE KEY INNOVATION ⭐⭐⭐
**Paper Section:** "Novel Substitution Effect Test" (Section 3, 4.3, 5)
**What It Does:** Implements your paper's signature methodological contribution
**Why Critical:** This IS your paper's innovation - no existing package has this

```r
simulate_dropout_scenario <- function(formula, data, drop_alternative,
                                      n_sims = 10000,
                                      models = c("MNL", "MNP"),
                                      verbose = TRUE) {
  # 1. Fit models on full choice set
  # 2. Generate large-sample ground truth (n=10,000)
  # 3. Remove specified alternative
  # 4. Calculate TRUE substitution patterns from ground truth
  # 5. Predict substitution patterns using each model
  # 6. Compare predicted vs. actual voter transitions
  # 7. Calculate dropout prediction error

  # Returns:
  #   - true_transitions: Where voters actually go (from simulation)
  #   - mnl_predictions: MNL's predicted transitions
  #   - mnp_predictions: MNP's predicted transitions (if converges)
  #   - prediction_errors: |predicted - actual| for each model
  #   - brier_scores: Accuracy of probability predictions
  #   - winner: Which model performs better
}
```

**Usage:**
```r
# Test Perot dropout scenario
result <- simulate_dropout_scenario(
  vote ~ ideology + income + education,
  data = election_1992,
  drop_alternative = "Perot",
  n_sims = 10000
)

# Shows:
# TRUE: 51% → Clinton, 49% → Bush
# MNL predicts: 52% → Clinton, 48% → Bush (error = 1%)
# MNP predicts: 98% → Clinton, 2% → Bush (error = 47%)
```

**Impact:** This function DIRECTLY demonstrates your paper's central finding that MNL outperforms MNP for substitution effects.

---

### 2. **evaluate_by_estimand()** - ESTIMAND-BASED FRAMEWORK ⭐⭐
**Paper Section:** "Estimand-Based Framework" (Section 2.3, 2.4)
**What It Does:** Evaluates model performance based on what user wants to estimate
**Why Important:** Operationalizes your conceptual innovation

```r
evaluate_by_estimand <- function(fitted_models, data, estimand, ...) {
  # estimand options:
  #   - "probabilities": Evaluate probability estimation (RMSE, Brier)
  #   - "parameters": Evaluate parameter recovery (bias in β)
  #   - "substitution": Evaluate substitution pattern accuracy
  #   - "all": Report all three

  # For each estimand type, use appropriate metrics:
  # - Probabilities: RMSE, Brier score, log-loss
  # - Parameters: Coefficient bias, SE accuracy
  # - Substitution: Dropout scenario error

  # Returns structured comparison showing:
  # "For estimating [ESTIMAND], Model X performs best because..."
}
```

**Usage:**
```r
mnl_fit <- nnet::multinom(vote ~ ideology, data = mydata)
mnp_fit <- fit_mnp_safe(vote ~ ideology, data = mydata)

# Evaluate for different estimands
evaluate_by_estimand(list(mnl=mnl_fit, mnp=mnp_fit),
                     data = mydata,
                     estimand = "probabilities")
# Result: "For probability estimation, MNL achieves RMSE=0.034 vs MNP=0.113"

evaluate_by_estimand(list(mnl=mnl_fit, mnp=mnp_fit),
                     data = mydata,
                     estimand = "substitution")
# Result: "For substitution effects, MNL error=5.2% vs MNP=8.1%"
```

---

### 3. **flexible_mnl()** - FUNCTIONAL FORM SPECIFICATION ⭐
**Paper Section:** "Functional Form Matters More" (Section 4.2, Finding 8)
**What It Does:** Automatically tries multiple MNL specifications
**Why Important:** Implements your finding that functional form matters MORE than relaxing IIA

```r
flexible_mnl <- function(formula, data,
                         forms = c("linear", "quadratic", "log", "both"),
                         selection_criterion = "RMSE",
                         cross_validate = TRUE) {
  # Fits:
  # - Linear MNL: y ~ x
  # - Quadratic MNL: y ~ x + I(x^2)
  # - Log MNL: y ~ log(x)
  # - Both: y ~ log(x) + I(x^2)
  # - Interactions: y ~ x1*x2

  # Compares performance
  # Returns best specification with diagnostic plots

  # Output:
  #   - best_model: Fitted model object
  #   - comparison_table: RMSE/Brier for each form
  #   - recommendation: "Use quadratic specification (RMSE=0.045 vs linear=0.054)"
}
```

**Impact:** Helps users implement your paper's guidance that "flexible MNL often beats inflexible MNP"

---

### 4. **substitution_matrix()** - TRANSITION PROBABILITIES
**Paper Section:** Empirical Application (Section 5)
**What It Does:** Calculate full matrix of where voters go when alternatives drop
**Why Useful:** Comprehensive view of substitution patterns

```r
substitution_matrix <- function(model_fit, data, from_alternative) {
  # Calculates transition matrix:
  #              To: Clinton  Bush  Perot
  # From: Perot    51%      49%     --

  # For all possible dropouts, shows where support flows
  # Compares models' predictions

  # Returns:
  #   - transition_matrix: Predicted flows
  #   - visualization: Sankey diagram or heatmap
}
```

---

### 5. **decision_framework()** - INTERACTIVE DECISION TOOL ⭐
**Paper Section:** "Practical Guidance" (Section 6)
**What It Does:** Interactive tool implementing your paper's decision rules
**Why Important:** Translates your findings into actionable guidance

```r
decision_framework <- function(n = NULL, estimand = NULL,
                               computational_limits = FALSE,
                               interactive = TRUE) {
  # Walks user through decision tree:
  # 1. What do you want to estimate? (probabilities/parameters/substitution)
  # 2. What's your sample size? (n)
  # 3. Any computational constraints?

  # Returns:
  #   - recommendation: "Use MNL because..."
  #   - reasoning: Step-by-step logic
  #   - caveats: Important considerations
  #   - alternative_options: If primary choice doesn't work
}
```

**Usage:**
```r
decision_framework(n = 300, estimand = "probabilities")
# → "Use Linear MNL. Reason: For probability estimation with n=300,
#    MNL outperforms MNP (RMSE: 0.031 vs 0.176). MNP only converges
#    72% of the time at this sample size."

decision_framework(n = 300, estimand = "substitution")
# → "Use Linear MNL. Reason: Even for substitution effects, MNL
#    achieves error=5.2% vs MNP=8.1% due to MNP's finite-sample bias."
```

---

## MEDIUM-IMPACT ADDITIONS

### 6. **convergence_report()** - COMPREHENSIVE DIAGNOSTICS
**Paper Section:** Convergence Crisis (Table 1)
**What It Does:** Detailed MNP convergence diagnostics beyond current check_mnp_convergence()

```r
convergence_report <- function(mnp_fit, n_draws = NULL) {
  # Reports:
  # - Gelman-Rubin statistics for all parameters
  # - Effective sample sizes
  # - Trace plots for β and Σ
  # - Autocorrelation diagnostics
  # - Warning if correlation estimates near boundaries (±1)
  # - Comparison to literature convergence rates

  # Includes visual report and recommendations
}
```

---

### 7. **functional_form_test()** - SPECIFICATION TESTING
**Paper Section:** Section 4.2
**What It Does:** Tests multiple functional forms, recommends best

```r
functional_form_test <- function(formula, data,
                                 test_forms = c("linear", "quadratic", "log"),
                                 metric = "RMSE") {
  # Systematically tests functional forms
  # Uses cross-validation or AIC/BIC
  # Returns ranked list with performance metrics

  # Output:
  # 1. Quadratic: RMSE=0.045 ✓ BEST
  # 2. Log: RMSE=0.051
  # 3. Linear: RMSE=0.054
}
```

---

### 8. **brier_score()** - STANDALONE METRIC
**Paper Section:** Used throughout (currently buried in evaluate_performance)
**What It Does:** Dedicated Brier score calculation and decomposition

```r
brier_score <- function(predicted_probs, actual_choices, decompose = TRUE) {
  # Calculates Brier score
  # Optionally decomposes into:
  #   - Calibration component
  #   - Refinement component
  #   - Uncertainty component

  # Helps diagnose WHY a model performs poorly
}
```

---

### 9. **sample_size_calculator()** - ENHANCED VERSION
**Paper Section:** Practical Guidance (Section 6.2)
**What It Does:** More sophisticated than current required_sample_size()

```r
sample_size_calculator <- function(desired_estimand,
                                   target_accuracy = NULL,
                                   n_alternatives = 3,
                                   expected_correlation = NULL) {
  # Based on your simulation results, calculates:
  # - Minimum n for MNP convergence (if using MNP)
  # - Expected RMSE at different sample sizes
  # - Power to detect substitution effects
  # - Tradeoff curves: n vs accuracy
}
```

---

## MOST CRITICAL FUNCTION TO ADD IMMEDIATELY

**simulate_dropout_scenario()** is the #1 priority because:

1. ✅ It's your paper's signature innovation
2. ✅ No existing R package has this
3. ✅ Directly demonstrates your central finding
4. ✅ Makes package uniquely valuable
5. ✅ Provides concrete tool for applied researchers

## IMPLEMENTATION PRIORITY

**Phase 1 (Immediate - Align with Paper):**
1. simulate_dropout_scenario()
2. evaluate_by_estimand()
3. flexible_mnl()

**Phase 2 (High Value):**
4. decision_framework()
5. substitution_matrix()
6. convergence_report()

**Phase 3 (Enhancements):**
7. functional_form_test()
8. brier_score()
9. sample_size_calculator()

---

## WHY THESE MATTER

Your paper makes 4 contributions:
1. **Estimand-based framework** → evaluate_by_estimand()
2. **Novel dropout test** → simulate_dropout_scenario() ⭐
3. **Systematic simulation** → Already have tools, but flexible_mnl() enhances
4. **Evidence-based guidance** → decision_framework()

Adding these functions would make the package:
- ✅ **Implement your paper's innovation** (not just reference it)
- ✅ **Unique in R ecosystem** (no package has dropout scenarios)
- ✅ **Actionable for users** (not just theoretical)
- ✅ **Citable software** (researchers can use AND cite)

---

## EXAMPLE WORKFLOW WITH NEW FUNCTIONS

```r
# 1. Use decision framework to pick model
decision_framework(n = 300, estimand = "probabilities")
# → Recommends MNL

# 2. Try flexible specifications
mnl_models <- flexible_mnl(vote ~ ideology + income, data = mydata)
# → Quadratic performs best

# 3. Evaluate by estimand
evaluate_by_estimand(mnl_models$best_model, data = mydata,
                     estimand = "probabilities")
# → RMSE = 0.034

# 4. Test substitution effects
dropout_test <- simulate_dropout_scenario(
  vote ~ ideology + income + I(income^2),
  data = mydata,
  drop_alternative = "Perot"
)
# → MNL error: 5.2%, MNP error: 8.1%

# 5. Create publication table
publication_table(mnl_models$best_model, format = "latex")
```

This workflow directly implements your paper's methodology!
