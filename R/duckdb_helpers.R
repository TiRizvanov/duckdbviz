#' Create a DuckDB connection for visualization
#'
#' This function creates a DuckDB connection and loads data for visualization
#'
#' @param data A data frame or tibble containing the data to visualize
#' @param temp_file Path to save the temporary CSV file
#'
#' @return A DuckDB connection
#' @keywords internal
create_duckdb_connection <- function(data, temp_file) {
  # Check for required packages
  if (!requireNamespace("duckdb", quietly = TRUE)) {
    stop("Package 'duckdb' is needed for this function to work. Please install it.",
         call. = FALSE)
  }
  if (!requireNamespace("DBI", quietly = TRUE)) {
    stop("Package 'DBI' is needed for this function to work. Please install it.",
         call. = FALSE)
  }
  
  # Create DuckDB connection
  con <- DBI::dbConnect(duckdb::duckdb())
  
  # Load data into DuckDB
  duckdb::duckdb_register(con, "data_table", data)
  
  # Create table from the registered data
  DBI::dbExecute(con, "CREATE TABLE viz_data AS SELECT * FROM data_table")
  
  # Return connection
  return(con)
}

#' Prepare data for visualization
#'
#' This function prepares data for visualization by ensuring it has the required columns
#'
#' @param data A data frame or tibble containing the data to visualize
#' @param x_col Column name for x-axis
#' @param y_col Column name for y-axis
#' @param color_col Optional column name for coloring points
#'
#' @return A data frame ready for visualization
#' @keywords internal
prepare_data_for_viz <- function(data, x_col, y_col, color_col = NULL) {
  # Create a copy of the data
  data_viz <- data
  
  # Add index if not present
  if (is.null(data_viz$index)) {
    data_viz$index <- seq_len(nrow(data_viz))
  }
  
  # Rename columns to match expected format
  names(data_viz)[names(data_viz) == x_col] <- "array_col"
  names(data_viz)[names(data_viz) == y_col] <- "array_row"
  
  # Handle color column
  if (!is.null(color_col)) {
    names(data_viz)[names(data_viz) == color_col] <- "in_tissue"
    
    # Convert to logical if it's not already
    if (!is.logical(data_viz$in_tissue)) {
      if (is.factor(data_viz$in_tissue) || is.character(data_viz$in_tissue)) {
        # For factors or character, convert first level/unique value to TRUE, others to FALSE
        first_level <- levels(data_viz$in_tissue)[1]
        if (is.null(first_level)) {
          first_level <- unique(data_viz$in_tissue)[1]
        }
        data_viz$in_tissue <- data_viz$in_tissue == first_level
      } else if (is.numeric(data_viz$in_tissue)) {
        # For numeric, convert non-zero to TRUE, zero to FALSE
        data_viz$in_tissue <- data_viz$in_tissue != 0
      }
    }
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
  
  return(data_viz)
}

#' Export data to CSV for visualization
#'
#' This function exports data to a CSV file for visualization
#'
#' @param data A data frame prepared for visualization
#' @param file Path to save the CSV file
#'
#' @return The path to the saved CSV file
#' @keywords internal
export_data_to_csv <- function(data, file) {
  # Write data to CSV
  write.csv(data, file, row.names = FALSE)
  
  # Return file path
  return(file)
}

#' Process selection data from JavaScript
#'
#' This function processes selection data received from JavaScript
#'
#' @param selection_data JSON string containing selection data
#' @param original_data Original data frame used for visualization
#'
#' @return A data frame containing the selected points with original column names
#' @keywords internal
process_selection_data <- function(selection_data, original_data) {
  if (is.null(selection_data) || selection_data == "null") {
    return(NULL)
  }
  
  # Parse JSON data
  selection <- jsonlite::fromJSON(selection_data)
  
  # Get indices of selected points
  selected_indices <- selection$index
  
  # Return subset of original data
  return(original_data[original_data$index %in% selected_indices, ])
}