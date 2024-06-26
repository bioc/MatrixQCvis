#' @importFrom ExperimentHub ExperimentHub
NULL

#' @name shinyQC
#'
#' @title Shiny application for initial QC exploration of -omics data sets
#'
#' @description
#' The shiny application allows to explore -omics
#' data sets especially with a focus on quality control. \code{shinyQC} gives
#' information on the type of samples included (if this was previously
#' specified within the \code{SummarizedExperiment} object). It gives 
#' information on the number of missing and measured values across features 
#' and across sets (e.g. quality control samples, control, and treatment 
#' groups, only displayed for \code{SummarizedExperiment} objects that 
#' contain missing values).
#'
#' \code{shinyQC} includes functionality to display (count/intensity) values 
#' across samples (to detect drifts in intensity values during the 
#' measurement), to display
#' mean-sd plots, MA plots, ECDF plots, and distance plots between samples.
#' \code{shinyQC} includes functionality to perform dimensionality reduction
#' (currently limited to PCA, PCoA, NMDS, tSNE, and UMAP). Additionally,
#' it includes functionality to perform differential expression analysis
#' (currently limited to moderated t-tests and the Wald test).
#'
#' @details 
#' \code{rownames(se)} should be set to the corresponding name of features, 
#' while \code{colnames(se)} should be set to the sample IDs. 
#' \code{rownames(se)} and \code{colnames(se)} are not allowed to be NULL.
#' \code{colnames(se)}, \code{colnames(assay(se))} and 
#' \code{rownames(colData(se))} all have to be identical.
#' 
#' \code{shinyQC} allows to subset the supplied \code{SummarizedExperiment} object. 
#' 
#' On exit of the shiny application, the (subsetted) \code{SummarizedExperiment} 
#' object is returned with information on the processing steps (normalization, 
#' transformation, batch correction and imputation). The object will 
#' only returned if \code{app_server = FALSE} and if the function call is assigned
#' to an object, e.g. \code{tmp <- shinyQC(se)}. 
#' 
#' If the \code{se} argument is omitted the app will load an interface that allows 
#' for data upload.
#'
#' @param se \code{SummarizedExperiment} object (can be omitted)
#' @param app_server \code{logical} (set to \code{TRUE} if run under a server 
#' environment)
#'
#' @importFrom shiny div fluidRow uiOutput insertTab runApp shinyUI tabsetPanel
#' @importFrom shinydashboard dashboardPage dashboardHeader dashboardSidebar
#' @importFrom shiny tags
#' @importFrom shinyjs useShinyjs hidden show
#' @importFrom SummarizedExperiment assay colData SummarizedExperiment
#' @importFrom methods is 
#'
#' @examples 
#' library(dplyr)
#' library(SummarizedExperiment)
#' 
#' ## create se
#' set.seed(1)
#' a <- matrix(rnorm(100, mean = 10, sd = 2), nrow = 10, ncol = 10, 
#'             dimnames = list(seq_len(10), paste("sample", seq_len(10))))
#' a[c(1, 5, 8), seq_len(5)] <- NA
#' cD <- data.frame(name = colnames(a), type = c(rep("1", 5), rep("2", 5)))
#' rD <- data.frame(spectra = rownames(a))
#' se <- SummarizedExperiment(assay = a, rowData = rD, colData = cD)
#' 
#' \donttest{shinyQC(se)}
#' 
#' @author Thomas Naake
#' 
#' @return \code{shiny} application, 
#' \code{SummarizedExperiment} upon exiting the \code{shiny} application
#'
#' @export
shinyQC <- function(se, app_server = FALSE) {

    has_se <- !missing(se)
    if (has_se) {
        if (!is(se, "SummarizedExperiment")) 
            stop("se is not of class 'SummarizedExperiment'")
        if (is.null(rownames(se))) 
            stop("rownames(se) is NULL")
        if (is.null(colnames(se)))
            stop("colnames(se) is NULL")

        ## access the assay slot
        a <- SummarizedExperiment::assay(se)

        ## access the colData slot and check for integrity of colnames/rownames
        cD <- se@colData |> as.data.frame()
        if (!all(colnames(se) == rownames(cD)))
            stop("colnames(se) do not match rownames(colData(se))")
        if (!all(colnames(a) == rownames(cD)))
            stop("colnames(assay(se)) do not match rownames(colData(se))")

        ## retrieve the names of assays(se) and return a character for 
        ## choices in the selectInput UI that allows for switching between 
        ## the different assays
        choicesAssaySE <- choiceAssaySE(se)
    } else {
        choicesAssaySE <- NULL
        se <- NULL
    }

    ## create environment to store the modified SummarizedExperiment object 
    ## into, on exiting the shiny application return the object stored in
    ## env_se$se_return (this will be NULL in case there was no 
    ## SummarizedExperiment loaded yet or a modified version of the 
    ## SummarizedExperiment depending on the user input in the shiny 
    ## environment)
    env_se <- new.env(parent = emptyenv())
    env_se$se_return <- NULL
    
    on.exit(expr = if (!app_server) {
        return(invisible(env_se$se_return))
    })
    
    ## define the values of the host, set to 0.0.0.0 in the server mode, that 
    ## other clients can connect to the host, otherwise set to localhost 
    if (app_server) {
        host <- getOption("shiny.host", "0.0.0.0")
    } else {
        host <- getOption("shiny.host", "127.0.0.1")
    }

    ## assign function for landing page
    landingPage = createLandingPage()
    
    ## define UI
    ui <- shiny::shinyUI(shinydashboard::dashboardPage(skin = "black",
        shinydashboard::dashboardHeader(title = "MatrixQCvis"),
        shinydashboard::dashboardSidebar(
            #fileInput("upload", "Upload...")
            ## Sidebar with a slider input
            shinyjs::useShinyjs(debug = TRUE),
            shinyjs::hidden(
                shiny::div(id = "sidebarPanelSE",
                    tag_loadMessage(),
                    tag_keepAlive(),
                    ## sidebar for tabs 'Values' and 'Dimension Reduction'
                    ## for normalizing, transforming, batch correcting and 
                    ## imputing data
                    sidebar_assayUI(),
                    sidebar_imputationUI(),
                    ## create sidebar for tab 'DE' (input for model 
                    ## matrix/contrasts) sidebar_UI()
                    sidebar_DEUI(), 
                    ## sidebar for excluding samples from se_r and generating 
                    ## report
                    sidebar_excludeSampleUI(id = "select"), 
                    sidebar_reportUI(),
                    ## sidebar for selecting assay in multi-assay 
                    ## SummarizedExperiment
                    sidebar_selectAssayUI(choicesAssaySE = choicesAssaySE)
            ))
        ),

        shinydashboard::dashboardBody(shiny::fluidRow(
            shiny::tags$head( 
                shiny::tags$script(
                    type="text/javascript",'$(document).ready(function(){
                    $(".main-sidebar").css("height","100%");
                    $(".main-sidebar .sidebar").css({"position":"relative","max-height": "100%","overflow": "auto"})
                    })')),
            shinyjs::useShinyjs(debug = TRUE),
            shinyjs::hidden(
                shiny::div(id = "tabPanelSE",
                    shiny::tabsetPanel(type = "tabs",
                        ## tabPanel for tab "Samples"
                        tP_samples_all(),
                        ## tabPanel for tab "Values"
                        tP_values_all(),
                        ## tabPanel for tab "Dimension Reduction"
                        tP_dimensionReduction_all(),
                        ## tabPanel for tab "DE"
                        tP_DE_all(),
                    id = "tabs") ## end tabsetPanel
                )
            )
        ),
        shiny::div(id = "uploadSE", 
            shiny::uiOutput("allPanels")
        )
    )))

    ## define server function
    server <- function(input, output, session) {

        if (!has_se) {
            FUN <- function(SE, MISSINGVALUE) {
                .initialize_server(se = SE, input = input, output = output, 
                    session = session, missingValue = MISSINGVALUE, 
                    envir = env_se)
            }
            landingPage(FUN, input = input, output = output, session = session, 
                app_server = app_server)
        } else {
            missingValue <- missingValuesSE(se)
            ## tabPanel for tab "Measured Values"
            if (missingValue) shiny::insertTab(inputId = "tabs", 
                tP_measuredValues_all(), target = "Samples", position = "after")
            ## tabPanel for tab "Missing Values"
            if (missingValue) shiny::insertTab(inputId = "tabs", 
                tP_missingValues_all(), target = "Measured Values", 
                position = "after")
            shinyjs::show("tabPanelSE")
            shinyjs::show("sidebarPanelSE")
            .initialize_server(se = se, input = input, output = output, 
                session = session, missingValue = missingValue,
                envir = env_se)
        }
        
    } ## end of server

    
    ## run the app
    app <- list(ui = ui, server = server)
    
    shiny::runApp(app, host = host, launch.browser = !app_server, port = 3838)
}

#' @name .initialize_server
#' 
#' @title Server initialization of \code{shinyQC}
#' 
#' @description 
#' The function \code{.initialize_server} defines most of the server function in 
#' \code{shinyQC}. Within the server function of \code{shinyQC}, 
#' \code{.initialize_server} is called in different context depending if 
#' the \code{se} was assigned or not. 
#' 
#' @param se \code{SummarizedExperiment}
#' @param input \code{shiny} input object
#' @param output \code{shiny} output object
#' @param session \code{shiny} session object
#' @param missingValue \code{logical}, specifying if the 
#' \code{SummarizedExperiment} 
#' object contains missing values in the assay slot
#' @param envir \code{environment}, \code{environment} to store the modified 
#' \code{SummarizedExperiment} object into
#'
#' @return 
#' Observers and reactive server expressions for all app elements
#' 
#' @importFrom SummarizedExperiment assays `metadata<-`
#' @importFrom rmarkdown render
#' @importFrom shinyhelper observe_helpers
#' @importFrom shiny renderText req outputOptions reactive observe sliderInput
#' @importFrom shiny updateCheckboxInput updateSelectInput observeEvent 
#' @importFrom shiny showModal modalDialog withProgress downloadHandler
#' @importFrom shiny reactiveValues bindCache
#' 
#' @author Thomas Naake
#' 
#' @noRd
.initialize_server <- function(se, input, output, session, 
                                    missingValue = TRUE, envir = new.env()) {
    
    if (!is.logical(missingValue)) stop("missingValue has to be logical")
    if (!is(envir, "environment")) stop("envir has to be of class environment")

    output$keepAlive <- shiny::renderText({
        shiny::req(input$keepAlive)
        paste("keep alive", input$keepAlive)
    })

    output$missingVals <- shiny::renderText({missingValue})
    shiny::outputOptions(output, "missingVals", suspendWhenHidden = FALSE)

    ## create server to select assay in multi-assay se
    output$lengthAssays <- shiny::renderText({
        if (length(SummarizedExperiment::assays(se)) > 1) {
            "TRUE"
        } else {
            "FALSE"
        }
    })
    
    ## set suspendWhenHidden to FALSE to retrieve lengthAssays
    ## even if it is not called explicitly (e.g. by renderText)
    shiny::outputOptions(output, "lengthAssays", suspendWhenHidden = FALSE)
    
    se_sel <- selectAssayServer("select", se = se, 
        selected = shiny::reactive(input$assaySelected))
    
    se_feat <- shiny::reactive({
        selectFeatureSE(se_sel(), 
            selection = input[["features-excludeFeature"]], 
            mode = input[["features-mode"]])
    })
    
    sidebar_excludeSampleServer("select", se = se)
    
    ## uses 'helpfiles' directory by default
    ## we use the withMathJax parameter to render formulae
    shinyhelper::observe_helpers(withMathJax = TRUE,
        help_dir = paste(find.package("MatrixQCvis"), "helpfiles", sep = "/"))
    
    ## create reactive SummarizedExperiment objects for raw, normalized, 
    ## transformed and imputed data
    se_r <- shiny::reactive({selectSampleSE(se = se_feat(), 
        selection = input[["select-excludeSamples"]], 
        mode = input[["select-mode"]])})
    
    ## TAB: Samples
    ## barplot about number for sample type
    histSampleServer("Sample_hist", se = se_r)
    mosaicSampleServer("Sample_mosaic", se = se_r)
    
    ## TAB: Measured values and Missing values
    ## barplot number of measured/missing features per sample
    samplesMeasuredMissingTbl <- sampleMeasuredMissingServer("MeMiTbl", 
                                                            se = se_r)
    barplotMeasuredMissingSampleServer(id = "MeV_number", 
        samplesMeasuredMissing = samplesMeasuredMissingTbl, measured = TRUE)
    barplotMeasuredMissingSampleServer(id = "MiV_number", 
        samplesMeasuredMissing = samplesMeasuredMissingTbl, measured = FALSE)
    
    ## sync input[["MeV-categoryHist"]] with input[["MeV-categoryUpSet"]]
    shiny::observe({
        input[["MeV-categoryHist"]]
        ## update upon change of MeV-categoryHist MeV-categoryUpSet to the
        ## value of MeV-categoryHist
        shiny::updateCheckboxInput(session, "MeV-categoryUpSet", NULL, 
            input[["MeV-categoryHist"]])
    })
    shiny::observe({
        input[["MeV-categoryUpSet"]]
        ## update upon change of MeV-categoryUpSet MeV-categoryHist to the
        ## value of MeV-categoryUpSet
        shiny::updateCheckboxInput(session, "MeV-categoryHist", NULL, 
            input[["MeV-categoryUpSet"]])
    })
    
    ## sync input[["MiV-categoryHist"]] with input[["MiV-categoryUpSet"]]
    shiny::observe({
        input[["MiV-categoryHist"]]
        ## update upon change of MiV-categoryHist MiV-categoryUpSet to the
        ## value of MiV-categoryHist
        shiny::updateCheckboxInput(session, "MiV-categoryUpSet", NULL, 
            input[["MiV-categoryHist"]])
    })
    shiny::observe({
        input[["MiV-categoryUpSet"]]
        ## update upon change of MiV-categoryUpSet MiV-categoryHist to the
        ## value of MiV-categoryUpSet
        shiny::updateCheckboxInput(session, "MiV-categoryHist", NULL, 
            input[["MiV-categoryUpSet"]])
    })
    
    ## tab: Histogram Features
    ## histogram for measured values across samples per feature
    histFeatServer("MeV", se = se_r, assay = a, measured = TRUE)
    histFeatServer("MiV", se = se_r, assay = a, measured = FALSE)
    
    ## tab: Histogram Features along variable (e.g. sample type)
    histFeatCategoryServer("MeV", se = se_r, measured = TRUE)
    histFeatCategoryServer("MiV", se = se_r, measured = FALSE)
    
    ## tab: UpSet (UpSet plot with set of measured features)
    upSetServer("MeV", se = se_r, measured = TRUE)
    upSetServer("MiV", se = se_r, measured = FALSE)
    
    ## tab: Sets
    setsServer("MeV", se = se_r, measured = TRUE)
    setsServer("MiV", se = se_r, measured = FALSE)
    
    ## TAB: Values and Dimension reduction plots
    
    ## observe expression: update UI on loading the app
    shiny::observe({
        ## update the batchCol selectInput menu to select the variable for
        ## batch correction
        cols_cD <- colnames(se@colData)
        shiny::updateSelectInput(session = session, inputId = "batchCol", 
            choices = cols_cD)
        shiny::updateSelectInput(session = session, inputId = "groupDist", 
            choices = cols_cD)
    })
    
    ## create reactive for assay slot
    a <- shiny::reactive({
        se_r() |>
            assay() |>
            as.matrix()
    })
    
    ## reactive expression for data transformation, returns a matrix with
    ## normalized values
    a_n <- shiny::reactive({
        #shiny::req(a(), input$normalization)
        ## input$normalization is either "none", "sum", "quantile division",
        ## "quantile"
        normalizeAssay(a(), method = input$normalization, 
            probs = input$quantile, multiplyByNormalizationValue = TRUE)
    })
    
    ## create SummarizedExperiment objects with updated assays
    se_r_n <- shiny::reactive({updateSE(se = se_r(), assay = a_n())})
    
    ## reactive expression for data batch correction, returns a matrix with
    ## batch-corrected values
    a_b <- shiny::reactive({
        batchCorrectionAssay(se_r_n(), method = input$batch, 
            batch = input$batchCol)
    })
    
    shiny::observeEvent({shiny::req(input$batch); input$batch}, {
        if (input$tabs == "Values" & input$batch != "none") {
            shiny::showModal(shiny::modalDialog(
                "It seems you have applied a batch correction method in the 'Values' tab.",
                "Please make sure to assess the existence and strength of the batch effect before and after applying the batch correction method.",
                "The most informative plots are the dimension reduction plots.",
                title = "Attention!", easyClose = TRUE))
        }
    })
    
    ## reactive expression for data transformation, returns a matrix with
    ## transformed values
    a_t <- shiny::reactive({
        ## input$transformation is either "none", "log", "log2", "log10",
        ## or "vsn"
        transformAssay(a_b(), method = input$transformation)
    })
    
    ## reactive expression for data imputation, returns a matrix with
    ## imputed values
    a_i <- shiny::reactive({
        if (missingValue) {
            ## impute missing values of the data.frame with transformed values
            imputeAssay(a_t(), input$imputation)    
        } else {
            a_t()
        }
    })
    
    ## create SummarizedExperiment objects with updated assays
    ##se_r_n <- shiny::reactive({updateSE(se = se_r(), assay = a_n())})
    se_r_b <- shiny::reactive({updateSE(se = se_r(), assay = a_b())})
    se_r_t <- shiny::reactive({updateSE(se = se_r(), assay = a_t())})
    se_r_i <- shiny::reactive({updateSE(se = se_r(), assay = a_i())})
    
    ## TAB: Values
    ## boxplots
    boxPlotUIServer("boxUI", se = se)
    boxPlotServer("boxRaw", se = se_r,
        orderCategory = shiny::reactive(input[["boxUI-orderCategory"]]),
        boxLog = shiny::reactive(input$boxLog),
        violin = shiny::reactive(input$violinPlot), type = "raw")
    boxPlotServer("boxNorm", se = se_r_n,
        orderCategory = shiny::reactive(input[["boxUI-orderCategory"]]),
        boxLog = shiny::reactive(input$boxLog),
        violin = shiny::reactive(input$violinPlot), type = "normalized")
    boxPlotServer("boxBatch", se = se_r_b,
        orderCategory = shiny::reactive(input[["boxUI-orderCategory"]]),
        boxLog = shiny::reactive(input$boxLog),
        violin = shiny::reactive(input$violinPlot), type = "batch corrected")
    boxPlotServer("boxTransf", se = se_r_t,
        orderCategory = shiny::reactive(input[["boxUI-orderCategory"]]),
        boxLog = function() FALSE,
        violin = shiny::reactive(input$violinPlot), type = "transformed")
    boxPlotServer("boxImp", se = se_r_i,
        orderCategory = shiny::reactive(input[["boxUI-orderCategory"]]),
        boxLog = function() FALSE,
        violin = shiny::reactive(input$violinPlot), type = "imputed")
        
    ## drift
    driftServer("drift", se = se_r, se_n = se_r_n, se_b = se_r_b,
        se_t = se_r_t, se_i = se_r_i, missingValue = missingValue)
    
    ## coefficient of variation
    cvServer(id = "cv", a_r = a, a_n = a_n, a_b = a_b, a_t = a_t, a_i = a_i,
        missingValue = missingValue)
    
    ## mean-sd plot
    meanSdServer(id = "meanSdTransf", assay = a_t, type = "transformed")
    meanSdServer(id = "meanSdImp", assay = a_i, type = "imputed")
    
    ## MA plot
    maServer(id = "MA", se = se_r, se_n = se_r_n, se_b = se_r_b, se_t = se_r_t,
        se_i = se_r_i, innerWidth = shiny::reactive(input$innerWidth),
        missingValue = missingValue)
    
    ## ECDF
    ECDFServer("ECDF", se = se_r, se_n = se_r_n, se_b = se_r_b, 
        se_t = se_r_t, se_i = se_r_i, missingValue = missingValue)
    
    ## distances
    distServer("distRaw", se = se_r, assay = a,
        method = shiny::reactive(input$methodDistMat), 
        label = shiny::reactive(input$groupDist), type = "raw")
    distServer("distNorm", se = se_r, assay = a_n,
        method = shiny::reactive(input$methodDistMat), 
        label = shiny::reactive(input$groupDist), type = "normalized")
    distServer("distBatch", se = se_r, assay = a_b,
        method = shiny::reactive(input$methodDistMat), 
        label = shiny::reactive(input$groupDist), type = "batch corrected")
    distServer("distTransf", se = se_r, assay = a_t, 
        method = shiny::reactive(input$methodDistMat),
        label = shiny::reactive(input$groupDist), type = "transformed")
    distServer("distImp", se = se_r, assay = a_i,
        method = shiny::reactive(input$methodDistMat),
        label = shiny::reactive(input$groupDist), type = "imputed")
    
    ## Features
    featureServer("features", se = se, a = a, a_n = a_n, a_b = a_b, a_t = a_t,
        a_i = a_i, missingValue = missingValue)
    
    ## TAB: Dimension reduction
    ## observe handlers to sync "scale" and "center" between the 'PCA' and
    ## 'tSNE' tab within the 'Dimension reduction' tab
    shiny::observe({
        input[["PCA-scale"]]
        ## update upon change of PCA-scale tSNE-scale to the value of
        ## PCA-scale
        shiny::updateCheckboxInput(session, "tSNE-scale", NULL,
                                                        input[["PCA-scale"]])
    })
    shiny::observe({
        input[["tSNE-scale"]]
        ## update upon change of tSNE-scale PCA-scale to the value of
        ## tSNE-scale
        shiny::updateCheckboxInput(session, "PCA-scale", NULL,
                                                        input[["tSNE-scale"]])
    })
    observe({
        input[["PCA-center"]]
        ## update upon change of PCA-center tSNE-center to the value of
        ## PCA-center
        shiny::updateCheckboxInput(session, "tSNE-center", NULL,
                                                        input[["PCA-center"]])
    })
    shiny::observe({
        input[["tSNE-center"]]
        ## update upon change of tSNE-center PCA-center to the value of
        ## tSNE-center
        shiny::updateCheckboxInput(session, "PCA-center", NULL,
                                                        input[["tSNE-center"]])
    })

    ## observe handlers to sync "distance" method between the 'PCoA' and
    ## 'NMDS' tab within the 'Dimension reduction' tab
    shiny::observe({
        input[["PCoA-dist"]]
        ## update upon change of PCoA-dist NMDS-dist to the value of
        ## PCoA-dist
        shiny::updateCheckboxInput(session, "NMDS-dist", NULL,
                                                        input[["PCoA-dist"]])
    })
    shiny::observe({
        input[["NMDS-dist"]]
        ## update upon change of NMDS-dist PCoA-dist to the value of NMDS-dist
        shiny::updateCheckboxInput(session, "PCoA-dist", NULL,
                                                        input[["NMDS-dist"]])
    })

    ## create reactive values that stores the parameters for the dimension
    ## reduction plots
    params <- shiny::reactiveValues(
        "center" = TRUE, "scale" = FALSE, ## for PCA
        "method" = "euclidean", ## for PCoA and NMDS
        "perplexity" = 1, "max_iter" = 1000, "initial_dims" = 10, ## for tSNE
        "dims" = 3, "pca_center" = TRUE, "pca_scale" = FALSE, ## for tSNE
        "min_dist" = 0.1, "n_neighbors" = 15, "spread" = 1) ## for UMAP

    ## change the reactive values upon the user input changes
    shiny::observe({
        params$center <- input[["PCA-center"]]
        params$scale <- input[["PCA-scale"]]
        params$method <- input[["PCoA-dist"]]
        params$perplexity <- input[["tSNE-perplexity"]]
        params$max_iter <- input[["tSNE-maxIter"]]
        params$initial_dims <- input[["tSNE-initialDims"]]
        params$dims <- input[["tSNE-dims"]]
        params$pca_center <- input[["PCA-center"]]
        params$pca_scale <- input[["PCA-scale"]]
        params$min_dist <- input[["UMAP-minDist"]]
        params$n_neighbors <- input[["UMAP-nNeighbors"]]
        params$spread <- input[["UMAP-spread"]]
    })

    ## server modules for the dimensional reduction plots
    sample_n <- reactive({ncol(se_r())})

    dimRedServer(id = "PCA", se = se_r, assay = a_i, type = "PCA",
        label = "PC", params = shiny::reactive(params),
        innerWidth = shiny::reactive(input$innerWidth), 
        selectedTab = shiny::reactive(input$dimensionReductionTab))
    dimRedServer(id = "PCoA", se = se_r, assay = a_i, type = "PCoA",
        label = "axis", params = shiny::reactive(params),
        innerWidth = shiny::reactive(input$innerWidth), 
        selectedTab = shiny::reactive(input$dimensionReductionTab))
    dimRedServer(id = "NMDS", se = se_r, assay = a_i, type = "NMDS",
        label = "MDS", params = shiny::reactive(params),
        innerWidth = shiny::reactive(input$innerWidth), 
        selectedTab = shiny::reactive(input$dimensionReductionTab))
    dimRedServer(id = "tSNE", se = se_r, assay = a_i, type = "tSNE",
        label = "dimension", params = shiny::reactive(params),
        innerWidth = shiny::reactive(input$innerWidth),
        selectedTab = shiny::reactive(input$dimensionReductionTab))
    tSNEUIServer(id = "tSNE", sample_n = sample_n)
    dimRedServer(id = "UMAP", se = se_r, assay = a_i, type = "UMAP",
        label = "axis", params = shiny::reactive(params),
        innerWidth = shiny::reactive(input$innerWidth),
        selectedTab = shiny::reactive(input$dimensionReductionTab))
    umapUIServer(id = "UMAP", sample_n = sample_n)
 
    ## run additional server modules for the scree plots (only for the
    ## tabs 'PCA' and 'tSNE') and loading plot
    screePlotServer("PCA", assay = a_i,
        center = shiny::reactive(input[["PCA-center"]]),
        scale = shiny::reactive(input[["PCA-scale"]]))
    loadingsPlotServer("PCA", assay = a_i, params = shiny::reactive(params))
    screePlotServer("tSNE", assay = a_i,
        center = shiny::reactive(input[["tSNE-center"]]),
        scale = shiny::reactive(input[["tSNE-scale"]]))

    ## TAB: Differential Expression (DE)
    ## create data.frame with colData of the supplied se
    colDataServer("colData", se = se_r)
    
    ## check if the supplied formula (input$modelMat) is valid and return
    ## NULL if otherwise
    validFormulaMM <- validFormulaMMServer("modelMatrix", 
        expr = shiny::reactive(input$modelMat), 
        action = shiny::reactive(input$actionModelMat), se = se_r)
    
    ## create the matrix of the Model Matrix using the validFormulaMM
    modelMatrix <- modelMatrixServer("modelMatrix", se = se_r, 
        validFormulaMM = validFormulaMM)
    
    ## create the data.frame of the Model Matrix to display
    modelMatrixUIServer("modelMatrix", modelMatrix = modelMatrix, 
        validFormulaMM = validFormulaMM)
    
    ## check if the supplied formula/expr (input$contrastMat) is vald and 
    ## return NULL if otherwise
    validExprContrast <- validExprContrastServer("contrast", 
        expr = shiny::reactive(input$contrastMat), 
        action = shiny::reactive(input$actionContrasts), modelMatrix = modelMatrix)
    
    ## create the matrix of the Contrast Matrix using the validExprContrast
    contrastMatrix <- contrastMatrixServer("contrast", 
        validExprContrast = validExprContrast, modelMatrix = modelMatrix)
    
    ## create the data.frame of the Contrast Matrix to display
    contrastMatrixUIServer("contrast", validFormulaMM = validFormulaMM, 
        validExprContrast = validExprContrast, contrastMatrix = contrastMatrix)
    
    ## calculate the fit and test results with eBayes (ttest) and 
    ## proDA, cache the results for proDA since it is computationally
    ## expensive
    fit_ttest <- fitServer("ttest", assay = a_i, 
        modelMatrix = modelMatrix,
        contrastMatrix = contrastMatrix)
    
    fit_proDA <- fitServer("proDA", assay = a_t,
            modelMatrix = modelMatrix,
            contrastMatrix = contrastMatrix) |>
        shiny::bindCache(a_t(), modelMatrix(), contrastMatrix(), 
                                                            cache = "session")
    
    ## create data.frame with the test results
    testResult <- testResultServer("testServer", 
        type = shiny::reactive(input$DEtype), fit_ttest = fit_ttest, 
        fit_proDA = fit_proDA, validFormulaMM = validFormulaMM, 
        validExprContrast = validExprContrast)
    
    
    ## display the test results
    topDEUIServer("topDE", type = shiny::reactive(input$DEtype),
        validFormulaMM = validFormulaMM, 
        validExprContrast = validExprContrast, testResult = testResult)
    
    ## create Volcano plot
    volcanoUIServer("volcano", type = shiny::reactive(input$DEtype),
        validFormulaMM = validFormulaMM,
        validExprContrast = validExprContrast, testResult = testResult)
    
    ## observer for creating the report
    output$report <- shiny::downloadHandler(
        filename = "report_qc.html",
        content = function(file) {
            shiny::withProgress(message = "Rendering, please wait!", {
                rep_tmp <- paste(find.package("MatrixQCvis"), 
                    "report/report_qc.Rmd", sep = "/")

                params_l = list(
                    missingValue = missingValue,
                    se_r = se_r(), se_n = se_r_n(), se_b = se_r_b(), 
                    se_t = se_r_t(), se_i = se_r_i(),
                    sample_hist = input[["Sample_hist-typeHist"]],
                    sample_mosaic_f1 = input[["Sample_mosaic-mosaicf1"]],
                    sample_mosaic_f2 = input[["Sample_mosaic-mosaicf2"]])
                
                if (missingValue) {
                    params_l <- append(params_l, 
                        list(mev_binwidth = input[["MeV-binwidth"]],
                            mev_binwidthC = input[["MeV-binwidthC"]],
                            mev_hist_category = input[["MeV-categoryHist"]],
                            mev_upset_category = input[["MeV-categoryUpset"]],
                            miv_binwidth = input[["MiV-binwidth"]],
                            miv_binwidthC = input[["MiV-binwidthC"]],
                            miv_hist_category = input[["MiV-categoryHist"]],
                            miv_upset_category = input[["MiV-categoryUpSet"]]))
                } else {
                    params_l <- append(params_l, 
                        list(mev_binwidth = 1, mev_binwidthC = 1,
                            mev_hist_category = NULL, mev_upset_category = NULL,
                            miv_binwidth = 1, miv_binwidthC = 1,
                            miv_hist_category = NULL, 
                            miv_upset_category = NULL))
                }
                params_l <- append(params_l,
                    list(int_log = input[["boxLog"]], 
                        int_violin = input[["violinPlot"]],
                        int_violin_orderCategory = input[["boxUI-orderCategory"]],
                        int_drift_data = input[["drift-data"]],
                        int_drift_aggregation = input[["drift-aggregation"]],
                        int_drift_category = input[["drift-category"]],
                        int_drift_orderCategory = input[["drift-orderCategory"]],
                        int_drift_level = input[["drift-levelSel"]],
                        int_drift_method = input[["drift-method"]],
                        int_ma_data = input[["MA-MAtype"]],
                        int_ma_group = input[["MA-groupMA"]],
                        int_ma_plot = input[["MA-plotMA"]],
                        int_hD_lines = input[["hDLines"]],
                        int_ecdf_data = input[["ECDF-ECDFtype"]],
                        int_ecdf_sample = input[["ECDF-sampleECDF"]],
                        int_ecdf_group = input[["ECDF-groupECDF"]],
                        int_dist_method = input[["methodDistMat"]],
                        int_dist_label = input[["groupDist"]],
                        int_feat_selectFeat = input[["features-selectFeature"]],
                        int_feat_featLine = input[["features-FeatureLines"]],
                        dr_pca_center = params$center,
                        dr_pca_scale = params$scale,
                        dr_pca_color = input[["PCA-color"]],
                        dr_pca_x = input[["PCA-x"]], 
                        dr_pca_y = input[["PCA-y"]],
                        dr_pcoa_method = params$method,
                        dr_pcoa_color = input[["PCoA-color"]],
                        dr_pcoa_x = input[["PCoA-x"]], 
                        dr_pcoa_y = input[["PCoA-y"]],
                        dr_nmds_color = input[["NMDS-color"]],
                        dr_nmds_x = input[["NMDS-x"]], 
                        dr_nmds_y = input[["NMDS-y"]],
                        dr_tsne_perplexity = params$perplexity,
                        dr_tsne_max_iter = params$max_iter,
                        dr_tsne_initial_dims = params$initial_dims,
                        dr_tsne_dims = params$dims,
                        dr_tsne_pca_center = params$pca_center,
                        dr_tsne_pca_scale = params$pca_scale,
                        dr_tsne_color = input[["tSNE-color"]],
                        dr_tsne_x = input[["tSNE-x"]], 
                        dr_tsne_y = input[["tSNE-y"]],
                        dr_umap_min_dist = params$min_dist,
                        dr_umap_n_neighbors = params$n_neighbors,
                        dr_umap_spread = params$spread,
                        dr_umap_color = input[["UMAP-color"]],
                        dr_umap_x = input[["UMAP-x"]], 
                        dr_umap_y = input[["UMAP-y"]],
                        de_m_formula = validFormulaMM(),
                        de_c_formula = validExprContrast,
                        de_method = input[["DEtype"]],
                        de_fit_ttest = fit_ttest(),
                        de_fit_proDA = fit_proDA()
                    )
                )
                
                rmarkdown::render(input = rep_tmp, output_file = file, 
                    params = params_l, envir = new.env(parent=globalenv()))
            })
        }
    )

    ## assign the se_r_i SummarizedExperiment to the environment envir
    ## (this object will be returned when exiting shinyQC)
    observe({
        se <- se_r_i()
        se@metadata <- list(
            "normalized" = input$normalization,
            "batch corrected" = input$batch,
            "transformation" = input$transformation)

        if (missingValue) {
            se@metadata[["imputation"]] <- input$imputation
        }
        assign("se_return", se, envir = envir)
        
    })
}
