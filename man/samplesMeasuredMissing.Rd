% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/tab_measuredvalues_missingvalues.R
\name{samplesMeasuredMissing}
\alias{samplesMeasuredMissing}
\title{Create tibble containing number of measured/missing features 
of samples}
\usage{
samplesMeasuredMissing(se)
}
\arguments{
\item{se}{`SummarizedExperiment` object}
}
\value{
`tbl` with number of measured/missing features per sample
}
\description{
`samplesMeasuredMissing` returns a `tbl` with 
the number of measured/missing
features of samples. The function will take as input a 
`SummarizedExperiment` object and will access its `assay()` slot
}
\examples{
## create se
a <- matrix(1:100, nrow = 10, ncol = 10, 
            dimnames = list(1:10, paste("sample", 1:10)))
a[c(1, 5, 8), 1:5] <- NA
set.seed(1)
a <- a + rnorm(100)
sample <- data.frame(name = colnames(a), type = c(rep("1", 5), rep("2", 5)))
featData <- data.frame(spectra = rownames(a))
se <- SummarizedExperiment::SummarizedExperiment(assay = a, 
    rowData = featData, colData = sample)

## create the data.frame with information on number of measured/missing
## values
samplesMeasuredMissing(se)

}