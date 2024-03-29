updateDragulaInputData <- function(data, geom_possible, session) {
  if (is.null(data)) {
    updateDragulaInput(
      session = session,
      inputId = "dragvars",
      status = NULL,
      choices = character(0),
      badge = FALSE
    )
  } else {
    # special case: geom_sf
    if (inherits(data, what = "sf")) {
      geom_possible$x <- c("sf", geom_possible$x)
    }
    
    var_choices <- get_col_names(data)
    
    updateDragulaInput(
      session = session,
      inputId = "dragvars",
      status = NULL,
      choiceValues = var_choices,
      choiceNames = badgeType(
        col_name = var_choices,
        col_type = col_type(data[, var_choices, drop = TRUE])
      ),
      badge = FALSE
    )
  }
  
}
#' @param data_rv A `reactiveValues` with at least a slot `data` containing a `data.frame`
#'  to use in the module. And a slot `name` corresponding to the name of the `data.frame`.
#' @param default_aes Default aesthetics to be used, can be a `character`
#'  vector or `reactive` function returning one.
#' @param import_from From where to import data, argument passed
#'  to \code{\link[datamods:import-modal]{datamods::import_ui}}.
#' @param data_modal logical, if FALSE, the data modal UI is never shown, if TRUE it's shown if data_rv$data is NULL at initialization
#' @param ... Additional arguments to controls_server
#'
#' @export
#'
#' @rdname esquisse-module
#' @order 2
#'
#' @importFrom shiny moduleServer reactiveValues observeEvent is.reactive
#'  renderPlot stopApp plotOutput showNotification isolate reactiveValuesToList
#' @importFrom ggplot2 ggplot_build ggsave %+%
#' @import ggplot2
#' @importFrom datamods import_modal import_server show_data
#' @importFrom rlang expr sym
esquisse_server <- function(id, 
                            data_rv = NULL,
                            default_aes = c("fill", "color", "size", "group", "facet"),
                            import_from = c("env", "file", "copypaste", "googlesheets"),
                            data_modal = TRUE,
                            hardcoded_dragula = NULL,
                            hardcoded_geom = NULL,
                            ...
                            ) {
  
  moduleServer(
    id = id,
    module = function(input, output, session) {
      ns <- session$ns
      globals <- reactiveValues(last_data = NULL, old_colnames = NULL, new_colnames = NULL, pop_etho_init = F, mapping = NULL, geom = NULL)
      ggplotCall <- reactiveValues(code = "")
      data_chart <- reactiveValues(data = NULL, name = NULL)
      
      # Settings modal (aesthetics choices)
      observeEvent(input$settings, {
        showModal(modal_settings(aesthetics = input$aesthetics))
      })
      
      
      geom <- reactive({
        if (!is.null(hardcoded_geom)) {
          hardcoded_geom
        } else {
          input$geom
        }
       })
      
      # Generate drag-and-drop input
      output$ui_aesthetics <- renderUI({
        if (is.reactive(default_aes)) {
          aesthetics <- default_aes()
        } else {
          if (is.null(input$aesthetics)) {
            aesthetics <- default_aes
          } else {
            aesthetics <- input$aesthetics
          }
        }
        data <- isolate(data_chart$data)
        if (!is.null(data)) {
          var_choices <- get_col_names(data)
          dragulaInput(
            inputId = ns("dragvars"),
            sourceLabel = "Variables",
            targetsLabels = c("X", "Y", aesthetics),
            targetsIds = c("xvar", "yvar", aesthetics),
            choiceValues = var_choices,
            choiceNames = badgeType(
              col_name = var_choices,
              col_type = col_type(data[, var_choices, drop = TRUE])
            ),
            selected = dropNulls(isolate(input$dragvars$target)),
            badge = FALSE,
            width = "100%",
            height = "70px",
            replace = TRUE
          )
        } else {
          dragulaInput(
            inputId = ns("dragvars"),
            sourceLabel = "Variables",
            targetsLabels = c("X", "Y", aesthetics),
            targetsIds = c("xvar", "yvar", aesthetics),
            choices = "",
            badge = FALSE,
            width = "100%",
            height = "70px",
            replace = TRUE
          )
        }
      })
      
      observeEvent(data_rv$data, {
        data_chart$data <- data_rv$data
        data_chart$name <- data_rv$name
      }, ignoreInit = FALSE)
      
      # Launch import modal if no data at start
      if (is.null(isolate(data_rv$data)) & data_modal) {
        datamods::import_modal(
          id = ns("import-data"),
          from = import_from,
          title = "Import data to create a graph"
        )
      }
      
      # Launch import modal if button clicked
      observeEvent(input$launch_import_data, {
        datamods::import_modal(
          id = ns("import-data"),
          from = import_from,
          title = "Import data to create a graph"
        )
      })
      
      # Data imported and update rv used
      data_imported_r <- datamods::import_server("import-data", return_class = "tbl_df")
      observeEvent(data_imported_r$data(), {
        data <- data_imported_r$data()
        data_chart$data <- data
        data_chart$name <- data_imported_r$name() %||% "imported_data"
      })
      
      observeEvent(input$show_data, {
        data <- controls_rv$data
        if (!is.data.frame(data)) {
          showNotification(
            ui = "No data to display",
            duration = 700,
            id = paste("esquisse", sample.int(1e6, 1), sep = "-"),
            type = "warning"
          )
        } else {
          datamods::show_data(data, title = "Dataset", type = "modal")
        }
      })
      
      # Update drag-and-drop input when data changes:
      # either the name
      # or the column names (because we need to show the updated list of column names)
      # in that case though I would like the selected mappings to stay
      observeEvent(c(data_chart$name, colnames(data_chart$data)), {
        data <- data_chart$data
        globals$old_colnames <<- globals$new_colnames
        globals$new_colnames <<- sort(colnames(data_chart$data))
        globals$mapping <<- input$dragvars$target
        globals$geom <<- input$dragvars$geom
        updateDragulaInputData(data, geom_possible, session)
      }, ignoreNULL= FALSE)
      
      geom_possible <- reactiveValues(x = "auto")
      geom_controls <- reactiveValues(x = "auto")
      observeEvent(list(input$dragvars$target, geom()), {
        geoms <- potential_geoms(
          data = data_chart$data,
          mapping = build_aes(
            data = data_chart$data,
            x = input$dragvars$target$xvar,
            y = input$dragvars$target$yvar
          )
        )
        geom_possible$x <- c("auto", geoms)
        
        geom_controls$x <- select_geom_controls(geom(), geoms)
        
        if (!is.null(input$dragvars$target$fill) | !is.null(input$dragvars$target$color)) {
          geom_controls$palette <- TRUE
        } else {
          geom_controls$palette <- FALSE
        }
      }, ignoreInit = TRUE)
      
      observeEvent(geom_possible$x, {
        geoms <- c(
          "auto", "line", "area", "bar", "histogram",
          "point", "boxplot", "violin", "density",
          "tile", "sf", "pop_etho", "tile_etho"
        )
        updateDropInput(
          session = session,
          inputId = "geom",
          selected = setdiff(geom_possible$x, "auto")[1],
          disabled = setdiff(geoms, geom_possible$x)
        )
      })
      
      # do this only if
      # * 1) the dragula inputs are empty (xvar, yvar, etc are empty)
      # * 2) the dragula inputs are loaded (the column names already show)
      # * 3) the data contains the passed hardcoded variables
      automatic_fill <- reactive({
        all(sapply(input$dragvars$target, is.null)) && !all("" == input$dragvars$source) && all(unlist(hardcoded_dragula$mapping) %in% colnames(data_chart$data))
      })
      
      observeEvent(automatic_fill(), {
        
        if (! is.null(hardcoded_dragula) && automatic_fill()) {

          # colnames_updated <- ! (all(globals$new_colnames %in% globals$old_colnames) & all(globals$old_colnames %in% globals$new_colnames))
          colnames_updated <- TRUE

            # if ("peak" %in% colnames(data_chart$data)) browser()

            toggleDragula(
              namespace = session$ns(""),
              mapping = hardcoded_dragula$mapping,
              geom = "auto"
            )
            updateShiny(
              namespace = session$ns(""),
              mapping = hardcoded_dragula$mapping,
              geom = hardcoded_dragula$geom
            )
        }
      }, ignoreInit = TRUE)
      
      observeEvent(input$dragvars$target, {
        
        if(all(sapply(input$dragvars$target, is.null))) {
        
          # if (colnames_updated & !is.null(globals$old_colnames) & all(unlist(globals$mapping) %in% colnames(data$data_chart))) {
          if (! all(is.null(unlist(globals$mapping))) & all(unlist(globals$mapping) %in% colnames(data_chart$data))) {
            
            toggleDragula(
              namespace = session$ns(""),
              mapping = globals$mapping,
              geom = globals$geom
            )
            updateShiny(
              namespace = session$ns(""),
              mapping = globals$mapping,
              geom = globals$geom
            )
          }
        }
      }, ignoreNULL = FALSE, priority = -1)
      
      
      # Module chart controls : title, xlabs, colors, export...
      # paramsChart <- reactiveValues(inputs = NULL)
      controls_rv <- controls_server(
        id = "controls",
        type = geom_controls,
        data_table = reactive(data_chart$data),
        data_name = reactive({
          req(data_chart$name)
          data_chart$name
        }),
        ggplot_rv = ggplotCall,
        aesthetics = reactive({
          dropNullsOrEmpty(input$dragvars$target)
        }),
        use_facet = reactive({
          !is.null(input$dragvars$target$facet) | !is.null(input$dragvars$target$facet_row) | !is.null(input$dragvars$target$facet_col)
        }),
        use_transX = reactive({
          if (is.null(input$dragvars$target$xvar))
            return(FALSE)
          identical(
            x = col_type(data_chart$data[[input$dragvars$target$xvar]]),
            y = "continuous"
          )
        }),
        use_transY = reactive({
          if (is.null(input$dragvars$target$yvar))
            return(FALSE)
          identical(
            x = col_type(data_chart$data[[input$dragvars$target$yvar]]),
            y = "continuous"
          )
        }),
        ...
      )
      
      
      render_ggplot("plooooooot", {
        req(data_chart$data)
        req(controls_rv$data)
        req(controls_rv$inputs)
        req(geom())
        
        aes_input <- make_aes(input$dragvars$target)
        
        req(unlist(aes_input) %in% names(data_chart$data))
        
        mapping <- build_aes(
          data = data_chart$data,
          .list = aes_input,
          geom = geom()
        )
        
        geoms <- potential_geoms(
          data = data_chart$data,
          mapping = mapping
        )
        req(geom() %in% geoms)
        
        data <- controls_rv$data
        
        scales <- which_pal_scale(
          mapping = mapping,
          palette = controls_rv$colors$colors,
          data = data,
          reverse = controls_rv$colors$reverse
        )
        
        if (identical(geom(), "auto")) {
          geom <- "blank"
        } else {
          geom <- geom()
        }
        
        observeEvent(geom(), {
          if(geom() == "pop_etho" & !globals$pop_etho_init) {
            # TODO
            # this works at the server side, but the UI stays showing the checkbox as false
            # the user can then activate it (with no effect) and disable it to reset it to normal
            controls_rv$ld_annotations$add <- T
            globals$pop_etho_init <- T
          }
        })
        
        geom_args <- match_geom_args(geom(), controls_rv$inputs, mapping = mapping)
        
        if(isTRUE(controls_rv$ld_annotations$add)) {
          geom <- c(geom, "ld_annotations")
          geom_args <- c(
            setNames(list(geom_args), geom()),
            list(ld_annotations = controls_rv$ld_annotations$args)
          )
        }
        if (isTRUE(controls_rv$smooth$add) & geom() %in% c("point", "line")) {
          geom <- c(geom, "smooth")
          geom_args <- c(
            setNames(list(geom_args), geom()),
            list(smooth = controls_rv$smooth$args)
          )
        }
        if (!is.null(aes_input$ymin) & !is.null(aes_input$ymax) & geom() %in% c("line")) {
          geom <- c("ribbon", geom)
          mapping_ribbon <- aes_input[c("ymin", "ymax")]
          geom_args <- c(
            list(ribbon = list(
              mapping = expr(aes(!!!syms2(mapping_ribbon))), 
              fill = controls_rv$inputs$color_ribbon
            )),
            setNames(list(geom_args), geom())
          )
          mapping$ymin <- NULL
          mapping$ymax <- NULL
        }
        
        scales_args <- scales$args
        scales <- scales$scales
        
        if (isTRUE(controls_rv$transX$use)) {
          scales <- c(scales, "x_continuous")
          scales_args <- c(scales_args, list(x_continuous = controls_rv$transX$args))
        }
        
        if (isTRUE(controls_rv$transY$use)) {
          scales <- c(scales, "y_continuous")
          scales_args <- c(scales_args, list(y_continuous = controls_rv$transY$args))
        }
        
        if (isTRUE(controls_rv$limits$x)) {
          xlim <- controls_rv$limits$xlim
        } else {
          xlim <- NULL
        }
        if (isTRUE(controls_rv$limits$y)) {
          ylim <- controls_rv$limits$ylim
        } else {
          ylim <- NULL
        }
        data_name <- data_chart$name %||% "data"
        gg_call <- ggcall(
          data = data_name,
          mapping = mapping,
          geom = geom,
          geom_args = geom_args,
          scales = scales,
          scales_args = scales_args,
          labs = controls_rv$labs,
          theme = controls_rv$theme$theme,
          theme_args = controls_rv$theme$args,
          coord = controls_rv$coord,
          facet = input$dragvars$target$facet,
          facet_row = input$dragvars$target$facet_row,
          facet_col = input$dragvars$target$facet_col,
          facet_args = controls_rv$facet,
          xlim = xlim,
          ylim = ylim
        )
        
        gg_call <- extend_gg_call(gg_call, ...)
 
        ggplotCall$code <- deparse2(gg_call)
        ggplotCall$call <- gg_call

        ggplotCall$ggobj <- safe_ggplot(
          expr = expr((!!gg_call) %+% !!sym("esquisse_data")),
          data = setNames(list(data, data), c("esquisse_data", data_chart$name))
        )
        ggplotCall$ggobj$plot
      }, filename = "esquisse-plot")
      
      
      # Close addin
      observeEvent(input$close, shiny::stopApp())
      
      # Ouput of module (if used in Shiny)
      output_module <- reactiveValues(code_plot = NULL, code_filters = NULL, data = NULL, time = NULL)
      observeEvent(ggplotCall$code, {
        output_module$code_plot <- ggplotCall$code
        output_module$time <- Sys.time()
      }, ignoreInit = TRUE)
      observeEvent(controls_rv$data, {
        output_module$code_filters <- controls_rv$code
        output_module$data <- controls_rv$data
        output_module$time <- Sys.time()
      }, ignoreInit = TRUE)
      
      return(output_module)
    }
  )
  
}
