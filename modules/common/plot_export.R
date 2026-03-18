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

  args <- list(
    filename = file,
    plot = plot_obj,
    width = width,
    height = height,
    bg = bg,
    device = export_format
  )

  if (export_format == "png") {
    args$dpi <- dpi
  }

  do.call(ggsave, args)
}
