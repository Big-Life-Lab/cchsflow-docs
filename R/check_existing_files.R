# Check for Existing Files in 2022 and 2023
# These years should have documentation files

library(dplyr)

# Load environment
if (file.exists(".env")) {
  readRenviron(".env")
}

source("R/setup_osf.R")
config <- config::get()
project <- init_osf()
doc_node <- osf_retrieve_node(config$osf$documentation_component_id)

# Function to show files in a folder with more detail
show_folder_contents <- function(folder_id, folder_name, max_depth = 4) {
  cat("📁", folder_name, "\n")
  
  get_contents_recursive <- function(current_id, current_path = "", depth = 0) {
    if (depth >= max_depth) return()
    
    indent <- paste(rep("  ", depth), collapse = "")
    
    tryCatch({
      folder <- osf_retrieve_file(current_id)
      files <- osf_ls_files(folder)
      
      if (nrow(files) == 0) {
        cat(indent, "(empty)\n")
        return()
      }
      
      for (i in 1:nrow(files)) {
        file_name <- files$name[i]
        file_id <- files$id[i]
        
        # Try to determine if it's a folder by attempting to list its contents
        is_folder <- tryCatch({
          subfolder <- osf_retrieve_file(file_id)
          subfiles <- osf_ls_files(subfolder)
          TRUE
        }, error = function(e) {
          FALSE
        })
        
        if (is_folder) {
          cat(indent, "📁", file_name, "\n")
          # Recurse into subfolders
          get_contents_recursive(file_id, 
                               if (current_path == "") file_name else paste(current_path, file_name, sep = "/"), 
                               depth + 1)
        } else {
          cat(indent, "📄", file_name, "\n")
        }
      }
    }, error = function(e) {
      cat(indent, "❌ Error accessing folder:", e$message, "\n")
    })
  }
  
  get_contents_recursive(folder_id)
}

# Check 2022 and 2023
years_to_check <- c("2022", "2023")
all_folders <- osf_ls_files(doc_node)

for (year in years_to_check) {
  cat("\n=== Year", year, "Contents ===\n")
  year_folder <- all_folders %>% filter(name == year)
  
  if (nrow(year_folder) > 0) {
    show_folder_contents(year_folder$id[1], year)
  } else {
    cat("Year", year, "folder not found\n")
  }
}

cat("\n=== Summary ===\n")
cat("This shows the actual file contents in 2022 and 2023 folders\n")