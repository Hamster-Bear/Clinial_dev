# 统计分析主模块
# 负责集成所有统计分析子模块

# 加载必要的包
library(shiny)
library(dplyr)
library(broom)
library(survival)
library(gt)
library(shinyWidgets)
library(DT)
library(tidyr)
# 确保加载 gtsummary
if (requireNamespace("gtsummary", quietly = TRUE)) {
  library(gtsummary)
}

# 加载子模块
source("modules/statistical_analysis/cox.R")
source("modules/statistical_analysis/logistic.R")
source("modules/statistical_analysis/linear.R")
source("modules/statistical_analysis/anova.R")
source("modules/statistical_analysis/chisq.R")
source("modules/statistical_analysis/desc.R")
source("modules/common/data_filter.R") # 加载通用筛选模块
source("modules/common/table_export.R")

# 统计方法选择UI
statistical_analysis_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      # 顶部：数据筛选（新增）
      column(
        width = 12,
        box(
          width = NULL,
          title = "全局数据筛选",
          status = "info",
          solidHeader = TRUE,
          collapsible = TRUE,
          collapsed = TRUE, # 默认折叠
          # 调用筛选模块 UI
          data_filter_ui(ns("global_filter"))
        )
      )
    ),
    fluidRow(
      # 左侧：方法选择和变量选择
      column(
        width = 4,
        box(
          width = 12,
          title = "统计方法选择",
          status = "primary",
          solidHeader = TRUE,
          selectInput(
            ns("stat_method"),
            "选择统计方法",
            choices = list(
              "描述性统计" = "desc",
              "回归模型" = list(
                "Cox回归" = "cox",
                "逻辑回归" = "logistic",
                "线性回归" = "linear"
              ),
              "组间比较" = list(
                "方差分析(ANOVA)" = "anova",
                "卡方检验" = "chi-sq",
                "CMH检验" = "cmh"
              ),
              "高级方法" = list(
                "MMRM" = "mmrm",
                "多重填补" = "mi"
              )
            )
          )
        ),
        
        # 变量选择和参数设置面板
        box(
          width = 12,
          title = "变量选择和参数设置",
          status = "info",
          solidHeader = TRUE,
          # 动态参数UI
          uiOutput(ns("stat_params_ui")),
          
          # 执行按钮
          actionButton(
            ns("run_analysis"),
            "运行分析",
            icon = icon("play"),
            class = "btn-success",
            width = "100%"
          )
        )
      ),
      
      # 右侧：结果展示
      column(
        width = 8,
        box(
          width = 12,
          title = "分析结果",
          status = "success",
          solidHeader = TRUE,
          tabsetPanel(
            tabPanel("统计表格", div(style = "width: 90%; margin: 18px auto 24px auto; padding: 8px 0 12px 0; overflow-x: auto;", gt::gt_output(ns("result_table")))),
            tabPanel("统计报告",
                     br(),
                     uiOutput(ns("analysis_interpretation"))
            ),
            tabPanel("可复现代码",
                     br(),
                     verbatimTextOutput(ns("repro_code_out"))
            )
          ),
          br(),
          fluidRow(
            column(
              width = 4,
              selectInput(
                ns("dl_format"),
                "导出格式",
                choices = c("Word" = "word", "HTML" = "html", "RTF" = "rtf"),
                selected = "word"
              )
            ),
            column(
              width = 4,
              textInput(ns("export_title"), "导出标题", value = "Table 1. Statistical Analysis Results")
            ),
            column(
              width = 4,
              div(style = "padding-top: 25px;", downloadButton(ns("dl_table"), "导出报告", class = "btn-primary"))
            )
          ),
          fluidRow(
            column(
              width = 12,
              textAreaInput(
                ns("export_footnotes"),
                "导出脚注（每行一条）",
                value = "Data are presented as n (%) for categorical variables and summary statistics for continuous variables.\nP values were calculated using method-specific tests.\nMissing values were retained and reported as available in source data.",
                rows = 4
              )
            )
          )
        )
      )
    )
  )
}

# 统计分析服务器逻辑
statistical_analysis_server <- function(id, data) {
  moduleServer(id, function(input, output, session) {
  ns <- session$ns
  
  # 调用筛选模块，获取筛选后的数据
  filtered_data <- data_filter_server("global_filter", data)
  
  # 获取列分组变量的水平（用于描述性统计）
  desc_group_levels <- reactive({
    req(filtered_data(), input$desc_col_group_var != "无")
    unique(filtered_data()[[input$desc_col_group_var]])
  })
  
  # 动态生成描述性统计的总计列设置UI
  output$desc_total_cols_ui <- renderUI({
    req(input$desc_total_cols_count >= 1, desc_group_levels())
    
    total_cols <- lapply(1:input$desc_total_cols_count, function(i) {
      wellPanel(
        textInput(ns(paste0("desc_total_col_name_", i)),
                  paste("总计列", i, "名称"),
                  value = paste("总计", i)),
        selectizeInput(
          inputId = ns(paste0("desc_total_col_groups_", i)),
          label = paste("选择总计列", i, "包含的组"),
          choices = desc_group_levels(),
          multiple = TRUE
        )
      )
    })
    
    do.call(tagList, total_cols)
  })
  
  # 获取描述性统计的总计列设置
  desc_total_cols_settings <- reactive({
    req(input$desc_total_cols_count >= 1, input$desc_col_group_var != "无")
    
    settings <- list()
    for (i in 1:input$desc_total_cols_count) {
      name_id <- paste0("desc_total_col_name_", i)
      groups_id <- paste0("desc_total_col_groups_", i)
      
      if (!is.null(input[[name_id]]) && !is.null(input[[groups_id]])) {
        settings[[i]] <- list(
          name = input[[name_id]],
          groups = input[[groups_id]]
        )
      }
    }
    
    settings
  })
  
  # 动态参数UI
  output$stat_params_ui <- renderUI({
    req(input$stat_method, filtered_data())
    
    switch(input$stat_method,
           "cox" = cox_params_ui(ns, filtered_data()),
           "logistic" = logistic_params_ui(ns, filtered_data()),
           "linear" = linear_params_ui(ns, filtered_data()),
           "anova" = anova_params_ui(ns, filtered_data()),
           "chi-sq" = chisq_params_ui(ns, filtered_data()),
           "desc" = desc_params_ui(ns, filtered_data()),
           NULL
    )
  })
  
  to_user_guidance <- function(raw_msg) {
    msg <- trimws(as.character(raw_msg))
    if (grepl("contrasts can be applied only to factors with 2 or more levels", msg, ignore.case = TRUE)) {
      return("某个分类变量在当前数据中仅剩1个水平，请调整全局筛选或更换分层/分组变量。")
    }
    if (grepl("computationally singular|奇异|collinea", msg, ignore.case = TRUE)) {
      return("模型变量间可能存在高度相关性，请减少预测变量或先做相关性筛查。")
    }
    if (grepl("did not converge|converge|separation|fitted probabilities numerically 0 or 1", msg, ignore.case = TRUE)) {
      return("模型未稳定收敛，建议合并稀疏分组、减少变量数量或放宽筛选条件。")
    }
    if (grepl("not enough|insufficient|too few|样本量|事件数", msg, ignore.case = TRUE)) {
      return("当前样本量或事件数不足，建议减少模型复杂度或扩大分析样本。")
    }
    if (grepl("object '.*' not found|不存在", msg, ignore.case = TRUE)) {
      return("存在变量缺失，请检查变量选择与数据准备步骤是否一致。")
    }
    if (grepl("NA/NaN/Inf|missing values|non-finite", msg, ignore.case = TRUE)) {
      return("数据中存在缺失或无效值，请在数据准备阶段处理后重试。")
    }
    paste0("请检查变量类型、筛选条件与样本量。系统原始信息：", msg)
  }

  get_method_profile <- function(method_code) {
    profiles <- list(
      "desc" = list(
        name = "描述性统计",
        intro = "用于系统描述样本的人口学特征、基线特征及主要指标分布。",
        scenarios = c("基线特征展示", "安全性/有效性指标概览", "探索性数据扫描"),
        metrics = c("分类变量: n (%)，百分比分母为当前分组内非缺失样本数", "连续变量: N、Mean (SD)、Median、Q1/Q3、Min/Max"),
        tips = c("优先检查关键变量缺失比例与异常值分布", "行分组表示分层，列分组表示并排比较", "解读总计列时确认其包含的组别定义")
      ),
      "cox" = list(
        name = "Cox回归",
        intro = "用于评估协变量与事件发生风险之间的关系，输出风险比(HR)。",
        scenarios = c("生存时间分析", "事件发生风险比较", "多因素风险校正"),
        metrics = c("核心统计量: HR、95%CI、P值", "HR>1 表示风险升高，HR<1 表示风险降低"),
        tips = c("先检查事件变量编码是否正确", "关注比例风险假设是否合理", "样本事件数不足时减少模型复杂度")
      ),
      "logistic" = list(
        name = "逻辑回归",
        intro = "用于二分类结局的关联建模，输出优势比(OR)。",
        scenarios = c("二分类结局建模", "危险因素筛选", "调整混杂后的关联评估"),
        metrics = c("核心统计量: OR、95%CI、P值", "OR>1 表示结局发生几率升高，OR<1 表示降低"),
        tips = c("确保响应变量为二分类编码", "留意稀疏数据与完全分离问题", "优先报告临床上有意义的效应量")
      ),
      "linear" = list(
        name = "线性回归",
        intro = "用于连续型结局建模，评估协变量对结局均值的线性影响。",
        scenarios = c("连续终点建模", "协变量校正分析", "剂量-效应趋势探索"),
        metrics = c("核心统计量: 回归系数、95%CI、P值", "系数正负代表结局变化方向"),
        tips = c("先检查线性关系与异常值", "注意残差分布与同方差性", "解释时同时报告方向、量级和不确定性")
      ),
      "anova" = list(
        name = "方差分析(ANOVA)",
        intro = "用于比较多个组别在连续型指标上的均值差异。",
        scenarios = c("多组均值比较", "治疗组间连续终点差异检验", "探索性组间比较"),
        metrics = c("核心统计量: F值、P值", "若总体差异显著，建议补充事后两两比较"),
        tips = c("确认组间方差齐性前提", "组样本量极不平衡时谨慎解释", "显著后再结合效应量报告临床意义")
      ),
      "chi-sq" = list(
        name = "卡方检验",
        intro = "用于检验两个分类变量之间是否存在统计关联。",
        scenarios = c("列联表分析", "组别与分类结局关联检验", "安全性事件发生率比较"),
        metrics = c("核心统计量: 卡方值、P值", "必要时关注单元格期望频数条件"),
        tips = c("当期望频数过低时考虑Fisher精确检验", "同时报告各组比例差异", "结果解读结合实际业务背景")
      )
    )
    if (!method_code %in% names(profiles)) {
      return(list(
        name = method_code,
        intro = "当前方法暂无预置说明。",
        scenarios = "请结合统计方案进行解释。",
        metrics = "请结合输出表格中的统计量进行解释。",
        tips = "优先核对变量类型、样本量与缺失值。"
      ))
    }
    profiles[[method_code]]
  }

  html_to_text <- function(x) {
    txt <- as.character(x)
    txt <- gsub("(?i)<br\\s*/?>", "\n", txt, perl = TRUE)
    txt <- gsub("(?i)</li>", "\n", txt, perl = TRUE)
    txt <- gsub("<[^>]+>", "", txt)
    txt <- gsub("&nbsp;", " ", txt, fixed = TRUE)
    txt <- gsub("&lt;", "<", txt, fixed = TRUE)
    txt <- gsub("&gt;", ">", txt, fixed = TRUE)
    txt <- gsub("&amp;", "&", txt, fixed = TRUE)
    txt <- gsub("[\r\t]", " ", txt)
    txt <- gsub("\n{2,}", "\n", txt)
    trimws(txt)
  }

  parse_p_value <- function(x) {
    s <- trimws(as.character(x))
    if (length(s) == 0 || is.na(s) || s == "") return(NA_real_)
    s <- gsub(",", ".", s, fixed = TRUE)
    if (grepl("^<", s)) {
      s <- sub("^<\\s*", "", s)
    }
    val <- suppressWarnings(as.numeric(s))
    if (is.na(val)) return(NA_real_)
    val
  }

  extract_key_findings <- function(gt_obj) {
    if (!inherits(gt_obj, "gt_tbl")) return(character(0))
    raw_df <- tryCatch(gt_obj[["_data"]], error = function(e) NULL)
    if (is.null(raw_df) || !is.data.frame(raw_df) || nrow(raw_df) == 0) return(character(0))
    nm <- names(raw_df)
    p_cols <- nm[grepl("p\\.value|p_value|pvalue|^p$", nm, ignore.case = TRUE)]
    label_cols <- nm[grepl("^label$|variable|term|characteristic|statistics", nm, ignore.case = TRUE)]
    est_cols <- nm[grepl("^estimate$|or$|hr$|rr$|beta|coef", nm, ignore.case = TRUE)]
    if (length(p_cols) == 0 || length(label_cols) == 0) return(character(0))
    p_col <- p_cols[1]
    label_col <- label_cols[1]
    est_col <- if (length(est_cols) > 0) est_cols[1] else NULL
    p_vec <- vapply(raw_df[[p_col]], parse_p_value, numeric(1))
    idx <- which(!is.na(p_vec) & p_vec < 0.05)
    if (length(idx) == 0) return(character(0))
    idx <- idx[seq_len(min(length(idx), 5))]
    findings <- vapply(idx, function(i) {
      label <- trimws(as.character(raw_df[[label_col]][i]))
      if (is.na(label) || label == "") return("")
      if (!is.null(est_col)) {
        est_val <- trimws(as.character(raw_df[[est_col]][i]))
        if (!is.na(est_val) && nzchar(est_val)) {
          return(paste0(label, " 与结局关联具有统计学意义 (P=", signif(p_vec[i], 3), ", 效应量=", est_val, ")"))
        }
      }
      paste0(label, " 与结局关联具有统计学意义 (P=", signif(p_vec[i], 3), ")")
    }, character(1))
    findings <- findings[nzchar(findings)]
    unique(findings)
  }

  build_stat_report <- function(result, method_code, analysis_ctx = list()) {
    profile <- get_method_profile(method_code)
    table_obj <- NULL
    if (inherits(result, "gt_tbl")) {
      table_obj <- result
    } else if (is.list(result) && !is.null(result$table) && inherits(result$table, "gt_tbl")) {
      table_obj <- result$table
    }
    key_findings <- if (!is.null(table_obj)) extract_key_findings(table_obj) else character(0)
    interpretation_lines <- character(0)
    if (is.list(result) && !is.null(result$interpretation)) {
      interpretation_text <- html_to_text(result$interpretation)
      interpretation_lines <- strsplit(interpretation_text, "\n", fixed = TRUE)[[1]]
      interpretation_lines <- trimws(interpretation_lines)
      interpretation_lines <- interpretation_lines[nzchar(interpretation_lines)]
    }
    if (length(key_findings) == 0 && length(interpretation_lines) > 0) {
      key_findings <- interpretation_lines[seq_len(min(3, length(interpretation_lines)))]
    }
    if (length(key_findings) == 0) {
      key_findings <- c("当前结果以统计表格为主，请结合研究目的重点关注主终点对应统计量。")
    }
    model_notes <- character(0)
    if (is.list(result) && !is.null(result$model_notes)) {
      model_notes <- unique(trimws(as.character(result$model_notes)))
      model_notes <- model_notes[nzchar(model_notes)]
    }

    predictors_n <- if (!is.null(analysis_ctx$predictors)) length(analysis_ctx$predictors) else 0
    response_var <- if (!is.null(analysis_ctx$response)) analysis_ctx$response else "未设置"
    strata_var <- if (!is.null(analysis_ctx$strata) && nzchar(analysis_ctx$strata)) analysis_ctx$strata else "无"
    facet_var <- if (!is.null(analysis_ctx$facet) && nzchar(analysis_ctx$facet)) analysis_ctx$facet else "无"
    model_mode <- "固定输入(Enter)建模"
    if (method_code == "logistic") {
      model_mode <- if (predictors_n <= 1) "单因素逻辑回归（固定输入，非逐步回归）" else "多因素逻辑回归（固定输入，非逐步回归）"
    }
    if (method_code == "linear") {
      model_mode <- if (predictors_n <= 1) "单因素线性回归（固定输入，非逐步回归）" else "多因素线性回归（固定输入，非逐步回归）"
    }
    if (method_code == "cox") {
      model_mode <- if (predictors_n <= 1) "单因素Cox回归（固定输入，非逐步回归）" else "多因素Cox回归（固定输入，非逐步回归）"
    }

    metric_explain <- switch(
      method_code,
      "logistic" = c("OR(95%CI): OR>1表示结局发生几率增加，OR<1表示降低", "P值: 常以P<0.05作为统计学显著阈值"),
      "linear" = c("Beta(95%CI): Beta表示自变量每增加1单位时结局均值的变化量", "Beta>0为正向关联，Beta<0为负向关联；P值用于判断显著性"),
      "cox" = c("HR(95%CI): HR>1表示事件风险升高，HR<1表示风险降低", "P值: 常以P<0.05作为统计学显著阈值"),
      profile$metrics
    )
    config_items <- c(
      paste0("响应变量/结局变量：", response_var),
      paste0("预测变量数量：", predictors_n),
      paste0("行分组变量：", strata_var),
      paste0("列分组变量：", facet_var),
      model_mode
    )
    field_dict <- switch(
      method_code,
      "logistic" = c("统计值列：OR (95% CI)", "OR>1：结局发生几率增加", "OR<1：结局发生几率降低", "P值：显著性检验结果", "分层差异P值：检验该分析变量的效应是否在不同分层间存在显著差异（交互检验）"),
      "linear" = c("统计值列：Beta (95% CI)", "Beta>0：正向关联", "Beta<0：负向关联", "P值：显著性检验结果", "分层差异P值：检验该分析变量的效应是否在不同分层间存在显著差异（交互检验）"),
      "cox" = c("统计值列：HR (95% CI)", "HR>1：事件风险升高", "HR<1：事件风险降低", "P值：显著性检验结果", "分层差异P值：检验该分析变量的效应是否在不同分层间存在显著差异（交互检验）"),
      c("请结合统计结果表中的列名和脚注解释字段含义")
    )

    make_ul <- function(items) {
      do.call(tags$ul, lapply(items, tags$li))
    }
    to_md_list <- function(items) {
      paste(paste0("- ", items), collapse = "\n")
    }

    ui <- tagList(
      h4("统计报告"),
      h5("可执行提示"),
      make_ul(profile$tips),
      h5("方法介绍"),
      p(profile$intro),
      h5("模型设定说明"),
      make_ul(c(model_mode, "当前实现不包含逐步筛选流程，如需逐步回归需单独开启变量筛选策略实现")),
      h5("模型配置摘要"),
      make_ul(config_items),
      h5("适用场景"),
      make_ul(profile$scenarios),
      h5("统计量说明"),
      make_ul(metric_explain),
      h5("表格字段说明"),
      make_ul(field_dict),
      h5("模型运行提示"),
      make_ul(if (length(model_notes) > 0) model_notes else c("未发现模型级警告或错误提示。")),
      h5("主要结果解读"),
      make_ul(key_findings)
    )

    markdown <- paste(
      paste0("## 统计报告（", profile$name, "）"),
      "",
      "### 可执行提示",
      to_md_list(profile$tips),
      "",
      "### 方法介绍",
      profile$intro,
      "",
      "### 模型设定说明",
      to_md_list(c(model_mode, "当前实现不包含逐步筛选流程，如需逐步回归需单独开启变量筛选策略实现")),
      "",
      "### 模型配置摘要",
      to_md_list(config_items),
      "",
      "### 适用场景",
      to_md_list(profile$scenarios),
      "",
      "### 统计量说明",
      to_md_list(metric_explain),
      "",
      "### 表格字段说明",
      to_md_list(field_dict),
      "",
      "### 模型运行提示",
      to_md_list(if (length(model_notes) > 0) model_notes else c("未发现模型级警告或错误提示。")),
      "",
      "### 主要结果解读",
      to_md_list(key_findings),
      sep = "\n"
    )
    list(ui = ui, markdown = markdown)
  }

  extract_export_table_df <- function(result) {
    table_obj <- NULL
    if (is.list(result) && !is.null(result$table)) {
      table_obj <- result$table
    } else {
      table_obj <- result
    }
    if (is.data.frame(table_obj)) {
      return(table_obj)
    }
    if (inherits(table_obj, "gt_tbl")) {
      gt_data <- tryCatch(table_obj[["_data"]], error = function(e) NULL)
      if (is.data.frame(gt_data)) {
        return(gt_data)
      }
    }
    data.frame(提示 = "当前结果无法转换为结构化表格", stringsAsFactors = FALSE)
  }

  extract_table_object <- function(result) {
    if (is.list(result) && !is.null(result$table)) {
      return(result$table)
    }
    result
  }

  build_export_footnotes <- function(method_code, custom_footnote = NULL) {
    custom_lines <- character(0)
    if (!is.null(custom_footnote) && nzchar(trimws(custom_footnote))) {
      custom_lines <- trimws(unlist(strsplit(custom_footnote, "\\r?\\n")))
      custom_lines <- custom_lines[nzchar(custom_lines)]
    }
    unique(custom_lines)
  }

  get_analysis_context <- reactive({
    method <- input$stat_method
    switch(method,
      "cox" = list(
        predictors = if (is.null(input$cox_covariates)) character(0) else input$cox_covariates,
        response = paste0(input$cox_time, " / ", input$cox_status),
        strata = if (is.null(input$cox_strata) || input$cox_strata == "None") "" else input$cox_strata,
        facet = if (is.null(input$cox_facet) || input$cox_facet == "None") "" else input$cox_facet
      ),
      "logistic" = list(
        predictors = if (is.null(input$logistic_predictors)) character(0) else input$logistic_predictors,
        response = if (is.null(input$logistic_response)) "未设置" else input$logistic_response,
        strata = if (is.null(input$logistic_strata) || input$logistic_strata == "None") "" else input$logistic_strata,
        facet = if (is.null(input$logistic_facet) || input$logistic_facet == "None") "" else input$logistic_facet
      ),
      "linear" = list(
        predictors = if (is.null(input$linear_predictors)) character(0) else input$linear_predictors,
        response = if (is.null(input$linear_response)) "未设置" else input$linear_response,
        strata = if (is.null(input$linear_strata) || input$linear_strata == "None") "" else input$linear_strata,
        facet = if (is.null(input$linear_facet) || input$linear_facet == "None") "" else input$linear_facet
      ),
      list(predictors = character(0))
    )
  })
  
  # 更新变量选择
  observe({
    req(filtered_data())
    
    df <- filtered_data()
    numeric_vars <- names(df)[sapply(df, is.numeric)]
    factor_vars <- names(df)[sapply(df, function(x) is.factor(x) || is.character(x) || is.logical(x))]
    all_vars <- names(df)
    
    # 更新Cox回归变量选择
    updateSelectInput(session, "cox_time", choices = numeric_vars)
    updateSelectInput(session, "cox_status", choices = all_vars)
    updateSelectizeInput(session, "cox_covariates", choices = all_vars)
    updateSelectInput(session, "cox_strata", choices = c("None", factor_vars))
    updateSelectInput(session, "cox_facet", choices = c("None", factor_vars))
    updateSelectInput(session, "cox_model_strata", choices = c("None", factor_vars))
    
    # 更新逻辑回归变量选择
    updateSelectInput(session, "logistic_response", choices = all_vars)
    updateSelectizeInput(session, "logistic_predictors", choices = all_vars)
    updateSelectInput(session, "logistic_strata", choices = c("None", factor_vars))
    updateSelectInput(session, "logistic_facet", choices = c("None", factor_vars))
    updateSelectInput(session, "logistic_model_strata", choices = c("None", factor_vars))
    
    # 更新线性回归变量选择
    updateSelectInput(session, "linear_response", choices = numeric_vars)
    updateSelectizeInput(session, "linear_predictors", choices = all_vars)
    updateSelectInput(session, "linear_strata", choices = c("None", factor_vars))
    updateSelectInput(session, "linear_facet", choices = c("None", factor_vars))
    updateSelectInput(session, "linear_model_strata", choices = c("None", factor_vars))
    
    # 更新方差分析变量选择
    updateSelectInput(session, "anova_response", choices = numeric_vars)
    updateSelectizeInput(session, "anova_factors", choices = factor_vars)
    
    # 更新卡方检验变量选择
    updateSelectInput(session, "chisq_var1", choices = factor_vars)
    updateSelectInput(session, "chisq_var2", choices = factor_vars)

    current_col_group <- isolate(input$desc_col_group_var)
    current_row_group <- isolate(input$desc_row_group_var)
    current_col_group <- if (is.null(current_col_group)) "无" else current_col_group
    current_row_group <- if (is.null(current_row_group)) "无" else current_row_group
    col_selected <- if (current_col_group %in% c("无", factor_vars)) current_col_group else "无"
    row_selected <- if (current_row_group %in% c("无", factor_vars)) current_row_group else "无"
    current_id_var <- isolate(input$desc_id_var)
    if (is.null(current_id_var) || !current_id_var %in% all_vars) {
      current_id_var <- if ("subject" %in% all_vars) "subject" else if (length(all_vars) > 0) all_vars[1] else NULL
    }
    updateSelectInput(session, "desc_col_group_var", choices = c("无", factor_vars), selected = col_selected)
    updateSelectInput(session, "desc_row_group_var", choices = c("无", factor_vars), selected = row_selected)
    updateSelectInput(session, "desc_id_var", choices = all_vars, selected = current_id_var)
  })

  output$logistic_event_mapping_ui <- renderUI({
    req(filtered_data(), input$logistic_response)
    if (!input$logistic_response %in% names(filtered_data())) return(NULL)
    vals <- unique(as.character(filtered_data()[[input$logistic_response]][!is.na(filtered_data()[[input$logistic_response]])]))
    vals <- vals[nzchar(vals)]
    if (length(vals) == 0) return(NULL)
    event_sel <- if ("1" %in% vals) "1" else vals[1]
    tagList(
      fluidRow(
        column(
          12,
          selectInput(ns("logistic_event_value"), "事件值 (Event)", choices = vals, selected = event_sel),
          bsTooltip(ns("logistic_event_value"), "选择一个取值作为事件，其他非缺失取值自动视为非事件", placement = "top", trigger = "hover")
        )
      )
    )
  })

  output$cox_status_mapping_ui <- renderUI({
    req(filtered_data(), input$cox_status)
    if (!input$cox_status %in% names(filtered_data())) return(NULL)
    vals <- unique(as.character(filtered_data()[[input$cox_status]][!is.na(filtered_data()[[input$cox_status]])]))
    vals <- vals[nzchar(vals)]
    if (length(vals) == 0) return(NULL)
    event_sel <- if ("1" %in% vals) "1" else vals[1]
    tagList(
      fluidRow(
        column(
          12,
          selectInput(ns("cox_event_value"), "事件值 (Event)", choices = vals, selected = event_sel),
          bsTooltip(ns("cox_event_value"), "选择一个取值作为事件，其他非缺失取值自动视为删失", placement = "top", trigger = "hover")
        )
      )
    )
  })

  observeEvent(list(filtered_data(), input$desc_col_group_var, input$desc_row_group_var), {
    req(filtered_data())

    all_vars <- names(filtered_data())
    selected_col_group <- if (is.null(input$desc_col_group_var)) "无" else input$desc_col_group_var
    selected_row_group <- if (is.null(input$desc_row_group_var)) "无" else input$desc_row_group_var
    desc_group_vars <- setdiff(c(selected_col_group, selected_row_group), "无")
    desc_candidate_vars <- setdiff(all_vars, desc_group_vars)
    current_desc_vars <- isolate(input$desc_variables)
    if (is.null(current_desc_vars)) {
      current_desc_vars <- character(0)
    }
    selected_desc_vars <- intersect(current_desc_vars, desc_candidate_vars)
    updateSelectizeInput(session, "desc_variables", choices = desc_candidate_vars, selected = selected_desc_vars, server = TRUE)
  }, ignoreInit = FALSE)
  
  # 执行分析
  analysis_results <- eventReactive(input$run_analysis, {
    req(filtered_data(), input$stat_method)
    
    tryCatch(withCallingHandlers({
      withProgress(message = "正在执行统计分析...", value = 0, {
        incProgress(0.2, detail = "检查输入参数")
        result_obj <- switch(input$stat_method,
          "cox" = {
            incProgress(0.3, detail = "运行Cox回归")
            status_vals <- unique(as.character(filtered_data()[[input$cox_status]][!is.na(filtered_data()[[input$cox_status]])]))
            if (length(status_vals) < 2) stop("Cox状态变量至少需要两个非缺失取值。")
            if (is.null(input$cox_event_value) || !as.character(input$cox_event_value) %in% status_vals) {
              stop("请先为Cox状态变量选择事件值。")
            }
            perform_cox_analysis(filtered_data(), input$cox_time, input$cox_status, input$cox_covariates, input$cox_strata, input$cox_facet, input$cox_event_value, input$cox_model_strata)
          },
          "logistic" = {
            incProgress(0.3, detail = "运行逻辑回归")
            resp_vals <- unique(as.character(filtered_data()[[input$logistic_response]][!is.na(filtered_data()[[input$logistic_response]])]))
            if (length(resp_vals) < 2) stop("逻辑回归响应变量至少需要两个非缺失取值。")
            if (is.null(input$logistic_event_value) || !as.character(input$logistic_event_value) %in% resp_vals) {
              stop("请先为逻辑回归响应变量选择事件值。")
            }
            perform_logistic_analysis(filtered_data(), input$logistic_response, input$logistic_predictors, input$logistic_strata, input$logistic_facet, input$logistic_event_value, input$logistic_model_strata)
          },
          "linear" = {
            incProgress(0.3, detail = "运行线性回归")
            perform_linear_analysis(filtered_data(), input$linear_response, input$linear_predictors, input$linear_strata, input$linear_facet, input$linear_model_strata)
          },
          "anova" = {
            incProgress(0.3, detail = "运行方差分析")
            perform_anova_analysis(filtered_data(), input$anova_response, input$anova_factors)
          },
          "chi-sq" = {
            incProgress(0.3, detail = "运行卡方检验")
            perform_chisq_analysis(filtered_data(), input$chisq_var1, input$chisq_var2)
          },
          "desc" = {
            incProgress(0.3, detail = "运行描述性统计")
            desc_vars <- if (is.null(input$desc_variables)) character(0) else input$desc_variables
            col_group_var <- if (is.null(input$desc_col_group_var)) "无" else input$desc_col_group_var
            row_group_var <- if (is.null(input$desc_row_group_var)) "无" else input$desc_row_group_var
            id_var <- if (is.null(input$desc_id_var) || input$desc_id_var == "") NULL else input$desc_id_var
            if (length(desc_vars) == 0) {
              stop("请至少选择一个分析变量")
            }
            if (col_group_var != "无" && row_group_var != "无" && identical(col_group_var, row_group_var)) {
              stop("行分组变量与列分组变量不能相同")
            }
            overlap_vars <- intersect(desc_vars, setdiff(c(col_group_var, row_group_var), "无"))
            if (length(overlap_vars) > 0) {
              stop(paste0("分析变量不能与分组变量重复: ", paste(overlap_vars, collapse = ", ")))
            }
            perform_desc_analysis(filtered_data(), desc_vars, col_group_var, row_group_var,
                                  input$desc_total_cols_count, desc_total_cols_settings(),
                                  input$desc_decimals, input$desc_auto_decimals, id_var)
          },
          NULL
        )
        incProgress(0.5, detail = "生成分析结果")
        result_obj
      })
    }, warning = function(w) {
      showNotification(paste("分析提示：", to_user_guidance(conditionMessage(w))), type = "warning")
      invokeRestart("muffleWarning")
    }), error = function(e) {
      # 记录详细的错误信息到控制台
      message(paste("统计分析错误详情:", e$message))
      message(paste("调用栈:", paste(deparse(e$call), collapse = "\n")))
      showNotification(paste("分析错误：", to_user_guidance(conditionMessage(e))), type = "error")
      NULL
    })
  })
  
  # 显示结果表格
  output$result_table <- render_gt({
    req(analysis_results())
    
    result <- analysis_results()
    export_title <- if (!is.null(input$export_title) && nzchar(trimws(input$export_title))) trimws(input$export_title) else "Statistical Analysis Results"
    footnotes <- build_export_footnotes(input$stat_method, input$export_footnotes)
    
    if (inherits(result, "gt_tbl")) {
      return(apply_sci_gt_style(result, title = export_title, footnotes = footnotes))
    } else if (is.data.frame(result)) {
      return(apply_sci_gt_style(gt::gt(result), title = export_title, footnotes = footnotes))
    } else if (is.list(result) && !is.null(result$table)) {
      if (inherits(result$table, "gt_tbl")) {
        return(apply_sci_gt_style(result$table, title = export_title, footnotes = footnotes))
      } else {
        return(apply_sci_gt_style(gt::gt(result$table), title = export_title, footnotes = footnotes))
      }
    } else {
      apply_sci_gt_style(gt::gt(data.frame(Result = "无可用结果")), title = export_title, footnotes = footnotes)
    }
  })
  
  output$analysis_interpretation <- renderUI({
    req(analysis_results())
    result <- analysis_results()
    report <- build_stat_report(result, input$stat_method, get_analysis_context())
    report$ui
  })

  output$repro_code_out <- renderText({
    req(analysis_results())
    result <- analysis_results()
    if (is.list(result) && !is.null(result$code)) {
      result$code
    } else {
      "当前分析方法暂未支持代码生成。"
    }
  })

  output$dl_table <- downloadHandler(
    filename = function() {
      fmt <- if (is.null(input$dl_format)) "word" else input$dl_format
      ext <- switch(fmt, word = "docx", html = "html", rtf = "rtf", "docx")
      paste0("analysis-report-", Sys.Date(), ".", ext)
    },
    content = function(file) {
      req(analysis_results())

      result <- analysis_results()
      report <- build_stat_report(result, input$stat_method, get_analysis_context())
      method_profile <- get_method_profile(input$stat_method)
      fmt <- if (is.null(input$dl_format)) "word" else input$dl_format
      export_title <- if (!is.null(input$export_title) && nzchar(trimws(input$export_title))) trimws(input$export_title) else paste0("Table. ", method_profile$name, " Analysis Results")
      export_footnotes <- build_export_footnotes(input$stat_method, input$export_footnotes)
      tryCatch({
        save_table_export(
          file = file,
          result_obj = result,
          format = fmt,
          title = export_title,
          footnotes = export_footnotes,
          report_md = report$markdown,
          method_name = method_profile$name
        )
      }, error = function(e) {
        msg <- to_user_guidance(conditionMessage(e))
        showNotification(paste("导出失败：", msg), type = "error")
        stop(msg)
      })
    }
  )
  
  # 返回分析结果
  return(analysis_results)
  })
}
