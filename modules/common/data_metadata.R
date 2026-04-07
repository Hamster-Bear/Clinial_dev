metadata_valid_var_types <- c("numeric", "factor", "date", "text")

metadata_determine_var_type <- function(x) {
  if (is.numeric(x)) {
    "numeric"
  } else if (is.factor(x) || (is.character(x) && length(unique(x[!is.na(x)])) <= 20)) {
    "factor"
  } else if (inherits(x, "Date") || inherits(x, "POSIXct") || inherits(x, "POSIXlt")) {
    "date"
  } else {
    "text"
  }
}

metadata_coerce_var_data <- function(x, var_type) {
  if (var_type == "numeric") {
    return(suppressWarnings(as.numeric(x)))
  }
  if (var_type == "date") {
    if (inherits(x, "Date")) return(x)
    if (inherits(x, "POSIXct") || inherits(x, "POSIXlt")) return(as.Date(x))
    x_chr <- as.character(x)
    parsed <- tryCatch(
      suppressWarnings(as.Date(
        x_chr,
        tryFormats = c(
          "%Y-%m-%d", "%Y/%m/%d", "%Y.%m.%d",
          "%Y%m%d", "%Y-%m-%d %H:%M:%S", "%Y/%m/%d %H:%M:%S",
          "%d/%m/%Y", "%m/%d/%Y"
        )
      )),
      error = function(e) as.Date(rep(NA_character_, length(x_chr)))
    )
    return(parsed)
  }
  if (var_type == "factor") {
    return(as.character(x))
  }
  as.character(x)
}

metadata_safe_numeric_range <- function(var_data) {
  valid_data <- var_data[!is.na(var_data)]
  if (length(valid_data) == 0) return(list(min = 0.0, max = 1.0))
  min_val <- tryCatch({
    result <- min(valid_data, na.rm = TRUE)
    if (length(result) == 0 || is.na(result) || !is.finite(result)) 0.0 else as.numeric(result)
  }, error = function(e) 0.0)
  max_val <- tryCatch({
    result <- max(valid_data, na.rm = TRUE)
    if (length(result) == 0 || is.na(result) || !is.finite(result)) 1.0 else as.numeric(result)
  }, error = function(e) 1.0)
  if (min_val > max_val) {
    temp <- min_val
    min_val <- max_val
    max_val <- temp + 1
  }
  if (!is.finite(min_val)) min_val <- 0.0
  if (!is.finite(max_val)) max_val <- 1.0
  list(min = min_val, max = max_val)
}

metadata_get_table <- function(data = NULL, metadata = NULL) {
  meta <- metadata %||% attr(data, "hamster_var_meta")
  if (!is.data.frame(meta) || !all(c("var_name", "label", "type") %in% names(meta))) return(NULL)
  meta
}

metadata_get_var_label <- function(var_name, var_data = NULL, label_overrides = NULL, data = NULL, metadata = NULL) {
  if (!is.null(label_overrides) && var_name %in% names(label_overrides) && nzchar(trimws(label_overrides[[var_name]]))) {
    return(trimws(label_overrides[[var_name]]))
  }
  meta <- metadata_get_table(data = data, metadata = metadata)
  if (!is.null(meta) && var_name %in% meta$var_name) {
    val <- meta$label[[match(var_name, meta$var_name)]]
    if (!is.null(val) && nzchar(trimws(as.character(val)))) return(trimws(as.character(val)))
  }
  var_label <- attr(var_data %||% data[[var_name]], "label")
  if (!is.null(var_label) && nzchar(trimws(as.character(var_label)))) {
    return(trimws(as.character(var_label)))
  }
  var_name
}

metadata_get_var_type <- function(var_name, var_data = NULL, type_overrides = NULL, data = NULL, metadata = NULL) {
  if (!is.null(type_overrides) && var_name %in% names(type_overrides) && type_overrides[[var_name]] %in% metadata_valid_var_types) {
    return(type_overrides[[var_name]])
  }
  meta <- metadata_get_table(data = data, metadata = metadata)
  if (!is.null(meta) && var_name %in% meta$var_name) {
    val <- meta$type[[match(var_name, meta$var_name)]]
    if (!is.null(val) && val %in% metadata_valid_var_types) return(val)
  }
  metadata_determine_var_type(var_data %||% data[[var_name]])
}

metadata_build_column_choices <- function(data, label_overrides = NULL, metadata = NULL) {
  vars <- names(data)
  labels <- vapply(vars, function(var_name) {
    var_label <- metadata_get_var_label(var_name, data[[var_name]], label_overrides = label_overrides, metadata = metadata)
    if (!identical(var_label, var_name)) paste0(var_name, " | ", var_label) else var_name
  }, character(1))
  setNames(vars, labels)
}

metadata_attach_to_data <- function(data, type_overrides = NULL, label_overrides = NULL, metadata = NULL) {
  if (!is.data.frame(data)) return(data)
  meta <- metadata_get_table(data = data, metadata = metadata)
  vars <- names(data)
  meta_df <- data.frame(
    var_name = vars,
    label = vapply(vars, function(var_name) metadata_get_var_label(var_name, data[[var_name]], label_overrides = label_overrides, metadata = meta), character(1)),
    type = vapply(vars, function(var_name) metadata_get_var_type(var_name, data[[var_name]], type_overrides = type_overrides, metadata = meta), character(1)),
    stringsAsFactors = FALSE
  )
  for (var_name in vars) {
    attr(data[[var_name]], "label") <- meta_df$label[[match(var_name, meta_df$var_name)]]
  }
  attr(data, "hamster_var_meta") <- meta_df
  data
}
