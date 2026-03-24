# 描述性统计模块 - 增强版

# 加载必要库
library(dplyr)
library(tidyr)
library(gt)
library(stringr)

# 描述性统计参数UI

# 描述性统计参数UI
desc_params_ui <- function(ns, data) {
  var_names <- names(data)
  default_id_var <- if ("subject" %in% var_names) "subject" else if (length(var_names) > 0) var_names[1] else NULL
  
  tagList(
    selectizeInput(ns("desc_variables"), "选择分析变量", choices = var_names, multiple = TRUE),
    selectInput(ns("desc_col_group_var"), "列分组变量 (可选)", choices = c("无", var_names)),
    selectInput(ns("desc_row_group_var"), "行分组变量 (可选)", choices = c("无", var_names)),
    selectInput(ns("desc_id_var"), "唯一标识符变量", choices = var_names, selected = default_id_var),
    
    # 使用与回归一致的公共 UI 渲染函数
    uiOutput(ns("desc_total_cols_ui")),
    
    numericInput(ns("desc_decimals"), "小数位数", value = 2, min = 0, max = 5),
    checkboxInput(ns("desc_auto_decimals"), "使用自动小数位数", value = TRUE)
  )
}

# 计算变量的原始数据小数位数
calculate_original_decimals <- function(data, variables) {
  numeric_vars <- variables[sapply(data[, variables, drop = FALSE], is.numeric)]
  decimal_info <- list()
  
  for(var in numeric_vars) {
    # 获取非缺失值
    values <- na.omit(data[[var]])
    if(length(values) == 0) {
      decimal_info[[var]] <- 0
      next
    }
    
    # 计算原始数据的小数位数
    decimals <- sapply(values, function(x) {
      if(is.integer(x) || x == round(x)) return(0)
      # 转换为字符串并计算小数位数
      x_str <- as.character(x)
      if(grepl("\\.", x_str)) {
        return(nchar(strsplit(x_str, "\\.")[[1]][2]))
      } else {
        return(0)
      }
    })
    
    # 取最常见的小数位数
    if(length(decimals) > 0) {
      decimal_counts <- table(decimals)
      most_common <- as.numeric(names(decimal_counts)[which.max(decimal_counts)])
      decimal_info[[var]] <- most_common
    } else {
      decimal_info[[var]] <- 0
    }
  }
  
  return(decimal_info)
}

# 描述性统计分析
perform_desc_analysis <- function(data, variables, col_group_var, row_group_var, total_cols_count, total_cols_settings, decimals, auto_decimals = TRUE, id_var = NULL) {
  if (is.null(data) || !is.data.frame(data)) {
    stop("数据不能为空，且必须为数据框")
  }
  if (is.null(variables) || length(variables) == 0) {
    stop("请至少选择一个分析变量")
  }
  if (!all(variables %in% names(data))) {
    stop("存在未在数据中找到的分析变量")
  }
  if (!is.null(id_var) && !id_var %in% names(data)) {
    stop("唯一标识符变量不存在于数据中")
  }

  df <- data
  vars <- variables
  col_group_var <- if (col_group_var != "无") col_group_var else NULL
  row_group_var <- if (row_group_var != "无") row_group_var else NULL
  is_categorical_group_var <- function(x) {
    is.factor(x) || is.character(x) || is.logical(x)
  }
  if (!is.null(col_group_var) && !col_group_var %in% names(df)) {
    stop("列分组变量不存在于数据中")
  }
  if (!is.null(row_group_var) && !row_group_var %in% names(df)) {
    stop("行分组变量不存在于数据中")
  }
  if (!is.null(col_group_var) && !is_categorical_group_var(df[[col_group_var]])) {
    stop("列分组变量仅支持分类型变量")
  }
  if (!is.null(row_group_var) && !is_categorical_group_var(df[[row_group_var]])) {
    stop("行分组变量仅支持分类型变量")
  }
  if (!is.null(col_group_var) && !is.null(row_group_var) && identical(col_group_var, row_group_var)) {
    stop("行分组变量与列分组变量不能相同")
  }
  overlap_vars <- intersect(vars, c(col_group_var, row_group_var))
  if (length(overlap_vars) > 0) {
    stop(paste0("分析变量不能与分组变量重复: ", paste(overlap_vars, collapse = ", ")))
  }

  numeric_vars <- vars[sapply(df[, vars, drop = FALSE], is.numeric)]
  factor_vars <- setdiff(vars, numeric_vars)
  auto_decimals_info <- if (auto_decimals && length(numeric_vars) > 0) calculate_original_decimals(df, numeric_vars) else list()
  stat_levels <- c("n", "Mean (SD)", "Median", "Q1, Q3", "Min, Max")

  format_num <- function(x, digits) {
    if (is.na(x) || !is.finite(x)) return("NA")
    sprintf(paste0("%.", digits, "f"), x)
  }

  stat_digits <- function(var) {
    if (auto_decimals && var %in% names(auto_decimals_info)) {
      base_decimals <- auto_decimals_info[[var]]
      list(mean = base_decimals + 1, sd = base_decimals + 2, minmax = base_decimals, q = base_decimals + 1)
    } else {
      list(mean = decimals, sd = decimals, minmax = decimals, q = decimals)
    }
  }

  calc_cont_stats <- function(x, digits_cfg) {
    x <- x[!is.na(x)]
    n <- length(x)
    if (n == 0) {
      return(c("n" = "0", "Mean (SD)" = "NA", "Median" = "NA", "Q1, Q3" = "NA", "Min, Max" = "NA"))
    }
    mean_txt <- format_num(mean(x), digits_cfg$mean)
    sd_val <- sd(x)
    sd_txt <- format_num(sd_val, digits_cfg$sd)
    median_txt <- format_num(median(x), digits_cfg$mean)
    q1_txt <- format_num(quantile(x, 0.25, na.rm = TRUE), digits_cfg$q)
    q3_txt <- format_num(quantile(x, 0.75, na.rm = TRUE), digits_cfg$q)
    min_txt <- format_num(min(x), digits_cfg$minmax)
    max_txt <- format_num(max(x), digits_cfg$minmax)
    c(
      "n" = as.character(n),
      "Mean (SD)" = paste0(mean_txt, " (", sd_txt, ")"),
      "Median" = median_txt,
      "Q1, Q3" = paste0(q1_txt, ", ", q3_txt),
      "Min, Max" = paste0(min_txt, ", ", max_txt)
    )
  }

  normalize_group_var <- function(df_in, group_var) {
    if (is.null(group_var)) return(df_in)
    df_in[[group_var]] <- ifelse(is.na(df_in[[group_var]]), "缺失", as.character(df_in[[group_var]]))
    df_in
  }

  build_factor_summary <- function(df_in, var, col_group_var = NULL, row_group_var = NULL, decimals = 2) {
    all_levels <- unique(as.character(df_in[[var]]))
    all_levels <- all_levels[!is.na(all_levels)]
    if (length(all_levels) == 0) {
      all_levels <- "缺失"
    }
    row_values <- if (is.null(row_group_var)) ".__ALL_ROW__" else unique(as.character(df_in[[row_group_var]]))
    col_values <- if (is.null(col_group_var)) ".__ALL_COL__" else unique(as.character(df_in[[col_group_var]]))
    if (length(row_values) == 0) row_values <- ".__ALL_ROW__"
    if (length(col_values) == 0) col_values <- ".__ALL_COL__"

    base_df <- df_in %>%
      mutate(
        .row = if (is.null(row_group_var)) ".__ALL_ROW__" else as.character(.data[[row_group_var]]),
        .col = if (is.null(col_group_var)) ".__ALL_COL__" else as.character(.data[[col_group_var]]),
        .level = ifelse(is.na(.data[[var]]), "缺失", as.character(.data[[var]]))
      )

    counts <- base_df %>%
      count(.row, .col, .level, name = "n") %>%
      complete(.row = row_values, .col = col_values, .level = all_levels, fill = list(n = 0)) %>%
      group_by(.row, .col) %>%
      mutate(
        den = sum(n),
        percent = ifelse(den > 0, n / den * 100, 0),
        stat = sprintf(paste0("%d (%.", decimals, "f%%)"), n, percent)
      ) %>%
      ungroup()

    if (!is.null(col_group_var)) {
      out <- counts %>%
        select(.row, .col, .level, stat) %>%
        pivot_wider(names_from = .col, values_from = stat, values_fill = sprintf(paste0("%d (%.", decimals, "f%%)"), 0, 0))
    } else {
      out <- counts %>%
        mutate(Total = stat) %>%
        select(.row, .level, Total) %>%
        distinct()
    }

    out$Variable <- var
    out$Statistics <- out$.level
    if (!is.null(row_group_var)) {
      out$RowGroup <- out$.row
      out <- out %>% select(Variable, RowGroup, Statistics, everything(), -.row, -.level)
    } else {
      out <- out %>% select(Variable, Statistics, everything(), -.row, -.level)
    }
    out
  }

  build_numeric_summary <- function(df_in, var, col_group_var = NULL, row_group_var = NULL, digits_cfg) {
    group_vars <- c(row_group_var, col_group_var)
    group_vars <- group_vars[!is.null(group_vars)]

    if (length(group_vars) == 0) {
      stats <- calc_cont_stats(df_in[[var]], digits_cfg)
      out <- data.frame(
        Variable = var,
        Statistics = names(stats),
        Total = as.character(stats),
        stringsAsFactors = FALSE
      )
      return(out)
    }

    long_df <- df_in %>%
      group_by(across(all_of(group_vars))) %>%
      summarise(stats = list(calc_cont_stats(.data[[var]], digits_cfg)), .groups = "drop") %>%
      unnest_wider(stats) %>%
      pivot_longer(cols = all_of(stat_levels), names_to = "Statistics", values_to = "stat")

    if (!is.null(col_group_var)) {
      wide_df <- long_df %>%
        pivot_wider(names_from = all_of(col_group_var), values_from = stat, values_fill = "NA")
    } else {
      wide_df <- long_df %>%
        mutate(Total = stat) %>%
        select(-stat)
    }

    wide_df$Variable <- var
    if (!is.null(row_group_var)) {
      wide_df <- wide_df %>% rename(RowGroup = all_of(row_group_var))
      wide_df <- wide_df %>% select(Variable, RowGroup, Statistics, everything())
    } else {
      wide_df <- wide_df %>% select(Variable, Statistics, everything())
    }
    wide_df
  }

  normalize_total_settings <- function(total_settings, df_in, col_group_var) {
    if (is.null(col_group_var) || length(total_settings) == 0) return(list())
    valid_settings <- list()
    group_levels <- unique(as.character(df_in[[col_group_var]]))
    for (i in seq_along(total_settings)) {
      setting <- total_settings[[i]]
      col_name <- if (!is.null(setting$name)) trimws(as.character(setting$name)) else ""
      if (nchar(col_name) == 0) col_name <- paste0("总计", i)
      groups <- if (!is.null(setting$groups)) intersect(as.character(setting$groups), group_levels) else character(0)
      if (length(groups) > 0) {
        valid_settings[[length(valid_settings) + 1]] <- list(name = col_name, groups = groups)
      }
    }
    if (length(valid_settings) > 0) {
      name_vec <- vapply(valid_settings, function(x) x$name, character(1))
      name_vec <- make.unique(name_vec, sep = "_")
      for (i in seq_along(valid_settings)) valid_settings[[i]]$name <- name_vec[i]
    }
    valid_settings
  }

  df_work <- normalize_group_var(df, row_group_var)
  df_work <- normalize_group_var(df_work, col_group_var)
  total_settings <- normalize_total_settings(total_cols_settings, df_work, col_group_var)

  result_list <- list()
  if (length(factor_vars) > 0) {
    factor_res <- lapply(factor_vars, function(var) build_factor_summary(df_work, var, col_group_var, row_group_var, 1))
    result_list <- c(result_list, factor_res)
  }
  if (length(numeric_vars) > 0) {
    numeric_res <- lapply(numeric_vars, function(var) build_numeric_summary(df_work, var, col_group_var, row_group_var, stat_digits(var)))
    result_list <- c(result_list, numeric_res)
  }
  if (length(result_list) == 0) return(NULL)

  final_result <- bind_rows(result_list)

  if (!is.null(col_group_var) && length(total_settings) > 0) {
    for (i in seq_along(total_settings)) {
      setting <- total_settings[[i]]
      setting_data <- df_work %>% filter(.data[[col_group_var]] %in% setting$groups)

      total_list <- list()
      if (length(factor_vars) > 0) {
        total_factor <- lapply(factor_vars, function(var) build_factor_summary(setting_data, var, NULL, row_group_var, decimals))
        total_list <- c(total_list, total_factor)
      }
      if (length(numeric_vars) > 0) {
        total_numeric <- lapply(numeric_vars, function(var) build_numeric_summary(setting_data, var, NULL, row_group_var, stat_digits(var)))
        total_list <- c(total_list, total_numeric)
      }

      if (length(total_list) > 0) {
        total_col_data <- bind_rows(total_list)
        join_cols <- c("Variable", "Statistics")
        if ("RowGroup" %in% names(final_result) && "RowGroup" %in% names(total_col_data)) {
          join_cols <- c("Variable", "RowGroup", "Statistics")
        }
        final_result <- final_result %>%
          left_join(
            total_col_data %>% select(all_of(join_cols), !!setting$name := Total),
            by = join_cols
          )
      }
    }
  }

  final_result <- final_result %>%
    mutate(
      Variable = factor(Variable, levels = vars),
      stat_order = ifelse(Statistics %in% stat_levels, match(Statistics, stat_levels), 1000 + as.integer(factor(Statistics)))
    )
  if ("RowGroup" %in% names(final_result)) {
    final_result <- final_result %>% arrange(Variable, RowGroup, stat_order, Statistics)
  } else {
    final_result <- final_result %>% arrange(Variable, stat_order, Statistics)
  }
  final_result <- final_result %>% mutate(Variable = as.character(Variable)) %>% select(-stat_order)
  var_label_map <- sapply(vars, function(v) {
    v_label <- attr(df[[v]], "label", exact = TRUE)
    if (is.null(v_label)) return(v)
    v_label <- trimws(as.character(v_label)[1])
    if (nchar(v_label) == 0) return(v)
    v_label
  }, USE.NAMES = TRUE)
  final_result <- final_result %>%
    mutate(VariableDisplay = unname(var_label_map[Variable]))
  count_subject_n <- function(df_in) {
    if (!is.null(id_var) && id_var %in% names(df_in)) {
      id_vals <- as.character(df_in[[id_var]])
      id_vals <- id_vals[!is.na(id_vals) & nzchar(trimws(id_vals))]
      return(length(unique(id_vals)))
    }
    nrow(df_in)
  }
  build_n_label <- function(col_name) {
    if (is.null(col_group_var)) {
      n_val <- count_subject_n(df_work)
      return(gt::md(paste0(col_name, "<br><span style='font-weight:normal'>(N = ", n_val, ")</span>")))
    }
    col_levels <- unique(as.character(df_work[[col_group_var]]))
    if (col_name %in% col_levels) {
      n_val <- count_subject_n(df_work %>% filter(.data[[col_group_var]] == col_name))
      return(gt::md(paste0(col_name, "<br><span style='font-weight:normal'>(N = ", n_val, ")</span>")))
    }
    setting_idx <- which(vapply(total_settings, function(x) identical(x$name, col_name), logical(1)))
    if (length(setting_idx) > 0) {
      groups <- total_settings[[setting_idx[1]]]$groups
      n_val <- count_subject_n(df_work %>% filter(.data[[col_group_var]] %in% groups))
      return(gt::md(paste0(col_name, "<br><span style='font-weight:normal'>(N = ", n_val, ")</span>")))
    }
    n_val <- count_subject_n(df_work)
    gt::md(paste0(col_name, "<br><span style='font-weight:normal'>(N = ", n_val, ")</span>"))
  }

  has_row_group <- "RowGroup" %in% names(final_result)
  if (has_row_group) {
    final_result <- final_result %>%
      group_by(Variable, RowGroup) %>%
      mutate(
        RowGroup = ifelse(row_number() == 1, as.character(RowGroup), "")
      ) %>%
      ungroup()
  }
  final_result <- final_result %>%
    group_by(Variable) %>%
    mutate(VariableDisplay = ifelse(row_number() == 1, VariableDisplay, "")) %>%
    ungroup()
  value_cols <- setdiff(names(final_result), c("Variable", "VariableDisplay", "RowGroup", "Statistics"))
  final_result <- final_result %>%
    mutate(
      Statistics = gsub("^\u00A0+", "", as.character(Statistics))
    )
  if (has_row_group) {
    final_result <- final_result %>%
      mutate(RowGroup = gsub("^\u00A0+", "", as.character(RowGroup)))
    var_blocks <- lapply(vars, function(v) {
      block <- final_result[final_result$Variable == v, , drop = FALSE]
      if (nrow(block) == 0) {
        return(NULL)
      }
      header_row <- block[1, , drop = FALSE]
      header_row$VariableDisplay <- unname(var_label_map[[v]])
      header_row$RowGroup <- ""
      header_row$Statistics <- ""
      if (length(value_cols) > 0) {
        for (col_name in value_cols) {
          header_row[[col_name]] <- ""
        }
      }
      block$VariableDisplay <- ""
      rbind(header_row, block)
    })
    final_result <- dplyr::bind_rows(var_blocks)
    ordered_cols <- c("Variable", "VariableDisplay", "RowGroup", "Statistics", value_cols)
  } else {
    ordered_cols <- c("Variable", "VariableDisplay", "Statistics", value_cols)
  }
  final_result <- final_result[, ordered_cols, drop = FALSE]
  gt_table <- gt::gt(final_result)

  label_map <- list(VariableDisplay = "分析变量", Statistics = "统计项")
  if (has_row_group) {
    label_map$RowGroup <- "亚组"
  }
  display_cols <- setdiff(names(final_result), c("Variable", "VariableDisplay", "RowGroup", "Statistics"))
  if (length(display_cols) > 0) {
    for (col_name in display_cols) {
      label_map[[col_name]] <- build_n_label(col_name)
    }
  }
  gt_table <- do.call(gt::cols_label, c(list(.data = gt_table), label_map))
  align_cols <- c("VariableDisplay", "Statistics")
  if (has_row_group) {
    align_cols <- c("VariableDisplay", "RowGroup", "Statistics")
  }
  gt_table <- gt_table %>%
    gt::cols_hide(columns = c("Variable")) %>%
    gt::cols_align(align = "left", columns = align_cols) %>%
    gt::tab_options(
      table.font.size = "small"
    )
  gt_table <- apply_sci_gt_style(
    gt_table,
    title = NULL,
    footnotes = NULL,
    left_columns = align_cols
  )
  interpretation <- HTML("<h4><b>结果解读 (Result Interpretation):</b></h4><ul><li>分类变量按 n (%) 展示，百分比保留1位小数。</li><li>连续变量展示 n、Mean (SD)、Median、Q1/Q3、Min/Max。</li><li>缺失值按可用数据保留并在统计项中体现。</li></ul>")
  list(
    table = gt_table,
    interpretation = interpretation,
    model_notes = c("描述性统计不输出P值，重点用于样本结构与分布描述。"),
    code = "perform_desc_analysis(data, variables, col_group_var, row_group_var, total_cols_count, total_cols_settings, decimals, auto_decimals, id_var)"
  )
}
