# 数据准备模块
# 负责数据的上传、预览、筛选和清洗

# 加载必要的包
library(shiny)
library(shinydashboard)
library(reactable)
library(dplyr)
library(shinyWidgets)
library(readr)
library(readxl)
library(haven)  # 支持SAS、SPSS、Stata文件

# 数据准备UI
data_preparation_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      # 数据上传区域
      box(
        width = 12,
        title = "数据上传",
        status = "primary",
        solidHeader = TRUE,
        fileInput(
          ns("file"),
          "上传数据文件 (CSV/Excel/SAS/SPSS)",
          accept = c(".csv", ".xlsx", ".xls", ".sas7bdat", ".sav", ".dta", ".por"),
          buttonLabel = "浏览文件",
          placeholder = "请选择一个文件进行上传",
          multiple = FALSE
        )
      )
    ),
    
    # 变量选择和筛选区域（条件显示）
    conditionalPanel(
      condition = "output.dataLoaded == true",
      ns = ns,
      
      fluidRow(
        # 左侧变量选择面板
        column(
          width = 6,
          box(
            width = NULL,
            title = "变量选择",
            status = "info",
            solidHeader = TRUE,
            selectizeInput(
              ns("selected_var"),
              "选择变量进行筛选:",
              choices = NULL,
              multiple = TRUE,
              options = list(
                placeholder = '选择要筛选的变量...',
                onInitialize = I('function() { this.setValue(""); }')
              )
            ),
            
            # 列显示选择 - 使用selectizeInput代替checkboxGroupInput以节省空间
            selectizeInput(
              ns("selected_columns"),
              "选择显示列:",
              choices = NULL,
              multiple = TRUE,
              options = list(
                placeholder = '选择要显示的列...',
                onInitialize = I('function() { this.setValue(""); }')
              )
            )
          )
        ),
        
        # 右侧筛选控制面板
        column(
          width = 6,
          box(
            width = NULL,
            title = "筛选控制",
            status = "warning",
            solidHeader = TRUE,
            # 重置按钮
            actionButton(
              ns("reset_filters"),
              "重置所有筛选",
              class = "btn-warning",
              width = "100%",
              icon = icon("refresh")
            ),
            
            # 筛选结果统计
            verbatimTextOutput(ns("filter_stats"))
          )
        )
      ),
      
      # 高级筛选面板（在数据预览上方）
      fluidRow(
        column(
          width = 12,
          box(
            width = NULL,
            title = "高级筛选",
            status = "primary",
            solidHeader = TRUE,
            # 动态筛选控件容器
            uiOutput(ns("filter_controls"))
          )
        )
      ),
      
      # 数据预览区域
      fluidRow(
        column(
          width = 12,
          box(
            width = NULL,
            title = "数据预览",
            status = "success",
            solidHeader = TRUE,
            reactable::reactableOutput(ns("data_table"))
          )
        )
      )
    )
  )
}

# 数据准备服务器逻辑
data_preparation_server <- function(input, output, session) {
  ns <- session$ns
  
  # 数据存储
  data_store <- reactiveVal()
  
  # 文件上传处理
 observeEvent(input$file, {
    req(input$file)
    
    ext <- tools::file_ext(input$file$datapath)
    
    tryCatch({
      if (ext %in% c("xlsx", "xls")) {
        data <- readxl::read_excel(input$file$datapath)
      } else if (ext == "csv") {
        data <- readr::read_csv(input$file$datapath)
      } else if (ext == "sas7bdat") {
        data <- haven::read_sas(input$file$datapath)
      } else if (ext %in% c("sav", "por")) {
        data <- haven::read_spss(input$file$datapath)
      } else if (ext == "dta") {
        data <- haven::read_dta(input$file$datapath)
      } else {
        stop("不支持的文件格式")
      }
      
      # 转换haven包的数据类型为标准R类型
      data <- data %>%
        mutate_if(haven::is.labelled, haven::as_factor)
      
      data_store(data)
      
      # 更新变量选择
      updateSelectizeInput(session, "selected_var",
                           choices = names(data),
                           server = TRUE)
    }, error = function(e) {
      showNotification(paste("文件读取错误:", e$message), type = "error")
    })
  })
  
  
  # 输出数据加载状态
 output$dataLoaded <- reactive({
    !is.null(data_store())
  })
  outputOptions(output, "dataLoaded", suspendWhenHidden = FALSE)
  
  # 显示示例数据表（当没有上传数据时）
  output$sample_table <- reactable::renderReactable({
    req(!is.null(data_store()))
    
    data <- data_store()
    
    # 根据变量类型设置列定义
    col_defs <- list()
    
    for (col_name in names(data)) {
      col_data <- data[[col_name]]
      
      if (is.numeric(col_data)) {
        col_defs[[col_name]] <- reactable::colDef(
          minWidth = 120,
          align = "right",
          style = function(value) {
            list(fontSize = "13px", color = ifelse(is.na(value), "#999999", "#212529"))
          }
        )
      } else if (is.factor(col_data) || is.character(col_data)) {
        col_defs[[col_name]] <- reactable::colDef(
          minWidth = 120,
          align = "left",
          style = function(value) {
            list(fontSize = "13px", color = ifelse(is.na(value), "#99999", "#212529"))
          }
        )
      } else if (inherits(col_data, "Date")) {
        col_defs[[col_name]] <- reactable::colDef(
          minWidth = 120,
          align = "center",
          format = reactable::colFormat(date = TRUE),
          style = function(value) {
            list(fontSize = "13px", color = ifelse(is.na(value), "#999999", "#212529"))
          }
        )
      }
    }
    
    reactable(
      data[1:min(10, nrow(data)), ],
      columns = col_defs,
      pagination = TRUE,
      searchable = TRUE,
      filterable = TRUE,
      striped = TRUE,
      highlight = TRUE,
      bordered = TRUE,
      compact = TRUE,
      defaultPageSize = 10,
      showPageSizeOptions = TRUE,
      pageSizeOptions = c(5, 10, 25)
    )
  })
  
  # 动态生成筛选控件
 output$filter_controls <- renderUI({
    req(data_store(), input$selected_var)
    
    data <- data_store()
    selected_vars <- input$selected_var
    
    if (length(selected_vars) == 0) return(NULL)
    
    # 使用fluidRow和column来实现横向布局
    controls <- lapply(selected_vars, function(var_name) {
      var_data <- data[[var_name]]
      var_type <- determine_var_type(var_data)
      
      # 创建控件组
      div(
        class = "filter-group",
        style = "border: 1px solid #ddd; padding: 10px; margin: 5px; border-radius: 5px; background-color: #f8f9fa; display: inline-block; vertical-align: top; width: 320px; margin-right: 10px; word-wrap: break-word;",
        
        # 变量名和类型显示
        h5(paste(var_name, "(", var_type, ")"), style = "margin-top: 0; color: #3; word-break: break-all;"),
        
        # 排除空值选项
        checkboxInput(ns(paste0("exclude_na_", var_name)), "排除空值", value = FALSE),
        
        # 根据变量类型生成不同控件
        if (var_type == "numeric") {
          wellPanel(
            style = "padding: 10px; background-color: white;",
            h6("数值范围筛选:"),
            numericInput(ns(paste0("num_min_", var_name)), "最小值:",
                         value = ifelse(length(var_data[!is.na(var_data)]) > 0, min(var_data, na.rm = TRUE), 0),
                         min = ifelse(length(var_data[!is.na(var_data)]) > 0, min(var_data, na.rm = TRUE), 0),
                         max = ifelse(length(var_data[!is.na(var_data)]) > 0, max(var_data, na.rm = TRUE), 1)),
            numericInput(ns(paste0("num_max_", var_name)), "最大值:",
                         value = ifelse(length(var_data[!is.na(var_data)]) > 0, max(var_data, na.rm = TRUE), 1),
                         min = ifelse(length(var_data[!is.na(var_data)]) > 0, min(var_data, na.rm = TRUE), 0),
                         max = ifelse(length(var_data[!is.na(var_data)]) > 0, max(var_data, na.rm = TRUE), 1))
          )
        } else if (var_type == "factor") {
          wellPanel(
            style = "padding: 10px; background-color: white;",
            h6("分类筛选:"),
            selectizeInput(ns(paste0("cat_values_", var_name)),
                           "选择值:",
                           choices = unique(var_data[!is.na(var_data)]),
                           selected = unique(var_data[!is.na(var_data)]),
                           multiple = TRUE,
                           options = list(
                             placeholder = "选择要包含的值...",
                             maxItems = 30,
                             plugins = list('remove_button'),
                             dropdownParent = "body"
                           ))
          )
        } else if (var_type == "date") {
          wellPanel(
            style = "padding: 10px; background-color: white;",
            h6("日期范围筛选:"),
            dateInput(ns(paste0("date_start_", var_name)), "开始日期:",
                      value = ifelse(length(var_data[!is.na(var_data)]) > 0, min(var_data, na.rm = TRUE), Sys.Date())),
            dateInput(ns(paste0("date_end_", var_name)), "结束日期:",
                      value = ifelse(length(var_data[!is.na(var_data)]) > 0, max(var_data, na.rm = TRUE), Sys.Date()))
          )
        } else {
          wellPanel(
            style = "padding: 10px; background-color: white;",
            h6("文本筛选:"),
            textInput(ns(paste0("text_search_", var_name)),
                     "关键词搜索:",
                     placeholder = "输入搜索关键词...")
          )
        }
      )
    })
    
    # 将控件包装在div中以实现横向滚动布局
    div(
      style = "overflow-x: auto; white-space: nowrap;",
      controls
    )
  })
  
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
  
  # 应用筛选
filtered_data <- reactive({
    req(data_store())
    
    data <- data_store()
    
    # 如果没有选择筛选变量，返回原始数据
    if (is.null(input$selected_var) || length(input$selected_var) == 0) {
      # 应用列选择
      if (!is.null(input$selected_columns) && length(input$selected_columns) > 0) {
        # 确保选择的列在数据中存在
        existing_cols <- intersect(input$selected_columns, names(data))
        if (length(existing_cols) > 0) {
          data <- data[, existing_cols, drop = FALSE]
        }
      }
      # 添加行号列
      data_with_row_numbers <- data %>%
        mutate(行号 = row_number()) %>%
        select(行号, everything())
      return(data_with_row_numbers)
    }
    
    selected_vars <- input$selected_var
    
    # 逐个应用筛选
    for (var_name in selected_vars) {
      var_data <- data[[var_name]]
      var_type <- determine_var_type(var_data)
      
      # 排除空值
      exclude_na_val <- input[[paste0("exclude_na_", var_name)]]
      if (!is.null(exclude_na_val) && exclude_na_val) {
        data <- data[!is.na(data[[var_name]]), ]
      }
      
      # 根据变量类型应用筛选
      if (var_type == "numeric") {
        min_val <- input[[paste0("num_min_", var_name)]]
        max_val <- input[[paste0("num_max_", var_name)]]
        
        if (!is.null(min_val) && !is.null(max_val) &&
            is.numeric(min_val) && is.numeric(max_val)) {
          data <- data[data[[var_name]] >= min_val & data[[var_name]] <= max_val, ]
        }
      } else if (var_type == "factor") {
        selected_values <- input[[paste0("cat_values_", var_name)]]
        if (!is.null(selected_values) && length(selected_values) > 0) {
          data <- data[data[[var_name]] %in% selected_values | is.na(data[[var_name]]), ]
        }
      } else if (var_type == "date") {
        start_date <- input[[paste0("date_start_", var_name)]]
        end_date <- input[[paste0("date_end_", var_name)]]
        
        if (!is.null(start_date) && !is.null(end_date) &&
            inherits(start_date, "Date") && inherits(end_date, "Date")) {
          data <- data[data[[var_name]] >= start_date & data[[var_name]] <= end_date, ]
        }
      } else { # text
        search_text <- input[[paste0("text_search_", var_name)]]
        if (!is.null(search_text) && search_text != "") {
          pattern <- paste0(".*", search_text, ".*", sep = "")
          data <- data[grepl(pattern, data[[var_name]], ignore.case = TRUE) | is.na(data[[var_name]]), ]
        }
      }
    }
    
    # 应用列选择
    if (!is.null(input$selected_columns) && length(input$selected_columns) > 0) {
      # 确保选择的列在数据中存在
      existing_cols <- intersect(input$selected_columns, names(data))
      if (length(existing_cols) > 0) {
        data <- data[, existing_cols, drop = FALSE]
      }
    }
    
    # 添加行号列
    data_with_row_numbers <- data %>%
      mutate(行号 = row_number()) %>%
      select(行号, everything())
    
    return(data_with_row_numbers)
  })
  
 # 显示数据表
 output$data_table <- reactable::renderReactable({
    req(filtered_data())
    
    data <- filtered_data()
    
    
    # 根据变量类型设置列定义
    col_defs <- list()
    
    for (col_name in names(data_with_row_numbers)) {
      col_data <- data_with_row_numbers[[col_name]]
      
      if (col_name == "行号") {
        # 行号列特殊处理
        col_defs[[col_name]] <- reactable::colDef(
          minWidth = 60,
          align = "center",
          style = function(value) {
            list(fontSize = "12px", fontWeight = "bold", color = "#666")
          }
        )
      } else if (is.numeric(col_data)) {
        col_defs[[col_name]] <- reactable::colDef(
          minWidth = 120,
          align = "right",
          style = function(value) {
            list(fontSize = "13px", color = ifelse(is.na(value), "#9999", "#212529"))
          }
        )
      } else if (is.factor(col_data) || is.character(col_data)) {
        col_defs[[col_name]] <- reactable::colDef(
          minWidth = 120,
          align = "left",
          style = function(value) {
            list(fontSize = "13px", color = ifelse(is.na(value), "#999999", "#212529"))
          }
        )
      } else if (inherits(col_data, "Date")) {
        col_defs[[col_name]] <- reactable::colDef(
          minWidth = 120,
          align = "center",
          format = reactable::colFormat(date = TRUE),
          style = function(value) {
            list(fontSize = "13px", color = ifelse(is.na(value), "#999999", "#212529"))
          }
        )
      }
    }
    
    reactable(
      data_with_row_numbers,
      columns = col_defs,
      pagination = TRUE,
      searchable = TRUE,
      filterable = TRUE,
      striped = TRUE,
      highlight = TRUE,
      bordered = TRUE,
      compact = TRUE,
      defaultPageSize = 25,
      showPageSizeOptions = TRUE,
      pageSizeOptions = c(10, 25, 50, 100),
      resizable = TRUE,
      height = 800
    )
  })
  
  # 显示筛选统计
 output$filter_stats <- renderText({
    req(data_store(), filtered_data())
    
    original_rows <- nrow(data_store())
    filtered_rows <- nrow(filtered_data())
    
    paste(
      "原始数据行数:", original_rows, "\n",
      "筛选后行数:", filtered_rows, "\n",
      "筛选比例:", round(filtered_rows/original_rows * 100, 2), "%"
    )
 })
  
  # 重置筛选
 observeEvent(input$reset_filters, {
    # 重置所有输入控件
    selected_vars <- input$selected_var
    if (!is.null(selected_vars)) {
      for (var_name in selected_vars) {
        var_data <- data_store()[[var_name]]
        var_type <- determine_var_type(var_data)
        
        if (var_type == "numeric") {
          updateNumericInput(session, paste0("num_min_", var_name),
                             value = ifelse(length(var_data[!is.na(var_data)]) > 0, min(var_data, na.rm = TRUE), 0))
          updateNumericInput(session, paste0("num_max_", var_name),
                             value = ifelse(length(var_data[!is.na(var_data)]) > 0, max(var_data, na.rm = TRUE), 1))
        } else if (var_type == "factor") {
          if(length(var_data[!is.na(var_data)]) > 0) {
            updateSelectizeInput(session, paste0("cat_values_", var_name),
                                 selected = unique(var_data[!is.na(var_data)]))
          }
        } else if (var_type == "date") {
          updateDateInput(session, paste0("date_start_", var_name),
                          value = ifelse(length(var_data[!is.na(var_data)]) > 0, min(var_data, na.rm = TRUE), Sys.Date()))
          updateDateInput(session, paste0("date_end_", var_name),
                          value = ifelse(length(var_data[!is.na(var_data)]) > 0, max(var_data, na.rm = TRUE), Sys.Date()))
        } else {
          updateTextInput(session, paste0("text_search_", var_name), value = "")
        }
        
        updateCheckboxInput(session, paste0("exclude_na_", var_name), value = FALSE)
      }
    }
  })
  
  # 监听数据变化，重置筛选变量选择和列选择
 observeEvent(data_store(), {
    updateSelectizeInput(session, "selected_var",
                         choices = names(data_store()),
                         server = TRUE)
    
    # 更新列选择
    updateSelectInput(session, "selected_columns",
                     choices = names(data_store()),
                     selected = names(data_store()))
  })
  
  # 返回筛选后的数据
  return(filtered_data)
}