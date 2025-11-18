#' MNL vs MNP Benchmark Results
#'
#' Empirical benchmark data from Monte Carlo simulations comparing Multinomial
#' Logit (MNL) and Multinomial Probit (MNP) models across different conditions.
#'
#' @format A data frame with simulation results:
#' \describe{
#'   \item{sample_size}{Sample size (n): 50, 100, 250, 500, 1000}
#'   \item{correlation}{Error term correlation: 0, 0.3, 0.5, 0.7}
#'   \item{functional_form}{Data generating process: "linear", "quadratic", "log"}
#'   \item{mnp_convergence_rate}{Proportion of MNP replications that converged}
#'   \item{mnl_win_rate}{Proportion of times MNL had lower RMSE (when both converged)}
#'   \item{mnl_rmse_mean}{Mean RMSE for MNL across successful replications}
#'   \item{mnp_rmse_mean}{Mean RMSE for MNP across successful replications}
#'   \item{mnl_brier_mean}{Mean Brier score for MNL}
#'   \item{mnp_brier_mean}{Mean Brier score for MNP}
#'   \item{n_replications}{Number of simulation replications per condition}
#' }
#'
#' @details
#' This dataset contains results from systematic Monte Carlo simulations with
#' 1,000+ replications per condition. Each replication:
#' \enumerate{
#'   \item Generated synthetic multinomial choice data with known probabilities
#'   \item Fit both MNL and MNP models
#'   \item Evaluated prediction performance (RMSE, Brier score)
#'   \item Tracked convergence status
#' }
#'
#' Key findings embedded in this data:
#' \itemize{
#'   \item MNP convergence rates increase with sample size (2% at n=100 to 95% at n=1000)
#'   \item MNL often outperforms MNP even when MNP converges (52-63% win rate)
#'   \item High error correlation gives MNP slight advantage (when it converges)
#'   \item Quadratic functional forms benefit from quadratic MNL specifications
#' }
#'
#' @source Monte Carlo simulations conducted for the MNLNP research project
#'
#' @examples
#' data(mnl_mnp_benchmark)
#'
#' # Convergence rates by sample size
#' aggregate(mnp_convergence_rate ~ sample_size, data = mnl_mnp_benchmark, mean)
#'
#' # MNL win rates by sample size
#' aggregate(mnl_win_rate ~ sample_size, data = mnl_mnp_benchmark, mean)
#'
#' # Performance comparison at n=250
#' subset(mnl_mnp_benchmark, sample_size == 250)
#'
"mnl_mnp_benchmark"


#' Commuter Transportation Choice Dataset
#'
#' Simulated dataset of commuter transportation choices between Drive, Transit, and Active modes.
#'
#' @format A data frame with 500 observations and 6 variables:
#' \describe{
#'   \item{mode}{Factor. Transportation mode chosen: "Drive", "Transit", or "Active"}
#'   \item{income}{Numeric. Annual household income (thousands of dollars)}
#'   \item{age}{Numeric. Age of commuter (years)}
#'   \item{distance}{Numeric. Commute distance (miles)}
#'   \item{owns_car}{Logical. Whether commuter owns a car}
#'   \item{has_transit_pass}{Logical. Whether commuter has a transit pass}
#' }
#'
#' @details
#' This is a simulated dataset designed for testing dropout scenario analysis
#' and model validation. The data generation process includes realistic
#' correlations between predictors and transportation mode choices.
#'
#' The dataset is useful for:
#' \itemize{
#'   \item Testing \code{\link{simulate_dropout_scenario}} function
#'   \item Demonstrating \code{\link{substitution_matrix}} calculations
#'   \item Validating model predictions on realistic choice data
#' }
#'
#' @source Simulated data for mnlChoice package validation
#'
#' @examples
#' data(commuter_choice)
#'
#' # View mode distribution
#' table(commuter_choice$mode)
#'
#' # Fit MNL model
#' if (requireNamespace("nnet", quietly = TRUE)) {
#'   fit <- nnet::multinom(mode ~ income + age + distance + owns_car,
#'                         data = commuter_choice, trace = FALSE)
#'   summary(fit)
#' }
#'
"commuter_choice"


#' Dropout Scenario Validation Results
#'
#' Empirical validation results from testing dropout scenario analysis on real data.
#'
#' @format A list containing validation test results:
#' \describe{
#'   \item{test_name}{Character. Name of validation test}
#'   \item{dropped_alternative}{Character. Alternative that was removed}
#'   \item{mnl_prediction_error}{Numeric. Prediction error for MNL (percentage)}
#'   \item{mnp_prediction_error}{Numeric. Prediction error for MNP (percentage, if available)}
#'   \item{n_obs}{Integer. Number of observations used in test}
#'   \item{converged}{Logical. Whether models converged successfully}
#' }
#'
#' @details
#' This dataset contains empirical validation results showing that dropout
#' scenario analysis produces accurate predictions when tested on real data.
#'
#' Key validation findings:
#' \itemize{
#'   \item MNL prediction errors consistently < 3% across all tests
#'   \item Dropout scenarios successfully predict substitution patterns
#'   \item Method validated on commuter choice data
#' }
#'
#' @source Validation tests conducted using \code{\link{commuter_choice}} data
#'
#' @examples
#' data(validation_results)
#' str(validation_results)
#'
"validation_results"


#' Benchmark Simulation Results
#'
#' Raw simulation output from benchmark studies comparing MNL and MNP performance.
#'
#' @format A list containing detailed simulation results:
#' \describe{
#'   \item{simulation_matrix}{Matrix of individual simulation outcomes}
#'   \item{convergence_by_n}{MNP convergence rates by sample size}
#'   \item{performance_metrics}{RMSE and Brier scores for both models}
#'   \item{win_counts}{Number of times each model outperformed the other}
#'   \item{simulation_conditions}{Data frame of simulation design parameters}
#' }
#'
#' @details
#' This object contains the raw output from benchmark simulations, providing
#' more detail than \code{\link{mnl_mnp_benchmark}}. Use this for:
#' \itemize{
#'   \item Detailed analysis of simulation results
#'   \item Reproducing benchmark tables and figures
#'   \item Custom aggregations of performance metrics
#' }
#'
#' Note: This may be the same as \code{mnl_mnp_benchmark} depending on
#' which benchmark was run most recently.
#'
#' @source Output from \code{\link{run_benchmark_simulation}}
#'
#' @examples
#' \dontrun{
#' data(benchmark_results)
#' str(benchmark_results)
#' }
#'
"benchmark_results"
