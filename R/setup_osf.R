# OSF.io Setup and Authentication
# This script handles OSF.io authentication and basic setup

library(osfr)
library(config)

# Load configuration
config <- config::get()

# Set up OSF authentication
setup_osf_auth <- function() {
  # Check if OSF_PAT is set
  if (Sys.getenv("OSF_PAT") == "") {
    stop("OSF_PAT environment variable not set. Please set your OSF Personal Access Token.")
  }
  
  # Authenticate with OSF
  osf_auth(token = config$osf$token)
  
  # Test authentication
  tryCatch({
    osf_retrieve_user("me")
    message("✓ OSF authentication successful")
    return(TRUE)
  }, error = function(e) {
    stop("OSF authentication failed: ", e$message)
  })
}

# Get project
get_osf_project <- function() {
  if (config$osf$project_id == "") {
    stop("OSF_PROJECT_ID environment variable not set.")
  }
  
  project <- osf_retrieve_node(config$osf$project_id)
  message("✓ Connected to OSF project: ", project$name)
  return(project)
}

# Initialize OSF connection
init_osf <- function() {
  setup_osf_auth()
  project <- get_osf_project()
  return(project)
}