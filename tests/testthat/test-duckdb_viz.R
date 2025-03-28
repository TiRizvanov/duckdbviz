library(testthat)
library(duckdbviz)

test_that("prepare_data_for_viz handles data correctly", {
  # Create test data
  test_data <- data.frame(
    x = c(1, 2, 3),
    y = c(4, 5, 6),
    color = c(TRUE, FALSE, TRUE)
  )
  
  # Call the function directly
  result <- duckdbviz:::prepare_data_for_viz(test_data, "x", "y", "color")
  
  # Check results
  expect_equal(colnames(result), c("x", "y", "color", "index", "array_col", "array_row", "in_tissue"))
  expect_equal(result$array_col, c(1, 2, 3))
  expect_equal(result$array_row, c(4, 5, 6))
  expect_equal(result$in_tissue, c(TRUE, FALSE, TRUE))
  expect_equal(result$index, c(1, 2, 3))
})

test_that("handle_selection processes selection data correctly", {
  # Create test data
  test_data <- data.frame(
    index = c(1, 2, 3),
    x = c(1, 2, 3),
    y = c(4, 5, 6)
  )
  
  # Create test selection JSON
  selection_json <- '[{"index":1,"array_col":1,"array_row":4,"in_tissue":true},{"index":3,"array_col":3,"array_row":6,"in_tissue":true}]'
  
  # Call the function directly
  result <- duckdbviz:::handle_selection(selection_json, test_data)
  
  # Check results
  expect_equal(nrow(result), 2)
  expect_equal(result$index, c(1, 3))
  expect_equal(result$x, c(1, 3))
  expect_equal(result$y, c(4, 6))
})

test_that("export_data_to_csv creates a valid CSV file", {
  # Create test data
  test_data <- data.frame(
    index = c(1, 2, 3),
    array_col = c(1, 2, 3),
    array_row = c(4, 5, 6),
    in_tissue = c(TRUE, FALSE, TRUE)
  )
  
  # Create temporary file
  temp_file <- tempfile(fileext = ".csv")
  
  # Call the function directly
  result_file <- duckdbviz:::export_data_to_csv(test_data, temp_file)
  
  # Check results
  expect_true(file.exists(result_file))
  
  # Read back the CSV and check content
  csv_data <- read.csv(result_file)
  expect_equal(nrow(csv_data), 3)
  expect_equal(csv_data$index, c(1, 2, 3))
  expect_equal(csv_data$array_col, c(1, 2, 3))
  expect_equal(csv_data$array_row, c(4, 5, 6))
  
  # Clean up
  file.remove(temp_file)
})