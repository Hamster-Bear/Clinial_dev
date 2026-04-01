build_plot_export_filename <- function(prefix, format, include_time = FALSE) {
  export_format <- tolower(if (is.null(format) || !nzchar(format)) "png" else format)
  stamp <- if (include_time) format(Sys.time(), "%Y%m%d_%H%M%S") else as.character(Sys.Date())
  paste0(prefix, "_", stamp, ".", export_format)
}

save_plot_export <- function(file, plot_obj, format, width = 10, height = 8, dpi = 300, bg = "white") {
  req(plot_obj)
  export_format <- tolower(if (is.null(format) || !nzchar(format)) "png" else format)

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
    device = device_fun
  )

  if (export_format == "png") {
    args$dpi <- dpi
  }

  tryCatch(
    do.call(ggsave, args),
    error = function(e) {
      if (export_format == "pdf") {
        args$device <- "pdf"
        do.call(ggsave, args)
      } else {
        stop(e)
      }
    }
  )
}
