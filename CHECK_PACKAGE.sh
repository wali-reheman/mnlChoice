#!/bin/bash
#
# Comprehensive Package Check Script
# Checks for common R package issues without requiring R
#

echo "==============================================================================="
echo "  mnlChoice Package Comprehensive Check"
echo "==============================================================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# Check 1: File Structure
echo "CHECK 1: Package Structure"
echo "-------------------------------------------"

required_files=("DESCRIPTION" "NAMESPACE" "LICENSE" "README.md")
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file exists"
    else
        echo -e "${RED}✗${NC} $file missing"
        ((ERRORS++))
    fi
done

required_dirs=("R" "tests" "man")
for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $dir/ directory exists"
    else
        echo -e "${RED}✗${NC} $dir/ directory missing"
        ((ERRORS++))
    fi
done

echo ""

# Check 2: R Source Files
echo "CHECK 2: R Source Files"
echo "-------------------------------------------"

R_FILES=$(find R -name "*.R" -type f | wc -l)
echo "Found $R_FILES R source files"

if [ $R_FILES -gt 0 ]; then
    echo -e "${GREEN}✓${NC} R source files present"
else
    echo -e "${RED}✗${NC} No R source files found"
    ((ERRORS++))
fi

# Check for syntax issues (basic)
echo ""
echo "Checking R files for common syntax issues..."

for file in R/*.R; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")

        # Check for unmatched braces
        open_braces=$(grep -o "{" "$file" | wc -l)
        close_braces=$(grep -o "}" "$file" | wc -l)

        if [ $open_braces -ne $close_braces ]; then
            echo -e "${RED}✗${NC} $filename: Unmatched braces (${open_braces} { vs ${close_braces} })"
            ((ERRORS++))
        else
            echo -e "${GREEN}✓${NC} $filename: Braces balanced"
        fi

        # Check for function definitions
        func_count=$(grep -c "function(" "$file")
        if [ $func_count -gt 0 ]; then
            echo "  └─ Contains $func_count function(s)"
        fi
    fi
done

echo ""

# Check 3: NAMESPACE consistency
echo "CHECK 3: NAMESPACE Exports"
echo "-------------------------------------------"

if [ -f "NAMESPACE" ]; then
    exports=$(grep "^export(" NAMESPACE | wc -l)
    s3methods=$(grep "^S3method(" NAMESPACE | wc -l)

    echo "Exports declared in NAMESPACE: $exports"
    echo "S3 methods declared: $s3methods"

    # List all exports
    echo ""
    echo "Exported functions:"
    grep "^export(" NAMESPACE | sed 's/export(/  - /' | sed 's/)//'

    if [ $s3methods -gt 0 ]; then
        echo ""
        echo "S3 methods:"
        grep "^S3method(" NAMESPACE | sed 's/S3method(/  - /' | sed 's/)//'
    fi

    echo ""
    echo -e "${GREEN}✓${NC} NAMESPACE file readable"
else
    echo -e "${RED}✗${NC} NAMESPACE file not found"
    ((ERRORS++))
fi

echo ""

# Check 4: Documentation
echo "CHECK 4: Documentation Files"
echo "-------------------------------------------"

doc_files=("README.md" "CLAUDE.md" "INSTALLATION.md" "TRANSFORMATION_SUMMARY.md" "PACKAGE_ASSESSMENT.md")
for file in "${doc_files[@]}"; do
    if [ -f "$file" ]; then
        lines=$(wc -l < "$file")
        echo -e "${GREEN}✓${NC} $file ($lines lines)"
    else
        echo -e "${YELLOW}⚠${NC} $file not found (optional)"
        ((WARNINGS++))
    fi
done

# Check for vignettes
if [ -d "vignettes" ]; then
    vignettes=$(find vignettes -name "*.Rmd" | wc -l)
    if [ $vignettes -gt 0 ]; then
        echo -e "${GREEN}✓${NC} Vignettes directory with $vignettes file(s)"
    else
        echo -e "${YELLOW}⚠${NC} Vignettes directory empty"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠${NC} No vignettes directory"
    ((WARNINGS++))
fi

echo ""

# Check 5: Tests
echo "CHECK 5: Test Files"
echo "-------------------------------------------"

if [ -d "tests/testthat" ]; then
    test_files=$(find tests/testthat -name "test-*.R" | wc -l)
    echo "Test files found: $test_files"

    if [ $test_files -gt 0 ]; then
        echo -e "${GREEN}✓${NC} Test suite present"
        find tests/testthat -name "test-*.R" -exec basename {} \; | while read tf; do
            echo "  - $tf"
        done
    else
        echo -e "${YELLOW}⚠${NC} No test files found"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠${NC} No tests/testthat directory"
    ((WARNINGS++))
fi

echo ""

# Check 6: DESCRIPTION file
echo "CHECK 6: DESCRIPTION File"
echo "-------------------------------------------"

if [ -f "DESCRIPTION" ]; then
    echo "Checking DESCRIPTION fields..."

    # Check required fields
    required_fields=("Package:" "Title:" "Version:" "Description:" "License:")
    for field in "${required_fields[@]}"; do
        if grep -q "^$field" DESCRIPTION; then
            echo -e "${GREEN}✓${NC} $field present"
        else
            echo -e "${RED}✗${NC} $field missing"
            ((ERRORS++))
        fi
    done

    # Extract key info
    echo ""
    echo "Package metadata:"
    grep "^Package:" DESCRIPTION
    grep "^Version:" DESCRIPTION
    grep "^Title:" DESCRIPTION | head -c 80
    echo "..."

    # Check dependencies
    echo ""
    if grep -q "^Imports:" DESCRIPTION; then
        echo -e "${GREEN}✓${NC} Imports specified"
    fi
    if grep -q "^Suggests:" DESCRIPTION; then
        echo -e "${GREEN}✓${NC} Suggests specified"
    fi

else
    echo -e "${RED}✗${NC} DESCRIPTION file not found"
    ((ERRORS++))
fi

echo ""

# Check 7: Function Naming Consistency
echo "CHECK 7: Function Naming Consistency"
echo "-------------------------------------------"

echo "Checking for consistent function naming..."

# Find all exported functions from NAMESPACE
if [ -f "NAMESPACE" ]; then
    grep "^export(" NAMESPACE | sed 's/export(//' | sed 's/)//' | while read func; do
        # Check if function is defined in R files
        if grep -rq "$func <- function" R/; then
            echo -e "${GREEN}✓${NC} $func: defined and exported"
        elif grep -rq "$func<-function" R/; then
            echo -e "${GREEN}✓${NC} $func: defined and exported (no space)"
        else
            echo -e "${YELLOW}⚠${NC} $func: exported but definition not found (might be in class methods)"
            ((WARNINGS++))
        fi
    done
fi

echo ""

# Check 8: Common R Issues
echo "CHECK 8: Common R Code Issues"
echo "-------------------------------------------"

echo "Scanning for common issues..."

for file in R/*.R; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")

        # Check for library() or require() calls (should use imports instead)
        lib_calls=$(grep -c "library(" "$file" 2>/dev/null || echo 0)
        req_calls=$(grep -c "require(" "$file" 2>/dev/null || echo 0)

        if [ $lib_calls -gt 0 ]; then
            echo -e "${YELLOW}⚠${NC} $filename: Contains library() calls ($lib_calls) - use Imports instead"
            ((WARNINGS++))
        fi

        # Check for setwd() calls (bad practice)
        setwd_calls=$(grep -c "setwd(" "$file" 2>/dev/null || echo 0)
        if [ $setwd_calls -gt 0 ]; then
            echo -e "${RED}✗${NC} $filename: Contains setwd() calls - remove these"
            ((ERRORS++))
        fi

        # Check for attach() calls (bad practice)
        attach_calls=$(grep -c "attach(" "$file" 2>/dev/null || echo 0)
        if [ $attach_calls -gt 0 ]; then
            echo -e "${RED}✗${NC} $filename: Contains attach() calls - avoid these"
            ((ERRORS++))
        fi
    fi
done

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓${NC} No common issues found"
fi

echo ""

# Check 9: File Sizes
echo "CHECK 9: File Sizes"
echo "-------------------------------------------"

echo "Large files (>100KB):"
find . -type f -size +100k ! -path "./.git/*" -exec ls -lh {} \; | awk '{print "  "$9" ("$5")"}'

echo ""

# Check 10: Git Status
echo "CHECK 10: Git Status"
echo "-------------------------------------------"

if [ -d ".git" ]; then
    echo -e "${GREEN}✓${NC} Git repository"
    echo "Current branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
    echo "Latest commit: $(git log -1 --oneline 2>/dev/null || echo 'none')"

    # Check for uncommitted changes
    if git diff-index --quiet HEAD -- 2>/dev/null; then
        echo -e "${GREEN}✓${NC} No uncommitted changes"
    else
        echo -e "${YELLOW}⚠${NC} Uncommitted changes present"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠${NC} Not a git repository"
    ((WARNINGS++))
fi

echo ""

# Summary
echo "==============================================================================="
echo "  CHECK SUMMARY"
echo "==============================================================================="
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ ALL CHECKS PASSED!${NC}"
    echo ""
    echo "The package structure looks good!"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ PASSED WITH WARNINGS${NC}"
    echo ""
    echo "Found $WARNINGS warning(s)"
    echo "These are minor issues that should be reviewed but won't prevent the package from working."
else
    echo -e "${RED}✗ CHECKS FAILED${NC}"
    echo ""
    echo "Found $ERRORS error(s) and $WARNINGS warning(s)"
    echo "These errors should be fixed before using the package."
fi

echo ""
echo "NOTE: This is a static analysis. To fully test the package, run:"
echo "  Rscript TEST_PACKAGE.R"
echo "  or"
echo "  R CMD check ."
echo ""

exit $ERRORS
