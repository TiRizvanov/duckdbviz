library(testthat)
library(duckdbviz)

test_that("DuckDBServer class works correctly", {
  # Create test data
  test_data <- data.frame(
    index = 1:10,
    array_col = 1:10,
    array_row = 11:20,
    in_tissue = rep(c(TRUE, FALSE), 5)
  )
  
  # Create server
  server <- DuckDBServer$new(test_data)
  
  # Test that connection is valid
  expect_true(DBI::dbIsValid(server$con))
  
  # Test query execution
  result <- server$execute_query("SELECT * FROM viz_data LIMIT 5")
  expect_equal(nrow(result), 5)
  expect_equal(ncol(result), 4)
  
  # Test arrow query
  if (requireNamespace("arrow", quietly = TRUE)) {
    result_arrow <- server$execute_query_arrow("SELECT * FROM viz_data LIMIT 5")
    expect_true(inherits(result_arrow, "Table"))
    expect_equal(nrow(result_arrow), 5)
  }
  
  # Test cache
  server$execute_query("SELECT COUNT(*) FROM viz_data", cache = TRUE)
  expect_equal(length(server$cache), 1)
  
  # Clean up
  server$close()
  expect_null(server$con)
})

test_that("Arrow serialization functions work correctly", {
  skip_if_not_installed("arrow")
  
  # Create test data
  test_data <- data.frame(
    index = 1:10,
    array_col = 1:10,
    array_row = 11:20,
    in_tissue = rep(c(TRUE, FALSE), 5)
  )
  
  # Convert to Arrow
  arrow_table <- df_to_arrow(test_data)
  expect_true(inherits(arrow_table, "Table"))
  
  # Serialize and deserialize
  raw_data <- serialize_arrow(arrow_table)
  expect_true(is.raw(raw_data))
  
  # Deserialize
  arrow_table2 <- deserialize_arrow(raw_data)
  expect_true(inherits(arrow_table2, "Table"))
  
  # Convert back to data frame
  df <- arrow_to_df(arrow_table2)
  expect_equal(df, test_data)
  
  # Test base64 encoding
  base64_string <- base64_encode(raw_data)
  expect_true(is.character(base64_string))
  
  # Test base64 decoding
  raw_data2 <- base64_decode(base64_string)
  expect_equal(raw_data, raw_data2)
})

test_that("prepare_data_for_viz handles data correctly", {
  # Create test data
  test_data <- data.frame(
    x = c(1, 2, 3),
    y = c(4, 5, 6),
    color = c(TRUE, FALSE, TRUE)
  )
  
  # Rename columns to match expected format
  data_viz <- test_data
  names(data_viz)[names(data_viz) == "x"] <- "array_col"
  names(data_viz)[names(data_viz) == "y"] <- "array_row"
  names(data_viz)[names(data_viz) == "color"] <- "in_tissue"
  
  # Add index if not present
  if (is.null(data_viz$index)) {
    data_viz$index <- seq_len(nrow(data_viz))
  }
  
  # Check results
  expect_equal(colnames(data_viz), c("array_col", "array_row", "in_tissue", "index"))
  expect_equal(data_viz$array_col, c(1, 2, 3))
  expect_equal(data_viz$array_row, c(4, 5, 6))
  expect_equal(data_viz$in_tissue, c(TRUE, FALSE, TRUE))
  expect_equal(data_viz$index, c(1, 2, 3))
})
