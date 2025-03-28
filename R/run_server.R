#' Start a local Node.js server for development
#'
#' This function starts a local Node.js server for development purposes
#'
#' @param port Port number to use for the server
#' @param open Whether to open the visualization in browser
#'
#' @return The process ID of the server
#' @export
run_server <- function(port = 3000, open = TRUE) {
  # Check if Node.js is installed
  node_check <- try(system("node --version", intern = TRUE), silent = TRUE)
  if (inherits(node_check, "try-error")) {
    stop("Node.js is required but not found. Please install Node.js and try again.")
  }
  
  # Get the path to the server.js file
  server_path <- system.file("www/server.js", package = "duckdbviz")
  
  if (server_path == "") {
    # If package is not installed, use development path
    server_path <- file.path(getwd(), "inst/www/server.js")
    if (!file.exists(server_path)) {
      stop("Server file not found. Please check your installation.")
    }
  }
  
  # Set environment variable for port
  Sys.setenv(PORT = port)
  
  # Start the server in the background
  server_dir <- dirname(server_path)
  
  # Use different commands based on OS
  if (.Platform$OS.type == "windows") {
    cmd <- paste0("cd ", shQuote(server_dir), " && start /B node ", shQuote(basename(server_path)))
    shell(cmd, wait = FALSE)
  } else {
    cmd <- paste0("cd ", shQuote(server_dir), " && node ", shQuote(basename(server_path)), " &")
    system(cmd, wait = FALSE)
  }
  
  # Wait a moment for the server to start
  Sys.sleep(2)
  
  # Open the visualization if requested
  if (open) {
    open_viz(paste0("http://localhost:", port))
  }
  
  # Return success message
  message(paste0("Server started at http://localhost:", port))
  invisible(TRUE)
}

#' Stop the local Node.js server
#'
#' This function stops the local Node.js server
#'
#' @return Invisible NULL
#' @export
stop_server <- function() {
  # Different commands based on OS
  if (.Platform$OS.type == "windows") {
    system("taskkill /F /IM node.exe", ignore.stdout = TRUE, ignore.stderr = TRUE)
  } else {
    system("pkill -f 'node.*server.js'", ignore.stdout = TRUE, ignore.stderr = TRUE)
  }
  
  message("Server stopped")
  invisible(NULL)
}

#' Open the visualization in RStudio's Viewer pane or browser
#'
#' @param url URL of the visualization, defaults to localhost:3000
#' @return NULL (invisible)
#' @export
open_viz <- function(url = "http://localhost:3000") {
  if (interactive()) {
    if (rstudioapi::isAvailable()) {
      # Open in RStudio's Viewer pane
      rstudioapi::viewer(url)
      message("Opened visualization in RStudio's Viewer pane.")
    } else {
      # Fallback to the default web browser
      utils::browseURL(url)
      message("Opened visualization in the default web browser.")
    }
  } else {
    # Non-interactive sessions (e.g., knitting documents)
    utils::browseURL(url)
    message("Opened visualization in the default web browser.")
  }
  invisible(NULL)
}