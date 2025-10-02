# Setup Google Drive Authentication for CCHS PUMF Documentation
#
# This script sets up authentication with Google Drive API to enable
# programmatic downloads of PUMF documentation

library(googledrive)

cat("Setting up Google Drive authentication...\n\n")

# Configure googledrive to use a specific cache for this project
# This keeps authentication tokens in the project directory
options(
  gargle_oauth_cache = ".secrets",
  gargle_oauth_email = TRUE
)

# Authenticate interactively
# This will open a browser window to authorize access
cat("This will open your browser to authorize Google Drive access.\n")
cat("Please sign in and authorize the application.\n\n")

drive_auth(
  email = TRUE,  # Will prompt for email selection
  cache = ".secrets"
)

# Test the authentication
cat("\nTesting authentication...\n")
drive_user()

cat("\n✓ Authentication successful!\n")
cat("\nYour credentials are cached in .secrets/\n")
cat("Make sure .secrets/ is in .gitignore to keep tokens private.\n")
