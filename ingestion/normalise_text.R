# normalise_text.R
# Shared text normalisation for all CCHS metadata ingestion scripts.
#
# Standardises labels and free-text fields so that cross-source comparisons
# are not polluted by encoding artefacts (smart quotes, em-dashes, etc.).
#
# Usage: source("ingestion/normalise_text.R")
#        labels <- normalise_label(labels)

normalise_label <- function(x) {
  # Vectorised: works on character vectors, returns character vector.
  # NA values pass through unchanged.
  if (!is.character(x)) return(x)

  # 1. Trim leading/trailing whitespace
  x <- trimws(x)

  # 2. Smart/curly single quotes -> straight apostrophe

  x <- gsub("\u2018", "'", x, fixed = TRUE)
  x <- gsub("\u2019", "'", x, fixed = TRUE)

  # 3. Smart/curly double quotes -> straight double quote
  x <- gsub("\u201C", "\"", x, fixed = TRUE)
  x <- gsub("\u201D", "\"", x, fixed = TRUE)

  # 4. Em-dash and en-dash -> hyphen
  x <- gsub("\u2014", "-", x, fixed = TRUE)
  x <- gsub("\u2013", "-", x, fixed = TRUE)

  # 5. Non-breaking space -> regular space
  x <- gsub("\u00A0", " ", x, fixed = TRUE)

  # 6. Collapse multiple spaces to single space
  x <- gsub("\\s+", " ", x)

  # 7. Strip surrounding single quotes and unescape doubled quotes
  #    e.g., "'Don''t know'" -> "Don't know"
  #    Absorbs strip_quotes() from ingest_613apps.R
  idx <- !is.na(x) & nchar(x) >= 2 &
         startsWith(x, "'") & endsWith(x, "'")
  x[idx] <- substr(x[idx], 2, nchar(x[idx]) - 1)
  x[idx] <- gsub("''", "'", x[idx], fixed = TRUE)

  x
}
