# R Shiny医学数据分析应用 - 增强功能设计

## 高级统计分析方法增强

### 生存分析模块
```r
# Kaplan-Meier生存分析
survival_fit <- reactive({
  req(clean_data(), input$survival_time, input$survival_status)
  
  survival::survfit(
    survival::Surv(get(input$survival_time), get(input$survival_status)) ~ 1,
    data = clean_data()
  )
})

# Cox比例风险模型
cox_model <- reactive({
  req(clean_data(), input$cox_time, input$cox_status, input$cox_covariates)
  
  formula <- as.formula(
    paste("Surv(", input$cox_time, ",", input$cox_status, ") ~", 
          paste(input$cox_covariates, collapse = "+"))
  )
  
  survival::coxph(formula, data = clean_data())
})
```

### 混合效应模型支持
```r
# 线性混合效应模型
lme_model <- reactive({
  req(clean_data(), input$lme_response, input$lme_fixed, input$lme_random)
  
  formula <- as.formula(
    paste(input$lme_response, "~", 
          paste(input$lme_fixed, collapse = "+"), "+",
          paste("(1|", input$lme_random, ")", collapse = "+"))
  )
  
  lme4::lmer(formula, data = clean_data())
})

# 广义线性混合效应模型
glme_model <- reactive({
  req(clean_data(), input$glme_response, input$glme_family, 
      input$glme_fixed, input$glme_random)
  
  formula <- as.formula(
    paste(input$glme_response, "~", 
          paste(input$glme_fixed, collapse = "+"), "+",
          paste("(1|", input$glme_random, ")", collapse = "+"))
  )
  
  lme4::glmer(formula, family = input$glme_family, data = clean_data())
})
```

### 多重插补分析
```r
# 多重插补处理
imputed_data <- reactive({
  req(clean_data(), input$imputation_vars, input$imputation_method)
  
  mice::mice(
    clean_data()[, input$imputation_vars, drop = FALSE],
    method = input$imputation_method,
    m = input$imputation_m,
    maxit = input$imputation_maxit
  )
})

# 插补后分析
pooled_analysis <- reactive({
  req(imputed_data(), input$analysis_formula)
  
  fits <- with(imputed_data(), lm(as.formula(input$analysis_formula)))
  mice::pool(fits)
})
```

## 医学专用可视化增强

### 生存曲线绘制
```r
# Kaplan-Meier曲线
output$km_plot <- renderPlotly({
  req(survival_fit())
  
  ggsurvplot(
    survival_fit(),
    data = clean_data(),
    risk.table = TRUE,
    pval = TRUE,
    conf.int = TRUE,
    palette = "lancet",
    ggtheme = theme_bw()
  ) %>% 
    ggplotly() %>%
    layout(title = "Kaplan-Meier生存曲线")
})
```

### 森林图绘制
```r
# Cox模型森林图
output$forest_plot <- renderPlot({
  req(cox_model())
  
  ggforest(
    cox_model(),
    data = clean_data(),
    main = "Cox回归森林图",
    fontsize = 0.8,
    noDigits = 3
  )
})
```

### 热图和相关性矩阵
```r
# 相关性热图
output$correlation_heatmap <- renderPlotly({
  req(clean_data())
  
  numeric_data <- clean_data() %>% select(where(is.numeric))
  cor_matrix <- cor(numeric_data, use = "complete.obs")
  
  plot_ly(
    x = colnames(cor_matrix),
    y = rownames(cor_matrix),
    z = cor_matrix,
    type = "heatmap",
    colors = colorRamp(c("blue", "white", "red"))
  ) %>%
    layout(title = "变量相关性热图")
})
```

## 用户界面和用户体验改进

### 现代化UI设计
```r
# 使用bslib进行现代化主题设计
theme <- bs_theme(
  version = 5,
  bg = "#FFFFFF",
  fg = "#000000",
  primary = "#1E88E5",
  secondary = "#FF6B6B",
  success = "#4CAF50",
  info = "#2196F3",
  warning = "#FFC107",
  danger = "#F44336"
)

# 应用主题
shinyOptions(bs_theme = theme)
```

### 响应式布局优化
```r
# 自适应网格系统
fluidPage(
  theme = theme,
  layout_columns(
    col_widths = breakpoints(
      lg = c(3, 6, 3),
      md = c(4, 8),
      sm = 12
    ),
    # 左侧边栏
    card(
      card_header("控制面板"),
      # 控制元素
    ),
    # 主内容区
    card(
      card_header("分析结果"),
      # 结果展示
    ),
    # 右侧边栏
    card(
      card_header("高级设置"),
      # 高级选项
    )
  )
)
```

### 交互式教程和帮助系统
```r
# 内置教程系统
introjsUI()
observeEvent(input$show_tutorial, {
  introjs(session, options = list(
    steps = list(
      list(
        element = "#file_upload",
        intro = "首先在这里上传您的数据文件"
      ),
      list(
        element = "#variable_tray",
        intro = "这里是变量托盘，可以拖放变量到图形映射区"
      ),
      # 更多步骤...
    )
  ))
})
```

## 数据导出和报告生成功能

### 多种格式导出
```r
# Word文档导出
output$export_word <- downloadHandler(
  filename = function() {
    paste("analysis-report-", Sys.Date(), ".docx", sep = "")
  },
  content = function(file) {
    req(analysis_results())
    
    rmarkdown::render(
      "report_template.Rmd",
      output_file = file,
      params = list(results = analysis_results()),
      envir = new.env(parent = globalenv())
    )
  }
)

# PDF图形导出
output$export_pdf <- downloadHandler(
  filename = function() {
    paste("plot-", Sys.Date(), ".pdf", sep = "")
  },
  content = function(file) {
    req(current_plot())
    
    pdf(file, width = 10, height = 8)
    print(current_plot())
    dev.off()
  }
)

# Excel数据导出
output$export_excel <- downloadHandler(
  filename = function() {
    paste("data-", Sys.Date(), ".xlsx", sep = "")
  },
  content = function(file) {
    writexl::write_xlsx(clean_data(), file)
  }
)
```

### 自动化报告生成
```r
# 报告模板系统
generate_report <- function(results, format = "html") {
  template <- system.file("templates", "medical_report.Rmd", package = "AutoTFL")
  
  render_args <- list(
    input = template,
    output_format = if (format == "html") "html_document" else "word_document",
    params = list(results = results),
    envir = new.env(parent = globalenv())
  )
  
  do.call(rmarkdown::render, render_args)
}
```

## 数据安全和合规性增强

### 审计日志系统
```r
# 完整操作审计
audit_log <- reactiveValues()
observe({
  # 记录所有重要操作
  audit_log$operations <- c(audit_log$operations, list(
    timestamp = Sys.time(),
    user = Sys.info()["user"],
    operation = "data_upload",
    details = list(file_name = input$file_upload$name)
  ))
})

# 审计报告生成
output$audit_report <- downloadHandler(
  filename = function() {
    paste("audit-log-", Sys.Date(), ".csv", sep = "")
  },
  content = function(file) {
    write.csv(audit_log$operations, file, row.names = FALSE)
  }
)
```

### 数据加密和访问控制
```r
# 敏感数据加密
encrypt_data <- function(data, key) {
  sodium::data_encrypt(
    serialize(data, NULL),
    key = sodium::hash(charToRaw(key))
  )
}

decrypt_data <- function(encrypted_data, key) {
  unserialize(
    sodium::data_decrypt(
      encrypted_data,
      key = sodium::hash(charToRaw(key))
    )
  )
}
```

## 性能和大型数据集优化

### 数据分块处理
```r
# 大数据集分块读取
chunked_data_processing <- function(file_path, chunk_size = 10000) {
  con <- file(file_path, "r")
  on.exit(close(con))
  
  # 读取列名
  header <- readLines(con, n = 1)
  col_names <- unlist(strsplit(header, ","))
  
  # 分块处理
  results <- list()
  chunk_count <- 0
  
  while (TRUE) {
    chunk <- readLines(con, n = chunk_size)
    if (length(chunk) == 0) break
    
    chunk_count <- chunk_count + 1
    chunk_data <- read.csv(text = chunk, col.names = col_names)
    
    # 处理当前分块
    results[[chunk_count]] <- process_chunk(chunk_data)
  }
  
  # 合并结果
  do.call(rbind, results)
}
```

### 内存使用优化
```r
# 内存监控和优化
memory_monitor <- reactiveTimer(5000) # 每5秒检查一次
observeEvent(memory_monitor(), {
  mem_usage <- pryr::mem_used()
  if (mem_usage > 1e9) { # 超过1GB
    showNotification(
      paste("内存使用过高:", format(mem_usage, big.mark = ","), "bytes"),
      type = "warning"
    )
    # 触发垃圾回收
    gc()
  }
})
```

### 延迟加载和缓存
```r
# 结果缓存系统
cached_results <- reactiveValues()
observeEvent(input$run_analysis, {
  # 创建分析结果的哈希键
  cache_key <- digest::digest(list(
    input$analysis_method,
    input$analysis_params,
    digest::digest(clean_data())
  ))
  
  # 检查缓存
  if (!is.null(cached_results[[cache_key]])) {
    analysis_results(cached_results[[cache_key]])
  } else {
    # 执行分析并缓存结果
    result <- perform_analysis()
    cached_results[[cache_key]] <- result
    analysis_results(result)
  }
})
```

## 集成测试和验证框架

### 自动化测试套件
```r
# 单元测试框架
test_module <- function(module_name) {
  testthat::test_that(paste(module_name, "功能测试"), {
    # 数据准备测试
    testthat::expect_silent(prepare_test_data())
    
    # 分析功能测试
    testthat::expect_is(perform_analysis(), "data.frame")
    
    # 可视化测试
    testthat::expect_silent(create_visualization())
  })
}

# 性能基准测试
benchmark_analysis <- function() {
  microbenchmark::microbenchmark(
    small_data = analyze_data(small_dataset),
    medium_data = analyze_data(medium_dataset),
    large_data = analyze_data(large_dataset),
    times = 10
  )
}
```

这个增强功能设计文档提供了全面的功能扩展，包括高级统计分析、医学专用可视化、现代化UI/UX、数据导出、安全性和性能优化，确保应用满足专业医学数据分析的需求。