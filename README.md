# duckdbviz: High-Performance Interactive Visualization for Large Datasets in R

`duckdbviz` is an R package that enables interactive visualization of large datasets using DuckDB and JavaScript. It provides a bidirectional communication system between R and the visualization, allowing for selection and filtering of data points with high performance.

## Key Features

- **High-Performance Visualization**: Render millions of points with adaptive sampling based on viewport and performance
- **Two Operating Modes**:
  - **Native DuckDB Mode**: Uses a WebSocket server with native DuckDB for maximum performance and scalability (recommended for large datasets)
  - **WebAssembly Mode**: Uses DuckDB-Wasm in the browser for simpler deployment
- **Apache Arrow Integration**: Uses Arrow for efficient data transfer without JSON serialization overhead
- **Dynamic Rendering**: Automatically adjusts rendering based on FPS to maintain smooth interaction
- **Interactive Selection**: Select areas of interest and retrieve the corresponding data in R

## Installation

```r
# Install from GitHub
# install.packages("devtools")
devtools::install_github("yourusername/duckdbviz")
```

Or install the package locally:

```r
# Install from local directory
install.packages("/path/to/duckdbviz", repos = NULL, type = "source")
```

## Dependencies

The package requires the following R packages:
- shiny
- htmltools
- jsonlite
- DBI
- duckdb
- rstudioapi
- arrow
- httpuv (for native DuckDB mode)

## Usage

### Basic Usage with WebAssembly Mode

```r
library(duckdbviz)

# Create a sample dataset
set.seed(123)
data <- data.frame(
  x = rnorm(10000, mean = 100, sd = 30),
  y = rnorm(10000, mean = 100, sd = 30),
  group = sample(c(TRUE, FALSE), 10000, replace = TRUE)
)

# Create an interactive visualization using WebAssembly mode
duckdb_viz(data, 
           x_col = "x", 
           y_col = "y", 
           color_col = "group",
           use_native_duckdb = FALSE)
```

### High-Performance Native DuckDB Mode (Recommended for Large Datasets)

```r
library(duckdbviz)

# Create a larger sample dataset
set.seed(123)
large_data <- data.frame(
  x = rnorm(1000000, mean = 100, sd = 30),
  y = rnorm(1000000, mean = 100, sd = 30),
  group = sample(c(TRUE, FALSE), 1000000, replace = TRUE)
)

# Create an interactive visualization using Native DuckDB mode
duckdb_viz(large_data, 
           x_col = "x", 
           y_col = "y", 
           color_col = "group",
           use_native_duckdb = TRUE,
           port = 8000)  # Optional: specify port for WebSocket server
```

### Getting Selected Points

```r
# After selecting points in the visualization
selected_points <- get_selection()

# Analyze the selected points
summary(selected_points)
```

### Cleaning Up Resources

When using native DuckDB mode, it's good practice to clean up the server when done:

```r
# Stop the DuckDB WebSocket server
stop_duckdb_server()
```

## Performance Considerations

### When to Use Native DuckDB Mode
- For datasets with 100,000+ points
- When performance is critical
- When your data can't fit entirely in browser memory
- For multi-user scenarios where a central server is preferred

### When to Use WebAssembly Mode
- For smaller datasets (under 100,000 points)
- When deployment simplicity is more important than raw performance
- For single-user scenarios
- When you want to avoid server-side components

## How It Works

### WebAssembly Mode
1. Data is serialized to Arrow format in R
2. Arrow data is transferred to the browser
3. DuckDB-Wasm loads the Arrow data and creates a virtual database
4. JavaScript visualization queries the database based on viewport
5. Dynamic rendering maintains smooth performance

### Native DuckDB Mode
1. A WebSocket server with native DuckDB is started in R
2. Browser connects to the WebSocket server
3. JavaScript visualization sends query requests based on viewport
4. Server executes queries against the native DuckDB instance
5. Results are transferred using Arrow for maximum efficiency
6. Dynamic rendering maintains smooth performance

## Technical Details

- **Data Transfer**: Uses Apache Arrow instead of JSON for 10-100x faster serialization/deserialization
- **Query Optimization**: Uses DuckDB's query optimization for efficient filtering and aggregation
- **Memory Efficiency**: Only transfers data that's visible in the current viewport
- **Adaptive Sampling**: Adjusts sample size based on performance to maintain target FPS
- **WebSocket Protocol**: Custom protocol for efficient query request/response in native mode

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.