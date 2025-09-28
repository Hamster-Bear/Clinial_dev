# 统计分析模块

# 统计方法选择UI
statistical_analysis_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
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
    
    # 动态参数UI
    uiOutput(ns("stat_params_ui")),
    
    # 执行按钮
    actionButton(
      ns("run_analysis"),
      "运行分析",
      icon = icon("play"),
      class = "btn-success"
    ),
    
    # 结果展示
    box(
      width = 12,
      title = "分析结果",
      status = "success",
      gt_output(ns("result_table")),
      br(),
      downloadButton(ns("dl_table"), "导出为Word")
    )
  )
}

# 统计分析服务器逻辑
statistical_analysis_server <- function(input, output, session, data) {
  ns <- session$ns
  
  # 动态参数UI
  output$stat_params_ui <- renderUI({
    req(input$stat_method, data())
    
    switch(input$stat_method,
           "cox" = cox_params_ui(ns),
           "logistic" = logistic_params_ui(ns, data()),
           "linear" = linear_params_ui(ns, data()),
           "anova" = anova_params_ui(ns, data()),
           "chi-sq" = chisq_params_ui(ns, data()),
           "desc" = desc_params_ui(ns, data()),
           NULL
    )
  })
  
  # Cox回归参数UI
  cox_params_ui <- function(ns) {
    tagList(
      selectInput(ns("cox_time"), "时间变量 (Time)", choices = NULL),
      selectInput(ns("cox_status"), "删失变量 (Status)", choices = NULL),
      selectizeInput(ns("cox_covariates"), "协变量 (Covariates)", choices = NULL, multiple = TRUE),
      selectInput(ns("cox_strata"), "分层变量 (Strata) - 可选", choices = c("None", NULL))
    )
  }
  
  # 逻辑回归参数UI
  logistic_params_ui <- function(ns, data) {
    numeric_vars <- names(data)[sapply(data, is.numeric)]
    tagList(
      selectInput(ns("logistic_response"), "响应变量", choices = numeric_vars),
      selectizeInput(ns("logistic_predictors"), "预测变量", choices = names(data), multiple = TRUE)
    )
  }
  
  # 线性回归参数UI
  linear_params_ui <- function(ns, data) {
    numeric_vars <- names(data)[sapply(data, is.numeric)]
    tagList(
      selectInput(ns("linear_response"), "响应变量", choices = numeric_vars),
      selectizeInput(ns("linear_predictors"), "预测变量", choices = names(data), multiple = TRUE)
    )
  }
  
  # 方差分析参数UI
  anova_params_ui <- function(ns, data) {
    numeric_vars <- names(data)[sapply(data, is.numeric)]
    factor_vars <- names(data)[sapply(data, is.factor)]
    tagList(
      selectInput(ns("anova_response"), "响应变量", choices = numeric_vars),
      selectizeInput(ns("anova_factors"), "分组变量", choices = factor_vars, multiple = TRUE)
    )
  }
  
  # 卡方检验参数UI
  chisq_params_ui <- function(ns, data) {
    factor_vars <- names(data)[sapply(data, is.factor)]
    tagList(
      selectInput(ns("chisq_var1"), "变量1", choices = factor_vars),
      selectInput(ns("chisq_var2"), "变量2", choices = factor_vars)
    )
  }
  
  # 描述性统计参数UI
  desc_params_ui <- function(ns, data) {
    tagList(
      selectizeInput(ns("desc_vars"), "选择变量", choices = names(data), multiple = TRUE),
      checkboxGroupInput(ns("desc_stats"), "统计量",
                         choices = c("平均值" = "mean", "标准差" = "sd", "中位数" = "median",
                                     "最小值" = "min", "最大值" = "max", "缺失值" = "na"),
                         selected = c("mean", "sd"))
    )
  }
  
  # 更新变量选择
  observe({
    req(data())
    
    df <- data()
    numeric_vars <- names(df)[sapply(df, is.numeric)]
    factor_vars <- names(df)[sapply(df, is.factor)]
    
    # 更新Cox回归变量选择
    updateSelectInput(session, "cox_time", choices = numeric_vars)
    updateSelectInput(session, "cox_status", choices = numeric_vars)
    updateSelectizeInput(session, "cox_covariates", choices = names(df))
    updateSelectInput(session, "cox_strata", choices = c("None", factor_vars))
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
             "desc" = perform_desc_analysis(data(), input$desc_vars, input$desc_stats),
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
    
    if (is.data.frame(result)) {
      gt(result) %>%
        tab_header(
          title = "统计分析结果",
          subtitle = paste("方法:", input$stat_method)
        ) %>%
        fmt_number(columns = where(is.numeric), decimals = 3)
    } else if (is.list(result) && !is.null(result$table)) {
      result$table
    } else {
      # 默认显示
      gt(tibble(Result = "无可用结果")) %>%
        tab_header(title = "分析结果")
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

# Cox回归分析
perform_cox_analysis <- function(data, cox_time, cox_status, cox_covariates, cox_strata) {
  req(cox_time, cox_status)
  
  # 验证变量是否存在
  if (!cox_time %in% names(data)) {
    stop(paste("时间变量", cox_time, "不存在于数据中"))
  }
  if (!cox_status %in% names(data)) {
    stop(paste("状态变量", cox_status, "不存在于数据中"))
  }
  
  # 验证协变量是否存在
  if (!is.null(cox_covariates) && length(cox_covariates) > 0) {
    missing_covariates <- cox_covariates[!cox_covariates %in% names(data)]
    if (length(missing_covariates) > 0) {
      stop(paste("协变量不存在:", paste(missing_covariates, collapse = ", ")))
    }
  }
  
  # 直接构建公式，避免中间变量
  if (length(cox_covariates) > 0) {
    formula <- as.formula(paste("Surv(", cox_time, ",", cox_status, ") ~",
                                paste(cox_covariates, collapse = "+")))
  } else {
    formula <- as.formula(paste("Surv(", cox_time, ",", cox_status, ") ~ 1"))
  }
  
  # 添加分层变量
  if (!is.null(cox_strata) && cox_strata != "None") {
    if (!cox_strata %in% names(data)) {
      stop(paste("分层变量", cox_strata, "不存在于数据中"))
    }
    formula <- as.formula(paste0(deparse(formula), " + strata(", cox_strata, ")"))
  }
  
  # 执行Cox回归
  model <- survival::coxph(formula, data = data)
  
  # 提取结果
  result <- broom::tidy(model, conf.int = TRUE, exponentiate = TRUE)
  
  return(result)
}

# 逻辑回归分析
perform_logistic_analysis <- function(data, logistic_response, logistic_predictors) {
  req(logistic_response, logistic_predictors)
  
  formula <- as.formula(
    paste(logistic_response, "~", paste(logistic_predictors, collapse = "+"))
  )
  
  model <- glm(formula, data = data, family = binomial())
  result <- broom::tidy(model, conf.int = TRUE, exponentiate = TRUE)
  
  return(result)
}

# 线性回归分析
perform_linear_analysis <- function(data, linear_response, linear_predictors) {
  req(linear_response, linear_predictors)
  
  formula <- as.formula(
    paste(linear_response, "~", paste(linear_predictors, collapse = "+"))
  )
  
  model <- lm(formula, data = data)
  result <- broom::tidy(model, conf.int = TRUE)
  
  return(result)
}

# 方差分析
perform_anova_analysis <- function(data, anova_response, anova_factors) {
  req(anova_response, anova_factors)
  
  formula <- as.formula(
    paste(anova_response, "~", paste(anova_factors, collapse = "*"))
  )
  
  model <- aov(formula, data = data)
  result <- broom::tidy(model)
  
  return(result)
}

# 卡方检验
perform_chisq_analysis <- function(data, chisq_var1, chisq_var2) {
  req(chisq_var1, chisq_var2)
  
  table <- table(data[[chisq_var1]], data[[chisq_var2]])
  test <- chisq.test(table)
  
  result <- data.frame(
    Statistic = test$statistic,
    p.value = test$p.value,
    df = test$parameter
  )
  
  return(result)
}

# 描述性统计
perform_desc_analysis <- function(data, desc_vars, desc_stats) {
  req(desc_vars, desc_stats)
  
  # 验证变量是否存在
  missing_vars <- desc_vars[!desc_vars %in% names(data)]
  if (length(missing_vars) > 0) {
    stop(paste("变量不存在:", paste(missing_vars, collapse = ", ")))
  }
  
  desc_data <- data %>% select(all_of(desc_vars))
  
  stats_list <- list()
  
  # 只对数值型变量计算统计量
  numeric_vars <- names(desc_data)[sapply(desc_data, is.numeric)]
  
  if ("mean" %in% desc_stats) {
    if (length(numeric_vars) > 0) {
      stats_list$Mean <- sapply(desc_data[numeric_vars], function(x) {
        if (is.numeric(x)) mean(x, na.rm = TRUE) else NA
      })
    }
  }
  
  if ("sd" %in% desc_stats) {
    if (length(numeric_vars) > 0) {
      stats_list$SD <- sapply(desc_data[numeric_vars], function(x) {
        if (is.numeric(x)) sd(x, na.rm = TRUE) else NA
      })
    }
  }
  
  if ("median" %in% desc_stats) {
    if (length(numeric_vars) > 0) {
      stats_list$Median <- sapply(desc_data[numeric_vars], function(x) {
        if (is.numeric(x)) median(x, na.rm = TRUE) else NA
      })
    }
  }
  
  if ("min" %in% desc_stats) {
    if (length(numeric_vars) > 0) {
      stats_list$Min <- sapply(desc_data[numeric_vars], function(x) {
        if (is.numeric(x)) min(x, na.rm = TRUE) else NA
      })
    }
  }
  
  if ("max" %in% desc_stats) {
    if (length(numeric_vars) > 0) {
      stats_list$Max <- sapply(desc_data[numeric_vars], function(x) {
        if (is.numeric(x)) max(x, na.rm = TRUE) else NA
      })
    }
  }
  
  if ("na" %in% desc_stats) {
    stats_list$Missing <- colSums(is.na(desc_data))
  }
  
  # 处理空结果的情况
  if (length(stats_list) == 0) {
    return(data.frame(Variable = desc_vars, Note = "无可用统计量"))
  }
  
  result <- as.data.frame(do.call(cbind, stats_list))
  result$Variable <- rownames(result)
  result <- result %>% select(Variable, everything())
  
  return(result)
}