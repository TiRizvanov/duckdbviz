% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/duckdb_helpers.R
\name{process_selection_data}
\alias{process_selection_data}
\title{Process selection data from JavaScript}
\usage{
process_selection_data(selection_data, original_data)
}
\arguments{
\item{selection_data}{JSON string containing selection data}

\item{original_data}{Original data frame used for visualization}
}
\value{
A data frame containing the selected points with original column names
}
\description{
This function processes selection data received from JavaScript
}
\keyword{internal}
