#' Create a WebSocket server with native DuckDB
#'
#' This function creates a WebSocket server that serves data from a native DuckDB instance
#'
#' @param data A data frame or tibble containing the data to visualize
#' @param port Port number for the WebSocket server
#' @param host Host address for the WebSocket server
#'
#' @return A list with server object and connection details
#' @importFrom httpuv startServer stopServer
#' @importFrom DBI dbConnect dbExecute dbGetQuery
#' @importFrom duckdb duckdb duckdb_register
#' @importFrom arrow as_arrow_table write_ipc_stream
#' @importFrom jsonlite fromJSON toJSON base64_enc
#' @export
create_duckdb_server <- function(data, port = 8000, host = "127.0.0.1") {
  # Check for required packages
  if (!requireNamespace("httpuv", quietly = TRUE)) {
    stop("Package 'httpuv' is needed for this function to work. Please install it.",
         call. = FALSE)
  }
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("Package 'arrow' is needed for this function to work. Please install it.",
         call. = FALSE)
  }
  
  # Create native DuckDB connection
  con <- DBI::dbConnect(duckdb::duckdb())
  
  # Register data directly - more efficient than creating a table
  # This keeps the data in memory without serialization/deserialization
  duckdb::duckdb_register(con, "tissue_positions", data)
  
  # Create a WebSocket server
  server <- httpuv::startServer(
    host = host,
    port = port,
    app = list(
      onWSOpen = function(ws) {
        # Handle new WebSocket connection
        ws$onMessage(function(binary, message) {
          tryCatch({
            # Parse request (expecting JSON)
            request <- jsonlite::fromJSON(message)
            
            if (request$type == "query") {
              # Execute query
              result <- DBI::dbGetQuery(con, request$query)
              
              # Convert to Arrow table
              arrow_table <- arrow::as_arrow_table(result)
              
              # Serialize to Arrow IPC format
              arrow_binary <- arrow::write_to_raw(arrow_table)
              
              # Base64 encode the binary data and wrap in JSON
              encoded_data <- jsonlite::base64_enc(arrow_binary)
              response <- jsonlite::toJSON(list(
                type = "arrow_data",
                data = encoded_data
              ), auto_unbox = TRUE)
              
              # Send as text rather than binary
              ws$send(response)
            } 
            else if (request$type == "metadata") {
              # Get metadata about the data
              bounds_query <- "SELECT 
                  MIN(array_col) as min_x, MAX(array_col) as max_x,
                  MIN(array_row) as min_y, MAX(array_row) as max_y,
                  COUNT(*) as total_rows
                FROM tissue_positions"
              
              bounds <- DBI::dbGetQuery(con, bounds_query)
              
              # Send metadata as JSON
              ws$send(jsonlite::toJSON(bounds))
            }
            else if (request$type == "save_selection") {
              # Handle request to save selection
              if (!is.null(request$data) && length(request$data) > 0) {
                # Get selection name
                selection_name <- request$name
                if (is.null(selection_name)) {
                  selection_name <- paste0("Selection", pkg_env$selection_counter)
                  pkg_env$selection_counter <- pkg_env$selection_counter + 1
                }
                
                message("Processing selection data...")
                
                # Convert selection data to data frame
                selection_df <- NULL
                tryCatch({
                  # Direct conversion of the JSON array to a data frame
                  selection_df <- as.data.frame(request$data)
                  
                  # Make sure in_tissue is logical
                  if ("in_tissue" %in% names(selection_df)) {
                    selection_df$in_tissue <- as.logical(selection_df$in_tissue)
                  }
                  
                  # Get indices from the selection
                  indices <- selection_df$index
                  
                  # Get original data for these indices (with original column names)
                  if (length(indices) > 0) {
                    # Map selected points back to original data
                    original_data <- data[data$index %in% indices, ]
                    
                    # Save to global environment
                    assign(selection_name, original_data, envir = .GlobalEnv)
                    
                    # Confirm to client
                    response <- jsonlite::toJSON(list(
                      type = "selection_saved",
                      name = selection_name,
                      count = nrow(original_data),
                      nextCounter = pkg_env$selection_counter + 1
                    ), auto_unbox = TRUE)
                    
                    ws$send(response)
                    
                    # Log to console
                    message(paste0("Selection saved as '", selection_name, "' with ", nrow(original_data), " points"))
                    
                    # Increment counter
                    pkg_env$selection_counter <- pkg_env$selection_counter + 1
                  } else {
                    message("No points found in selection")
                  }
                }, error = function(e) {
                  message("Error processing selection data: ", e$message)
                  print(str(request$data))
                  ws$send(jsonlite::toJSON(list(
                    type = "error",
                    message = paste("Error processing selection:", e$message)
                  )))
                })
              }
            }
            else if (request$type == "ping") {
              # Simple ping to check connection
              ws$send(jsonlite::toJSON(list(
                type = "pong",
                time = Sys.time()
              )))
            }
          }, error = function(e) {
            # Send error back to client
            ws$send(jsonlite::toJSON(list(
              type = "error",
              message = e$message
            )))
            
            # Log error
            message("WebSocket error: ", e$message)
          })
        })
        
        # Handle WebSocket close
        ws$onClose(function() {
          # Potentially clean up resources
          message("WebSocket connection closed")
        })
      },
      
      # Static file handler
      call = function(req) {
        # Simplified handler that only returns basic info
        list(
          status = 200,
          headers = list('Content-Type' = 'application/json'),
          body = jsonlite::toJSON(list(
            message = "DuckDB WebSocket server is running",
            endpoint = paste0("ws://", host, ":", port)
          ))
        )
      }
    )
  )
  
  # Store connection in the environment for later access/cleanup
  pkg_env <- get_pkg_env()
  pkg_env$duckdb_conn <- con
  pkg_env$websocket_server <- server
  pkg_env$selection_counter <- 1
  pkg_env$original_data <- data
  
  # Return server info
  server_info <- list(
    server = server,
    host = host,
    port = port,
    url = paste0("ws://", host, ":", port),
    total_rows = nrow(data)
  )
  
  message("Native DuckDB server started at ws://", host, ":", port)
  
  invisible(server_info)
}

#' Stop the DuckDB WebSocket server
#'
#' @return Invisible NULL
#' @export
stop_duckdb_server <- function() {
  pkg_env <- get_pkg_env()
  
  # Close DuckDB connection if exists
  if (!is.null(pkg_env$duckdb_conn)) {
    tryCatch({
      DBI::dbDisconnect(pkg_env$duckdb_conn, shutdown = TRUE)
      pkg_env$duckdb_conn <- NULL
      message("DuckDB connection closed")
    }, error = function(e) {
      message("Error closing DuckDB connection: ", e$message)
    })
  }
  
  # Stop WebSocket server if exists
  if (!is.null(pkg_env$websocket_server)) {
    tryCatch({
      httpuv::stopServer(pkg_env$websocket_server)
      pkg_env$websocket_server <- NULL
      message("WebSocket server stopped")
    }, error = function(e) {
      message("Error stopping WebSocket server: ", e$message)
    })
  }
  
  invisible(NULL)
}