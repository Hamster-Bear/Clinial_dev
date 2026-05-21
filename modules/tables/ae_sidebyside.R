# 不良事件并列对比图 (Side-by-Side AE Plot) 模块
# 展示治疗期不良事件 (TEAE) 与治疗相关不良事件 (TRAE) 的对比

library(shiny)
library(ggplot2)
library(dplyr)
library(tidyr)

#' 不良事件并列对比图参数 UI
#'
#' @param id Shiny 模块ID
#' @param data 数据框
#' @return tagList
#' @export
ae_sidebyside_params_ui <- function(id, data) {
  ns <- NS(id)
  cols <- names(data)
  
  tagList(
    # 变量选择
    selectInput(ns("ae_term_col"), "不良事件名称 (AEDECOD):", choices = cols, selected = "AEDECOD"),
    selectInput(ns("ae_sev_col"), "严重程度 (AETOXGR):", choices = cols, selected = "AETOXGR"),
    selectInput(ns("ae_subj_col"), "受试者标识符 (USUBJID):", choices = cols, selected = "USUBJID"),
    selectInput(ns("ae_group_col"), "分组变量 (TRT01A/ARM):", choices = c("无", cols), selected = "TRT01A"),
    
    # TEAE 和 TRAE 标识
    # 改进：使用更灵活的筛选方式，类似 data_filter
    h5("数据定义 (基于原始 ADAE)"),
    
    # TEAE 定义
    fluidRow(
      column(6, selectInput(ns("ae_flag_col"), "TEAE 变量 (TRTEMFL):", choices = c("无", cols), selected = "TRTEMFL")),
      column(6, uiOutput(ns("ae_flag_val_ui")))
    ),
    
    # TRAE 定义
    fluidRow(
      column(6, selectInput(ns("ae_rel_col"), "TRAE 变量 (AEREL):", choices = c("无", cols), selected = "AEREL")),
      column(6, uiOutput(ns("ae_rel_val_ui")))
    ),
    
    hr(),
    h5("图形设置"),
    selectInput(
      ns("ae_count_mode"),
      "计数口径:",
      choices = c(
        "按最重等级（人次）" = "worst_subject_term",
        "按事件次数（条次）" = "event_count"
      ),
      selected = "worst_subject_term"
    ),
    sliderInput(ns("ae_min_pct"), "最小发生率 (%) - 仅展示高于此比例的事件:", min = 0, max = 20, value = 0, step = 1),
    sliderInput(ns("ae_plot_height"), "图片高度 (px)", min = 400, max = 1200, value = 800)
  )
}

#' 动态生成值选择 UI (辅助函数，需在 server 端调用)
#' @export
ae_sidebyside_params_server <- function(id, data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # 动态生成 TEAE 值选择
    output$ae_flag_val_ui <- renderUI({
      req(input$ae_flag_col, input$ae_flag_col != "无")
      col_data <- data()[[input$ae_flag_col]]
      if (is.factor(col_data) || is.character(col_data)) {
        selectInput(ns("ae_flag_val"), "值 (等于):", choices = unique(col_data), selected = "Y", multiple = TRUE)
      } else {
        textInput(ns("ae_flag_val"), "值 (包含):", value = "Y")
      }
    })
    
    # 动态生成 TRAE 值选择
    output$ae_rel_val_ui <- renderUI({
      req(input$ae_rel_col, input$ae_rel_col != "无")
      col_data <- data()[[input$ae_rel_col]]
      if (is.factor(col_data) || is.character(col_data)) {
        # 尝试智能选择 "RELATED" 相关的值
        all_vals <- unique(col_data)
        sel_vals <- grep("RELATED|POSSIBLE|PROBABLE|DEFINITE", all_vals, ignore.case = TRUE, value = TRUE)
        if (length(sel_vals) == 0) sel_vals <- all_vals[1]
        
        selectInput(ns("ae_rel_val"), "值 (包含):", choices = all_vals, selected = sel_vals, multiple = TRUE)
      } else {
        textInput(ns("ae_rel_val"), "值 (包含):", value = "RELATED")
      }
    })
  })
}

#' 执行不良事件并列对比图分析
#'
#' @param data 原始数据 (ADAE)
#' @param term_col 不良事件名称变量
#' @param sev_col 严重程度变量
#' @param subj_col 受试者标识符变量
#' @param group_col 分组变量
#' @param flag_col TEAE 标志变量
#' @param flag_val TEAE 标志值
#' @param rel_col 相关性标志变量
#' @param rel_val 相关性标志值
#' @param count_mode 计数口径（worst_subject_term 或 event_count）
#' @param min_pct 最小发生率阈值
#' @return ggplot 对象
#' @export
perform_ae_sidebyside_analysis <- function(data, term_col, sev_col, subj_col, group_col, flag_col, flag_val, rel_col, rel_val, count_mode = "worst_subject_term", min_pct = 0) {
  req(data, term_col, sev_col, subj_col)
  term_sym <- rlang::sym(term_col)
  sev_sym <- rlang::sym(sev_col)
  subj_sym <- rlang::sym(subj_col)
  
  # 0. 分组处理 (如果选择了分组变量)
  # 当前按首个分组或整体数据绘制；更细粒度分组建议先用全局筛选限定人群。
  # N_TOTAL 仍按当前展示数据重新计算。
  
  # 1. 数据预处理与汇总
  # 即使是 Subject Level 数据，也需要先汇总成 Term + Grade 级别的计数
  
  # 计算总人数 (N_TOTAL) - 优先使用 subj_col 计算
  if (subj_col %in% names(data)) {
      N_TOTAL <- n_distinct(data[[subj_col]])
  } else {
      N_TOTAL <- 100 # Fallback
  }
  
  # 过滤 TEAE
  df_teae <- data
  if (flag_col != "无" && flag_col %in% names(data)) {
    # 支持多选值或字符串包含
    if (length(flag_val) > 1 || all(flag_val %in% unique(data[[flag_col]]))) {
        df_teae <- df_teae %>% filter(!!sym(flag_col) %in% flag_val)
    } else {
        # 兼容旧逻辑或文本输入
        df_teae <- df_teae %>% filter(grepl(flag_val, !!sym(flag_col), ignore.case = TRUE))
    }
  }
  
  # 过滤 TRAE (通常 TRAE 是 TEAE 的子集，但也可能是独立的定义)
  # 这里假设 TRAE 必须也是 TEAE
  df_trae <- df_teae
  if (rel_col != "无" && rel_col %in% names(data)) {
     if (length(rel_val) > 1 || all(rel_val %in% unique(data[[rel_col]]))) {
         df_trae <- df_trae %>% filter(!!sym(rel_col) %in% rel_val)
     } else {
         df_trae <- df_trae %>% filter(grepl(rel_val, !!sym(rel_col), ignore.case = TRUE))
     }
  }
  
  severity_values <- c(as.character(df_teae[[sev_col]]), as.character(df_trae[[sev_col]]))
  severity_values <- severity_values[!is.na(severity_values) & nzchar(severity_values)]
  unique_grades <- unique(severity_values)
  if (length(unique_grades) == 0) {
    stop("严重程度变量没有可用值")
  }
  if (any(grepl("\\d", unique_grades))) {
    sev_num <- suppressWarnings(as.numeric(gsub("\\D", "", unique_grades)))
    grade_levels <- unique_grades[order(sev_num, decreasing = TRUE, na.last = TRUE)]
  } else {
    grade_levels <- sort(unique_grades, decreasing = TRUE)
  }
  
  collapse_worst_grade <- function(df, count_name) {
    df %>%
      mutate(
        .sev_chr = as.character(!!sev_sym),
        .sev_rank = match(.sev_chr, grade_levels)
      ) %>%
      filter(!is.na(!!term_sym), !is.na(!!subj_sym), !is.na(.sev_rank)) %>%
      group_by(!!term_sym, !!subj_sym) %>%
      slice_min(order_by = .sev_rank, n = 1, with_ties = FALSE) %>%
      ungroup() %>%
      count(!!term_sym, !!sev_sym, name = count_name) %>%
      rename(AEDECOD = !!term_sym, AESEV = !!sev_sym)
  }
  
  if (count_mode == "event_count") {
    teae_summary <- df_teae %>%
      filter(!is.na(!!term_sym), !is.na(!!sev_sym)) %>%
      count(!!term_sym, !!sev_sym, name = "TEAE_Count") %>%
      rename(AEDECOD = !!term_sym, AESEV = !!sev_sym)
    trae_summary <- df_trae %>%
      filter(!is.na(!!term_sym), !is.na(!!sev_sym)) %>%
      count(!!term_sym, !!sev_sym, name = "TRAE_Count") %>%
      rename(AEDECOD = !!term_sym, AESEV = !!sev_sym)
  } else {
    teae_summary <- collapse_worst_grade(df_teae, "TEAE_Count")
    trae_summary <- collapse_worst_grade(df_trae, "TRAE_Count")
  }
  
  # 合并
  plot_data <- full_join(teae_summary, trae_summary, by = c("AEDECOD", "AESEV")) %>%
    mutate(
      TEAE_Count = replace_na(TEAE_Count, 0),
      TRAE_Count = replace_na(TRAE_Count, 0)
    )
  
  plot_prep <- plot_data %>%
    mutate(
      TEAE_Pct = (TEAE_Count / N_TOTAL) * 100,
      TRAE_Pct = (TRAE_Count / N_TOTAL) * 100,
      AESEV = factor(AESEV, levels = grade_levels)
    ) %>%
    group_by(AEDECOD) %>%
    arrange(AESEV) %>%
    mutate(
      trae_xmax = cumsum(TRAE_Pct),
      trae_xmin = trae_xmax - TRAE_Pct,
      teae_xmin = -cumsum(TEAE_Pct),
      teae_xmax = teae_xmin + TEAE_Pct,
      total_teae_pct = sum(TEAE_Pct),
      total_trae_pct = sum(TRAE_Pct),
      total_teae_n = sum(TEAE_Count),
      total_trae_n = sum(TRAE_Count)
    ) %>%
    ungroup()
  
  # 筛选发生率
  if (min_pct > 0) {
      plot_prep <- plot_prep %>%
          filter(total_teae_pct >= min_pct)
  }
  
  # 按 TEAE 总发生率降序排列
  # 若某个 Term 缺少最高 Grade，则按总百分比排序
  term_order_df <- plot_prep %>%
      group_by(AEDECOD) %>%
      summarise(max_teae = max(total_teae_pct)) %>%
      arrange(max_teae) 
  
  teae_order <- term_order_df$AEDECOD
  plot_prep$AEDECOD <- factor(plot_prep$AEDECOD, levels = teae_order)
  
  # 计算 X 轴动态上限
  max_val <- max(c(plot_prep$total_teae_pct, plot_prep$total_trae_pct), na.rm = TRUE) * 1.25
  if (!is.finite(max_val) || max_val == 0) max_val <- 10 # 默认值
  plot_family <- graphics_resolve_font_spec("sans")$unified
  
  # 3. 绘图
  p <- ggplot(plot_prep) +
    # 右侧 TRAE 条形
    geom_rect(aes(xmin = trae_xmin, xmax = trae_xmax, 
                  ymin = as.numeric(AEDECOD) - 0.38, ymax = as.numeric(AEDECOD) + 0.38, 
                  fill = AESEV), color = "white", linewidth = 0.3) +
    # 左侧 TEAE 条形
    geom_rect(aes(xmin = teae_xmin, xmax = teae_xmax, 
                  ymin = as.numeric(AEDECOD) - 0.38, ymax = as.numeric(AEDECOD) + 0.38, 
                  fill = AESEV), color = "white", linewidth = 0.3) +
    
    # 汇总标注
    geom_text(aes(x = -total_teae_pct - (max_val * 0.05), y = as.numeric(AEDECOD), 
                  label = paste0(total_teae_n, " (", sprintf("%.1f", total_teae_pct), "%)")),
              hjust = 1, size = 4, fontface = "bold", family = plot_family, check_overlap = TRUE) +
    geom_text(aes(x = total_trae_pct + (max_val * 0.05), y = as.numeric(AEDECOD), 
                  label = paste0(total_trae_n, " (", sprintf("%.1f", total_trae_pct), "%)")),
              hjust = 0, size = 4, fontface = "bold", family = plot_family, check_overlap = TRUE) +
    
    # 中心分隔线
    geom_vline(xintercept = 0, color = "black", linewidth = 1.2) +
    
    # 坐标轴与比例尺
    scale_y_continuous(breaks = 1:length(teae_order), labels = teae_order) +
    scale_x_continuous(labels = function(x) paste0(abs(x), "%"), 
                       limits = c(-max_val * 1.5, max_val * 1.5)) + # 增加空间给 Label
    
    # 配色 (自动匹配 Grade 数量)
    scale_fill_brewer(palette = "Blues", direction = -1, name = "Severity") +
    
    # 标题与标签
    labs(
      title = "TEAE vs TRAE Incidence Distribution",
      subtitle = paste0("Left: TEAE (N=", N_TOTAL, ") | Right: TRAE (N=", N_TOTAL, ")"),
      x = "Incidence Rate (%)",
      y = NULL
    ) +
    
    theme_minimal(base_family = plot_family) +
    theme(
      plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),
      plot.subtitle = element_text(hjust = 0.5, size = 12),
      axis.text.y = element_text(size = 12, face = "bold", color = "black"),
      legend.position = "bottom"
    )
    
  return(p)
}

#' 生成代码 (占位)
#' @export
generate_ae_sidebyside_code <- function(term_col, sev_col, subj_col, group_col,
                                        flag_col, flag_val, rel_col, rel_val,
                                        count_mode = "worst_subject_term",
                                        min_pct = 0, data_name = "data") {
  code <- c(
    "# AE 并列对比图 复现代码",
    "library(ggplot2)",
    "library(dplyr)",
    "library(tidyr)",
    "",
    paste0("data <- ", data_name),
    "",
    paste0("term_col <- \"", term_col, "\""),
    paste0("sev_col <- \"", sev_col, "\""),
    paste0("subj_col <- \"", subj_col, "\""),
    paste0("group_col <- \"", group_col, "\""),
    paste0("flag_col <- \"", flag_col, "\""),
    paste0("flag_val <- \"", flag_val, "\""),
    paste0("rel_col <- \"", rel_col, "\""),
    paste0("rel_val <- \"", rel_val, "\""),
    paste0("count_mode <- \"", count_mode, "\""),
    paste0("min_pct <- ", min_pct),
    "",
    "result <- perform_ae_sidebyside_analysis(",
    "  data = data,",
    "  term_col = term_col,",
    "  sev_col = sev_col,",
    "  subj_col = subj_col,",
    "  group_col = group_col,",
    "  flag_col = flag_col,",
    "  flag_val = flag_val,",
    "  rel_col = rel_col,",
    "  rel_val = rel_val,",
    "  count_mode = count_mode,",
    "  min_pct = min_pct",
    ")",
    "",
    "print(result)"
  )

  paste(code, collapse = "\n")
}

apply_ae_sidebyside_state <- function(session, state) {
  extra <- if (is.list(state$extra_state)) state$extra_state else state
  prefix <- "ae_sidebyside_params-"
  if (!is.null(extra$ae_term_col))
    updateSelectizeInput(session, paste0(prefix, "ae_term_col"), selected = extra$ae_term_col)
  if (!is.null(extra$ae_sev_col))
    updateSelectizeInput(session, paste0(prefix, "ae_sev_col"), selected = extra$ae_sev_col)
  if (!is.null(extra$ae_subj_col))
    updateSelectizeInput(session, paste0(prefix, "ae_subj_col"), selected = extra$ae_subj_col)
  if (!is.null(extra$ae_group_col))
    updateSelectizeInput(session, paste0(prefix, "ae_group_col"), selected = extra$ae_group_col)
  if (!is.null(extra$ae_flag_col))
    updateSelectizeInput(session, paste0(prefix, "ae_flag_col"), selected = extra$ae_flag_col)
  if (!is.null(extra$ae_flag_val))
    updateSelectizeInput(session, paste0(prefix, "ae_flag_val"), selected = extra$ae_flag_val)
  if (!is.null(extra$ae_rel_col))
    updateSelectizeInput(session, paste0(prefix, "ae_rel_col"), selected = extra$ae_rel_col)
  if (!is.null(extra$ae_rel_val))
    updateSelectizeInput(session, paste0(prefix, "ae_rel_val"), selected = extra$ae_rel_val)
  if (!is.null(extra$ae_count_mode))
    updateSelectizeInput(session, paste0(prefix, "ae_count_mode"), selected = extra$ae_count_mode)
  if (!is.null(extra$ae_min_pct))
    updateNumericInput(session, paste0(prefix, "ae_min_pct"), value = extra$ae_min_pct)
  invisible(TRUE)
}
