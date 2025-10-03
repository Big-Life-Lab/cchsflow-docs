# Check R version compatibility
required <- "4.2"
if (!startsWith(as.character(getRversion()), required)) {
  message(sprintf(
    "WARNING: This project targets R %s.x; you are on %s.\nSome packages may not work correctly.",
    required, getRversion()
  ))
}

# Activate renv if lockfile exists
if (file.exists("renv.lock")) {
  source("renv/activate.R")
}
