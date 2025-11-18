#' Generate Synthetic Multinomial Choice Data
#'
#' Creates synthetic multinomial choice data with known probabilities for testing
#' and simulation studies. Allows control over sample size, number of alternatives,
#' error correlation, and functional form.
#'
#' @param n Integer. Number of observations to generate.
#' @param n_alternatives Integer. Number of choice alternatives (default 3).
#' @param n_vars Integer. Number of explanatory variables (default 2).
#' @param correlation Numeric. Correlation between error terms (0 to 1). Default 0.
#' @param functional_form Character. "linear", "quadratic", or "log". Default "linear".
#' @param effect_size Numeric. Magnitude of coefficients. Default 1.
#' @param seed Integer. Random seed for reproducibility. If NULL, no seed set.
#'
#' @return A list with components:
#'   \item{data}{Data frame with choice outcome and covariates}
#'   \item{true_probs}{Matrix of true choice probabilities}
#'   \item{true_betas}{Matrix of true coefficient values}
#'   \item{correlation_matrix}{Correlation matrix used for errors}
#'   \item{formula}{Formula object dynamically created based on n_vars (e.g., choice ~ x1 + x2 + x3)}
#'   \item{n_vars}{Number of predictor variables}
#'   \item{n_alternatives}{Number of choice alternatives}
#'
#' @details
#' This function generates multinomial choice data using either a logit or probit
#' data generating process. The errors can be correlated according to the specified
#' correlation structure.
#'
#' For the linear functional form, utilities are:
#' \deqn{U_{ij} = \beta_j' X_i + \epsilon_{ij}}
#'
#' For quadratic:
#' \deqn{U_{ij} = \beta_j' X_i + \gamma_j' X_i^2 + \epsilon_{ij}}
#'
#' The chosen alternative is the one with highest utility.
#'
#' @examples
#' # Generate simple 3-alternative choice data
#' dat <- generate_choice_data(n = 250)
#' head(dat$data)
#' head(dat$true_probs)
#'
#' # Generate data with correlation
#' dat <- generate_choice_data(n = 500, correlation = 0.5)
#'
#' # Generate data with quadratic functional form
#' dat <- generate_choice_data(n = 250, functional_form = "quadratic")
#'
#' @export
generate_choice_data <- function(n, n_alternatives = 3, n_vars = 2,
                                  correlation = 0, functional_form = "linear",
                                  effect_size = 1, seed = NULL) {

  # Set seed if provided
  if (!is.null(seed)) {
    set.seed(seed)
  }

  # Input validation
  if (n < 1) stop("n must be positive")
  if (n_alternatives < 2) stop("n_alternatives must be at least 2")
  if (n_vars < 1) stop("n_vars must be at least 1")
  if (correlation < 0 || correlation > 1) stop("correlation must be between 0 and 1")
  if (!functional_form %in% c("linear", "quadratic", "log")) {
    stop("functional_form must be 'linear', 'quadratic', or 'log'")
  }

  # Generate covariates
  X <- matrix(rnorm(n * n_vars), nrow = n, ncol = n_vars)
  colnames(X) <- paste0("x", 1:n_vars)

  # Generate coefficients for each alternative (first alternative is reference)
  betas <- matrix(0, nrow = n_vars, ncol = n_alternatives - 1)
  for (j in 1:(n_alternatives - 1)) {
    betas[, j] <- rnorm(n_vars, mean = 0, sd = effect_size)
  }
  rownames(betas) <- paste0("x", 1:n_vars)
  colnames(betas) <- paste0("alt", 2:n_alternatives)

  # Calculate utilities based on functional form
  V <- matrix(0, nrow = n, ncol = n_alternatives)

  # Alternative 1 (reference) has utility 0 + error
  # Alternatives 2+ have systematic component
  for (j in 2:n_alternatives) {
    if (functional_form == "linear") {
      V[, j] <- X %*% betas[, j - 1]
    } else if (functional_form == "quadratic") {
      # Add quadratic terms
      V[, j] <- X %*% betas[, j - 1] + 0.3 * rowSums(X^2)
    } else if (functional_form == "log") {
      # Log transform positive values, linear for others
      X_log <- X
      X_log[X > 0] <- log(X[X > 0] + 1)
      V[, j] <- X_log %*% betas[, j - 1]
    }
  }

  # Generate correlated errors
  if (correlation > 0) {
    # Create correlation matrix
    cor_matrix <- matrix(correlation, n_alternatives, n_alternatives)
    diag(cor_matrix) <- 1

    # Generate correlated normal errors
    require_mvtnorm <- requireNamespace("mvtnorm", quietly = TRUE)
    if (require_mvtnorm) {
      errors <- mvtnorm::rmvnorm(n, mean = rep(0, n_alternatives), sigma = cor_matrix)
    } else {
      # Fallback: use simple correlation structure
      z <- matrix(rnorm(n * n_alternatives), n, n_alternatives)
      common_factor <- rnorm(n)
      errors <- sqrt(correlation) * common_factor + sqrt(1 - correlation) * z
    }
  } else {
    cor_matrix <- diag(n_alternatives)
    errors <- matrix(rnorm(n * n_alternatives), n, n_alternatives)
  }

  # Total utility
  U <- V + errors

  # Make choice (highest utility)
  choice <- apply(U, 1, which.max)

  # Calculate true probabilities (assuming logit DGP for probability calculation)
  exp_V <- exp(V)
  true_probs <- exp_V / rowSums(exp_V)
  colnames(true_probs) <- paste0("prob_alt", 1:n_alternatives)

  # Create data frame
  data_df <- data.frame(
    choice = factor(choice),
    X,
    stringsAsFactors = FALSE
  )

  # Create formula dynamically based on n_vars
  predictor_names <- paste0("x", 1:n_vars)
  formula_str <- paste("choice ~", paste(predictor_names, collapse = " + "))
  formula_obj <- as.formula(formula_str)

  # Return results
  list(
    data = data_df,
    true_probs = true_probs,
    true_betas = betas,
    correlation_matrix = cor_matrix,
    functional_form = functional_form,
    n = n,
    n_alternatives = n_alternatives,
    n_vars = n_vars,
    formula = formula_obj  # Dynamic formula based on actual n_vars
  )
}


#' Evaluate Prediction Performance
#'
#' Calculates performance metrics comparing predicted to true probabilities.
#'
#' @param predicted_probs Matrix of predicted choice probabilities (n x J).
#' @param true_probs Matrix of true choice probabilities (n x J).
#' @param actual_choices Vector of actual choices (factor or numeric).
#' @param metrics Character vector of metrics to compute. Options: "RMSE",
#'   "Brier", "LogLoss", "Accuracy". Default is all.
#'
#' @return A list with computed metrics.
#'
#' @details
#' Computes standard prediction performance metrics:
#' \itemize{
#'   \item RMSE - Root Mean Squared Error across all probabilities
#'   \item Brier - Brier score (mean squared error for probabilities)
#'   \item LogLoss - Logarithmic loss (cross-entropy)
#'   \item Accuracy - Proportion of correct predictions
#' }
#'
#' @examples
#' # Generate data with known probabilities
#' dat <- generate_choice_data(n = 100, seed = 123)
#'
#' # Fit a model and get predictions
#' # (this is a placeholder - you'd use actual model predictions)
#' predicted <- dat$true_probs + matrix(rnorm(100 * 3, sd = 0.1), 100, 3)
#' predicted <- predicted / rowSums(predicted)  # Normalize
#'
#' # Evaluate performance
#' evaluate_performance(predicted, dat$true_probs, dat$data$choice)
#'
#' @export
evaluate_performance <- function(predicted_probs, true_probs = NULL,
                                  actual_choices = NULL,
                                  metrics = c("RMSE", "Brier", "LogLoss", "Accuracy")) {

  results <- list()

  # RMSE (if true probabilities available)
  if ("RMSE" %in% metrics && !is.null(true_probs)) {
    rmse <- sqrt(mean((predicted_probs - true_probs)^2))
    results$RMSE <- rmse
  }

  # Brier score (if actual choices available)
  if ("Brier" %in% metrics && !is.null(actual_choices)) {
    # Convert choices to indicators
    n <- nrow(predicted_probs)
    J <- ncol(predicted_probs)

    if (is.factor(actual_choices)) {
      actual_choices <- as.numeric(actual_choices)
    }

    y_matrix <- matrix(0, n, J)
    for (i in 1:n) {
      y_matrix[i, actual_choices[i]] <- 1
    }

    brier <- mean((y_matrix - predicted_probs)^2)
    results$Brier <- brier
  }

  # Log Loss (if actual choices available)
  if ("LogLoss" %in% metrics && !is.null(actual_choices)) {
    if (is.factor(actual_choices)) {
      actual_choices <- as.numeric(actual_choices)
    }

    # Extract predicted probability for chosen alternative
    n <- length(actual_choices)
    chosen_probs <- numeric(n)
    for (i in 1:n) {
      chosen_probs[i] <- predicted_probs[i, actual_choices[i]]
    }

    # Avoid log(0)
    chosen_probs <- pmax(chosen_probs, 1e-15)

    logloss <- -mean(log(chosen_probs))
    results$LogLoss <- logloss
  }

  # Accuracy (if actual choices available)
  if ("Accuracy" %in% metrics && !is.null(actual_choices)) {
    predicted_choices <- apply(predicted_probs, 1, which.max)

    if (is.factor(actual_choices)) {
      actual_choices <- as.numeric(actual_choices)
    }

    accuracy <- mean(predicted_choices == actual_choices)
    results$Accuracy <- accuracy
  }

  return(results)
}
