format_p_value_regression <- function(x) {
  if (exists("format_p_value_ama", mode = "function")) {
    return(format_p_value_ama(x))
  }
  val <- suppressWarnings(as.numeric(x))
  if (is.na(val)) return("NA")
  if (val < 0.001) return("<0.001")
  if (val > 0.99) return(">0.99")
  sprintf("%.3f", val)
}

build_repro_code_template <- function(steps) {
  lines <- character(0)
  for (i in seq_along(steps)) {
    step <- steps[[i]]
    title <- if (!is.null(step$title)) as.character(step$title)[1] else paste0("Step ", i)
    body <- if (!is.null(step$lines)) as.character(step$lines) else character(0)
    lines <- c(lines, paste0("# ", i, ") ", title), body, "")
  }
  paste(lines, collapse = "\n")
}
