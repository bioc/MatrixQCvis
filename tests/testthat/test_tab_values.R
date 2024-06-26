#' @importFrom SummarizedExperiment SummarizedExperiment assay
#' @importFrom tibble tibble

## create se
a <- matrix(seq_len(1000), nrow = 100, ncol = 10,
    dimnames = list(seq_len(100), paste("sample", seq_len(10))))
a[c(1, 5, 8), seq_len(5)] <- NA
set.seed(1)
a <- a + rnorm(1000)
cD <- data.frame(name = colnames(a), type = c(rep("1", 5), rep("2", 5)))
rD <- data.frame(spectra = rownames(a))
se <- SummarizedExperiment::SummarizedExperiment(assay = a, rowData = rD,
    colData = cD)
se_error <- se
colnames(colData(se_error)) <- c("x5at1t1g161asy", "type")

## function createBoxplot
test_that("createBoxplot", {
    g <- createBoxplot(se)

    expect_error(createBoxplot(SummarizedExperiment::assay(se)),
        "unable to find an inherited method for function")
    expect_error(createBoxplot(se = se, orderCategory = "name",
        title =  "test", log = "", violin = TRUE), "not interpretable as logical")
    expect_error(createBoxplot(se = se, orderCategory = "name",
        title = "test", log = TRUE, violin = ""), "invalid argument type")
    expect_error(createBoxplot(se = se, orderCategory = "foo", title = "",
          log = TRUE, violin = TRUE),
        "should be one of")
    expect_error(createBoxplot(se = se_error, orderCategory = "x5at1t1g161asy"),
        "Column name `x5at1t1g161asy` must not be duplicated")
    expect_is(g, "gg")
})

## function driftPlot
test_that("driftPlot", {
    expect_is(
        driftPlot(se = se, aggregation = "median", category = "type",
            orderCategory = "type", level = "all", method = "loess"), "plotly")
  expect_error(driftPlot(se = se, aggregation = "", category = "type",
      orderCategory = "type", level = "all", method = "loess"),
      "should be one of")
  expect_error(driftPlot(se = se, aggregation = "median", category = "foo",
      orderCategory = "type", level = "all", method = "loess"),
      "should be one of")
  expect_error(driftPlot(se = se, aggregation = "median", category = "type",
      orderCategory = "foo", level = "all", method = "loess"),
      "should be one of")
  expect_error(driftPlot(se = se, aggregation = "median", category = "type",
      orderCategory = "type", level = "foo", method = "loess"),
      "should be one of")
  expect_error(driftPlot(se = se, aggregation = "median", category = "type",
      orderCategory = "type", level = "all", method = "foo"),
      "should be one of")
  expect_error(driftPlot(se = se_error, aggregation = "median",
            category = "type", orderCategory = "type", level = "all",
            method = "loess"),
      "Column name `x5at1t1g161asy` must not be duplicated")
})

## function cv
test_that("cv", {
    x <- matrix(seq_len(100), ncol = 5)
    expect_equal(cv(x)$raw,
        c(56.343617, 19.396983, 11.715009,  8.391603,  6.537105))
    expect_equal(names(cv(x)), "raw")
    expect_equal(names(cv(x, NULL)), NULL)
    expect_true(is.numeric(cv(x)$raw))
    expect_error(cv("foo"), "must have a positive length")
    expect_error(cv(seq_len(100)), "must have a positive length")
})

## function plotCV
test_that("plotCV", {
    x1 <- matrix(seq_len(100), ncol = 5)
    x2 <- matrix(seq(101, 200), ncol = 5)
    df <- data.frame(cv(x1, "raw"), cv(x2, "normalized"))
    g <- plotCV(df)
    expect_error(plotCV(NULL), "df is not a data.frame")
    expect_error(plotCV(NA), "df is not a data.frame")
    expect_error(plotCV(x1), "df is not a data.frame")
    expect_is(g, "gg")
})

## function ECDF
test_that("ECDF", {

    sample_1 <- colnames(se)[1]
    x <- SummarizedExperiment::assay(se)
    g <- ECDF(se, sample_1, "all")

    expect_error(ECDF(x, sample_1, "all"), "unable to find an inherited method")
    expect_error(ECDF(se, "", "all"), "'arg' should be one of")
    expect_error(ECDF(se, sample_1, "test"), "'arg' should be one of")
    expect_error(ECDF(se_error, sample_1, "all"),
        "Column name `x5at1t1g161asy` must not be duplicated")
    expect_is(g, "gg")
})

## function distShiny
test_that("distShiny", {
    x <- SummarizedExperiment::assay(se)

    matTest <- matrix(
        c(0,        173.0173, 349.8123,
          173.0173, 0,        176.7957,
          349.8123, 176.7957, 0), byrow = TRUE, ncol = 3, nrow = 3,
        dimnames = list(c(colnames(x)[seq_len(3)]), c(colnames(x)[seq_len(3)])))

    expect_error(distShiny(x, "test"), "invalid distance method")
    expect_equal(distShiny(x[seq_len(3), seq_len(3)], method = "euclidean"), matTest,
                 tolerance = 1e-02)
    expect_true(is.matrix(distShiny(x)))
})

## function distSample
test_that("distSample", {
    x <- SummarizedExperiment::assay(se)
    d <- distShiny(x, method = "euclidean")
    g <- distSample(d, se, label = "type")

    expect_error(distSample(d[seq_len(3), seq_len(3)], se = se, label = "type"),
        "number of observations in top annotation")
    expect_error(distSample(d, se = se[, seq_len(3)], label = "type"),
        "number of observations in top annotation")
    expect_is(g, "Heatmap")
})

## function sumDistSample
test_that("sumDistSample", {
    x <- SummarizedExperiment::assay(se)
    d <- distShiny(x, method = "euclidean")
    g <- sumDistSample(d)

    ##expect_error(sumDistSample(d, se), "no method for coercing this S4 class")
    ##expect_error(sumDistSample(matrix(seq_len(3))), "requires the following aesthetics")
    expect_error(sumDistSample(se),
        "must be an array of at least two dimensions")
    expect_is(g, "plotly")
})

## function MAvalues
test_that("MAvalues", {
    tbl_test <- tibble::tibble(Feature = as.character(c(rep(2, 3), rep(3, 3))),
        name = rep(colnames(se)[seq_len(3)], 2),
        A = c(4.149180, 5.535751, 5.785051, 4.144537, 5.534471, 5.785192),
        M = c( -6.044885, 2.274541, 3.770344, -6.061178, 2.278427, 3.782751),
        name.y = rep(colnames(se)[seq_len(3)], 2),
        type = "1")
    ma <- MAvalues(se = se, group = "all")

    expect_error(MAvalues(assay(se), log2 = TRUE, "all"),
        "unable to find an inherited method for function")
    expect_error(MAvalues(se, log2 = TRUE, group = ""), "'arg' should be one of")
    expect_error(MAvalues(se, log2 = "", group = "all"),
        "argument is not interpretable as logical")
    expect_error(MAvalues(se_error, log2 = TRUE, group = "all"),
        "Column name `x5at1t1g161asy` must not be duplicated")
    expect_true(is.data.frame(ma))
    expect_equal(dim(ma), c(1000, 6))
    expect_true(is.character(ma$Feature))
    expect_true(is.character(ma$name))
    expect_true(is.numeric(ma$A))
    expect_true(is.numeric(ma$M))
    expect_true(is.character(ma$type))
    expect_equal(MAvalues(se[c(2, 3), seq_len(3)], group = "all"), tbl_test,
          tolerance = 1e-07)
})

## function hoeffDvalues
test_that("hoeffDValues", {
    tbl <- MAvalues(se)
    l_test <- list(raw = c(0.9901381, 0.7174001, 0.2431791, 0.8799139,
        0.9270406, 0.9566922, 0.9671259, 0.9773905, 0.9788422, 0.9766581))
    l_test_subset <- list(raw = c(0.9924323, 0.6885165, 0.2892747, 0.8822307,
        0.9255351, 0.9562963, 0.9635617, 0.9784907, 0.9765922, 0.9765521))
    names(l_test$raw) <- colnames(se)
    names(l_test_subset$raw) <- colnames(se)


    hD <- hoeffDValues(tbl, name = "raw", sample_n = NULL)
    set.seed(2022)
    hD_subset <- hoeffDValues(tbl, name = "raw", sample_n = 90)

    expect_error(hoeffDValues(tbl[, !colnames(tbl) %in% "A"]),
        "Column `A` doesn't exist")
    expect_error(hoeffDValues(tbl[, !colnames(tbl) %in% "M"]),
        "Column `M` doesn't exist")
    expect_equal(hD, l_test, tolerance = 1e-07)
    expect_equal(hD_subset, l_test_subset, tolerance = 1e-07)
    expect_true(is.list(hD))
    expect_equal(length(hD), 1)
    expect_equal(length(unlist(hD)), length(unique(tbl$name)))
})

## function hoeffDPlot
test_that("hoeffDPlot", {
    l_1 <- list(raw = seq_len(10))
    l_2 <- list(normalized = seq_len(10))
    l_3 <- list(transformed = seq_len(10))
    l_4 <- list("batch corrected" = seq_len(10))
    l_5 <- list(imputed = seq_len(10))
    l_6 <- list(foo = seq_len(9))
    df <- data.frame(l_1, l_2)
    g <- hoeffDPlot(df)

    df <- data.frame(l_1, l_2, l_3, l_4, l_5)
    expect_error(hoeffDPlot(df, lines = ""),
        "argument is not interpretable as logical")
    expect_error({data.frame(l_1, l_6); hoeffDPlot(df)},
        "arguments imply differing number of rows")
    expect_is(g, "plotly")
})

## function MAplot
test_that("MAplot", {
    tbl <- MAvalues(se, group = "all")
    g <- MAplot(tbl, group = "all", plot = "all")

    expect_error(suppressWarnings(MAplot(se, "all")),
        "must be a ")
    expect_error(MAplot(tbl, group = "foo", plot = "all"), "should be one of ")
    expect_error(MAplot(tbl, group = "all", plot = "foo"),
        "plot not in ")
    expect_error(MAplot(tbl, group = "all", plot = c("sample 1", "foo")),
        "plot not in ")
    expect_is(g, "gg")
})

## function createDfFeature
test_that("createDfFeature", {

    x1 <- matrix(seq_len(100), ncol = 10, nrow = 10,
         dimnames = list(paste("feature", seq_len(10)), paste("sample", seq_len(10))))
    x2 <- x1 + 5
    x3 <- x2 + 10

    l <- list(x1 = x1, x2 = x2, x3 = x3)
    df <- createDfFeature(l, "feature 1")
    expect_equal(df$x1, seq(1, 91, 10))
    expect_equal(df$x2, seq(6, 96, 10))
    expect_equal(df$x3, seq(16, 106, 10))
    expect_is(df, "data.frame")
    expect_identical(rownames(df), paste("sample", seq_len(10)))
    expect_error(createDfFeature(l, "foo"), "subscript out of bounds")
    expect_error(createDfFeature("foo", "feature 1"),
        "incorrect number of dimensions")
})

## function featurePlot
test_that("featurePlot", {
    x1 <- matrix(seq_len(100), ncol = 10, nrow = 10,
      dimnames = list(paste("feature", seq_len(10)), paste("sample", seq_len(10))))
    x2 <- x1 + 5
    x3 <- x2 + 10

    l <- list(x1 = x1, x2 = x2, x3 = x3)
    df <- createDfFeature(l, "feature 1")
    expect_is(featurePlot(df), "gg")
    expect_error(featurePlot(NULL), "df is not a data.frame")
})

## function cvFeaturePlot
test_that("cvFeaturePlot", {
    x1 <- matrix(seq_len(100), ncol = 10, nrow = 10,
        dimnames = list(paste("feature", seq_len(10)), paste("sample", seq_len(10))))
    x2 <- x1 + 5
    x3 <- x2 + 10

    l <- list(x1 = x1, x2 = x2, x3 = x3)

    expect_is(cvFeaturePlot(l = l, lines = FALSE), "plotly")
    expect_is(cvFeaturePlot(l = l, lines = TRUE), "plotly")
    expect_error(cvFeaturePlot(l = NULL, lines = TRUE))
    expect_error(cvFeaturePlot(l = l, lines = "foo"),
        "argument is not interpretable as logical")
})

## function normalizeAssay
test_that("normalizeAssay", {
    a <- SummarizedExperiment::assay(se)
    a_n <- normalizeAssay(a, method = "none",
        multiplyByNormalizationValue = FALSE)
    a_n_multiply <- normalizeAssay(a, method = "none",
        multiplyByNormalizationValue = TRUE)
    a_s <- normalizeAssay(a, method = "sum",
        multiplyByNormalizationValue = FALSE)
    a_s_multiply <- normalizeAssay(a, method = "sum",
        multiplyByNormalizationValue = TRUE)
    a_qd <- normalizeAssay(a, method = "quantile division", probs = 0.75,
        multiplyByNormalizationValue = FALSE)
    a_qd_multiply <- normalizeAssay(a, method = "quantile division",
        probs = 0.75, multiplyByNormalizationValue = TRUE)
    a_q <- normalizeAssay(a, method = "quantile", multiplyByNormalizationValue = FALSE)
    a_q_multiply <- normalizeAssay(a, method = "quantile", multiplyByNormalizationValue = TRUE)
    expect_error(normalizeAssay(se), "a is not a matrix")
    expect_error(normalizeAssay(a, "foo"), "'arg' should be one of ")

    expect_equal(a_n, a)
    expect_equal(a_n_multiply, a)
    expect_equal(a_n_multiply, a_n)
    expect_equal(a_q, a_q_multiply)

    expect_true(is.matrix(a_n))
    expect_true(is.matrix(a_n_multiply))
    expect_true(is.matrix(a_s))
    expect_true(is.matrix(a_s_multiply))
    expect_true(is.matrix(a_qd))
    expect_true(is.matrix(a_qd_multiply))
    expect_true(is.matrix(a_q))
    expect_true(is.matrix(a_q_multiply))

    expect_equal(dim(a_n), dim(a))
    expect_equal(dim(a_n_multiply), dim(a))
    expect_equal(dim(a_s), dim(a))
    expect_equal(dim(a_s_multiply), dim(a))
    expect_equal(dim(a_qd), dim(a))
    expect_equal(dim(a_qd_multiply), dim(a))
    expect_equal(dim(a_q), dim(a))
    expect_equal(dim(a_q_multiply), dim(a))

    expect_equal(rownames(a_n), rownames(a))
    expect_equal(rownames(a_n_multiply), rownames(a))
    expect_equal(rownames(a_s), rownames(a))
    expect_equal(rownames(a_s_multiply), rownames(a))
    expect_equal(rownames(a_qd), rownames(a))
    expect_equal(rownames(a_qd_multiply), rownames(a))
    expect_equal(rownames(a_q), rownames(a))
    expect_equal(rownames(a_q_multiply), rownames(a))

    expect_equal(colnames(a_n), colnames(a))
    expect_equal(colnames(a_n_multiply), colnames(a))
    expect_equal(colnames(a_s), colnames(a))
    expect_equal(colnames(a_s_multiply), colnames(a))
    expect_equal(colnames(a_qd), colnames(a))
    expect_equal(colnames(a_qd_multiply), colnames(a))
    expect_equal(colnames(a_q), colnames(a))
    expect_equal(colnames(a_q_multiply), colnames(a))
})

## function transformAssay
test_that("transformAssay", {
    a <- SummarizedExperiment::assay(se)
    a_n <- transformAssay(a, method = "none")
    a_l <- transformAssay(a, method = "log")
    a_l2 <- transformAssay(a, method = "log2")
    a_l10 <- transformAssay(a, method = "log10")
    a_v <- transformAssay(a, method = "vsn")

    expect_error(transformAssay(se), "a is not a matrix")
    expect_error(transformAssay(a, "foo"), "'arg' should be one of ")
    expect_equal(a_n, a)
    expect_true(is.matrix(a_n))
    expect_true(is.matrix(a_l))
    expect_true(is.matrix(a_l2))
    expect_true(is.matrix(a_v))
    expect_equal(a_l, log(a))
    expect_equal(a_l2, log2(a))
    expect_equal(a_l10, log10(a))
    expect_equal(dim(a_n), dim(a))
    expect_equal(dim(a_l), dim(a))
    expect_equal(dim(a_l2), dim(a))
    expect_equal(dim(a_l10), dim(a))
    expect_equal(dim(a_v), dim(a))
    expect_equal(rownames(a_n), rownames(a))
    expect_equal(rownames(a_l), rownames(a))
    expect_equal(rownames(a_l2), rownames(a))
    expect_equal(rownames(a_l10), rownames(a))
    expect_equal(rownames(a_v), rownames(a))
    expect_equal(colnames(a_n), colnames(a))
    expect_equal(colnames(a_l), colnames(a))
    expect_equal(colnames(a_l2), colnames(a))
    expect_equal(colnames(a_l10), colnames(a))
    expect_equal(colnames(a_v), colnames(a))
})

## function batchCorrectionAssay
test_that("batchCorrectionAssay", {
    a <- matrix(seq_len(1000), nrow = 100, ncol = 10,
        dimnames = list(seq_len(100), paste("sample", seq_len(10))))
    se_b <- se
    SummarizedExperiment::assay(se_b) <- a
    a_n <- batchCorrectionAssay(se_b, method = "none")
    a_l <- batchCorrectionAssay(se_b, method = "removeBatchEffect (limma)",
        batch = "type", batch2 = NULL)
    a_c <- batchCorrectionAssay(se_b, method = "ComBat",
        batch = "type", batch2 = NULL, par.prior = FALSE)

    ## removeBatchEffect (limma)
    expect_error(batchCorrectionAssay(a, "removeBatchEffect (limma)"),
        "unable to find an inherited method for function")
    expect_error(batchCorrectionAssay(se_b, "foo"), "'arg' should be one of ")
    expect_error(batchCorrectionAssay(se_b, "removeBatchEffect (limma)", 
        batch = "foo", batch2 = NULL),
        "should be one of")
    expect_error(batchCorrectionAssay(se_b, "removeBatchEffect (limma)", 
        batch = "type", batch2 = "foo"),
        "should be one of")
    expect_error(batchCorrectionAssay(se_b, "removeBatchEffect (limma)", 
        batch = "foo", batch2 = "foo"),
        "should be one of")
    expect_error(batchCorrectionAssay(se_b, "removeBatchEffect (limma)", 
        batch = NULL, batch2 = "foo"),
        "should be one of")
    expect_equal(batchCorrectionAssay(se_b, "removeBatchEffect (limma)", 
        batch = NULL, batch2 = NULL), a)
    
    ## ComBat
    expect_error(batchCorrectionAssay(a, "ComBat"),
        "unable to find an inherited method for function")
    expect_error(batchCorrectionAssay(se_b, "ComBat", 
        batch = "foo", batch2 = NULL),
        "should be one of")
    expect_error(batchCorrectionAssay(se_b, "ComBat", 
        batch = "foo", batch2 = "foo"),
        "should be one of")
    expect_equal(batchCorrectionAssay(se_b, "ComBat", 
        batch = NULL, batch2 = NULL), a)
    
    expect_equal(a_n, a)
    expect_true(is.matrix(a_n))
    expect_true(is.matrix(a_l))
    expect_true(is.matrix(a_c))
    expect_equal(dim(a_n), dim(a))
    expect_equal(dim(a_l), dim(a))
    expect_equal(dim(a_c), dim(a))
    expect_equal(rownames(a_n), rownames(a))
    expect_equal(rownames(a_l), rownames(a))
    expect_equal(rownames(a_c), rownames(a))
    expect_equal(colnames(a_n), colnames(a))
    expect_equal(colnames(a_l), colnames(a))
    expect_equal(colnames(a_c), colnames(a))
})

## function imputeAssay
test_that("imputeAssay", {
    a <- SummarizedExperiment::assay(se)
    a_bpca <- imputeAssay(a, "BPCA")
    a_knn <- imputeAssay(a, "kNN")
    a_min <- imputeAssay(a, "Min")
    a_mindet <- imputeAssay(a, "MinDet")
    a_minprob <- imputeAssay(a, "MinProb")
    a_none <- imputeAssay(a, "none")

    expect_error(imputeAssay(se), "a is not a matrix")
    expect_error(imputeAssay(se, "foo"), "a is not a matrix")
    expect_true(is.matrix(a_bpca))
    expect_true(is.matrix(a_knn))
    expect_true(is.matrix(a_min))
    expect_true(is.matrix(a_mindet))
    expect_true(is.matrix(a_minprob))
    expect_true(is.matrix(a_none))
    expect_equal(dim(a_bpca), dim(a))
    expect_equal(dim(a_knn), dim(a))
    expect_equal(dim(a_min), dim(a))
    expect_equal(dim(a_mindet), dim(a))
    expect_equal(dim(a_minprob), dim(a))
    expect_equal(dim(a_none), dim(a))
    expect_equal(rownames(a_bpca), rownames(a))
    expect_equal(rownames(a_knn), rownames(a))
    expect_equal(rownames(a_min), rownames(a))
    expect_equal(rownames(a_mindet), rownames(a))
    expect_equal(rownames(a_minprob), rownames(a))
    expect_equal(rownames(a_none), rownames(a))
    expect_equal(colnames(a_bpca), colnames(a))
    expect_equal(colnames(a_knn), colnames(a))
    expect_equal(colnames(a_min), colnames(a))
    expect_equal(colnames(a_mindet), colnames(a))
    expect_equal(colnames(a_minprob), colnames(a))
    expect_equal(colnames(a_none), colnames(a))
    expect_equal(as.vector(a[1, seq_len(6)]), c(NA, NA, NA, NA, NA, 501.0773),
        tolerance = 1e-04)
    expect_equal(as.vector(a[5, seq_len(6)]), c(NA, NA, NA, NA, NA, 505.9916),
        tolerance = 1e-04)
    expect_equal(as.vector(a_bpca[1, seq_len(6)]),
        c(700.2801, 700.2800, 700.2800, 700.2801, 700.2801, 501.0773),
        tolerance = 5e-01)
    expect_equal(as.vector(a_bpca[5, seq_len(6)]),
        c(704.9565, 704.9565, 704.9565, 704.9566, 704.9566, 505.9916),
        tolerance = 5e-01)
    expect_equal(as.vector(a_knn[1, seq_len(6)]),
        c(6.799054, 106.900480, 207.305202, 306.809707, 406.564452, 501.077303),
        tolerance = 1e-04)
    expect_equal(as.vector(a_knn[5, seq_len(6)]),
        c(6.799054, 106.900480, 207.305202, 306.809707, 406.564452, 505.991601),
        tolerance = 1e-04)
    expect_equal(as.vector(a_min[1, seq_len(6)]),
        c(2.164371, 2.164371, 2.164371, 2.164371, 2.164371, 501.077303),
        tolerance = 1e-04)
    expect_equal(as.vector(a_min[5, seq_len(6)]),
        c(2.164371, 2.164371, 2.164371, 2.164371, 2.164371, 505.991601),
        tolerance = 1e-04)
    expect_equal(as.vector(a_mindet[1, seq_len(6)]),
        c(505.0606, 505.0606, 505.0606, 505.0606, 505.0606, 501.0773),
        tolerance = 1e-04)
    expect_equal(as.vector(a_mindet[5, seq_len(6)]),
        c(509.9465, 509.9465, 509.9465, 509.9465, 509.9465, 505.9916),
        tolerance = 1e-04)
    expect_equal(as.vector(a_minprob[1, seq_len(6)]),
        c(485.9080, 507.6398, 495.5805, 490.3416, 479.0684, 501.0773),
        tolerance = 1e-04)
    expect_equal(as.vector(a_minprob[5, seq_len(6)]),
        c(550.3846, 479.6420, 547.0334, 449.2677, 429.0399, 505.9916),
        tolerance = 1e-04)
    expect_equal(a_none, a)
})


