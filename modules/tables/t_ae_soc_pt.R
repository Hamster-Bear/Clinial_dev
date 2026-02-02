# AE SOC/PT 汇总表格模块 - 基于 rtables 和 tern
# 生成符合监管要求的不良事件汇总表，支持 SOC/PT 分层计数

library(shiny)
library(dplyr)
library(rtables)
library(tern)

#' AE SOC/PT 汇总表格参数 UI
#'
#' 生成用于配置 AE 汇总表格的用户界面控件，包括治疗组变量、SOC 变量、PT 变量选择和安全人群筛选。
#'
#' @param ns Shiny 命名空间函数
#' @param data 数据框，用于动态更新变量选择
#' @return tagList 包含所有输入控件的 UI 对象
#' @export
t_ae_soc_pt_params_ui <- function(ns, data) {
  var_names <- names(data)
  
  # 治疗组变量建议（常见列名）
  trt_candidates <- var_names[grep("(ARM|TRT|TREATMENT)", var_names, ignore.case = TRUE)]
  if (length(trt_candidates) == 0) trt_candidates <- var_names
  
  # SOC 变量建议
  soc_candidates <- var_names[grep("(SOC|BODSYS)", var_names, ignore.case = TRUE)]
  if (length(soc_candidates) == 0) soc_candidates <- var_names
  
  # PT 变量建议
  pt_candidates <- var_names[grep("(PT|DECOD|TERM)", var_names, ignore.case = TRUE)]
  if (length(pt_candidates) == 0) pt_candidates <- var_names
  
  # 安全人群筛选变量建议
  saffl_candidates <- var_names[grep("(SAFFL|SAFETY)", var_names, ignore.case = TRUE)]
  
  tagList(
    # 治疗组变量选择
    selectizeInput(
      ns("ae_trt_var"),
      "选择治疗组变量",
      choices = var_names,
      selected = ifelse(length(trt_candidates) > 0, trt_candidates[1], var_names[1])
    ),
    
    # SOC 变量选择
    selectizeInput(
      ns("ae_soc_var"),
      "选择 SOC 变量（系统器官分类）",
      choices = var_names,
      selected = ifelse(length(soc_candidates) > 0, soc_candidates[1], var_names[1])
    ),
    
    # PT 变量选择
    selectizeInput(
      ns("ae_pt_var"),
      "选择 PT 变量（首选术语）",
      choices = var_names,
      selected = ifelse(length(pt_candidates) > 0, pt_candidates[1], var_names[1])
    ),
    
    # 安全人群筛选
    checkboxInput(
      ns("ae_enable_saffl"),
      "筛选安全人群（SAFFL == 'Y'）",
      value = TRUE
    ),
    conditionalPanel(
      condition = paste0("input['", ns("ae_enable_saffl"), "'] == true"),
      selectizeInput(
        ns("ae_saffl_var"),
        "安全人群筛选变量",
        choices = c("SAFFL", saffl_candidates),
        selected = ifelse(length(saffl_candidates) > 0, saffl_candidates[1], "SAFFL")
      ),
      textInput(
        ns("ae_saffl_val"),
        "安全人群筛选值",
        value = "Y"
      )
    ),
    
    helpText("注：表格将按 SOC 分层，统计各治疗组和总体的事件数与患者数。")
  )
}

#' 执行 AE SOC/PT 汇总分析
#'
#' 基于用户选择的参数生成 AE 汇总表格，使用 rtables 和 tern 包。
#'
#' @param data 数据框，必须包含 USUBJID 列以及用户选择的治疗组、SOC、PT 变量
#' @param trt_var 字符，治疗组变量名
#' @param soc_var 字符，SOC 变量名
#' @param pt_var 字符，PT 变量名
#' @param saffl_var 字符，安全人群筛选变量名（可选，若为 NULL 则不筛选）
#' @param saffl_val 字符，安全人群筛选变量的值（默认 "Y"）
#' @return 一个 rtables 表格对象，若出错则返回 NULL
#' @export
perform_t_ae_soc_pt_analysis <- function(data,
                                         trt_var,
                                         soc_var,
                                         pt_var,
                                         saffl_var = NULL,
                                         saffl_val = "Y") {
  # 输入验证
  if (missing(data) || missing(trt_var) || missing(soc_var) || missing(pt_var)) {
    stop("`data`, `trt_var`, `soc_var`, `pt_var` 参数不能缺失")
  }
  if (!is.data.frame(data)) {
    stop("`data` 必须是数据框")
  }
  required_vars <- c(trt_var, soc_var, pt_var, saffl_var, "USUBJID")
  required_vars <- required_vars[!is.null(required_vars)]
  missing_vars <- setdiff(required_vars, names(data))
  if (length(missing_vars) > 0) {
    stop("以下变量在数据集中不存在: ", paste(missing_vars, collapse = ", "))
  }
  
  tryCatch({
    # 数据筛选
    df_ana <- data
    if (!is.null(saffl_var) && saffl_var %in% names(data)) {
      df_ana <- df_ana %>% filter(!!sym(saffl_var) == saffl_val)
    }
    
    # 为变量添加标签（用于表格输出）
    attr(df_ana[[soc_var]], "label") <- "MedDRA System Organ Class"
    attr(df_ana[[pt_var]], "label") <- "MedDRA Preferred Term"
    
    # 计算列计数（各治疗组的唯一受试者数）
    col_counts <- df_ana %>%
      group_by(across(all_of(trt_var))) %>%
      summarise(n = n_distinct(USUBJID), .groups = "drop")
    
    # 计算总体唯一受试者数
    total_n <- n_distinct(df_ana$USUBJID)
    
    # 构建 Layout
    lyt <- basic_table(show_colcounts = TRUE) %>%
      split_cols_by(var = trt_var) %>%
      add_overall_col(label = "All Patients") %>%
      analyze_num_patients(
        vars = "USUBJID",
        .stats = c("unique", "nonunique"),
        .labels = c(
          unique = "Total number of patients with at least one adverse event",
          nonunique = "Overall total number of events"
        )
      ) %>%
      split_rows_by(
        var = soc_var,
        child_labels = "visible",
        nested = FALSE,
        split_fun = drop_split_levels,
        label_pos = "topleft",
        split_label = "MedDRA System Organ Class"
      ) %>%
      summarize_num_patients(
        var = "USUBJID",
        .stats = c("unique", "nonunique"),
        .labels = c(
          unique = "Total number of patients with at least one adverse event",
          nonunique = "Total number of events"
        )
      ) %>%
      count_occurrences(vars = pt_var, .indent_mods = -1L) %>%
      append_varlabels(df_ana, pt_var, indent = 1L)
    
    # 构建表格
    tbl <- build_table(lyt, df = df_ana)
    
    # 强制修正表头 N 值（确保 N = Unique Patients）
    # 设置各治疗组的 N
    counts <- col_counts$n
    col_counts(tbl) <- c(counts, total_n)
    
    return(tbl)
    
  }, error = function(e) {
    warning("生成 AE 汇总表格时出错: ", e$message)
    return(NULL)
  })
}

#' 生成 AE SOC/PT 汇总表格的 R 代码（占位符）
#'
#' @param trt_var 字符，治疗组变量名
#' @param soc_var 字符，SOC 变量名
#' @param pt_var 字符，PT 变量名
#' @param saffl_var 字符，安全人群筛选变量名
#' @param saffl_val 字符，安全人群筛选值
#' @return 字符，R 代码字符串
#' @export
generate_t_ae_soc_pt_code <- function(trt_var,
                                      soc_var,
                                      pt_var,
                                      saffl_var = NULL,
                                      saffl_val = "Y") {
  return("# AE SOC/PT 汇总表格代码生成功能待完善")
}
