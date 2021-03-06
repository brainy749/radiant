% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ann.R
\name{plot.ann}
\alias{plot.ann}
\title{Plot method for the ann function}
\usage{
\method{plot}{ann}(x, shiny = FALSE, ...)
}
\arguments{
\item{x}{Return value from \code{\link{ann}}}

\item{shiny}{Did the function call originate inside a shiny app}

\item{...}{further arguments passed to or from other methods}
}
\description{
Plot method for the ann function
}
\details{
See \url{http://vnijs.github.io/radiant/analytics/ann.html} for an example in Radiant
}
\examples{
result <- ann("titanic", "survived", c("pclass","sex"), lev = "Yes")
plot(result, plots = c("imp","net"))

}
\seealso{
\code{\link{ann}} to generate results

\code{\link{summary.ann}} to summarize results

\code{\link{predict.ann}} for prediction
}

