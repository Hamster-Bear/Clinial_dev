build_table_export_filename <- function(prefix, format, include_time = FALSE) {
  export_format <- tolower(if (is.null(format) || !nzchar(format)) "docx" else format)
  # 规范化：内部 "word" 映射为文件扩展名 "docx"
  export_format <- switch(export_format, word = "docx", export_format)
  stamp <- if (include_time) format(Sys.time(), "%Y%m%d_%H%M%S") else as.character(Sys.Date())
  paste0(prefix, "_", stamp, ".", export_format)
}

format_p_value_ama <- function(x) {
  # 处理已经是字符串且可能是占位符的情况
  if (is.character(x) && length(x) == 1 && (x == "NA" || x == "—" || x == "")) {
    return("—")
  }
  
  val <- suppressWarnings(as.numeric(x))
  if (is.na(val)) {
    return("—")
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
  # rtables 对象通过 matrix_form 提取多列结构
  if (inherits(table_obj, "TableTree") || inherits(table_obj, "InstantiatedColumnInfo")) {
    mf <- tryCatch(matrix_form(table_obj), error = function(e) NULL)
    if (!is.null(mf) && is.matrix(mf$strings) && nrow(mf$strings) > 1 && ncol(mf$strings) > 0) {
      col_names <- as.character(mf$strings[1, ])
      col_names[!nzchar(col_names)] <- "Row"
      col_names <- make.unique(col_names, sep = "_")
      data_mat <- mf$strings[-1, , drop = FALSE]
      if (ncol(data_mat) == length(col_names)) {
        df <- as.data.frame(data_mat, stringsAsFactors = FALSE)
        names(df) <- col_names
        return(df)
      }
    }
  }
  if (inherits(table_obj, "gt_tbl")) {
    gt_data <- tryCatch(table_obj[["_data"]], error = function(e) NULL)
    gt_boxhead <- tryCatch(table_obj[["_boxhead"]], error = function(e) NULL)
    if (is.data.frame(gt_data) && is.data.frame(gt_boxhead) && all(c("var", "type", "column_label") %in% names(gt_boxhead))) {
      hidden_vars <- gt_boxhead$var[gt_boxhead$type == "hidden"]
      if (length(hidden_vars) > 0) {
        gt_data <- gt_data[, setdiff(names(gt_data), hidden_vars), drop = FALSE]
      }
      row_group_vars <- gt_boxhead$var[gt_boxhead$type == "row_group"]
      if (length(row_group_vars) > 0 && row_group_vars[[1]] %in% names(gt_data)) {
        rg <- row_group_vars[[1]]
        rg_vals <- as.character(gt_data[[rg]])
        same_as_prev <- c(FALSE, rg_vals[-1] == rg_vals[-length(rg_vals)])
        rg_vals[same_as_prev] <- ""
        gt_data[[rg]] <- rg_vals
        non_rg <- setdiff(names(gt_data), rg)
        gt_data <- gt_data[, c(rg, non_rg), drop = FALSE]
      }
      label_map <- stats::setNames(as.character(gt_boxhead$column_label), gt_boxhead$var)
      clean_label <- function(x) {
        trim_keep_nbsp <- function(y) {
          temp <- gsub("\u00A0", "\u0001", y, fixed = TRUE)
          temp <- gsub("^[ \t\r\n]+|[ \t\r\n]+$", "", temp, perl = TRUE)
          gsub("\u0001", "\u00A0", temp, fixed = TRUE)
        }
        txt <- gsub("(?i)<br\\s*/?>", "\n", x, perl = TRUE)
        txt <- gsub("<[^>]+>", "", txt)
        txt <- gsub("&nbsp;", " ", txt, fixed = TRUE)
        txt <- gsub("[ \t]*\n[ \t]*", "\n", txt, perl = TRUE)
        txt <- trim_keep_nbsp(txt)
        ifelse(!nzchar(txt), NA_character_, txt)
      }
      new_names <- vapply(names(gt_data), function(v) {
        raw <- label_map[[v]]
        if (is.null(raw) || is.na(raw)) {
          return(v)
        }
        lbl <- clean_label(raw)
        if (is.na(lbl)) {
          return(v)
        }
        lbl
      }, character(1))
      names(gt_data) <- make.unique(new_names, sep = "_")
      return(gt_data)
    }
    if (is.data.frame(gt_data)) {
      return(gt_data)
    }
  }
  txt <- graphics_with_showtext_paused(paste(capture.output(print(table_obj)), collapse = "\n"))
  data.frame(Result = strsplit(txt, "\n", fixed = TRUE)[[1]], stringsAsFactors = FALSE)
}

apply_sci_gt_style <- function(gt_table, title = NULL, footnotes = NULL, left_columns = 1) {
  boxhead <- tryCatch(gt_table[["_boxhead"]], error = function(e) NULL)
  if (is.data.frame(boxhead) && all(c("var", "type", "column_label") %in% names(boxhead))) {
    vis_idx <- which(as.character(boxhead[["type"]]) != "hidden")
    if (length(vis_idx) > 0) {
      label_map <- list()
      for (idx in vis_idx) {
        col_var <- as.character(boxhead[["var"]][[idx]])
        raw_label <- as.character(boxhead[["column_label"]][[idx]])
        clean_label <- gsub("**", "", raw_label, fixed = TRUE)
        if (!identical(clean_label, raw_label)) {
          if (grepl("<[^>]+>", clean_label)) {
            label_map[[col_var]] <- gt::md(clean_label)
          } else {
            label_map[[col_var]] <- clean_label
          }
        }
      }
      if (length(label_map) > 0) {
        gt_table <- do.call(gt::cols_label, c(list(.data = gt_table), label_map))
      }
    }
  }
  all_cols <- if (is.data.frame(boxhead) && "var" %in% names(boxhead)) {
    type_vec <- if ("type" %in% names(boxhead)) as.character(boxhead[["type"]]) else rep("default", nrow(boxhead))
    as.character(boxhead[["var"]][type_vec != "hidden"])
  } else character(0)
  left_cols_resolved <- if (is.numeric(left_columns)) {
    if (length(all_cols) > 0) {
      all_cols[pmax(1, pmin(length(all_cols), as.integer(left_columns)))]
    } else {
      left_columns
    }
  } else {
    intersect(as.character(left_columns), all_cols)
  }
  center_cols <- if (length(all_cols) > 0) setdiff(all_cols, left_cols_resolved) else gt::everything()
  styled <- gt_table %>%
    gt::tab_options(
      table.font.names = c("Times New Roman", "SimSun", "sans"),
      table.font.size = gt::px(10),
      heading.align = "left",
      table.border.top.style = "none",
      table.border.bottom.style = "none",
      heading.border.bottom.style = "none",
      table_body.hlines.style = "none",
      table_body.vlines.style = "none",
      row_group.border.top.style = "none",
      row_group.border.bottom.style = "none",
      row_group.border.left.style = "none",
      row_group.border.right.style = "none",
      column_labels.border.top.style = "none",
      column_labels.border.bottom.style = "solid",
      column_labels.border.bottom.width = gt::px(0.8),
      table_body.border.top.style = "none",
      table_body.border.bottom.style = "none",
      stub.border.style = "none",
      heading.title.font.size = gt::px(10),
      heading.title.font.weight = "bold",
      source_notes.font.size = gt::px(9),
      table.width = gt::pct(100),
      container.width = gt::pct(100),
      data_row.padding = gt::px(3)
    ) %>%
    gt::cols_align(align = "center", columns = center_cols)
  if (length(left_cols_resolved) > 0) {
    styled <- styled %>% gt::cols_align(align = "left", columns = left_cols_resolved)
  }
  n_rows <- tryCatch(nrow(gt_table[["_data"]]), error = function(e) 0L)
  styled <- styled %>%
    gt::tab_style(
      style = gt::cell_borders(sides = "bottom", color = "black", weight = gt::px(0.8)),
      locations = gt::cells_column_labels(columns = gt::everything())
    )
  if (length(left_cols_resolved) > 0) {
    styled <- styled %>%
      gt::tab_style(
        style = gt::cell_text(align = "left"),
        locations = gt::cells_column_labels(columns = left_cols_resolved)
      ) %>%
      gt::tab_style(
        style = gt::cell_text(align = "left"),
        locations = gt::cells_body(columns = left_cols_resolved)
      )
  }
  if (!is.null(title) && nzchar(trimws(title))) {
    styled <- styled %>%
      gt::tab_header(title = gt::md(trimws(title))) %>%
      gt::tab_style(
        style = gt::cell_borders(sides = "bottom", color = "black", weight = gt::px(1.5)),
        locations = gt::cells_title(groups = "title")
      )
  }
  if (n_rows > 0) {
    styled <- styled %>%
      gt::tab_style(
        style = gt::cell_borders(sides = "bottom", color = "black", weight = gt::px(1.5)),
        locations = gt::cells_body(rows = n_rows, columns = gt::everything())
      )
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
  tryCatch({
    if (inherits(table_obj, "ggplot")) {
      tryCatch({
        ggsave(filename = file, plot = table_obj, width = width, height = height, dpi = dpi, bg = "white")
      }, error = function(e) {
        stop(sprintf("ggplot 对象 PNG 导出失败: %s", conditionMessage(e)))
      })
      return(invisible(TRUE))
    }
    if (inherits(table_obj, "gt_tbl")) {
      if (!requireNamespace("webshot2", quietly = TRUE)) {
        stop("表格 PNG 导出需要 webshot2 包。请运行 install.packages('webshot2') 安装。")
      }
      tryCatch({
        gt_obj <- apply_sci_gt_style(table_obj, title = title, footnotes = footnotes)
        gt::gtsave(data = gt_obj, filename = file)
      }, error = function(e) {
        stop(sprintf("gt 表格 PNG 导出失败: %s", conditionMessage(e)))
      })
      return(invisible(TRUE))
    }
    if (is.data.frame(table_obj)) {
      tryCatch({
        grDevices::png(filename = file, width = width, height = height, units = "in", res = dpi, bg = "white")
        on.exit(grDevices::dev.off(), add = TRUE)
        grid::grid.newpage()
        grid::grid.draw(gridExtra::tableGrob(table_obj))
      }, error = function(e) {
        stop(sprintf("data.frame 表格 PNG 导出失败: %s", conditionMessage(e)))
      })
      return(invisible(TRUE))
    }
    tryCatch({
      text_content <- graphics_with_showtext_paused(paste(capture.output(print(table_obj)), collapse = "\n"))
      data_frame <- data.frame(Result = strsplit(text_content, "\n", fixed = TRUE)[[1]], stringsAsFactors = FALSE)
      grDevices::png(filename = file, width = width, height = height, units = "in", res = dpi, bg = "white")
      on.exit(grDevices::dev.off(), add = TRUE)
      grid::grid.newpage()
      grid::grid.draw(gridExtra::tableGrob(data_frame))
    }, error = function(e) {
      stop(sprintf("文本回退表格 PNG 导出失败: %s", conditionMessage(e)))
    })
    invisible(TRUE)
  }, error = function(e) {
    msg <- sprintf("[TableExportError] PNG export failed: %s", conditionMessage(e))
    message(msg)
    stop(msg)
  })
}

build_sci_flextable <- function(table_obj, title = "导出结果", footnotes = NULL, merge_first_col = TRUE) {
  if (!requireNamespace("flextable", quietly = TRUE) || !requireNamespace("officer", quietly = TRUE)) {
    stop("导出 Word 需要安装 flextable 和 officer 包")
  }
  clean_gt_label <- function(x) {
    trim_keep_nbsp <- function(y) {
      temp <- gsub("\u00A0", "\u0001", y, fixed = TRUE)
      temp <- gsub("^[ \t\r\n]+|[ \t\r\n]+$", "", temp, perl = TRUE)
      gsub("\u0001", "\u00A0", temp, fixed = TRUE)
    }
    txt <- gsub("(?i)<br\\s*/?>", "\n", as.character(x), perl = TRUE)
    txt <- gsub("\\s{2,}\\n", "\n", txt, perl = TRUE)
    txt <- gsub("<[^>]+>", "", txt)
    txt <- gsub("&nbsp;", " ", txt, fixed = TRUE)
    txt <- gsub("[ \t]*\n[ \t]*", "\n", txt, perl = TRUE)
    txt <- gsub("\\s*\\(N\\s*=\\s*([^\\)]+)\\)", "\n(N = \\1)", txt, perl = TRUE)
    txt <- gsub("\n{2,}", "\n", txt, perl = TRUE)
    trim_keep_nbsp(txt)
  }
  df <- extract_table_dataframe(table_obj)
  ft <- NULL
  left_col_keys <- character(0)
  spanner_runs <- list()
  has_spanner_header <- FALSE
  if (inherits(table_obj, "gt_tbl")) {
    gt_data <- tryCatch(table_obj[["_data"]], error = function(e) NULL)
    gt_boxhead <- tryCatch(table_obj[["_boxhead"]], error = function(e) NULL)
    if (is.data.frame(gt_data) && is.data.frame(gt_boxhead) && all(c("var", "type", "column_label") %in% names(gt_boxhead))) {
      var_vec <- as.character(gt_boxhead[["var"]])
      type_vec <- as.character(gt_boxhead[["type"]])
      label_vec <- as.character(gt_boxhead[["column_label"]])
      align_vec <- if ("column_align" %in% names(gt_boxhead)) as.character(gt_boxhead[["column_align"]]) else rep("center", length(var_vec))
      col_keys <- var_vec[type_vec != "hidden"]
      col_keys <- col_keys[col_keys %in% names(gt_data)]
      if (length(col_keys) > 0) {
        col_align <- vapply(col_keys, function(v) {
          idx <- which(var_vec == v)[1]
          if (is.na(idx)) "center" else align_vec[[idx]]
        }, character(1))
        left_col_keys <- col_keys[tolower(col_align) == "left"]
        df <- gt_data[, col_keys, drop = FALSE]
        row_group_vars <- var_vec[type_vec == "row_group"]
        if (length(row_group_vars) > 0 && row_group_vars[[1]] %in% names(df)) {
          rg <- row_group_vars[[1]]
          rg_vals <- as.character(df[[rg]])
          same_as_prev <- c(FALSE, rg_vals[-1] == rg_vals[-length(rg_vals)])
          rg_vals[same_as_prev] <- ""
          df[[rg]] <- rg_vals
        }
        labels <- vapply(col_keys, function(v) {
          raw <- label_vec[which(var_vec == v)[1]]
          lbl <- clean_gt_label(raw)
          if (!nzchar(lbl)) v else lbl
        }, character(1))
        label_map <- stats::setNames(as.list(labels), col_keys)
        gt_spanners <- tryCatch(table_obj[["_spanners"]], error = function(e) NULL)
        run_labels <- character(0)
        if (is.data.frame(gt_spanners) && all(c("vars", "spanner_label") %in% names(gt_spanners)) && nrow(gt_spanners) > 0) {
          sp_map <- stats::setNames(rep("", length(col_keys)), col_keys)
          for (i in seq_len(nrow(gt_spanners))) {
            members <- trimws(unlist(strsplit(as.character(gt_spanners$vars[[i]]), ",", fixed = TRUE)))
            members <- intersect(members, col_keys)
            if (length(members) > 0) {
              sp_label <- clean_gt_label(gt_spanners$spanner_label[[i]])
              sp_map[members] <- sp_label
            }
          }
          if (any(nzchar(sp_map))) {
            vals <- character(0)
            widths <- integer(0)
            idx <- 1L
            while (idx <= length(col_keys)) {
              current <- sp_map[[idx]]
              end_idx <- idx
              while (end_idx < length(col_keys) && identical(sp_map[[end_idx + 1L]], current)) {
                end_idx <- end_idx + 1L
              }
              if (nzchar(current)) {
                spanner_runs[[length(spanner_runs) + 1L]] <- idx:end_idx
                run_labels <- c(run_labels, current)
              }
              idx <- end_idx + 1L
            }
            has_spanner_header <- TRUE
          }
        }
        gap_cols <- character(0)
        if (has_spanner_header && length(spanner_runs) > 1) {
          run_end_cols <- vapply(spanner_runs, function(run) max(run), integer(1))
          split_cols <- run_end_cols[run_end_cols < length(col_keys)]
          old_to_new <- integer(length(col_keys))
          new_keys <- character(0)
          for (idx in seq_along(col_keys)) {
            new_keys <- c(new_keys, col_keys[[idx]])
            old_to_new[[idx]] <- length(new_keys)
            split_pos <- which(split_cols == idx)
            if (length(split_pos) > 0) {
              gap_name <- paste0(".gap_", split_pos[[1]])
              df[[gap_name]] <- ""
              label_map[[gap_name]] <- ""
              gap_cols <- c(gap_cols, gap_name)
              new_keys <- c(new_keys, gap_name)
            }
          }
          col_keys <- new_keys
          spanner_runs <- lapply(spanner_runs, function(run) old_to_new[run])
        }
        df <- df[, col_keys, drop = FALSE]
        ft <- flextable::flextable(df, col_keys = col_keys)
        ft <- flextable::set_header_labels(ft, values = label_map[col_keys])
        if (has_spanner_header && length(spanner_runs) > 0) {
          sp_map_final <- stats::setNames(rep("", length(col_keys)), col_keys)
          for (i in seq_along(spanner_runs)) {
            sp_map_final[spanner_runs[[i]]] <- run_labels[[i]]
          }
          vals <- character(0)
          widths <- integer(0)
          idx <- 1L
          while (idx <= length(col_keys)) {
            current <- sp_map_final[[idx]]
            end_idx <- idx
            while (end_idx < length(col_keys) && identical(sp_map_final[[end_idx + 1L]], current)) {
              end_idx <- end_idx + 1L
            }
            vals <- c(vals, current)
            widths <- c(widths, end_idx - idx + 1L)
            idx <- end_idx + 1L
          }
          ft <- flextable::add_header_row(ft, values = vals, colwidths = widths, top = TRUE)
        }
        if (length(gap_cols) > 0) {
          body_font_size_pt <- 10
          gap_char_width_in <- (body_font_size_pt / 72) * 0.5
          ft <- flextable::width(ft, j = gap_cols, width = gap_char_width_in)
        }
      }
    }
  }
  if (is.null(ft)) {
    ft <- flextable::flextable(df)
  }
  ft <- flextable::border_remove(ft)
  thick_border <- officer::fp_border(color = "black", width = 1.5)
  thin_border <- officer::fp_border(color = "black", width = 0.8)
  ft <- flextable::hline_top(ft, border = thick_border, part = "all")
  if (isTRUE(has_spanner_header) && length(spanner_runs) > 0) {
    for (run in spanner_runs) {
      ft <- flextable::hline(ft, i = 1, j = run, border = thin_border, part = "header")
    }
  } else {
    ft <- flextable::hline(ft, i = 1, border = thin_border, part = "header")
  }
  ft <- flextable::hline_bottom(ft, border = thick_border, part = "all")
  ft <- flextable::font(ft, fontname = "Times New Roman", part = "all")
  ft <- flextable::fontsize(ft, size = 10, part = "all")
  ft <- flextable::align(ft, align = "center", part = "header")
  if (ncol(df) > 0) {
    left_idx <- suppressWarnings(match(left_col_keys, names(df)))
    left_idx <- left_idx[!is.na(left_idx)]
    if (length(left_idx) == 0) {
      left_idx <- 1L
    }
    center_idx <- setdiff(seq_len(ncol(df)), left_idx)
    ft <- flextable::align(ft, j = left_idx, align = "left", part = "all")
    if (length(center_idx) > 0) {
      ft <- flextable::align(ft, j = center_idx, align = "center", part = "all")
    }
    if (isTRUE(merge_first_col)) {
      ft <- flextable::merge_v(ft, j = 1)
    }
  }
  ft <- flextable::autofit(ft)
  ft <- flextable::fit_to_width(ft, max_width = 6.5)
  ft <- flextable::set_table_properties(ft, layout = "autofit", width = 1)
  if (!is.null(title) && nzchar(trimws(title))) {
    ft <- flextable::set_caption(
      ft,
      caption = flextable::as_paragraph(
        flextable::as_chunk(
          trimws(title),
          props = officer::fp_text(font.family = "Times New Roman", font.size = 10, bold = TRUE)
        )
      )
    )
  }
  footnote_vec <- normalize_footnotes(footnotes)
  if (length(footnote_vec) > 0) {
    for (ft_note in footnote_vec) {
      ft <- flextable::add_footer_lines(ft, values = ft_note)
    }
    ft <- flextable::font(ft, fontname = "Times New Roman", part = "footer")
    ft <- flextable::fontsize(ft, size = 9, part = "footer")
    ft <- flextable::align(ft, align = "left", part = "footer")
  }
  ft
}

markdown_to_doc_lines <- function(report_md) {
  if (is.null(report_md) || !nzchar(trimws(report_md))) {
    return(character(0))
  }
  lines <- unlist(strsplit(as.character(report_md), "\\r?\\n"))
  lines <- gsub("^#{1,6}\\s*", "", lines, perl = TRUE)
  lines <- gsub("^[-*+]\\s+", "• ", lines, perl = TRUE)
  lines <- gsub("`", "", lines, fixed = TRUE)
  lines <- trimws(lines)
  lines[nzchar(lines)]
}

rtables_to_flextable <- function(tbl, title = NULL, footnotes = NULL) {
  if (!requireNamespace("flextable", quietly = TRUE) || !requireNamespace("officer", quietly = TRUE)) {
    stop("导出 Word 需要安装 flextable 和 officer 包")
  }
  mf <- matrix_form(tbl)
  mat <- mf$strings
  ri <- mf$row_info

  if (!is.matrix(mat) || nrow(mat) < 2 || ncol(mat) < 1) {
    stop("matrix_form 返回的矩阵结构异常")
  }

  # 第一行作为列名，其余为数据
  col_names <- as.character(mat[1, ])
  col_names[!nzchar(col_names)] <- "Row"
  col_names <- make.unique(col_names, sep = "_")
  data_mat <- mat[-1, , drop = FALSE]

  if (ncol(data_mat) != length(col_names)) {
    stop(sprintf("列数不匹配: 数据 %d 列, 列名 %d 个", ncol(data_mat), length(col_names)))
  }

  df <- as.data.frame(data_mat, stringsAsFactors = FALSE)
  names(df) <- col_names

  # 构建 flextable
  ft <- flextable::flextable(df)

  # 行标签缩进：ri 是 data.frame，第一行对应 mat[1,]（表头），跳过
  if (is.data.frame(ri) && nrow(ri) > 1) {
    ri_body <- ri[-1, , drop = FALSE]
    indent_vals <- vapply(seq_len(nrow(ri_body)), function(i) {
      node_class <- ri_body$node_class[i]
      path_raw <- ri_body$path[[i]]
      path_str <- paste(path_raw, collapse = " ")
      if (identical(node_class, "LabelRow")) {
        0L
      } else if (grepl("USUBJID|analyze_num_patients", path_str)) {
        # 分析行（Total patients/events）在顶层，不缩进
        0L
      } else if (grepl("PT", path_str)) {
        # SOC > PT 下的 DataRow，缩进
        2L
      } else {
        0L
      }
    }, integer(1))
  } else {
    indent_vals <- rep(0L, nrow(df))
  }

  # 应用样式
  ft <- flextable::border_remove(ft)
  thick_border <- officer::fp_border(color = "black", width = 1.5)
  thin_border <- officer::fp_border(color = "black", width = 0.8)
  ft <- flextable::hline_top(ft, border = thick_border, part = "all")
  ft <- flextable::hline(ft, i = 1, border = thin_border, part = "header")
  ft <- flextable::hline_bottom(ft, border = thick_border, part = "all")
  ft <- flextable::font(ft, fontname = "Times New Roman", part = "all")
  ft <- flextable::fontsize(ft, size = 10, part = "all")
  ft <- flextable::align(ft, align = "center", part = "header")

  # 行标签左对齐，数据列居中（按 matrix_form aligns）
  ft <- flextable::align(ft, j = 1, align = "left", part = "all")
  if (ncol(df) > 1) {
    ft <- flextable::align(ft, j = seq_len(ncol(df))[-1], align = "center", part = "all")
  }

  # 行标签缩进
  if (any(indent_vals > 0)) {
    indent_rows <- which(indent_vals > 0)
    for (ir in indent_rows) {
      ft <- flextable::padding(ft, i = ir, j = 1, padding.left = indent_vals[ir] * 10, part = "body")
    }
  }

  ft <- flextable::autofit(ft)
  ft <- flextable::fit_to_width(ft, max_width = 6.5)
  ft <- flextable::set_table_properties(ft, layout = "autofit", width = 1)

  # 标题
  if (!is.null(title) && nzchar(trimws(title))) {
    ft <- flextable::set_caption(
      ft,
      caption = flextable::as_paragraph(
        flextable::as_chunk(
          trimws(title),
          props = officer::fp_text(font.family = "Times New Roman", font.size = 10, bold = TRUE)
        )
      )
    )
  }

  # 脚注
  footnote_vec <- normalize_footnotes(footnotes)
  if (length(footnote_vec) > 0) {
    for (ft_note in footnote_vec) {
      ft <- flextable::add_footer_lines(ft, values = ft_note)
    }
    ft <- flextable::font(ft, fontname = "Times New Roman", part = "footer")
    ft <- flextable::fontsize(ft, size = 9, part = "footer")
    ft <- flextable::align(ft, align = "left", part = "footer")
  }

  ft
}

save_table_docx <- function(file, table_obj, title = "导出结果", footnotes = NULL, report_md = NULL, method_name = "统计分析", include_report = FALSE, merge_first_col = TRUE) {
  # rtables 对象走专用转换路径，保留多列结构；失败则降级到通用路径
  if (inherits(table_obj, "TableTree") || inherits(table_obj, "InstantiatedColumnInfo")) {
    ft <- tryCatch(
      rtables_to_flextable(table_obj, title = title, footnotes = footnotes),
      error = function(e) {
        message(sprintf("[rtables_to_flextable] 降级到文本回退: %s", conditionMessage(e)))
        NULL
      }
    )
    if (!is.null(ft)) {
      df <- NULL
    } else {
      df <- extract_table_dataframe(table_obj)
      ft <- build_sci_flextable(table_obj = df, title = title, footnotes = footnotes, merge_first_col = merge_first_col)
    }
  } else {
    df <- extract_table_dataframe(table_obj)
    ft <- build_sci_flextable(table_obj = table_obj, title = title, footnotes = footnotes, merge_first_col = merge_first_col)
  }
  if (isTRUE(include_report)) {
    doc <- officer::read_docx()
    doc <- officer::body_add_par(doc, "统计分析报告", style = "heading 1")
    doc <- officer::body_add_par(doc, paste0("方法：", method_name), style = "Normal")
    report_lines <- markdown_to_doc_lines(report_md)
    if (length(report_lines) > 0) {
      for (line in report_lines) {
        doc <- officer::body_add_par(doc, line, style = "Normal")
      }
    }
    doc <- officer::body_add_par(doc, "统计结果表", style = "heading 2")
    doc <- flextable::body_add_flextable(doc, value = ft)
    print(doc, target = file)
    return(invisible(TRUE))
  }
  if (!is.null(df) && ncol(df) > 8) {
    sec <- officer::prop_section(
      page_size = officer::page_size(orient = "landscape"),
      page_margins = officer::page_mar()
    )
    flextable::save_as_docx("Table" = ft, path = file, pr_section = sec)
  } else {
    flextable::save_as_docx("Table" = ft, path = file)
  }
  invisible(TRUE)
}

extract_table_for_export <- function(result_obj) {
  if (is.list(result_obj) && !is.null(result_obj$table)) {
    return(result_obj$table)
  }
  result_obj
}

#' R 原生表格 PDF 导出（零外部依赖）
#'
#' 使用 grid::grid.table / gridExtra::tableGrob + grDevices::cairo_pdf 将表格
#' 渲染为 PDF，无需 Chromium、pandoc 或 rmarkdown。
#'
#' @param file 输出 PDF 文件路径
#' @param table_obj gt_tbl / data.frame / TableTree / InstantiatedColumnInfo 对象
#' @param width 页面宽度（英寸）
#' @param height 页面高度（英寸）
#' @param title 表格标题（可选）
#' @param footnotes 脚注字符向量（可选）
#' @param pointsize 基础字体大小（pt）
save_table_pdf_native <- function(file, table_obj, width = 10, height = 8,
                                   title = NULL, footnotes = NULL,
                                   pointsize = 10) {
  tryCatch({
    # 提取纯数据框（复用现有提取逻辑，处理 gt/rtables/data.frame/文本回退）
    df <- extract_table_dataframe(table_obj)
    if (!is.data.frame(df) || nrow(df) == 0) {
      stop("无法从表格对象提取有效数据")
    }

    # 统一列名为字符型，避免 tableGrob 显示 NA
    colnames(df) <- make.unique(ifelse(
      is.na(names(df)) | !nzchar(names(df)),
      paste0("Col", seq_along(names(df))),
      names(df)
    ), sep = "_")

    # 所有单元格转为字符
    df[] <- lapply(df, as.character)
    df[is.na(df)] <- ""

    font_family <- "sans"

    # 规范化脚注
    footnote_vec <- normalize_footnotes(footnotes)
    has_title <- !is.null(title) && nzchar(trimws(title))
    has_footnotes <- length(footnote_vec) > 0

    # 计算布局行数
    n_parts <- 1L  # 表格本体
    if (has_title) n_parts <- n_parts + 1L
    if (has_footnotes) n_parts <- n_parts + length(footnote_vec)

    # 高度分配
    heights <- rep(1, n_parts)
    title_row <- NULL
    table_row <- 1L
    fn_start <- NULL

    if (has_title && has_footnotes) {
      heights <- c(0.08, 0.82, rep(0.10 / length(footnote_vec), length(footnote_vec)))
      title_row <- 1L
      table_row <- 2L
      fn_start <- 3L
    } else if (has_title) {
      heights <- c(0.08, 0.92)
      title_row <- 1L
      table_row <- 2L
    } else if (has_footnotes) {
      heights <- c(0.90, rep(0.10 / length(footnote_vec), length(footnote_vec)))
      table_row <- 1L
      fn_start <- 2L
    }

    # 打开 PDF 设备（优先 Cairo，兜底基础 pdf）
    device_ok <- tryCatch({
      grDevices::cairo_pdf(file, width = width, height = height,
                           pointsize = pointsize, bg = "white")
      TRUE
    }, error = function(e) {
      message(sprintf("[TableExport] cairo_pdf 不可用，回退到基础 pdf 设备: %s",
                      conditionMessage(e)))
      FALSE
    })
    if (!isTRUE(device_ok)) {
      grDevices::pdf(file, width = width, height = height,
                     pointsize = pointsize, bg = "white")
    }
    on.exit(grDevices::dev.off(), add = TRUE)

    grid::grid.newpage()

    # 创建网格布局
    grid::pushViewport(grid::viewport(
      layout = grid::grid.layout(n_parts, 1,
                                  heights = grid::unit(heights, "npc"))
    ))

    # 标题
    if (has_title) {
      grid::pushViewport(grid::viewport(layout.pos.row = title_row, layout.pos.col = 1))
      grid::grid.text(
        trimws(title),
        x = grid::unit(0.02, "npc"), hjust = 0,
        gp = grid::gpar(fontsize = pointsize + 2, fontface = "bold",
                        fontfamily = font_family)
      )
      grid::popViewport()
    }

    # 表格主体
    grid::pushViewport(grid::viewport(layout.pos.row = table_row, layout.pos.col = 1))
    tbl_theme <- gridExtra::ttheme_default(
      base_size = pointsize,
      base_family = font_family,
      padding = grid::unit(c(2, 4), "mm"),
      core = list(
        fg_params = list(hjust = 0, x = 0.02),
        bg_params = list(fill = "white")
      ),
      colhead = list(
        fg_params = list(fontface = "bold", hjust = 0, x = 0.02),
        bg_params = list(fill = "#f5f5f5")
      )
    )
    tbl_grob <- gridExtra::tableGrob(
      df,
      rows = NULL,
      theme = tbl_theme
    )
    grid::grid.draw(tbl_grob)
    grid::popViewport()

    # 脚注
    if (has_footnotes) {
      for (i in seq_along(footnote_vec)) {
        grid::pushViewport(grid::viewport(
          layout.pos.row = fn_start + i - 1L,
          layout.pos.col = 1
        ))
        grid::grid.text(
          footnote_vec[i],
          x = grid::unit(0.02, "npc"), hjust = 0,
          gp = grid::gpar(fontsize = pointsize - 2, fontfamily = font_family)
        )
        grid::popViewport()
      }
    }

    invisible(TRUE)
  }, error = function(e) {
    msg <- sprintf("[TableExportError] Native PDF export failed: %s",
                   conditionMessage(e))
    message(msg)
    stop(msg)
  })
}

save_table_export <- function(file, result_obj, format = "word", title = "导出结果", footnotes = NULL, report_md = NULL, method_name = "统计分析", include_report = FALSE, merge_first_col = TRUE) {
  fmt <- tolower(if (is.null(format) || !nzchar(format)) "word" else format)
  fmt <- switch(fmt, docx = "word", fmt)
  table_obj <- extract_table_for_export(result_obj)
  if (identical(fmt, "word")) {
    save_table_docx(file = file, table_obj = table_obj, title = title, footnotes = footnotes, report_md = report_md, method_name = method_name, include_report = include_report, merge_first_col = merge_first_col)
    return(invisible(TRUE))
  }
  if (!fmt %in% c("html", "rtf", "pdf")) {
    stop("仅支持 word/html/rtf/pdf 导出格式")
  }
  prereq_err <- graphics_check_export_prerequisites(fmt)
  if (!is.null(prereq_err)) {
    stop(prereq_err)
  }

  # PDF 格式走 R 原生路径（零外部依赖），不走 rmarkdown→chrome_print
  if (identical(fmt, "pdf")) {
    if (isTRUE(include_report)) {
      stop("PDF 导出暂不支持附带分析报告。请使用 Word 格式导出完整报告。")
    }
    save_table_pdf_native(
      file = file,
      table_obj = table_obj,
      width = 10,
      height = 8,
      title = title,
      footnotes = footnotes
    )
    return(invisible(TRUE))
  }

  rendered_table <- if (inherits(table_obj, "gt_tbl")) {
    apply_sci_gt_style(table_obj, title = title, footnotes = footnotes)
  } else if (is.data.frame(table_obj)) {
    apply_sci_gt_style(gt::gt(table_obj), title = title, footnotes = footnotes)
  } else {
    txt <- graphics_with_showtext_paused(paste(capture.output(print(table_obj)), collapse = "\n"))
    data.frame(Result = strsplit(txt, "\n", fixed = TRUE)[[1]], stringsAsFactors = FALSE)
  }
  payload <- list(
    rendered_table = rendered_table,
    report_md = if (is.null(report_md)) "" else as.character(report_md),
    method_name = if (is.null(method_name)) "统计分析" else as.character(method_name),
    include_report = isTRUE(include_report)
  )
  tmp_rds <- tempfile(fileext = ".rds")
  saveRDS(payload, tmp_rds)
  tmp_rds <- normalizePath(tmp_rds, winslash = "/", mustWork = FALSE)
  if (isTRUE(payload$include_report)) {
    rmd_content <- paste0(
      "---\n",
      "title: \"\"\n",
      "params:\n",
      "  payload_rds: \"\"\n",
      "  method_name: \"\"\n",
      "---\n\n",
      "```{r, echo=FALSE, results='asis'}\n",
      "payload <- readRDS(params$payload_rds)\n",
      "cat(payload$report_md)\n",
      "```\n\n",
      "## Table\n\n",
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
  } else {
    rmd_content <- paste0(
      "---\n",
      "title: \"\"\n",
      "params:\n",
      "  payload_rds: \"\"\n",
      "  method_name: \"\"\n",
      "---\n\n",
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
  }
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
