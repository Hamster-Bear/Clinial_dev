# AE SOC/PT 汇总表格模块 - 基于 rtables 和 tern
# 生成符合监管要求的不良事件汇总表，支持 SOC/PT 分层计数

library(shiny)
library(dplyr)
library(rtables)
library(tern)

#' AE SOC/PT 汇总表格参数 UI
#'
#' 生成用于配置 AE 汇总表格的用户界面控件，包括分组变量、SOC 变量、PT 变量选择和人群筛选。
#'
#' @param ns Shiny 命名空间函数
#' @param data 数据框，用于动态更新变量选择
#' @return tagList 包含所有输入控件的 UI 对象
#' @export
t_ae_soc_pt_params_ui <- function(ns, data) {
  var_names <- names(data)
  
  # 分组变量建议（常见列名）
  trt_candidates <- var_names[grep("(ARM|TRT|TREATMENT|GROUP)", var_names, ignore.case = TRUE)]
  if (length(trt_candidates) == 0) trt_candidates <- var_names
  
  # SOC 变量建议 (AE, CM, PR 通用)
  soc_candidates <- var_names[grep("(SOC|BODSYS|CAT|CATEGORY|CLASS)", var_names, ignore.case = TRUE)]
  if (length(soc_candidates) == 0) soc_candidates <- var_names
  
  # PT 变量建议 (AE, CM, PR 通用)
  pt_candidates <- var_names[grep("(PT|DECOD|TERM|TRT|NAME)", var_names, ignore.case = TRUE)]
  if (length(pt_candidates) == 0) pt_candidates <- var_names
  
  # 人群筛选变量建议
  pop_candidates <- var_names[grep("(FL|FLAG|POP)", var_names, ignore.case = TRUE)]
  if (length(pop_candidates) == 0) pop_candidates <- var_names
  
  # 受试者标识变量建议
  id_candidates <- var_names[grep("(USUBJID|SUBJID|ID)", var_names, ignore.case = TRUE)]
  if (length(id_candidates) == 0) id_candidates <- var_names
  
  tagList(
    # 适用类型提示
    div(
      style = "background-color: #f8f9fa; padding: 10px; border-radius: 5px; margin-bottom: 15px; border-left: 4px solid #17a2b8;",
      p(tags$b("适用类型:"), " 本表格适用于分级统计数据，例如："),
      tags$ul(
        tags$li("不良事件 (AE): SOC (System Organ Class) / PT (Preferred Term)"),
        tags$li("合并用药 (CM): ATC Class / CMDECOD (Drug Name)"),
        tags$li("既往手术 (PR): SOC / Preferred Term")
      ),
      p(style = "color: #6c757d; font-size: 0.9em; margin-bottom: 0;", "注：请根据实际数据类型选择对应的一级分类变量（如SOC）和二级分类变量（如PT）。")
    ),
    
    # 受试者标识变量选择
    selectizeInput(
      ns("subject_id_var"),
      "选择受试者标识变量 (Subject ID)",
      choices = var_names,
      selected = ifelse(length(id_candidates) > 0, id_candidates[1], var_names[1])
    ),
    
    # 分组变量选择
    selectizeInput(
      ns("ae_trt_var"),
      "选择分组变量 (Grouping Variable)",
      choices = var_names,
      selected = ifelse(length(trt_candidates) > 0, trt_candidates[1], var_names[1])
    ),
    
    # 一级分类变量选择
    selectizeInput(
      ns("ae_soc_var"),
      "选择一级分类变量 (如 SOC, ATC Class)",
      choices = var_names,
      selected = ifelse(length(soc_candidates) > 0, soc_candidates[1], var_names[1])
    ),
    
    # 二级分类变量选择
    selectizeInput(
      ns("ae_pt_var"),
      "选择二级分类变量 (如 PT, CMDECOD)",
      choices = var_names,
      selected = ifelse(length(pt_candidates) > 0, pt_candidates[1], var_names[1])
    ),
    
    # 人群筛选
    checkboxInput(
      ns("ae_enable_pop"),
      "启用人群筛选 (Population Filter)",
      value = TRUE
    ),
    conditionalPanel(
      condition = paste0("input['", ns("ae_enable_pop"), "'] == true"),
      fluidRow(
        column(6, 
          selectizeInput(
            ns("ae_pop_var"),
            "筛选变量",
            choices = pop_candidates,
            selected = ifelse("SAFFL" %in% pop_candidates, "SAFFL", pop_candidates[1])
          )
        ),
        column(6, 
          textInput(
            ns("ae_pop_val"),
            "筛选值 (如 'Y')",
            value = "Y"
          )
        )
      )
    ),
    
    helpText("注：表格将按一级分类分层，统计各分组和总体的事件数与受试者数。")
  )
}

#' 执行分级统计汇总分析 (AE/CM/PR)
#'
#' 基于用户选择的参数生成分级汇总表格，使用 rtables 和 tern 包。
#'
#' @param data 数据框，必须包含受试者ID以及用户选择的分组、一级分类、二级分类变量
#' @param trt_var 字符，分组变量名
#' @param soc_var 字符，一级分类变量名
#' @param pt_var 字符，二级分类变量名
#' @param id_var 字符，受试者标识变量名
#' @param pop_var 字符，人群筛选变量名（可选，若为 NULL 则不筛选）
#' @param pop_val 字符，人群筛选变量的值（默认 "Y"）
#' @return 一个 rtables 表格对象，若出错则返回 NULL
#' @export
perform_t_ae_soc_pt_analysis <- function(data,
                                         trt_var,
                                         soc_var,
                                         pt_var,
                                         id_var = "USUBJID",
                                         pop_var = NULL,
                                         pop_val = "Y") {
  # 输入验证
  if (missing(data) || missing(trt_var) || missing(soc_var) || missing(pt_var) || missing(id_var)) {
    stop("`data`, `trt_var`, `soc_var`, `pt_var`, `id_var` 参数不能缺失")
  }
  if (!is.data.frame(data)) {
    stop("`data` 必须是数据框")
  }
  
  required_vars <- c(trt_var, soc_var, pt_var, id_var)
  if (!is.null(pop_var)) required_vars <- c(required_vars, pop_var)
  
  required_vars <- required_vars[!is.null(required_vars) & required_vars != ""]
  missing_vars <- setdiff(required_vars, names(data))
  if (length(missing_vars) > 0) {
    stop("以下变量在数据集中不存在: ", paste(missing_vars, collapse = ", "))
  }
  
  tryCatch({
    # 数据筛选
    df_ana <- data
    if (!is.null(pop_var) && pop_var != "" && pop_var %in% names(data)) {
      # 处理筛选值类型，尝试匹配
      target_val <- pop_val
      if (is.numeric(df_ana[[pop_var]])) target_val <- as.numeric(pop_val)
      
      df_ana <- df_ana %>% filter(!!sym(pop_var) == target_val)
    }
    
    # 确保分组变量为因子并保留空水平（如果有需要）
    df_ana[[trt_var]] <- as.factor(df_ana[[trt_var]])
    
    # 为变量添加标签（用于表格输出，如果未设置）
    if (is.null(attr(df_ana[[soc_var]], "label"))) attr(df_ana[[soc_var]], "label") <- "System Organ Class / Category"
    if (is.null(attr(df_ana[[pt_var]], "label"))) attr(df_ana[[pt_var]], "label") <- "Preferred Term / Item"
    
    # 计算列计数（各分组的唯一受试者数）
    # 使用 id_var 进行计数
    col_counts_df <- df_ana %>%
      group_by(across(all_of(trt_var))) %>%
      summarise(n = n_distinct(!!sym(id_var)), .groups = "drop")
    
    # 计算总体唯一受试者数
    total_n <- n_distinct(df_ana[[id_var]])
    
    # 确保所有分组都有计数，即使某些组被过滤掉
    levels_trt <- levels(df_ana[[trt_var]])
    counts_vec <- setNames(rep(0, length(levels_trt)), levels_trt)
    if (nrow(col_counts_df) > 0) {
      counts_vec[as.character(col_counts_df[[trt_var]])] <- col_counts_df$n
    }
    
    # 构建 Layout
    lyt <- basic_table(show_colcounts = TRUE) %>%
      split_cols_by(var = trt_var) %>%
      add_overall_col(label = "All Patients") %>%
      analyze_num_patients(
        vars = id_var,
        .stats = c("unique", "nonunique"),
        .labels = c(
          unique = "Total number of patients with at least one event",
          nonunique = "Overall total number of events"
        )
      ) %>%
      split_rows_by(
        var = soc_var,
        child_labels = "visible",
        nested = FALSE,
        split_fun = drop_split_levels,
        label_pos = "topleft",
        split_label = attr(df_ana[[soc_var]], "label")
        # inset 参数在某些 rtables 版本中不支持，已移除。如果需要缩进效果，可以使用 label_pos="topleft" 配合自定义 split_fun
      ) %>%
      summarize_num_patients(
        var = id_var,
        .stats = c("unique", "nonunique"),
        .labels = c(
          unique = "Total number of patients with at least one event",
          nonunique = "Total number of events"
        )
      ) %>%
      count_occurrences(vars = pt_var, .indent_mods = -1L) %>%
      append_varlabels(df_ana, pt_var, indent = 1L)
    
    # 构建表格
    tbl <- build_table(lyt, df = df_ana)
    
    # 强制修正表头 N 值（确保 N = Unique Patients）
    col_counts(tbl) <- c(as.numeric(counts_vec), total_n)
    
    return(tbl)
    
  }, error = function(e) {
    # 错误处理：返回包含错误信息的 NULL，或者抛出更友好的错误
    stop(paste("生成分级汇总表格时出错:", e$message))
  })
}

#' 生成分级汇总表格的 R 代码（占位符）
#'
#' @param trt_var 字符，分组变量名
#' @param soc_var 字符，一级分类变量名
#' @param pt_var 字符，二级分类变量名
#' @param id_var 字符，受试者标识变量名
#' @param pop_var 字符，人群筛选变量名
#' @param pop_val 字符，人群筛选值
#' @return 字符，R 代码字符串
#' @export
generate_t_ae_soc_pt_code <- function(trt_var,
                                      soc_var,
                                      pt_var,
                                      id_var = "USUBJID",
                                      pop_var = NULL,
                                      pop_val = "Y") {
  return("# 分级汇总表格代码生成功能待完善")
}
