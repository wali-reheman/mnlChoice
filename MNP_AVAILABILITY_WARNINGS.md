# MNP Availability Warnings - Implementation Summary

## Overview

Added comprehensive warnings throughout the package to alert users when the MNP package is not installed. This ensures users understand when MNP-related features are unavailable and prevents silent failures.

## Files Modified

### 1. R/fit_mnp_safe.R
**Change:** Enhanced warning when MNP not available
- **Line 64-70:** Prominent warning with installation instructions
- Uses `immediate. = TRUE` for immediate display
- Clear messaging about fallback behavior

**Warning message:**
```r
*** MNP package not installed ***
MNP is required for multinomial probit models.
Install with: install.packages('MNP')
```

### 2. R/recommend_model.R
**Change:** Check MNP availability at function start
- **Line 49-59:** Added upfront MNP availability check
- Warns users that recommendations assume MNP is available
- Suggests using MNL for all analyses if MNP unavailable

**Warning message:**
```r
*** MNP package not installed ***
Recommendations for MNP assume the package is available.
Install with: install.packages('MNP')
Without MNP, use MNL for all analyses.
```

### 3. R/compare_mnl_mnp.R
**Change:** Check MNP availability before comparison
- **Line 64-74:** Upfront check with clear warning
- **Line 83-87:** Display warning in header output
- Informs users comparison will be MNL-only

**Warning message:**
```r
*** MNP package not installed ***
Cannot compare MNL vs MNP without MNP package.
Install with: install.packages('MNP')
Proceeding with MNL-only analysis.
```

**Console output includes:**
```
=== MNL vs MNP Comparison ===
*** MNP not available - MNL-only results ***
```

### 4. R/compare_mnl_mnp_improved.R (compare_mnl_mnp_cv)
**Change:** Check MNP availability before cross-validation
- **Line 20-30:** Upfront check with clear warning
- **Line 38-41:** Display warning in header output
- Same behavior as compare_mnl_mnp

**Warning message:**
```r
*** MNP package not installed ***
Cannot compare MNL vs MNP without MNP package.
Install with: install.packages('MNP')
Proceeding with MNL-only analysis.
```

### 5. R/publication_tools.R (publication_table)
**Change:** Inform users about MNP-only tables
- **Line 62-71:** Check when mnp_fit is NULL
- Informative message (not warning) since NULL is valid
- Only displays if verbose = TRUE

**Message:**
```r
Note: MNP package not installed. Table will show MNL results only.
To compare with MNP, install with: install.packages('MNP')
```

### 6. R/iia_and_decision.R (test_iia)
**Change:** Warn when recommending MNP but package unavailable
- **Line 180-181:** Check MNP availability
- **Line 204-207:** Display warning if IIA violated and MNP not available
- Contextual warning only when MNP would be recommended

**Warning displayed when IIA violated:**
```
⚠️  IIA appears violated. This suggests:
  • Error terms may be correlated across alternatives
  • MNL may produce biased estimates
  • Consider MNP (if n >= 500) or mixed logit

  *** Note: MNP package not installed ***
  Install with: install.packages('MNP')
```

## Functions That DON'T Need Warnings

### quick_decision()
- Never recommends MNP (only "MNL" or "Either")
- No warning needed

### Other utility functions
- Functions that don't directly reference or recommend MNP
- generate_choice_data(), evaluate_performance(), etc.

## Warning Strategy

### Levels of Warnings

1. **Critical (stop execution):** None - we allow MNL-only workflows
2. **Warning (warning() function):** When user explicitly requests MNP functionality
3. **Message (message() function):** Informative notes about availability

### When Warnings Appear

1. **Immediate warnings:** When user calls function expecting MNP comparison
   - `compare_mnl_mnp()`, `compare_mnl_mnp_cv()`
   - `fit_mnp_safe()` (with fallback)

2. **Conditional warnings:** When MNP would be recommended
   - `recommend_model()` - shows warning upfront
   - `test_iia()` - shows warning only if IIA violated

3. **Informative messages:** When MNP absence is normal
   - `publication_table()` - note about MNL-only table

### User Experience

**Before (silent failures):**
```r
> compare_mnl_mnp(choice ~ x1, data = dat)
# Silently falls back to MNL, user thinks they compared both
```

**After (clear warnings):**
```r
> compare_mnl_mnp(choice ~ x1, data = dat)
Warning:
*** MNP package not installed ***
Cannot compare MNL vs MNP without MNP package.
Install with: install.packages('MNP')
Proceeding with MNL-only analysis.

=== MNL vs MNP Comparison ===
*** MNP not available - MNL-only results ***
# User clearly understands limitation
```

## Testing

All functions should work correctly whether MNP is installed or not:

### With MNP installed:
- ✅ All functions work as designed
- ✅ No warnings (MNP available)
- ✅ Full MNL vs MNP comparisons

### Without MNP installed:
- ✅ All functions still work (graceful degradation)
- ✅ Clear warnings about MNP unavailability
- ✅ MNL-only workflows function correctly
- ✅ Users understand what's missing

## Installation Instructions Provided

All warnings consistently direct users to:
```r
install.packages('MNP')
```

## Documentation Impact

### User-facing changes:
- More transparent about package dependencies
- Clear guidance when features unavailable
- Better user experience for MNL-only workflows

### Technical improvements:
- Consistent warning strategy across package
- Graceful degradation without silent failures
- Maintains backward compatibility

## Summary

✅ **6 functions enhanced** with MNP availability warnings
✅ **Consistent messaging** across all warnings
✅ **Graceful degradation** - package works with or without MNP
✅ **Clear user guidance** - installation instructions always provided
✅ **No breaking changes** - existing code continues to work

This implementation addresses the critical assessment finding that "MNP dependency not handled properly" and ensures users are never confused about whether MNP comparisons are actually happening.
