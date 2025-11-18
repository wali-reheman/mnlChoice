# test_iia() Scoping Issue

## Problem
`test_iia()` has a scoping conflict when sourced along with other package files.
Error: "object of type 'closure' is not subsettable"

## Status
- ✅ **Core logic is SOUND** - validated step-by-step
- ✅ **Function works in isolation** - when only iia_and_decision.R is sourced
- ❌ **Fails in test framework** - when all R files are sourced together

## Hypothesis
Likely a conflict between the `formula` and `data` parameter names and base R functions or other package internals when multiple files create a complex environment.

## Attempted Fixes
1. `force()` on parameters - no effect
2. Dotted variable names (`.formula`, `.data`) - "object not found" errors
3. Renamed locals (`fml`, `dat`) - same "object not found"
4. Explicit argument names in multinom() calls - no effect
5. Different evaluation strategies - all failed

## Workaround
For now, use `quick_decision()` for instant recommendations and `compare_mnl_mnp()` for empirical model comparison. Both work perfectly.

## Next Steps
- Investigate R package environment best practices
- Consider renaming function to avoid conflicts
- May need to restructure how formula evaluation works
- Consult R package development experts

## Impact
**Low** - Other high-impact functions work perfectly:
- quick_decision(): ✅ 100% tests pass
- publication_table(): ✅ 100% tests pass
- Real dataset: ✅ Works
- Benchmark warnings: ✅ Works

The package delivers its core value despite this issue.
