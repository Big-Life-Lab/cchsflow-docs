# Explore OSF Documentation Component Structure
# This script will connect to OSF and examine the existing folder structure

source("R/setup_osf.R")

# First, let's make sure we have your actual PAT in the .env file
# You need to edit .env and replace the placeholder with your real token

# Load environment variables from .env file
if (file.exists(".env")) {
  readRenviron(".env")
} else {
  stop("Please create .env file with your OSF credentials")
}

# Load configuration
config <- config::get()

# Test the connection
project <- init_osf()

# Explore the main project structure
cat("=== Main Project Structure ===\n")
main_files <- osf_ls_files(project)
print(names(main_files))  # Let's see what columns are available
if ("name" %in% names(main_files)) {
  print(main_files$name)
}

# Connect directly to Documentation component
cat("\n=== Connecting to Documentation Component ===\n")
doc_component_id <- config$osf$documentation_component_id
doc_node <- osf_retrieve_node(doc_component_id)
cat("Connected to component:", doc_node$name, "\n")
  
# Function to recursively explore folder structure
explore_folders <- function(node, depth = 0) {
  indent <- paste(rep("  ", depth), collapse = "")
  files <- osf_ls_files(node)
  
  if (nrow(files) > 0) {
    cat(indent, "Found", nrow(files), "items:\n")
    for (i in 1:nrow(files)) {
      cat(indent, "  -", files$name[i], "\n")
      
      # Try to explore subfolders (limit depth to avoid infinite loops)
      if (depth < 3) {
        tryCatch({
          subfolder <- osf_retrieve_file(files$id[i])
          explore_folders(subfolder, depth + 1)
        }, error = function(e) {
          cat(indent, "    (file or inaccessible)\n")
        })
      }
    }
  } else {
    cat(indent, "No items found\n")
  }
}
  
cat("\n=== Documentation Component Structure ===\n")
explore_folders(doc_node)