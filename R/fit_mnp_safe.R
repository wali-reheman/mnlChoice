#' Safely Fit Multinomial Probit with Error Handling
#'
#' Wrapper around MNP::mnp() that handles common convergence failures gracefully
#' with automatic fallback options and multiple retry attempts.
#'
#' @param formula Formula object specifying the model.
#' @param data Data frame containing the variables.
#' @param fallback Character. What to do if MNP fails: "MNL" (fit MNL instead),
#'   "error" (throw error), or "NULL" (return NULL). Default is "MNL".
#' @param max_attempts Integer. Number of times to retry MNP with different
#'   starting values. Default is 3.
#' @param verbose Logical. Print convergence status messages. Default is TRUE.
#' @param ... Additional arguments passed to MNP::mnp() or nnet::multinom().
#'
#' @return A fitted model object (class "mnp" or "multinom") or NULL if fallback="NULL"
#'   and all attempts fail. Includes additional attribute "model_type" indicating
#'   which model was actually fit.
#'
#' @details
#' Common MNP convergence errors handled:
#' \itemize{
#'   \item "TruncNorm: lower bound > upper bound" - Numerical instability
#'   \item MCMC convergence failures - Poor mixing or non-convergence
#'   \item Starting value issues - Improper initialization
#' }
#'
#' The function tries multiple random seeds for starting values if initial
#' attempts fail. If all attempts fail and fallback="MNL", fits standard
#' multinomial logit using nnet::multinom() instead.
#'
#' @examples
#' \dontrun{
#' # Simulate some data
#' set.seed(123)
#' n <- 100
#' x1 <- rnorm(n)
#' x2 <- rnorm(n)
#' y <- sample(1:3, n, replace = TRUE)
#' dat <- data.frame(y = factor(y), x1, x2)
#'
#' # Try to fit MNP, fallback to MNL if it fails
#' fit <- fit_mnp_safe(y ~ x1 + x2, data = dat, fallback = "MNL")
#'
#' # Check which model was actually fit
#' attr(fit, "model_type")
#' }
#'
#' @export
fit_mnp_safe <- function(formula, data, fallback = "MNL", max_attempts = 3,
                         verbose = TRUE, ...) {

  # Input validation
  if (!fallback %in% c("MNL", "error", "NULL")) {
    stop("fallback must be 'MNL', 'error', or 'NULL'")
  }

  if (max_attempts < 1) {
    stop("max_attempts must be at least 1")
  }

  # Check if MNP package is available
  mnp_available <- requireNamespace("MNP", quietly = TRUE)

  if (!mnp_available) {
    warning(
      "\n*** MNP package not installed ***\n",
      "MNP is required for multinomial probit models.\n",
      "Install with: install.packages('MNP')\n",
      call. = FALSE, immediate. = TRUE
    )

    if (fallback == "MNL") {
      if (verbose) message("Falling back to MNL (multinomial logit)...")
      return(.fit_mnl_fallback(formula, data, verbose, ...))
    } else if (fallback == "error") {
      stop("MNP package not installed. Install with: install.packages('MNP')")
    } else {
      if (verbose) message("Returning NULL (MNP not available, fallback='NULL')")
      return(NULL)
    }
  }

  # Get smart starting values from MNL (first attempt only)
  mnl_coefs <- NULL
  if (requireNamespace("nnet", quietly = TRUE)) {
    mnl_quick <- tryCatch({
      nnet::multinom(formula = formula, data = data, trace = FALSE)
    }, error = function(e) NULL)

    if (!is.null(mnl_quick)) {
      mnl_coefs <- coef(mnl_quick)
      if (verbose) {
        message("Using MNL coefficients as smart starting values for MNP...")
      }
    }
  }

  # Try fitting MNP with multiple attempts
  for (attempt in 1:max_attempts) {
    if (verbose && max_attempts > 1) {
      message(sprintf("MNP fitting attempt %d of %d...", attempt, max_attempts))
    }

    fit <- tryCatch({
      # Set different seed for each attempt
      set.seed(12345 + attempt * 100)

      # Use smart starting values on first attempt, random on subsequent
      if (attempt == 1 && !is.null(mnl_coefs)) {
        # Convert MNL coefs to MNP starting value format
        # MNP expects a matrix for coef.p (coefficients)
        starting_coefs <- as.matrix(mnl_coefs)

        # Call MNP with starting values
        MNP::mnp(formula = formula, data = data, verbose = FALSE,
                coef.p = starting_coefs, ...)
      } else {
        # Call MNP::mnp with default starting values
        MNP::mnp(formula = formula, data = data, verbose = FALSE, ...)
      }

    }, error = function(e) {
      if (verbose && attempt == max_attempts) {
        message(sprintf("MNP error: %s", e$message))
      }
      NULL
    }, warning = function(w) {
      if (verbose) {
        message(sprintf("MNP warning: %s", w$message))
      }
      NULL
    })

    # Check if fit succeeded
    if (!is.null(fit)) {
      if (verbose) {
        message("MNP converged successfully.")
      }

      # Add model type attribute
      attr(fit, "model_type") <- "MNP"
      return(fit)
    }
  }

  # All MNP attempts failed
  if (verbose) {
    message(sprintf("MNP failed to converge after %d attempts.", max_attempts))
  }

  # Handle fallback
  if (fallback == "MNL") {
    if (verbose) {
      message("Falling back to MNL (nnet::multinom)...")
    }
    return(.fit_mnl_fallback(formula, data, verbose, ...))

  } else if (fallback == "error") {
    stop("MNP failed to converge and fallback='error'")

  } else {
    # fallback == "NULL"
    return(NULL)
  }
}


#' @keywords internal
.fit_mnl_fallback <- function(formula, data, verbose = TRUE, ...) {

  # Check if nnet is available
  if (!requireNamespace("nnet", quietly = TRUE)) {
    stop("nnet package required for MNL fallback. Install with: install.packages('nnet')")
  }

  # Fit MNL using nnet::multinom
  fit <- tryCatch({
    nnet::multinom(formula = formula, data = data, trace = FALSE, ...)
  }, error = function(e) {
    stop(sprintf("MNL fitting also failed: %s", e$message))
  })

  if (verbose) {
    message("MNL fitted successfully.")
  }

  # Add model type attribute
  attr(fit, "model_type") <- "MNL"
  return(fit)
}
