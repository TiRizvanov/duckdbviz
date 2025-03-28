# Example script for using duckdbviz package

# Load the package
library(duckdbviz)

# Create a sample dataset
set.seed(123)
data <- data.frame(
  index = 1:10000,
  array_col = rnorm(10000, mean = 100, sd = 30),
  array_row = rnorm(10000, mean = 100, sd = 30),
  in_tissue = sample(c(TRUE, FALSE), 10000, replace = TRUE)
)

# Create an interactive visualization
duckdb_viz(data, 
           x_col = "array_col", 
           y_col = "array_row", 
           color_col = "in_tissue")

# After making a selection in the visualization, you can:
# Get the current selection
# selected_points <- get_current_selection()

# Save the selection to a variable
# save_selection("my_selection")

# To run in standalone mode:
# run_server(port = 3000)
# open_viz("http://localhost:3000")
# stop_server() # when done
