# 描述性统计表格模块 - 基于 gtsummary 的生产级实现
# 支持自动变量类型检测、自定义总计列、代码输出等

library(dplyr)
library(gt)
library(shiny)
library(rlang)
library(gtsummary)

#' 人口统计表格参数 UI (基于 gtsummary)
#'
#' 生成用于配置人口统计表格的用户界面控件，支持自动变量类型检测、自定义总计列和代码输出。
#'
#' @param ns Shiny 命名空间函数
#' @param data 数据框，用于动态更新变量选择
#' @return tagList 包含所有输入控件的 UI 对象
#' @export
t_dm_params_ui <- function(ns, data) {
  var_names <- names(data)
  # 分组变量只选择因子或字符型
  group_candidates <- var_names[sapply(data, function(x) is.factor(x) || is.character(x))]
  
  tagList(
    # 分析变量选择（多选）
    selectizeInput(
      ns("dm_variables"),
      "选择分析变量（可多选，自动判断类型）",
      choices = var_names,
      multiple = TRUE,
      options = list(maxItems = 15, placeholder = "请选择至少一个变量")
    ),
    
    # 分组变量选择（单选）
    selectizeInput(
      ns("dm_by_var"),
      "选择分组变量（单选）",
      choices = c("无", group_candidates),
      selected = "无",
      options = list(placeholder = "选择分组变量，留空表示不分组")
    ),
    
    # 自动类型检测提示
    helpText("注：变量类型将根据数据类型自动判断，数值型为连续变量，字符/因子型为分类变量"),
    
    # 总计列配置
    h4("总计列配置"),
    checkboxInput(
      ns("dm_enable_total_cols"),
      "启用自定义总计列",
      value = FALSE
    ),
    conditionalPanel(
      condition = paste0("input['", ns("dm_enable_total_cols"), "'] == true"),
      numericInput(
        ns("dm_total_cols_count"),
        "总计列数量",
        value = 1,
        min = 1,
        max = 5,
        step = 1
      ),
      uiOutput(ns("dm_total_cols_ui"))
    ),
    
    # 表格标题与脚注
    textInput(ns("dm_table_title"), "表格标题", value = "人口统计表格"),
    textInput(ns("dm_table_footnote"), "表格脚注", value = "")
  )
}

#' 获取总计列设置 UI（动态生成）
#'
#' 在服务器端调用，为每个总计列生成名称和分组选择。
#'
#' @param ns Shiny 命名空间函数
#' @param total_cols_count 总计列数量
#' @param group_levels 分组变量的水平（用于选择）
#' @return 包含总计列设置 UI 的 tagList
#' @export
t_dm_total_cols_ui <- function(ns, total_cols_count, group_levels) {
  total_cols <- lapply(seq_len(total_cols_count), function(i) {
    wellPanel(
      textInput(
        ns(paste0("dm_total_col_name_", i)),
        paste("总计列", i, "名称"),
        value = paste("总计", i)
      ),
      selectizeInput(
        ns(paste0("dm_total_col_groups_", i)),
        paste("选择总计列", i, "包含的组"),
        choices = group_levels,
        multiple = TRUE
      )
    )
  })
  do.call(tagList, total_cols)
}

#' 执行人口统计表格分析 (基于 gtsummary)
#'
#' 基于用户选择的参数生成人口统计表格，使用 gtsummary 包，支持自动变量类型检测和自定义总计列。
#'
#' @param data 数据框
#' @param variables 字符向量，需要分析的变量名
#' @param by_var 字符，分组变量名（可选），若为 NULL 或 "无" 表示不分组
#' @param total_cols_settings 列表，总计列设置（可选），每个元素需包含 `name` 和 `groups` 字段
#' @param table_title 字符，表格标题
#' @param table_footnote 字符，表格脚注
#' @return 一个 gt 表格对象，若出错则返回 NULL
#' @export
perform_t_dm_analysis <- function(data,
                                  variables,
                                  by_var = NULL,
                                  total_cols_settings = NULL,
                                  table_title = "人口统计表格",
                                  table_footnote = "") {
  
  # 输入验证
  if (missing(data) || missing(variables)) {
    stop("`data` 和 `variables` 参数不能缺失")
  }
  if (!is.data.frame(data)) {
    stop("`data` 必须是数据框")
  }
  if (!all(variables %in% names(data))) {
    stop("部分变量在数据集中不存在: ",
         paste(setdiff(variables, names(data)), collapse = ", "))
  }
  
  # 处理分组变量
  if (!is.null(by_var) && by_var == "无") {
    by_var <- NULL
  }
  if (!is.null(by_var) && !by_var %in% names(data)) {
    stop("分组变量 '", by_var, "' 在数据集中不存在")
  }
  
  # 自动检测变量类型（连续 vs 分类）
  detect_variable_types <- function(data, variables) {
    cont_vars <- character(0)
    cat_vars <- character(0)
    
    for (var in variables) {
      if (var %in% names(data)) {
        # 检查是否为数值型且唯一值较多（通常为连续变量）
        if (is.numeric(data[[var]]) && length(unique(na.omit(data[[var]]))) > 10) {
          cont_vars <- c(cont_vars, var)
        } else {
          # 其他情况视为分类变量
          cat_vars <- c(cat_vars, var)
        }
      }
    }
    
    list(cont_vars = cont_vars, cat_vars = cat_vars)
  }
  
  var_types <- detect_variable_types(data, variables)
  cont_vars <- var_types$cont_vars
  cat_vars <- var_types$cat_vars
  
  # 至少需要一个变量
  if (length(cont_vars) == 0 && length(cat_vars) == 0) {
    warning("没有有效的数值或分类变量")
    return(NULL)
  }
  
  # 构建 type 参数列表
  type_list <- list()
  if (length(cont_vars) > 0) {
    for (var in cont_vars) {
      type_list[[var]] <- "continuous2"
    }
  }
  if (length(cat_vars) > 0) {
    for (var in cat_vars) {
      type_list[[var]] <- "categorical"
    }
  }
  
  # 生成基础表格
  tryCatch({
    library(gtsummary)
    theme_gtsummary_compact()
    
    if (!is.null(by_var)) {
      tbl <- data |>
        tbl_summary(
          by = !!sym(by_var),
          include = all_of(variables),
          type = type_list,
          statistic = list(
            # 连续变量统计
            all_continuous() ~ c(
              "{N_nonmiss}",
              "{mean} ({sd})",
              "{median} ({p25}, {p75})",
              "{min}, {max}"
            ),
            # 分类变量统计，显示所有水平
            all_categorical() ~ "{n} ({p}%)"
          ),
          digits = list(all_continuous() ~ c(0, 2, 2, 2, 0, 0)),
          missing = "no"
        )
    } else {
      tbl <- data |>
        tbl_summary(
          include = all_of(variables),
          type = type_list,
          statistic = list(
            all_continuous() ~ c(
              "{N_nonmiss}",
              "{mean} ({sd})",
              "{median} ({p25}, {p75})",
              "{min}, {max}"
            ),
            all_categorical() ~ "{n} ({p}%)"
          ),
          digits = list(all_continuous() ~ c(0, 2, 2, 2, 0, 0)),
          missing = "no"
        )
    }
    
    # 添加自定义总计列
    if (!is.null(total_cols_settings) && length(total_cols_settings) > 0) {
      # 构建表格列表用于合并
      tbl_list <- list(tbl)
      # 为每个总计列设置创建表格
      for (setting in total_cols_settings) {
        if (!is.null(setting$name) && !is.null(setting$groups)) {
          # 过滤数据，只包含指定组
          subset_data <- data
          if (!is.null(by_var) && length(setting$groups) > 0) {
            subset_data <- subset_data %>% filter(!!sym(by_var) %in% setting$groups)
          }
          # 创建总计列表格（无分组）
          total_tbl <- subset_data |>
            tbl_summary(
              include = all_of(variables),
              type = type_list,
              statistic = list(
                all_continuous() ~ c(
                  "{N_nonmiss}",
                  "{mean} ({sd})",
                  "{median} ({p25}, {p75})",
                  "{min}, {max}"
                ),
                all_categorical() ~ "{n} ({p}%)"
              ),
              digits = list(all_continuous() ~ c(0, 2, 2, 2, 0, 0)),
              missing = "no"
            )
          # 添加到列表
          tbl_list <- c(tbl_list, list(total_tbl))
        }
      }
      # 合并表格
      if (length(tbl_list) > 1) {
        tbl <- tbl_merge(tbl_list, tab_spanner = FALSE)
        # 设置列标签
        # 原始表格的列标签已由分组变量定义，总计列表格的列标签使用设置名称
        # tbl_merge 会自动使用每个表格的默认列名
        # 如需调整合并后的列标题，可再调用 modify_header()
      }
    }
    
    # 应用格式化
    tbl <- tbl %>%
      bold_labels() %>%
      italicize_levels() %>%
      modify_header(
        label = "**变量**",
        all_stat_cols() ~ "**{level}**  \nN = {n}"
      ) %>%
      modify_spanning_header(all_stat_cols() ~ "**分组**") %>%
      modify_footnote(everything() ~ NA) %>%
      modify_caption(table_title)
    
    # 转换为 gt 表格并应用脚注
    gt_table <- tbl %>%
      as_gt() %>%
      gt::tab_options(
        table.font.size = "12px",
        column_labels.font.weight = "bold",
        heading.title.font.size = "14px",
        table.width = "100%"
      )
    
    if (!is.null(table_footnote) && table_footnote != "") {
      gt_table <- gt_table %>%
        gt::tab_footnote(footnote = table_footnote, locations = gt::cells_title())
    }
    
    return(gt_table)
    
  }, error = function(e) {
    warning("生成表格时出错: ", e$message)
    return(NULL)
  })
}

#' 生成人口统计表格的 R 代码（占位符）
#'
#' 待实现：根据参数生成可复现的 R 代码字符串。
#'
#' @param variables 字符向量，需要分析的变量名
#' @param by_var 字符，分组变量名（可选）
#' @param total_cols_settings 列表，总计列设置（可选）
#' @param table_title 字符，表格标题
#' @param table_footnote 字符，表格脚注
#' @return 字符，R 代码字符串
#' @export
generate_t_dm_code <- function(variables,
                               by_var = NULL,
                               total_cols_settings = NULL,
                               table_title = "人口统计表格",
                               table_footnote = "",
                               data_name = "data") {
  code <- c(
    "# 人口统计表格 (t_dm) 复现代码",
    "library(gtsummary)",
    "library(gt)",
    "library(dplyr)",
    "",
    paste0("data <- ", data_name),
    "",
    paste0("variables <- c(", paste(sprintf('"%s"', variables), collapse = ", "), ")")
  )

  if (!is.null(by_var) && nzchar(by_var)) {
    code <- c(code, paste0("by_var <- \"", by_var, "\""))
  } else {
    code <- c(code, "by_var <- NULL")
  }

  if (!is.null(total_cols_settings) && length(total_cols_settings) > 0) {
    code <- c(code, "", "# 总计列设置")
    for (i in seq_along(total_cols_settings)) {
      s <- total_cols_settings[[i]]
      grp_str <- paste(sprintf('"%s"', s$groups), collapse = ", ")
      code <- c(code, paste0("total_col_", i, "_name <- \"", s$name, "\""))
      code <- c(code, paste0("total_col_", i, "_groups <- c(", grp_str, ")"))
    }
    item_str <- paste(sapply(seq_along(total_cols_settings), function(i) {
      paste0("list(name = total_col_", i, "_name, groups = total_col_", i, "_groups)")
    }), collapse = ", ")
    code <- c(code, paste0("total_cols_settings <- list(", item_str, ")"))
  } else {
    code <- c(code, "total_cols_settings <- NULL")
  }

  code <- c(code, "",
    "result <- perform_t_dm_analysis(",
    "  data = data,",
    "  variables = variables,",
    "  by_var = by_var,",
    "  total_cols_settings = total_cols_settings,",
    paste0("  table_title = \"", table_title, "\","),
    paste0("  table_footnote = \"", table_footnote, "\""),
    ")",
    "",
    "print(result)"
  )

  paste(code, collapse = "\n")
}

apply_t_dm_state <- function(session, state) {
  extra <- if (is.list(state$extra_state)) state$extra_state else state
  if (!is.null(extra$dm_variables))
    updateSelectizeInput(session, "dm_variables", selected = extra$dm_variables)
  if (!is.null(extra$dm_by_var))
    updateSelectizeInput(session, "dm_by_var", selected = extra$dm_by_var)
  if (!is.null(extra$dm_enable_total_cols))
    updateCheckboxInput(session, "dm_enable_total_cols", value = extra$dm_enable_total_cols)
  if (!is.null(extra$dm_total_cols_count))
    updateNumericInput(session, "dm_total_cols_count", value = extra$dm_total_cols_count)
  if (!is.null(extra$dm_table_title))
    updateTextInput(session, "dm_table_title", value = extra$dm_table_title)
  if (!is.null(extra$dm_table_footnote))
    updateTextInput(session, "dm_table_footnote", value = extra$dm_table_footnote)
  invisible(TRUE)
}
