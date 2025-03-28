#' Create a DuckDB-powered interactive visualization using native DuckDB
#'
#' This function creates an interactive visualization using native DuckDB and JavaScript
#' for efficient rendering of large datasets.
#'
#' @param data A data frame or tibble containing the data to visualize
#' @param x_col Column name for x-axis
#' @param y_col Column name for y-axis
#' @param color_col Optional column name for coloring points
#' @param width Width of the visualization in pixels
#' @param height Height of the visualization in pixels
#' @param use_native_duckdb Whether to use native DuckDB (TRUE) or DuckDB-Wasm (FALSE)
#' @param port Port number for the WebSocket server when using native DuckDB
#' @param launch Whether to launch the visualization immediately
#'
#' @return A Shiny app object
#' @export
duckdb_viz <- function(data, 
                       x_col, 
                       y_col, 
                       color_col = NULL,
                       width = NULL, 
                       height = NULL,
                       use_native_duckdb = TRUE,
                       port = 8000,
                       launch = TRUE) {
  
  # Check for required packages
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("Package 'shiny' is needed for this function to work. Please install it.",
         call. = FALSE)
  }
  if (!requireNamespace("htmltools", quietly = TRUE)) {
    stop("Package 'htmltools' is needed for this function to work. Please install it.",
         call. = FALSE)
  }
  if (use_native_duckdb && !requireNamespace("httpuv", quietly = TRUE)) {
    stop("Package 'httpuv' is needed for native DuckDB mode. Please install it.",
         call. = FALSE)
  }
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("Package 'arrow' is needed for this function to work. Please install it.",
         call. = FALSE)
  }
  
  # Prepare the data
  if (is.null(data$index)) {
    data$index <- seq_len(nrow(data))
  }
  
  # Rename columns to match expected format
  data_viz <- data
  names(data_viz)[names(data_viz) == x_col] <- "array_col"
  names(data_viz)[names(data_viz) == y_col] <- "array_row"
  
  # Handle color column
  if (!is.null(color_col)) {
    names(data_viz)[names(data_viz) == color_col] <- "in_tissue"
  } else if (!"in_tissue" %in% names(data_viz)) {
    # If no color column provided and no in_tissue column exists, add a default
    data_viz$in_tissue <- TRUE
  }
  
  # Ensure required columns exist
  required_cols <- c("index", "array_col", "array_row", "in_tissue")
  missing_cols <- setdiff(required_cols, names(data_viz))
  if (length(missing_cols) > 0) {
    stop(paste("Missing required columns:", paste(missing_cols, collapse = ", ")))
  }
  
  # Get the path to the www directory
  www_dir <- system.file("www", package = "duckdbviz")
  
  # If package is not installed, use development path
  if (www_dir == "") {
    www_dir <- file.path(getwd(), "inst/www")
    if (!dir.exists(www_dir)) {
      stop("Cannot find www directory. Please check your installation.")
    }
  }
  
  # Determine which HTML file to use
  if (use_native_duckdb) {
    html_file <- file.path(www_dir, "index_native.html")
    
    # Start the native DuckDB server in the background
    server_info <- create_duckdb_server(data_viz, port = port)
    websocket_url <- server_info$url
  } else {
    html_file <- file.path(www_dir, "index.html")
    websocket_url <- NULL
    
    # For non-native mode, prepare Arrow data for transfer
    arrow_table <- arrow::as_arrow_table(data_viz)
    temp_file <- tempfile(fileext = ".arrow")
    arrow::write_feather(arrow_table, temp_file)
    arrow_binary <- readBin(temp_file, "raw", file.info(temp_file)$size)
    arrow_base64 <- jsonlite::base64_enc(arrow_binary)
    file.remove(temp_file)
  }
  
  # Create a completely self-contained Shiny app with embedded HTML
  # Read the HTML file
  html_content <- readLines(html_file, warn = FALSE)
  html_content <- paste(html_content, collapse = "\n")
  
  # Create Shiny app
  app <- shiny::shinyApp(
    ui = shiny::fluidPage(
      shiny::tags$head(
        shiny::tags$style(
          shiny::HTML("
            html, body { width: 100%; height: 100%; margin: 0; padding: 0; }
          ")
        ),
        # Include Apache Arrow JavaScript library
        shiny::tags$script(src = "https://cdn.jsdelivr.net/npm/apache-arrow@latest/+esm", type = "module"),
        # Conditionally include data based on mode
        if (!use_native_duckdb) {
          shiny::tags$script(shiny::HTML(paste0("window.arrowData = '", arrow_base64, "';")))
        } else {
          shiny::tags$script(shiny::HTML(paste0("window.websocketUrl = '", websocket_url, "';")))
        }
      ),
      shiny::titlePanel("DuckDB Interactive Visualization"),
      # Embed the HTML directly in the Shiny app
      shiny::tags$div(
        shiny::HTML(html_content),
        style = paste0("width: ", if(is.null(width)) "100%" else paste0(width, "px"), "; ",
                       "height: ", if(is.null(height)) "800px" else paste0(height, "px"), ";")
      ),
      shiny::fluidRow(
        shiny::column(
          width = 12,
          shiny::verbatimTextOutput("selection_info")
        )
      )
    ),
    server = function(input, output, session) {
      # Initialize selection storage
      selected_data <- shiny::reactiveVal(NULL)
      
      # Listen for selection events from JavaScript
      shiny::observeEvent(input$viz_selection, {
        # When selection happens, create a function to retrieve the data
        selection_js <- paste0(
          "window.RViz && window.RViz.getSelectionData ? ",
          "JSON.stringify(window.RViz.getSelectionData()) : 'null'"
        )
        
        # Get selection name
        selection_name <- input$viz_selection$name
        if (is.null(selection_name)) {
          pkg_env <- get_pkg_env()
          selection_name <- paste0("Selection", pkg_env$selection_counter)
          pkg_env$selection_counter <- pkg_env$selection_counter + 1
        }
        
        # Execute JavaScript to get selection data
        shiny::runjs(paste0("
          Shiny.setInputValue('selection_data', {
            data: ", selection_js, ",
            name: '", selection_name, "'
          });
        "))
      })
      
      # Process the selection data when it arrives
      shiny::observeEvent(input$selection_data, {
        if (!is.null(input$selection_data$data) && input$selection_data$data != "null") {
          # Parse the JSON data
          selection <- jsonlite::fromJSON(input$selection_data$data)
          selected_data(selection)
          
          # Get the selection name
          selection_name <- input$selection_data$name
          
          # Save selection to global environment
          if (use_native_duckdb) {
            # For native mode, send save request to WebSocket server
            socket_message <- jsonlite::toJSON(list(
              type = "save_selection",
              data = selection,
              name = selection_name
            ))
            
            shiny::runjs(paste0("
              if (window.socket && window.socket.readyState === WebSocket.OPEN) {
                window.socket.send('", socket_message, "');
              }
            "))
          } else {
            # For WebAssembly mode, save directly
            mapping <- list(
              x = "array_col",
              y = "array_row",
              group = "in_tissue"
            )
            
            # Get indices from selection
            indices <- sapply(selection, function(d) d$index)
            
            # Get original data for these indices
            pkg_env <- get_pkg_env()
            original_data <- pkg_env$current_data
            selection_data <- original_data[original_data$index %in% indices, ]
            
            # Save to global environment
            assign(selection_name, selection_data, envir = .GlobalEnv)
            
            # Update selection counter
            pkg_env$selection_counter <- pkg_env$selection_counter + 1
            
            # Log to console
            message(paste0("Selection saved as '", selection_name, "' with ", nrow(selection_data), " points"))
          }
          
          # Display info about the selection
          output$selection_info <- shiny::renderText({
            if (is.null(selected_data())) {
              "No points selected"
            } else {
              paste0(
                "Selected ", length(selected_data()), " points and saved as '", selection_name, 
                "' in your workspace. Use '", selection_name, "' to access this data in R."
              )
            }
          })
        }
      })
      
      # Clean up on session end
      session$onSessionEnded(function() {
        if (use_native_duckdb) {
          # Only stop the server if running in development mode
          # In production, we may want multiple users to connect
          if (interactive()) {
            stop_duckdb_server()
          }
        }
      })
      
      # Make selection data available to the R session
      session$userData$selected_data <- selected_data
    }
  )
  
  # Store the app in the package environment for later access
  pkg_env <- get_pkg_env()
  pkg_env$current_app <- app
  pkg_env$current_data <- data
  pkg_env$use_native_duckdb <- use_native_duckdb
  pkg_env$selection_counter <- 1
  
  # Launch the app if requested
  if (launch) {
    # Check if running in RStudio
    if (interactive() && requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
      # Use the RStudio viewer
      shiny::runApp(app, launch.browser = rstudioapi::viewer)
    } else {
      # Use the default browser
      shiny::runApp(app)
    }
  }
  
  # Return the app object
  invisible(app)
}