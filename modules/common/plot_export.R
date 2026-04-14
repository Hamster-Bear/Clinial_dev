build_plot_export_filename <- function(prefix, format, include_time = FALSE) {
  export_format <- tolower(if (is.null(format) || !nzchar(format)) "png" else format)
  stamp <- if (include_time) format(Sys.time(), "%Y%m%d_%H%M%S") else as.character(Sys.Date())
  paste0(prefix, "_", stamp, ".", export_format)
}

save_plot_export <- function(file, plot_obj, format, width = 10, height = 8, dpi = 300, bg = "white") {
  if (is.null(plot_obj)) {
    stop("plot_obj 不能为空")
  }
  export_format <- tolower(if (is.null(format) || !nzchar(format)) "png" else format)
  width <- suppressWarnings(as.numeric(width))
  height <- suppressWarnings(as.numeric(height))
  dpi <- suppressWarnings(as.numeric(dpi))

  if (length(width) == 0 || is.na(width) || !is.finite(width) || width <= 0) width <- 10
  if (length(height) == 0 || is.na(height) || !is.finite(height) || height <= 0) height <- 8
  if (length(dpi) == 0 || is.na(dpi) || !is.finite(dpi) || dpi <= 0) dpi <- 300

  if (!export_format %in% c("png", "pdf", "svg")) {
    stop(paste0("不支持的导出格式: ", export_format))
  }

  device_fun <- switch(
    export_format,
    png = "png",
    pdf = grDevices::cairo_pdf,
    svg = if (requireNamespace("svglite", quietly = TRUE)) svglite::svglite else grDevices::svg,
    export_format
  )

  args <- list(
    filename = file,
    plot = plot_obj,
    width = width,
    height = height,
    bg = bg,
    device = device_fun,
    limitsize = FALSE
  )

  if (export_format == "png") {
    args$dpi <- dpi
  }

  tryCatch(
    do.call(ggplot2::ggsave, args),
    error = function(e) {
      if (export_format == "pdf") {
        args$device <- "pdf"
        do.call(ggplot2::ggsave, args)
      } else {
        stop(e)
      }
    }
  )
}
