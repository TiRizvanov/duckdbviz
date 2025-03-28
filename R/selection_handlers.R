#' Handle selection data from JavaScript visualization
#'
#' This function processes selection data received from the JavaScript visualization
#' and makes it available in the R session.
#'
#' @param selection_data JSON string containing selection data
#' @param original_data Original data frame used for visualization
#'
#' @return A data frame containing the selected points
#' @keywords internal
handle_selection <- function(selection_data, original_data) {
  if (is.null(selection_data) || selection_data == "null") {
    return(NULL)
  }
  
  # Parse JSON data
  selection <- jsonlite::fromJSON(selection_data)
  
  # Get indices of selected points
  selected_indices <- as.numeric(selection$index)
  
  # Return subset of original data
  if (length(selected_indices) > 0) {
    return(original_data[original_data$index %in% selected_indices, ])
  } else {
    return(NULL)
  }
}

#' Store selection in package environment
#'
#' @param selection Selection data
#' @keywords internal
store_selection <- function(selection) {
  pkg_env <- get_pkg_env()
  pkg_env$current_selection <- selection
}

#' Get the current selection from the visualization
#'
#' This function retrieves the current selection from the visualization
#'
#' @return A data frame containing the selected points, or NULL if no selection
#' @export
get_current_selection <- function() {
  pkg_env <- get_pkg_env()
  
  if (is.null(pkg_env$current_selection)) {
    message("No current selection available.")
    return(NULL)
  }
  
  return(pkg_env$current_selection)
}

#' Save the current selection to a variable
#'
#' This function saves the current selection to a variable in the specified environment
#'
#' @param name Name to assign to the selection
#' @param envir Environment to assign the selection to, defaults to parent frame
#'
#' @return Invisibly returns the selection
#' @export
save_selection <- function(name, envir = parent.frame()) {
  selection <- get_current_selection()
  
  if (is.null(selection)) {
    warning("No selection available to save.")
    return(invisible(NULL))
  }
  
  assign(name, selection, envir = envir)
  message(paste0("Selection saved as '", name, "'"))
  
  invisible(selection)
}

#' Get the currently selected points from the visualization
#'
#' @return A data frame containing the selected points
#' @export
get_selection <- function() {
  pkg_env <- get_pkg_env()
  
  if (is.null(pkg_env$current_app)) {
    stop("No active visualization found. Run duckdb_viz() first.")
  }
  
  # Access the selected data from the Shiny session
  selected_data <- pkg_env$current_app$server$userData$selected_data()
  
  if (is.null(selected_data)) {
    message("No points are currently selected.")
    return(NULL)
  }
  
  # Return the selected data
  return(selected_data)
}