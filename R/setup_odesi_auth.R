# ODESI/Borealis API Authentication Setup
#
# This script helps you set up authentication for downloading restricted datasets
# from ODESI via the Borealis Dataverse API.
#
# Authentication is only needed for restricted/private datasets.
# Public datasets can be downloaded without authentication.
#
# To get an API token:
# 1. Go to https://borealisdata.ca/
# 2. Log in or create an account
# 3. Click on your name in top right -> API Token
# 4. Copy your API token
#
# Usage:
#   source("R/setup_odesi_auth.R")
#   setup_odesi_auth("your-api-token-here")

#' Set up ODESI/Borealis API authentication
#'
#' This function helps configure your API key for accessing restricted datasets
#' from ODESI via Borealis. You can either:
#' 1. Pass the key directly to this function
#' 2. Set it as an environment variable manually
#' 3. Store it in your .Renviron file
#'
#' @param api_key Your Borealis API token (optional)
#' @param save_to_renviron Save to .Renviron file for persistence (default: TRUE)
setup_odesi_auth <- function(api_key = NULL, save_to_renviron = TRUE) {

  cat("\n")
  cat("═══════════════════════════════════════════════════════════\n")
  cat("ODESI/Borealis API Authentication Setup\n")
  cat("═══════════════════════════════════════════════════════════\n\n")

  # If no key provided, check if one exists
  if (is.null(api_key)) {
    existing_key <- Sys.getenv("DATAVERSE_KEY", unset = NA)

    if (!is.na(existing_key) && nchar(existing_key) > 0) {
      cat("✓ API key already configured in environment\n")
      cat("  Key preview:", substr(existing_key, 1, 10), "...\n\n")

      response <- readline(prompt = "Do you want to update it? (y/n): ")
      if (!tolower(response) %in% c("y", "yes")) {
        cat("\nKeeping existing configuration.\n")
        return(invisible(NULL))
      }
    }

    cat("To get your API token:\n")
    cat("1. Go to https://borealisdata.ca/\n")
    cat("2. Log in or create an account\n")
    cat("3. Click on your name (top right) -> API Token\n")
    cat("4. Copy your API token\n\n")

    api_key <- readline(prompt = "Enter your API token: ")

    if (is.null(api_key) || nchar(api_key) == 0) {
      stop("API key is required")
    }
  }

  # Validate key format (basic check)
  api_key <- trimws(api_key)
  if (nchar(api_key) < 10) {
    warning("API key seems too short. Please verify it's correct.")
  }

  # Set for current session
  Sys.setenv(DATAVERSE_KEY = api_key)
  cat("✓ API key set for current R session\n")

  # Optionally save to .Renviron
  if (save_to_renviron) {
    renviron_path <- file.path(Sys.getenv("HOME"), ".Renviron")

    # Read existing .Renviron if it exists
    if (file.exists(renviron_path)) {
      renviron_lines <- readLines(renviron_path)

      # Remove any existing DATAVERSE_KEY lines
      renviron_lines <- renviron_lines[!grepl("^DATAVERSE_KEY=", renviron_lines)]
    } else {
      renviron_lines <- character(0)
    }

    # Add new key
    renviron_lines <- c(renviron_lines, paste0("DATAVERSE_KEY=", api_key))

    # Write back
    writeLines(renviron_lines, renviron_path)

    cat("✓ API key saved to ~/.Renviron\n")
    cat("  (Will be automatically loaded in future R sessions)\n\n")

    cat("Note: Restart R or run readRenviron('~/.Renviron') to load in current session\n\n")
  }

  # Test the authentication
  cat("Testing authentication...\n")
  test_result <- test_odesi_auth(api_key)

  if (test_result) {
    cat("\n")
    cat("═══════════════════════════════════════════════════════════\n")
    cat("✓ Setup Complete!\n")
    cat("═══════════════════════════════════════════════════════════\n\n")
    cat("You can now download restricted datasets using:\n")
    cat("  source('R/download_odesi_data.R')\n")
    cat("  download_odesi_dataset('doi:10.5683/SP3/XXXXX')\n\n")
  } else {
    cat("\n")
    cat("⚠ Authentication test failed\n")
    cat("Please verify your API token is correct\n\n")
  }

  invisible(api_key)
}

#' Test ODESI/Borealis API authentication
#'
#' @param api_key API token to test (uses environment variable if not provided)
#' @return TRUE if authentication works, FALSE otherwise
test_odesi_auth <- function(api_key = NULL) {

  if (is.null(api_key)) {
    api_key <- Sys.getenv("DATAVERSE_KEY", unset = NA)
    if (is.na(api_key)) {
      cat("✗ No API key found\n")
      return(FALSE)
    }
  }

  # Test by getting user info
  library(httr)
  url <- "https://borealisdata.ca/api/users/:me"

  response <- GET(url, add_headers("X-Dataverse-key" = api_key))

  if (status_code(response) == 200) {
    user_info <- content(response, "parsed")
    cat("✓ Authentication successful\n")
    if ("data" %in% names(user_info) && "displayName" %in% names(user_info$data)) {
      cat("  Logged in as:", user_info$data$displayName, "\n")
    }
    return(TRUE)
  } else {
    cat("✗ Authentication failed (status:", status_code(response), ")\n")
    return(FALSE)
  }
}

#' Remove ODESI/Borealis API authentication
#'
#' Removes the API key from the current session and optionally from .Renviron
#'
#' @param remove_from_renviron Also remove from .Renviron file (default: TRUE)
remove_odesi_auth <- function(remove_from_renviron = TRUE) {

  cat("Removing ODESI/Borealis API authentication...\n")

  # Remove from current session
  Sys.unsetenv("DATAVERSE_KEY")
  cat("✓ Removed from current session\n")

  # Remove from .Renviron
  if (remove_from_renviron) {
    renviron_path <- file.path(Sys.getenv("HOME"), ".Renviron")

    if (file.exists(renviron_path)) {
      renviron_lines <- readLines(renviron_path)
      original_count <- length(renviron_lines)

      # Remove DATAVERSE_KEY lines
      renviron_lines <- renviron_lines[!grepl("^DATAVERSE_KEY=", renviron_lines)]

      if (length(renviron_lines) < original_count) {
        writeLines(renviron_lines, renviron_path)
        cat("✓ Removed from ~/.Renviron\n")
      } else {
        cat("  (No entry found in ~/.Renviron)\n")
      }
    }
  }

  cat("\nAuthentication removed.\n")
  invisible(NULL)
}

#' Show current ODESI/Borealis API authentication status
show_odesi_auth_status <- function() {

  cat("\n")
  cat("═══════════════════════════════════════════════════════════\n")
  cat("ODESI/Borealis API Authentication Status\n")
  cat("═══════════════════════════════════════════════════════════\n\n")

  # Check environment variable
  api_key <- Sys.getenv("DATAVERSE_KEY", unset = NA)

  if (!is.na(api_key) && nchar(api_key) > 0) {
    cat("✓ API key configured in current session\n")
    cat("  Key preview:", substr(api_key, 1, 10), "...\n\n")

    # Test authentication
    test_result <- test_odesi_auth(api_key)

    if (!test_result) {
      cat("\n⚠ API key is set but authentication test failed\n")
      cat("  The key may be invalid or expired\n")
    }
  } else {
    cat("✗ No API key configured in current session\n\n")
  }

  # Check .Renviron
  renviron_path <- file.path(Sys.getenv("HOME"), ".Renviron")
  if (file.exists(renviron_path)) {
    renviron_lines <- readLines(renviron_path)
    has_key <- any(grepl("^DATAVERSE_KEY=", renviron_lines))

    if (has_key) {
      cat("✓ API key found in ~/.Renviron\n")
      cat("  (Will be loaded automatically in future R sessions)\n")
    } else {
      cat("  No API key in ~/.Renviron\n")
    }
  }

  cat("\n")
  invisible(NULL)
}

# If run interactively, show status
if (interactive()) {
  show_odesi_auth_status()

  cat("Available functions:\n")
  cat("  setup_odesi_auth()        - Set up API authentication\n")
  cat("  test_odesi_auth()         - Test current authentication\n")
  cat("  show_odesi_auth_status()  - Show authentication status\n")
  cat("  remove_odesi_auth()       - Remove authentication\n\n")
}
