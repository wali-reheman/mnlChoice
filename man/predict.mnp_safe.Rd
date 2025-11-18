\name{predict.mnp_safe}
\alias{predict.mnp_safe}
\title{Predict Method for mnp_safe Objects}
\usage{
\method{predict}{mnp_safe}(object, newdata, type = c("probs", "class"), ...)
}
\arguments{
\item{object}{An object of class "mnp_safe" from \code{\link{fit_mnp_safe}}.}

\item{newdata}{Optional data frame for predictions. If NULL, uses fitted values.}

\item{type}{Type of prediction: "probs" for probabilities or "class" for predicted classes.}

\item{...}{Additional arguments (currently unused).}
}
\value{
If type = "probs": matrix of predicted probabilities for each alternative.
If type = "class": vector of predicted classes.
}
\description{
S3 predict method for objects returned by \code{fit_mnp_safe()}.
}
\details{
This method extracts predictions from MNP models fitted with the safe wrapper function.
}
\examples{
\dontrun{
# Fit model
model <- fit_mnp_safe(y ~ x1 + x2, data = mydata)

# Get predicted probabilities
probs <- predict(model, type = "probs")

# Get predicted classes
classes <- predict(model, type = "class")
}
}
\seealso{
\code{\link{fit_mnp_safe}}
}
