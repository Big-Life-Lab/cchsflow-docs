# ODESI Data Download Scripts

This directory contains R scripts for downloading data from ODESI (Ontario Data Documentation, Extraction Service and Infrastructure), which is integrated with Borealis, the Canadian Dataverse Repository.

## Overview

ODESI provides access to social science research data from Canadian surveys and studies. These scripts use the Dataverse API to programmatically download datasets.

## Files

- **[download_odesi_data.R](download_odesi_data.R)** - Main download functions
- **[setup_odesi_auth.R](setup_odesi_auth.R)** - Authentication setup for restricted datasets
- **[example_odesi_download.R](example_odesi_download.R)** - Usage examples

## Quick Start

### 1. Install Required Packages

```r
install.packages(c("httr", "jsonlite", "xml2"))
```

### 2. Download Public Datasets

For public/open datasets, no authentication is needed:

```r
source("R/download_odesi_data.R")

# Using ODESI URL
download_odesi_dataset(
  doi = "https://odesi.ca/en/details?id=/odesi/doi__10-5683_SP3_ZVCGBK.xml",
  dest_dir = "odesi-data"
)

# Or using DOI directly
download_odesi_dataset(
  doi = "doi:10.5683/SP3/ZVCGBK",
  dest_dir = "odesi-data"
)
```

### 3. Download Restricted Datasets

For restricted datasets, you need a Borealis API token:

#### Get API Token
1. Go to https://borealisdata.ca/
2. Log in or create an account
3. Click your name (top right) → API Token
4. Copy your API token

#### Set Up Authentication

```r
source("R/setup_odesi_auth.R")
setup_odesi_auth("your-api-token-here")
```

This will:
- Save your API token to `~/.Renviron` for future sessions
- Test that authentication works
- Set the token for the current R session

#### Download Restricted Dataset

```r
source("R/download_odesi_data.R")
download_odesi_dataset(
  doi = "doi:10.5683/SP3/RESTRICTED",
  dest_dir = "odesi-data"
)
```

## Main Functions

### `download_odesi_dataset()`

Downloads all files from a single ODESI dataset.

**Parameters:**
- `doi` - DOI or ODESI URL (e.g., "doi:10.5683/SP3/ZVCGBK" or full ODESI URL)
- `dest_dir` - Destination directory (default: "odesi-data")
- `server` - Dataverse server URL (default: "https://borealisdata.ca")
- `key` - API key for restricted files (optional, reads from DATAVERSE_KEY env var)
- `create_subdir` - Create subdirectory for each dataset (default: TRUE)

**Returns:**
List with download statistics (files downloaded, size, duration, etc.)

**What it downloads:**
- All data files from the dataset
- Dataset metadata as JSON (`dataset_metadata.json`)
- File listing as CSV (`file_list.csv`)

### `download_multiple_odesi_datasets()`

Downloads multiple datasets in sequence.

**Parameters:**
- `dois` - Vector of DOIs or ODESI URLs
- `dest_dir` - Base destination directory
- `server` - Dataverse server URL
- `key` - API key (optional)

**Example:**
```r
datasets <- c(
  "doi:10.5683/SP3/ZVCGBK",
  "doi:10.5683/SP3/ANOTHER",
  "https://odesi.ca/en/details?id=/odesi/doi__10-5683_SP3_THIRD.xml"
)

results <- download_multiple_odesi_datasets(
  dois = datasets,
  dest_dir = "odesi-data"
)
```

### `get_dataset_files()`

Gets list of files in a dataset without downloading.

**Example:**
```r
files <- get_dataset_files("doi:10.5683/SP3/ZVCGBK")
print(files)

# Check total size before downloading
total_mb <- sum(files$filesize) / 1024^2
cat("Total size:", round(total_mb, 2), "MB\n")
```

### `get_dataset_metadata()`

Gets full dataset metadata.

**Example:**
```r
metadata <- get_dataset_metadata("doi:10.5683/SP3/ZVCGBK")

# Extract information
title <- metadata$data$latestVersion$metadataBlocks$citation$fields[[1]]$value
cat("Title:", title, "\n")
```

### `extract_doi_from_odesi_url()`

Extracts DOI from an ODESI URL.

**Example:**
```r
url <- "https://odesi.ca/en/details?id=/odesi/doi__10-5683_SP3_ZVCGBK.xml"
doi <- extract_doi_from_odesi_url(url)
# Returns: "doi:10.5683/SP3/ZVCGBK"
```

## Authentication Functions

### `setup_odesi_auth()`

Set up API authentication for restricted datasets.

```r
source("R/setup_odesi_auth.R")

# Interactive setup (prompts for API token)
setup_odesi_auth()

# Or pass token directly
setup_odesi_auth("your-api-token-here")

# Don't save to .Renviron (session only)
setup_odesi_auth("your-api-token-here", save_to_renviron = FALSE)
```

### `show_odesi_auth_status()`

Check current authentication status.

```r
show_odesi_auth_status()
```

### `test_odesi_auth()`

Test if authentication is working.

```r
test_odesi_auth()
```

### `remove_odesi_auth()`

Remove API authentication.

```r
remove_odesi_auth()
```

## Output Structure

When you download a dataset, the files are organized as follows:

```
odesi-data/
└── doi_10.5683_SP3_ZVCGBK/          # Subdirectory per dataset (sanitized DOI)
    ├── dataset_metadata.json        # Full dataset metadata
    ├── file_list.csv                # List of all files with details
    ├── data_file_1.tab              # Downloaded data files
    ├── data_file_2.dta
    ├── codebook.pdf
    └── ...
```

## Finding Datasets on ODESI

1. Go to https://odesi.ca/
2. Search for datasets using keywords, topics, or collections
3. Click on a dataset to view details
4. Copy the URL or DOI to use with these scripts

## Tips

### Previewing Before Download

```r
# Check dataset info before downloading
doi <- "doi:10.5683/SP3/ZVCGBK"

# Get metadata
metadata <- get_dataset_metadata(doi)
title <- metadata$data$latestVersion$metadataBlocks$citation$fields[[1]]$value

# Get file list
files <- get_dataset_files(doi)
total_mb <- sum(files$filesize) / 1024^2

cat("Dataset:", title, "\n")
cat("Files:", nrow(files), "\n")
cat("Size:", round(total_mb, 2), "MB\n")

# Then download if desired
download_odesi_dataset(doi)
```

### Batch Processing

```r
# Read DOIs from a file
dois <- readLines("datasets_to_download.txt")

# Download all
results <- download_multiple_odesi_datasets(dois)

# Save results
saveRDS(results, "download_results.rds")
```

### Skip Existing Files

The scripts automatically skip files that already exist in the destination directory, making it safe to re-run downloads.

## Troubleshooting

### "Access forbidden" error
- The dataset is restricted and requires authentication
- Run `setup_odesi_auth()` to configure your API token

### "Could not extract DOI from URL"
- Verify the ODESI URL format
- Or use the DOI directly instead of the URL

### "No files found in dataset"
- The dataset may not have any downloadable files
- Check the ODESI webpage to verify

### Connection timeout
- Large files may take time to download
- Check your internet connection
- Try downloading individual files instead of the whole dataset

## API Documentation

For more details on the Dataverse API:
- Borealis API Guide: https://borealisdata.ca/guides/en/latest/api/index.html
- Scholars Portal Dataverse API: https://learn.scholarsportal.info/all-guides/borealis-admin/dataverse-api/

## Related Scripts

- [download_gdrive_cchs_data.R](download_gdrive_cchs_data.R) - Download CCHS data from Google Drive
- [download_gdrive_pumf.R](download_gdrive_pumf.R) - Download PUMF data from Google Drive

## License

These scripts are provided as-is for use with ODESI/Borealis. Please respect data use agreements and citations required by individual datasets.
