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

# 加载子模块
source("modules/statistical_analysis/cox.R")
source("modules/statistical_analysis/logistic.R")
source("modules/statistical_analysis/linear.R")
source("modules/statistical_analysis/anova.R")
source("modules/statistical_analysis/chisq.R")
source("modules/statistical_analysis/desc.R")
source("modules/common/data_filter.R") # 加载通用筛选模块

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
            tabPanel("统计表格", gt::gt_output(ns("result_table"))),
            tabPanel("结果说明",
                     br(),
                     h4("输出说明:"),
                     tags$ul(
                       tags$li("分类变量: n (%)，百分比分母为当前分组内非缺失样本数"),
                       tags$li("连续变量: N, Mean (SD), Median, Q1/Q3, Min/Max"),
                       tags$li("全缺失、空分组或无法估计时统一显示 NA"),
                       tags$li("行分组作为亚组展示，统计项以缩进方式层级呈现")
                     )
            )
          ),
          br(),
          downloadButton(ns("dl_table"), "导出为Word", class = "btn-primary")
        )
      )
    )
  )
}

# 统计分析服务器逻辑
statistical_analysis_server <- function(input, output, session, data) {
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
  
  # 更新变量选择
  observe({
    req(filtered_data())
    
    df <- filtered_data()
    numeric_vars <- names(df)[sapply(df, is.numeric)]
    factor_vars <- names(df)[sapply(df, function(x) is.factor(x) || is.character(x) || is.logical(x))]
    all_vars <- names(df)
    
    # 更新Cox回归变量选择
    updateSelectInput(session, "cox_time", choices = numeric_vars)
    updateSelectInput(session, "cox_status", choices = numeric_vars)
    updateSelectizeInput(session, "cox_covariates", choices = all_vars)
    updateSelectInput(session, "cox_strata", choices = c("None", factor_vars))
    
    # 更新逻辑回归变量选择
    updateSelectInput(session, "logistic_response", choices = numeric_vars)
    updateSelectizeInput(session, "logistic_predictors", choices = all_vars)
    
    # 更新线性回归变量选择
    updateSelectInput(session, "linear_response", choices = numeric_vars)
    updateSelectizeInput(session, "linear_predictors", choices = all_vars)
    
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
    
    tryCatch({
      switch(input$stat_method,
             "cox" = perform_cox_analysis(filtered_data(), input$cox_time, input$cox_status, input$cox_covariates, input$cox_strata),
             "logistic" = perform_logistic_analysis(filtered_data(), input$logistic_response, input$logistic_predictors),
             "linear" = perform_linear_analysis(filtered_data(), input$linear_response, input$linear_predictors),
             "anova" = perform_anova_analysis(filtered_data(), input$anova_response, input$anova_factors),
             "chi-sq" = perform_chisq_analysis(filtered_data(), input$chisq_var1, input$chisq_var2),
             "desc" = {
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
    }, error = function(e) {
      # 记录详细的错误信息到控制台
      message(paste("统计分析错误详情:", e$message))
      message(paste("调用栈:", paste(deparse(e$call), collapse = "\n")))
      
      showNotification(paste("分析错误:", e$message), type = "error")
      NULL
    })
  })
  
  # 显示结果表格
  output$result_table <- render_gt({
    req(analysis_results())
    
    result <- analysis_results()
    
    if (inherits(result, "gt_tbl")) {
      return(result)
    } else if (is.data.frame(result)) {
      # 简单转换为gt表格
      gt::gt(result)
    } else if (is.list(result) && !is.null(result$table)) {
      gt::gt(result$table)
    } else {
      # 默认显示空表格
      gt::gt(data.frame(Result = "无可用结果"))
    }
  })
  
  # 导出Word文档
  output$dl_table <- downloadHandler(
    filename = function() {
      paste("analysis-result-", Sys.Date(), ".docx", sep = "")
    },
    content = function(file) {
      req(analysis_results())
      
      # 创建临时Rmd文件
      rmd_content <- paste0(
        "---\n",
        "title: \"统计分析报告\"\n",
        "output: word_document\n",
        "---\n\n",
        "## 分析方法\n",
        "统计方法: ", input$stat_method, "\n\n",
        "## 结果\n",
        "```{r}\n",
        "knitr::kable(analysis_results(), format = 'pipe')\n",
        "```\n"
      )
      
      tmp_rmd <- tempfile(fileext = ".Rmd")
      writeLines(rmd_content, tmp_rmd)
      
      # 渲染文档
      rmarkdown::render(
        tmp_rmd,
        output_file = file,
        envir = new.env(parent = globalenv())
      )
    }
  )
  
  # 返回分析结果
  return(analysis_results)
}
