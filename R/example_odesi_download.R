# Example: Download data from ODESI
#
# This script demonstrates how to download data from ODESI using the
# download_odesi_data.R functions.
#
# The example uses the dataset from:
# https://odesi.ca/en/details?id=/odesi/doi__10-5683_SP3_ZVCGBK.xml

source("R/download_odesi_data.R")

# ═══════════════════════════════════════════════════════════════════
# Example 1: Download using ODESI URL
# ═══════════════════════════════════════════════════════════════════

# You can pass the full ODESI URL directly - the DOI will be extracted
download_odesi_dataset(
  doi = "https://odesi.ca/en/details?id=/odesi/doi__10-5683_SP3_ZVCGBK.xml",
  dest_dir = "odesi-data"
)

# ═══════════════════════════════════════════════════════════════════
# Example 2: Download using DOI directly
# ═══════════════════════════════════════════════════════════════════

# Or you can use the DOI directly if you know it
download_odesi_dataset(
  doi = "doi:10.5683/SP3/ZVCGBK",
  dest_dir = "odesi-data"
)

# ═══════════════════════════════════════════════════════════════════
# Example 3: Download with custom subdirectory naming
# ═══════════════════════════════════════════════════════════════════

# By default, creates a subdirectory based on the DOI
# Set create_subdir = FALSE to download directly to dest_dir
download_odesi_dataset(
  doi = "doi:10.5683/SP3/ZVCGBK",
  dest_dir = "odesi-data/my-custom-folder",
  create_subdir = FALSE
)

# ═══════════════════════════════════════════════════════════════════
# Example 4: Download restricted datasets (requires authentication)
# ═══════════════════════════════════════════════════════════════════

# First, set up authentication (only needed once)
# source("R/setup_odesi_auth.R")
# setup_odesi_auth()  # This will prompt for your API token

# Then download restricted datasets
# The API key will be automatically used from the environment variable
# download_odesi_dataset(
#   doi = "doi:10.5683/SP3/RESTRICTED",
#   dest_dir = "odesi-data"
# )

# ═══════════════════════════════════════════════════════════════════
# Example 5: Download multiple datasets
# ═══════════════════════════════════════════════════════════════════

# Create a vector of DOIs or URLs
datasets <- c(
  "https://odesi.ca/en/details?id=/odesi/doi__10-5683_SP3_ZVCGBK.xml"
  # Add more datasets here
  # "doi:10.5683/SP3/ANOTHER",
  # "doi:10.5683/SP3/YETANOTHER"
)

# Download all datasets
# results <- download_multiple_odesi_datasets(
#   dois = datasets,
#   dest_dir = "odesi-data"
# )

# ═══════════════════════════════════════════════════════════════════
# Example 6: Check what's in a dataset before downloading
# ═══════════════════════════════════════════════════════════════════

# Get file list without downloading
doi <- "doi:10.5683/SP3/ZVCGBK"
files <- get_dataset_files(doi)
print(files)

# View total size
total_size_mb <- sum(files$filesize) / 1024^2
cat("Total dataset size:", round(total_size_mb, 2), "MB\n")

# ═══════════════════════════════════════════════════════════════════
# Example 7: Get dataset metadata
# ═══════════════════════════════════════════════════════════════════

# Get full metadata
metadata <- get_dataset_metadata("doi:10.5683/SP3/ZVCGBK")

# Extract citation information
citation <- metadata$data$latestVersion$metadataBlocks$citation$fields
title <- citation[[1]]$value
cat("Dataset title:", title, "\n")
