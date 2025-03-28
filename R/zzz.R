#' @importFrom utils packageVersion
.onLoad <- function(libname, pkgname) {
  # Create package environment
  if (!exists("pkg_env", envir = asNamespace(pkgname))) {
    assign("pkg_env", new.env(), envir = asNamespace(pkgname))
  }
  
  # Initialize variables in package environment
  pkg_env <- get("pkg_env", envir = asNamespace(pkgname))
  pkg_env$current_app <- NULL
  pkg_env$current_data <- NULL
  pkg_env$current_selection <- NULL
  pkg_env$temp_file <- NULL
  pkg_env$duckdb_conn <- NULL
  pkg_env$websocket_server <- NULL
  pkg_env$use_native_duckdb <- FALSE
  
  invisible()
}

#' @importFrom utils packageVersion
.onAttach <- function(libname, pkgname) {
  packageStartupMessage(paste0("duckdbviz ", utils::packageVersion("duckdbviz"), " loaded."))
  packageStartupMessage("Use duckdb_viz() to create interactive visualizations.")
  
  invisible()
}

# Internal function to get package environment
get_pkg_env <- function() {
  if (!exists("pkg_env", envir = asNamespace("duckdbviz"))) {
    assign("pkg_env", new.env(), envir = asNamespace("duckdbviz"))
  }
  get("pkg_env", envir = asNamespace("duckdbviz"))
}