# 通用数据筛选模块
# 提取自 data_preparation.R，用于在各个分析模块中提供统一的数据筛选功能

library(shiny)
library(dplyr)
library(shinyWidgets)

# ==============================================================================
# 辅助函数 (复制自 data_preparation.R)
# ==============================================================================

# 判断变量类型
determine_var_type <- function(x) {
  if (is.numeric(x)) {
    return("numeric")
  } else if (is.factor(x) || (is.character(x) && length(unique(x[!is.na(x)])) <= 20)) {
    return("factor")
  } else if (inherits(x, "Date") || inherits(x, "POSIXct") || inherits(x, "POSIXlt")) {
    return("date")
  } else {
    return("text")
  }
}

# 安全计算数值范围
safe_numeric_range <- function(var_data) {
  valid_data <- var_data[!is.na(var_data)]
  if (length(valid_data) == 0) return(list(min = 0.0, max = 1.0))
  
  min_val <- tryCatch({
    result <- min(valid_data, na.rm = TRUE)
    if (length(result) == 0 || is.na(result) || !is.finite(result)) 0.0 else as.numeric(result)
  }, error = function(e) 0.0)
  
  max_val <- tryCatch({
    result <- max(valid_data, na.rm = TRUE)
    if (length(result) == 0 || is.na(result) || !is.finite(result)) 1.0 else as.numeric(result)
  }, error = function(e) 1.0)
  
  if (min_val > max_val) {
    temp <- min_val
    min_val <- max_val
    max_val <- temp + 1
  }
  
  if (!is.finite(min_val)) min_val <- 0.0
  if (!is.finite(max_val)) max_val <- 1.0
  
  return(list(min = min_val, max = max_val))
}

# ==============================================================================
# 模块 UI
# ==============================================================================
data_filter_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    tags$head(
      tags$style(HTML("
        .filter-group .selectize-control.multi .selectize-input > div {
          display: block !important;
          margin-bottom: 4px !important;
        }
        .filter-controls-container {
          scrollbar-width: thin;
          scrollbar-color: #888 #f1f1f1;
        }
      "))
    ),
    
    box(
      width = 12,
      title = "数据筛选 (可选)",
      status = "info",
      solidHeader = TRUE,
      collapsible = TRUE,
      collapsed = TRUE, # 默认折叠，不干扰主流程
      
      fluidRow(
        column(
          width = 4,
          selectizeInput(
            ns("selected_var"),
            "添加筛选变量:",
            choices = NULL,
            multiple = TRUE,
            options = list(placeholder = '选择变量...')
          )
        ),
        column(
          width = 2,
          actionButton(
            ns("reset_filters"),
            "重置筛选",
            class = "btn-warning",
            style = "margin-top: 25px;",
            icon = icon("refresh")
          )
        ),
        column(
          width = 6,
          verbatimTextOutput(ns("filter_stats"), placeholder = TRUE)
        )
      ),
      
      # 动态筛选控件容器
      uiOutput(ns("filter_controls"))
    )
  )
}

# ==============================================================================
# 模块 Server
# ==============================================================================
data_filter_server <- function(id, data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # 监听数据变化，更新变量选择列表
    observeEvent(data(), {
      req(data())
      updateSelectizeInput(session, "selected_var", choices = names(data()), server = TRUE)
    })
    
    # 动态生成筛选控件
    output$filter_controls <- renderUI({
      req(data(), input$selected_var)
      df <- data()
      selected_vars <- input$selected_var
      
      if (length(selected_vars) == 0) return(NULL)
      
      controls <- lapply(selected_vars, function(var_name) {
        var_data <- df[[var_name]]
        var_type <- determine_var_type(var_data)
        
        div(
          class = "filter-group",
          style = "border: 1px solid #ddd; padding: 8px; margin: 3px; border-radius: 4px; background-color: #f8f9fa; display: inline-block; vertical-align: top; width: 280px; margin-right: 8px;",
          
          h5(paste(var_name, "(", var_type, ")"), style = "margin-top: 0; color: #333; font-size: 13px;"),
          
          if (var_type == "numeric") {
            range_vals <- safe_numeric_range(var_data)
            tagList(
              fluidRow(
                column(6, numericInput(ns(paste0("min_", var_name)), "Min:", value = range_vals$min)),
                column(6, numericInput(ns(paste0("max_", var_name)), "Max:", value = range_vals$max))
              )
            )
          } else if (var_type == "factor") {
            vals <- unique(var_data[!is.na(var_data) & var_data != ""])
            selectizeInput(ns(paste0("val_", var_name)), NULL, choices = vals, multiple = TRUE, options = list(placeholder = "Select values..."))
          } else {
            textInput(ns(paste0("txt_", var_name)), NULL, placeholder = "Search...")
          }
        )
      })
      
      div(
        class = "filter-controls-container",
        style = "overflow-x: auto; white-space: nowrap; padding: 5px; max-height: 200px;",
        controls
      )
    })
    
    # 执行筛选
    filtered_data <- reactive({
      req(data())
      df <- data()
      
      if (is.null(input$selected_var) || length(input$selected_var) == 0) {
        return(df)
      }
      
      for (var_name in input$selected_var) {
        var_data <- df[[var_name]]
        var_type <- determine_var_type(var_data)
        
        if (var_type == "numeric") {
          min_val <- input[[paste0("min_", var_name)]]
          max_val <- input[[paste0("max_", var_name)]]
          if (!is.null(min_val)) df <- df %>% filter(!!sym(var_name) >= min_val | is.na(!!sym(var_name)))
          if (!is.null(max_val)) df <- df %>% filter(!!sym(var_name) <= max_val | is.na(!!sym(var_name)))
        } else if (var_type == "factor") {
          vals <- input[[paste0("val_", var_name)]]
          if (!is.null(vals) && length(vals) > 0) {
            df <- df %>% filter(!!sym(var_name) %in% vals)
          }
        } else {
          txt <- input[[paste0("txt_", var_name)]]
          if (!is.null(txt) && txt != "") {
             df <- df %>% filter(grepl(txt, !!sym(var_name), ignore.case = TRUE))
          }
        }
      }
      df
    })
    
    # 统计信息
    output$filter_stats <- renderText({
      req(data(), filtered_data())
      n_orig <- nrow(data())
      n_filt <- nrow(filtered_data())
      paste0("筛选结果: ", n_filt, " / ", n_orig, " 行 (", round(n_filt/n_orig*100, 1), "%)")
    })
    
    # 重置
    observeEvent(input$reset_filters, {
      updateSelectizeInput(session, "selected_var", selected = character(0))
    })
    
    return(filtered_data)
  })
}
