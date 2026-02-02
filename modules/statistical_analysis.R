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

# 统计方法选择UI
statistical_analysis_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
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
                       tags$li("分类变量: n (n/N%)"),
                       tags$li("连续变量: mean (sd)"),
                       tags$li("中位数: median"),
                       tags$li("最小值/最大值: min, max"),
                       tags$li("四分位数: q1, q3")
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
  
  # 获取列分组变量的水平（用于描述性统计）
  desc_group_levels <- reactive({
    req(data(), input$desc_col_group_var != "无")
    unique(data()[[input$desc_col_group_var]])
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
    req(input$stat_method, data())
    
    switch(input$stat_method,
           "cox" = cox_params_ui(ns, data()),
           "logistic" = logistic_params_ui(ns, data()),
           "linear" = linear_params_ui(ns, data()),
           "anova" = anova_params_ui(ns, data()),
           "chi-sq" = chisq_params_ui(ns, data()),
           "desc" = desc_params_ui(ns, data()),
           NULL
    )
  })
  
  # 更新变量选择
  observe({
    req(data())
    
    df <- data()
    numeric_vars <- names(df)[sapply(df, is.numeric)]
    factor_vars <- names(df)[sapply(df, is.factor)]
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
    
    # 更新描述性统计变量选择
    updateSelectizeInput(session, "desc_variables", choices = all_vars)
    updateSelectInput(session, "desc_col_group_var", choices = c("无", factor_vars))
    updateSelectInput(session, "desc_row_group_var", choices = c("无", factor_vars))
  })
  
  # 执行分析
  analysis_results <- eventReactive(input$run_analysis, {
    req(data(), input$stat_method)
    
    tryCatch({
      switch(input$stat_method,
             "cox" = perform_cox_analysis(data(), input$cox_time, input$cox_status, input$cox_covariates, input$cox_strata),
             "logistic" = perform_logistic_analysis(data(), input$logistic_response, input$logistic_predictors),
             "linear" = perform_linear_analysis(data(), input$linear_response, input$linear_predictors),
             "anova" = perform_anova_analysis(data(), input$anova_response, input$anova_factors),
             "chi-sq" = perform_chisq_analysis(data(), input$chisq_var1, input$chisq_var2),
             "desc" = perform_desc_analysis(data(), input$desc_variables, input$desc_col_group_var, input$desc_row_group_var,
                                            input$desc_total_cols_count, desc_total_cols_settings(),
                                            input$desc_decimals, input$desc_auto_decimals),
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