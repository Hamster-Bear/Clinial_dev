build_table_export_filename <- function(prefix, format, include_time = FALSE) {
  export_format <- tolower(if (is.null(format) || !nzchar(format)) "docx" else format)
  stamp <- if (include_time) format(Sys.time(), "%Y%m%d_%H%M%S") else as.character(Sys.Date())
  paste0(prefix, "_", stamp, ".", export_format)
}

format_p_value_ama <- function(x) {
  val <- suppressWarnings(as.numeric(x))
  if (is.na(val)) {
    return("NA")
  }
  if (val < 0.001) {
    return("<0.001")
  }
  if (val > 0.99) {
    return(">0.99")
  }
  sprintf("%.3f", val)
}

normalize_footnotes <- function(footnotes) {
  if (is.null(footnotes)) {
    return(character(0))
  }
  f <- trimws(as.character(footnotes))
  unique(f[nzchar(f)])
}

extract_table_dataframe <- function(table_obj) {
  if (is.data.frame(table_obj)) {
    return(table_obj)
  }
  if (inherits(table_obj, "gt_tbl")) {
    gt_data <- tryCatch(table_obj[["_data"]], error = function(e) NULL)
    if (is.data.frame(gt_data)) {
      return(gt_data)
    }
  }
  txt <- paste(capture.output(print(table_obj)), collapse = "\n")
  data.frame(Result = strsplit(txt, "\n", fixed = TRUE)[[1]], stringsAsFactors = FALSE)
}

apply_sci_gt_style <- function(gt_table, title = NULL, footnotes = NULL) {
  styled <- gt_table %>%
    gt::tab_options(
      table.font.names = "Times New Roman",
      table.font.size = gt::px(10),
      heading.align = "left",
      table.border.top.style = "solid",
      table.border.top.width = gt::px(2),
      table.border.bottom.style = "solid",
      table.border.bottom.width = gt::px(2),
      heading.border.bottom.style = "solid",
      heading.border.bottom.width = gt::px(1),
      table_body.hlines.style = "none",
      table_body.vlines.style = "none",
      column_labels.border.top.style = "none",
      column_labels.border.bottom.style = "solid",
      column_labels.border.bottom.width = gt::px(1),
      data_row.padding = gt::px(3)
    ) %>%
    gt::opt_table_outline(style = "none", width = gt::px(0)) %>%
    gt::cols_align(align = "left", columns = 1) %>%
    gt::cols_align(align = "center", columns = gt::everything())
  if (!is.null(title) && nzchar(trimws(title))) {
    styled <- styled %>% gt::tab_header(title = gt::md(trimws(title)))
  }
  footnote_vec <- normalize_footnotes(footnotes)
  if (length(footnote_vec) > 0) {
    for (ft in footnote_vec) {
      styled <- styled %>% gt::tab_source_note(gt::md(ft))
    }
  }
  styled
}

save_table_png <- function(file, table_obj, width = 10, height = 8, dpi = 300, title = NULL, footnotes = NULL) {
  if (inherits(table_obj, "ggplot")) {
    ggsave(filename = file, plot = table_obj, width = width, height = height, dpi = dpi, bg = "white")
    return(invisible(TRUE))
  }
  if (inherits(table_obj, "gt_tbl")) {
    gt_obj <- apply_sci_gt_style(table_obj, title = title, footnotes = footnotes)
    gt::gtsave(data = gt_obj, filename = file)
    return(invisible(TRUE))
  }
  if (is.data.frame(table_obj)) {
    grDevices::png(filename = file, width = width, height = height, units = "in", res = dpi, bg = "white")
    on.exit(grDevices::dev.off(), add = TRUE)
    grid::grid.newpage()
    grid::grid.draw(gridExtra::tableGrob(table_obj))
    return(invisible(TRUE))
  }
  text_content <- paste(capture.output(print(table_obj)), collapse = "\n")
  data_frame <- data.frame(Result = strsplit(text_content, "\n", fixed = TRUE)[[1]], stringsAsFactors = FALSE)
  grDevices::png(filename = file, width = width, height = height, units = "in", res = dpi, bg = "white")
  on.exit(grDevices::dev.off(), add = TRUE)
  grid::grid.newpage()
  grid::grid.draw(gridExtra::tableGrob(data_frame))
  invisible(TRUE)
}

build_sci_flextable <- function(table_obj, title = "导出结果", footnotes = NULL) {
  if (!requireNamespace("flextable", quietly = TRUE) || !requireNamespace("officer", quietly = TRUE)) {
    stop("导出 Word 需要安装 flextable 和 officer 包")
  }
  df <- extract_table_dataframe(table_obj)
  ft <- flextable::flextable(df)
  ft <- flextable::border_remove(ft)
  thick_border <- officer::fp_border(color = "black", width = 2)
  thin_border <- officer::fp_border(color = "black", width = 1)
  ft <- flextable::hline_top(ft, border = thick_border, part = "all")
  ft <- flextable::hline(ft, i = 1, border = thin_border, part = "header")
  ft <- flextable::hline_bottom(ft, border = thick_border, part = "all")
  ft <- flextable::font(ft, fontname = "Times New Roman", part = "all")
  ft <- flextable::fontsize(ft, size = 10, part = "all")
  ft <- flextable::align(ft, align = "center", part = "header")
  if (ncol(df) > 0) {
    ft <- flextable::align(ft, j = 1, align = "left", part = "all")
  }
  if (ncol(df) > 1) {
    ft <- flextable::align(ft, j = 2:ncol(df), align = "center", part = "all")
  }
  if (!is.null(title) && nzchar(trimws(title))) {
    ft <- flextable::set_caption(ft, caption = trimws(title))
  }
  footnote_vec <- normalize_footnotes(footnotes)
  if (length(footnote_vec) > 0) {
    for (ft_note in footnote_vec) {
      ft <- flextable::add_footer_lines(ft, values = ft_note)
    }
  }
  ft
}

save_table_docx <- function(file, table_obj, title = "导出结果", footnotes = NULL) {
  ft <- build_sci_flextable(table_obj = table_obj, title = title, footnotes = footnotes)
  flextable::save_as_docx("Table" = ft, path = file)
  invisible(TRUE)
}

extract_table_for_export <- function(result_obj) {
  if (is.list(result_obj) && !is.null(result_obj$table)) {
    return(result_obj$table)
  }
  result_obj
}

save_table_export <- function(file, result_obj, format = "word", title = "导出结果", footnotes = NULL, report_md = NULL, method_name = "统计分析") {
  fmt <- tolower(if (is.null(format) || !nzchar(format)) "word" else format)
  fmt <- switch(fmt, docx = "word", fmt)
  table_obj <- extract_table_for_export(result_obj)
  if (identical(fmt, "word")) {
    save_table_docx(file = file, table_obj = table_obj, title = title, footnotes = footnotes)
    return(invisible(TRUE))
  }
  if (!fmt %in% c("html", "rtf")) {
    stop("仅支持 word/html/rtf 导出格式")
  }
  if (!requireNamespace("rmarkdown", quietly = TRUE)) {
    stop("导出 HTML/RTF 需要安装 rmarkdown 包")
  }
  rendered_table <- if (inherits(table_obj, "gt_tbl")) {
    apply_sci_gt_style(table_obj, title = title, footnotes = footnotes)
  } else if (is.data.frame(table_obj)) {
    apply_sci_gt_style(gt::gt(table_obj), title = title, footnotes = footnotes)
  } else {
    txt <- paste(capture.output(print(table_obj)), collapse = "\n")
    data.frame(Result = strsplit(txt, "\n", fixed = TRUE)[[1]], stringsAsFactors = FALSE)
  }
  payload <- list(
    rendered_table = rendered_table,
    report_md = if (is.null(report_md)) "" else as.character(report_md),
    method_name = if (is.null(method_name)) "统计分析" else as.character(method_name)
  )
  tmp_rds <- tempfile(fileext = ".rds")
  saveRDS(payload, tmp_rds)
  tmp_rds <- normalizePath(tmp_rds, winslash = "/", mustWork = FALSE)
  rmd_content <- paste0(
    "---\n",
    "title: \"统计分析报告\"\n",
    "params:\n",
    "  payload_rds: \"\"\n",
    "  method_name: \"\"\n",
    "---\n\n",
    "## 分析方法\n\n",
    "方法：`r params$method_name`\n\n",
    "## 统计报告\n\n",
    "```{r, echo=FALSE, results='asis'}\n",
    "payload <- readRDS(params$payload_rds)\n",
    "if (nzchar(trimws(payload$report_md))) cat(payload$report_md)\n",
    "```\n\n",
    "## 统计结果表\n\n",
    "```{r, echo=FALSE, results='asis'}\n",
    "payload <- readRDS(params$payload_rds)\n",
    "table_obj <- payload$rendered_table\n",
    "if (inherits(table_obj, 'gt_tbl')) {\n",
    "  table_obj\n",
    "} else if (is.data.frame(table_obj)) {\n",
    "  knitr::kable(table_obj, format='pipe')\n",
    "} else {\n",
    "  txt <- paste(capture.output(print(table_obj)), collapse='\\n')\n",
    "  knitr::kable(data.frame(Result = strsplit(txt, '\\n', fixed = TRUE)[[1]]), format='pipe')\n",
    "}\n",
    "```\n"
  )
  tmp_rmd <- tempfile(fileext = ".Rmd")
  writeLines(rmd_content, tmp_rmd)
  output_format <- switch(fmt, html = "html_document", rtf = "rtf_document", "word_document")
  rmarkdown::render(
    input = tmp_rmd,
    output_format = output_format,
    output_file = basename(file),
    output_dir = dirname(file),
    params = list(payload_rds = tmp_rds, method_name = payload$method_name),
    envir = new.env(parent = globalenv()),
    quiet = TRUE
  )
  invisible(TRUE)
}
