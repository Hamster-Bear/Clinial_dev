get_numeric_vars <- function(df) {
  if (is.null(df)) return(character(0))
  names(df)[vapply(df, is.numeric, logical(1))]
}

get_categorical_vars <- function(df, include_logical = TRUE) {
  if (is.null(df)) return(character(0))
  names(df)[vapply(df, function(x) {
    is.factor(x) || is.character(x) || (isTRUE(include_logical) && is.logical(x))
  }, logical(1))]
}

get_time_vars <- function(df) {
  if (is.null(df)) return(character(0))
  names(df)[vapply(df, function(x) {
    is.numeric(x) || inherits(x, "Date") || inherits(x, "POSIXt")
  }, logical(1))]
}

resolve_plot_size_config <- function(
  mode = "wide_standard",
  static_width_px = NULL,
  static_height_px = NULL,
  interactive_width_px = NULL,
  interactive_height_px = NULL,
  export_width_in = NULL,
  export_height_in = NULL,
  defaults = list(
    static_width = 1200,
    static_height = 760,
    interactive_width = 1200,
    interactive_height = 620,
    export_width = 13,
    export_height = 9
  )
) {
  to_num <- function(x, fallback) {
    val <- suppressWarnings(as.numeric(x))
    if (is.na(val) || !is.finite(val)) fallback else val
  }

  if (!identical(mode, "custom")) {
    return(defaults)
  }

  list(
    static_width = to_num(static_width_px, defaults$static_width),
    static_height = to_num(static_height_px, defaults$static_height),
    interactive_width = to_num(interactive_width_px, defaults$interactive_width),
    interactive_height = to_num(interactive_height_px, defaults$interactive_height),
    export_width = to_num(export_width_in, defaults$export_width),
    export_height = to_num(export_height_in, defaults$export_height)
  )
}

graphics_notify_success <- function(module_name) {
  showNotification(paste0(module_name, "生成完成"), type = "message")
}

graphics_notify_error <- function(module_name, err) {
  msg <- if (inherits(err, "error")) conditionMessage(err) else as.character(err)
  showNotification(paste0(module_name, "生成错误: ", msg), type = "error")
}
