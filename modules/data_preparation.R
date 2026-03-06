# 数据准备模块
# 负责数据的上传、预览、筛选和清洗

# 加载必要的包
library(shiny)
library(shinydashboard)
library(reactable)
library(dplyr)
library(shinyWidgets)
library(readxl)
library(haven)  # 支持SAS、SPSS、Stata文件
library(vroom)  # 高性能CSV读取
library(memoise) # 函数缓存

# 数据准备UI
data_preparation_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    tags$head(
      tags$style(HTML("
        /* 只针对高级筛选中的分类变量选择框 */
        .filter-group .selectize-control.multi .selectize-input > div {
          display: block !important;
          margin-bottom: 4px !important;
        }
        .filter-group .selectize-control.multi .selectize-input {
          padding: 4px !important;
          height: auto !important;
        }
        /* 优化滚动条样式 */
        .filter-controls-container {
          scrollbar-width: thin;
          scrollbar-color: #888 #f1f1f1;
        }
        .filter-controls-container::-webkit-scrollbar {
          width: 8px;
          height: 8px;
        }
        .filter-controls-container::-webkit-scrollbar-track {
          background: #f1f1f1;
        }
        .filter-controls-container::-webkit-scrollbar-thumb {
          background: #888;
          border-radius: 4px;
        }
        .filter-controls-container::-webkit-scrollbar-thumb:hover {
          background: #555;
        }
      "))
    ),
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
                placeholder = '搜索变量名或Label后选择显示列...',
                plugins = list('remove_button')
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
            reactable::reactableOutput(ns("data_table")),
            # 添加渲染状态提示
            conditionalPanel(
              condition = "output.renderingTable == true",
              ns = ns,
              div("正在渲染数据表格...", style = "text-align: center; padding: 20px; color: #666;")
            )
          )
        )
      ),
      
      fluidRow(
        column(
          width = 12,
          box(
            width = NULL,
            title = "变量信息卡片",
            status = "primary",
            solidHeader = TRUE,
            reactable::reactableOutput(ns("variable_info_table")),
            br(),
            selectizeInput(
              ns("meta_vars"),
              "选择需要调整的变量:",
              choices = NULL,
              multiple = TRUE,
              options = list(
                placeholder = "选择变量后可修改类型与Label...",
                plugins = list("remove_button")
              )
            ),
            uiOutput(ns("variable_meta_controls")),
            fluidRow(
              column(
                width = 6,
                actionButton(
                  ns("apply_var_meta"),
                  "应用变量设置",
                  class = "btn-primary",
                  width = "100%"
                )
              ),
              column(
                width = 6,
                actionButton(
                  ns("reset_var_type_overrides"),
                  "恢复自动识别",
                  class = "btn-default",
                  width = "100%"
                )
              )
            )
          )
        )
      )
    )
  )
}

# 缓存列定义函数 - 使用memoise优化
get_column_def_cached <- memoise(function(col_name, col_data) {
  if (col_name == "行号") {
    return(reactable::colDef(
      minWidth = 60,
      maxWidth = 80,
      align = "center",
      style = list(fontSize = "12px", fontWeight = "bold", color = "#666")
    ))
  } else if (is.numeric(col_data)) {
    return(reactable::colDef(
      minWidth = 100,
      maxWidth = 150,
      align = "right",
      style = list(fontSize = "13px", color = "#212529")
    ))
  } else if (is.factor(col_data) || is.character(col_data)) {
    return(reactable::colDef(
      minWidth = 120,
      maxWidth = 200,
      align = "left",
      style = list(fontSize = "13px", color = "#212529")
    ))
  } else if (inherits(col_data, "Date")) {
    return(reactable::colDef(
      minWidth = 120,
      maxWidth = 150,
      align = "center",
      format = reactable::colFormat(date = TRUE),
      style = list(fontSize = "13px", color = "#212529")
    ))
  } else {
    return(reactable::colDef(
      minWidth = 120,
      maxWidth = 200,
      align = "left",
      style = list(fontSize = "13px", color = "#212529")
    ))
  }
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

valid_var_types <- c("numeric", "factor", "date", "text")

coerce_var_data <- function(x, var_type) {
  if (var_type == "numeric") {
    return(suppressWarnings(as.numeric(x)))
  }
  if (var_type == "date") {
    if (inherits(x, "Date")) {
      return(x)
    }
    if (inherits(x, "POSIXct") || inherits(x, "POSIXlt")) {
      return(as.Date(x))
    }
    return(suppressWarnings(as.Date(x)))
  }
  if (var_type == "factor") {
    return(as.character(x))
  }
  as.character(x)
}

# 安全计算数值范围 - 处理全空值的情况
safe_numeric_range <- function(var_data) {
  # 过滤出非空值
  valid_data <- var_data[!is.na(var_data)]
  
  # 如果没有有效数据，返回默认范围
  if (length(valid_data) == 0) {
    return(list(min = 0.0, max = 1.0))
  }
  
  # 尝试计算最小值
  min_val <- tryCatch({
    result <- min(valid_data, na.rm = TRUE)
    # 确保结果是标量且有限
    if (length(result) == 0 || is.na(result) || !is.finite(result)) {
      0.0
    } else {
      as.numeric(result)
    }
  }, error = function(e) {
    0.0
  })
  
  # 尝试计算最大值
  max_val <- tryCatch({
    result <- max(valid_data, na.rm = TRUE)
    # 确保结果是标量且有限
    if (length(result) == 0 || is.na(result) || !is.finite(result)) {
      1.0
    } else {
      as.numeric(result)
    }
  }, error = function(e) {
    1.0
  })
  
  # 确保最小值不大于最大值
  if (min_val > max_val) {
    temp <- min_val
    min_val <- max_val
    max_val <- temp + 1
  }
  
  # 最终检查确保值是有限的
  if (!is.finite(min_val)) min_val <- 0.0
  if (!is.finite(max_val)) max_val <- 1.0
  
  return(list(min = min_val, max = max_val))
}

# 数据准备服务器逻辑
data_preparation_server <- function(input, output, session) {
  ns <- session$ns
  
  # 数据存储
  data_store <- reactiveVal()
  var_type_overrides <- reactiveVal(setNames(character(0), character(0)))
  var_label_overrides <- reactiveVal(setNames(character(0), character(0)))
  
  # 渲染状态
  rendering_table <- reactiveVal(FALSE)
  
  # 性能监控
  performance_metrics <- reactiveValues(
    load_time = NULL,
    filter_time = NULL,
    render_time = NULL
  )
  
  get_var_label <- function(var_name, var_data) {
    label_overrides <- var_label_overrides()
    if (var_name %in% names(label_overrides) && nzchar(trimws(label_overrides[[var_name]]))) {
      return(trimws(label_overrides[[var_name]]))
    }
    var_label <- attr(var_data, "label")
    if (!is.null(var_label) && nzchar(trimws(as.character(var_label)))) {
      return(trimws(as.character(var_label)))
    }
    var_name
  }
  
  get_effective_var_type <- function(var_name, var_data) {
    type_overrides <- var_type_overrides()
    if (var_name %in% names(type_overrides) && type_overrides[[var_name]] %in% valid_var_types) {
      return(type_overrides[[var_name]])
    }
    determine_var_type(var_data)
  }
  
  build_column_choices <- function(data) {
    vars <- names(data)
    labels <- vapply(vars, function(var_name) {
      var_label <- get_var_label(var_name, data[[var_name]])
      if (!identical(var_label, var_name)) {
        paste0(var_name, " | ", var_label)
      } else {
        var_name
      }
    }, character(1))
    setNames(vars, labels)
  }
  
  remove_named_value <- function(x, key) {
    if (length(x) == 0 || is.null(names(x))) {
      return(x)
    }
    x[names(x) != key]
  }
  
  format_filter_conditions <- function(data, selected_vars) {
    if (is.null(selected_vars) || length(selected_vars) == 0) {
      return("无")
    }
    condition_text <- character(0)
    for (var_name in selected_vars) {
      if (!(var_name %in% names(data))) {
        next
      }
      var_type <- get_effective_var_type(var_name, data[[var_name]])
      item <- NULL
      if (var_type == "numeric") {
        min_val <- input[[paste0("num_min_", var_name)]]
        max_val <- input[[paste0("num_max_", var_name)]]
        if (!is.null(min_val) && !is.null(max_val)) {
          item <- paste0(var_name, " 数值[", min_val, ", ", max_val, "]")
        }
      } else if (var_type == "factor") {
        vals <- input[[paste0("cat_values_", var_name)]]
        if (!is.null(vals) && length(vals) > 0) {
          item <- paste0(var_name, " 分类{", paste(vals, collapse = ", "), "}")
        }
      } else if (var_type == "date") {
        start_date <- input[[paste0("date_start_", var_name)]]
        end_date <- input[[paste0("date_end_", var_name)]]
        if (!is.null(start_date) && !is.null(end_date)) {
          item <- paste0(var_name, " 日期[", as.character(start_date), ", ", as.character(end_date), "]")
        }
      } else {
        search_text <- input[[paste0("text_search_", var_name)]]
        if (!is.null(search_text) && nzchar(trimws(search_text))) {
          item <- paste0(var_name, " 文本包含\"", search_text, "\"")
        }
      }
      if (var_type != "factor") {
        na_filter_val <- input[[paste0("na_filter_", var_name)]]
        if (!is.null(na_filter_val) && na_filter_val != "all") {
          na_text <- if (na_filter_val == "exclude") "排除空值" else "仅空值"
          if (is.null(item)) {
            item <- paste0(var_name, " ", na_text)
          } else {
            item <- paste0(item, " + ", na_text)
          }
        }
      }
      if (!is.null(item)) {
        condition_text <- c(condition_text, item)
      }
    }
    if (length(condition_text) == 0) {
      return("无")
    }
    paste(condition_text, collapse = "；")
  }
  
  # 文件上传处理
  observeEvent(input$file, {
    req(input$file)
    
    # 显示加载提示
    notification_id <- showNotification("正在加载数据文件，请稍候...", type = "message", duration = NULL)
    
    # 记录开始时间
    start_time <- Sys.time()
    
    ext <- tools::file_ext(input$file$datapath)
    
    tryCatch({
      data <- NULL
      
      # 根据文件类型使用不同的读取策略
      if (ext %in% c("xlsx", "xls")) {
        # 对于Excel文件，使用最优参数
        data <- readxl::read_excel(input$file$datapath, guess_max = 1000)
      } else if (ext == "csv") {
        # 使用vroom提高CSV读取性能
        data <- vroom::vroom(input$file$datapath, progress = FALSE)
      } else if (ext == "sas7bdat") {
        data <- haven::read_sas(input$file$datapath, encoding = "UTF-8")
      } else if (ext %in% c("sav", "por")) {
        data <- haven::read_spss(input$file$datapath, encoding = "UTF-8")
      } else if (ext == "dta") {
        data <- haven::read_dta(input$file$datapath, encoding = "UTF-8")
      } else {
        stop("不支持的文件格式")
      }
      
      # 优化数据类型转换 - 只转换有意义的labelled变量
      data <- data %>%
        mutate(across(where(haven::is.labelled), ~ haven::as_factor(.x, levels = "labels")))
      
      # 强制垃圾回收以释放内存
      gc()
      
      data_store(data)
      var_type_overrides(setNames(character(0), character(0)))
      var_label_overrides(setNames(character(0), character(0)))
      
      # 记录加载时间
      load_time <- Sys.time() - start_time
      performance_metrics$load_time <- load_time
      
      all_choices <- build_column_choices(data)
      
      # 更新变量选择
      updateSelectizeInput(session, "selected_var",
                           choices = all_choices,
                           server = TRUE)
      
      # 更新列选择 - 限制默认显示列数以提高性能
      max_default_cols <- min(25, length(names(data)))  # 最多显示25列
      default_display_cols <- head(names(data), max_default_cols)
      updateSelectizeInput(session, "selected_columns",
                           choices = all_choices,
                           selected = default_display_cols,
                           server = TRUE)
      
      updateSelectizeInput(session, "meta_vars",
                           choices = all_choices,
                           selected = character(0),
                           server = TRUE)
      
      # 显示成功提示
      showNotification(paste("数据加载完成！耗时:", round(load_time, 2), "秒，共", nrow(data), "行 x", ncol(data), "列"),
                     type = "message")
      
      # 关闭加载提示
      removeNotification(id = notification_id)
    }, error = function(e) {
      removeNotification(id = notification_id)
      showNotification(paste("文件读取错误:", e$message), type = "error")
    })
  })
  
  
  # 输出数据加载状态
  output$dataLoaded <- reactive({
    !is.null(data_store())
  })
  outputOptions(output, "dataLoaded", suspendWhenHidden = FALSE)
  
  # 输出渲染状态
  output$renderingTable <- reactive({
    rendering_table()
  })
  outputOptions(output, "renderingTable", suspendWhenHidden = FALSE)
  
  # 动态生成筛选控件
  output$filter_controls <- renderUI({
    req(data_store(), input$selected_var)
    
    data <- data_store()
    selected_vars <- input$selected_var
    
    if (length(selected_vars) == 0) return(NULL)
    
    # 限制最多显示20个筛选控件以提高性能
    if (length(selected_vars) > 20) {
      selected_vars <- head(selected_vars, 20)
      showNotification("为提高性能，最多显示20个筛选控件", type = "warning", duration = 3000)
    }
    
    # 使用更高效的控件生成方式
    controls <- lapply(selected_vars, function(var_name) {
      raw_var_data <- data[[var_name]]
      var_data <- raw_var_data
      var_label <- get_var_label(var_name, raw_var_data)
      var_type <- get_effective_var_type(var_name, raw_var_data)
      var_data <- coerce_var_data(var_data, var_type)
      
      # 创建控件组
      div(
        class = "filter-group",
        style = "border: 1px solid #ddd; padding: 8px; margin: 3px; border-radius: 4px; background-color: #f8f9fa; display: inline-block; vertical-align: top; width: 280px; margin-right: 8px; word-wrap: break-word;",
        
        # 变量名和类型显示
        h5(
          if (!identical(var_label, var_name)) {
            paste0(var_name, " [", var_label, "] (", var_type, ")")
          } else {
            paste0(var_name, " (", var_type, ")")
          },
          style = "margin-top: 0; color: #3; font-size: 13px; word-break: break-all;"
        ),
        
        # 空值筛选选项 - 只对非分类变量显示
        if (var_type != "factor") {
          radioButtons(ns(paste0("na_filter_", var_name)),
                      "空值筛选:",
                      choices = c("全部" = "all",
                                 "排除空值" = "exclude",
                                 "仅显示空值" = "only"),
                      selected = "all",
                      inline = TRUE,
                      width = "100%")
        },
        
        # 根据变量类型生成不同控件
        if (var_type == "numeric") {
          # 使用安全函数计算数值范围
          range_vals <- safe_numeric_range(var_data)
          
          # 强制转换为标量并确保有效性
          safe_min <- as.numeric(range_vals$min)[1]
          safe_max <- as.numeric(range_vals$max)[1]
          
          # 最终防护：确保所有值都是有效数值
          if (length(safe_min) == 0 || is.na(safe_min) || !is.finite(safe_min)) safe_min <- 0.0
          if (length(safe_max) == 0 || is.na(safe_max) || !is.finite(safe_max)) safe_max <- 1.0
          
          # 确保最小值不大于最大值
          if (safe_min > safe_max) {
            temp <- safe_min
            safe_min <- safe_max
            safe_max <- temp + 1
          }
          
          # 使用固定的参数值，避免任何条件逻辑
          final_min_val <- as.numeric(safe_min)
          final_max_val <- as.numeric(safe_max)
          final_min_range <- as.numeric(safe_min - 1)
          final_max_range <- as.numeric(safe_max + 1)
          final_step <- 1  # 固定步长，避免NULL
          
          # 最终验证：确保所有参数都是长度为1的数值向量
          stopifnot(
            length(final_min_val) == 1 && is.numeric(final_min_val),
            length(final_max_val) == 1 && is.numeric(final_max_val),
            length(final_min_range) == 1 && is.numeric(final_min_range),
            length(final_max_range) == 1 && is.numeric(final_max_range),
            length(final_step) == 1 && is.numeric(final_step)
          )
          
          tagList(
            h6("数值范围:", style = "margin: 5px 0; font-size: 11px; color: #666;"),
            fluidRow(
              column(6,
                numericInput(
                  ns(paste0("num_min_", var_name)),
                  "最小值:",
                  value = final_min_val,
                  min = final_min_range,
                  max = final_max_val,
                  step = final_step,
                  width = "100%"
                )
              ),
              column(6,
                numericInput(
                  ns(paste0("num_max_", var_name)),
                  "最大值:",
                  value = final_max_val,
                  min = final_min_val,
                  max = final_max_range,
                  step = final_step,
                  width = "100%"
                )
              )
            )
          )
        } else if (var_type == "factor") {
          # 获取所有非空唯一值，排除NA和空字符串
          # 首先确保处理字符型变量中的空字符串
          if (is.character(var_data)) {
            # 对于字符型变量，将空字符串视为空值
            non_empty_values <- var_data[!is.na(var_data) & var_data != ""]
          } else {
            # 对于其他类型，只排除NA
            non_empty_values <- var_data[!is.na(var_data)]
          }
          unique_values <- unique(non_empty_values)
          
          # 检查是否存在空值（包括NA和空字符串）
          has_na_values <- any(is.na(var_data)) ||
                          (is.character(var_data) && any(var_data == "", na.rm = TRUE))
          
          # 统一处理逻辑：当存在空值时，在选项列表中添加"NA"选项
          if (length(unique_values) > 100) {
            # 如果唯一值超过100个，限制显示数量
            # 显示前99个非空值 + "NA"选项 = 100个选项
            unique_non_na_values <- head(unique_values, 99)
            choices_with_na <- if (has_na_values) {
              c(unique_non_na_values, "NA")
            } else {
              head(unique_values, 100)  # 如果没有空值，显示前100个非空值
            }
            selected_with_na <- choices_with_na  # 默认选择所有显示的值
            
            tagList(
              h6("分类值 (前100):", style = "margin: 5px 0; font-size: 11px; color: #666;"),
              selectizeInput(ns(paste0("cat_values_", var_name)),
                             NULL,
                             choices = choices_with_na,
                             selected = selected_with_na,
                             multiple = TRUE,
                             options = list(
                               placeholder = "选择值...",
                               maxItems = 30,  # 限制选择项数
                               plugins = list('remove_button'),
                               dropdownParent = "body"
                             ))
            )
          } else {
            # 唯一值不超过100个，显示所有非空值
            choices_with_na <- if (has_na_values) {
              c(unique_values, "NA")
            } else {
              unique_values
            }
            selected_with_na <- choices_with_na  # 默认选择所有值
            
            tagList(
              h6("分类值:", style = "margin: 5px 0; font-size: 11px; color: #666;"),
              selectizeInput(ns(paste0("cat_values_", var_name)),
                             NULL,
                             choices = choices_with_na,
                             selected = selected_with_na,
                             multiple = TRUE,
                             options = list(
                               placeholder = "选择值...",
                               maxItems = 30,
                               plugins = list('remove_button'),
                               dropdownParent = "body"
                             ))
            )
          }
        } else if (var_type == "date") {
          # 预先计算日期范围以避免在UI函数中出现长度为零的向量
          valid_data <- var_data[!is.na(var_data)]
          has_valid_data <- length(valid_data) > 0
          
          min_val <- if(has_valid_data) {
            tryCatch(min(valid_data), error = function(e) NA)
          } else NA
          
          max_val <- if(has_valid_data) {
            tryCatch(max(valid_data), error = function(e) NA)
          } else NA
          
          # 确保日期是有效的，否则使用默认值
          final_start <- if(!is.na(min_val) && inherits(min_val, "Date")) min_val else Sys.Date()
          final_end <- if(!is.na(max_val) && inherits(max_val, "Date")) max_val else Sys.Date()
          
          tagList(
            h6("日期范围:", style = "margin: 5px 0; font-size: 11px; color: #666;"),
            dateInput(ns(paste0("date_start_", var_name)), "开始:",
                      value = final_start,
                      width = "100%"),
            dateInput(ns(paste0("date_end_", var_name)), "结束:",
                      value = final_end,
                      width = "100%")
          )
        } else {
          tagList(
            h6("文本搜索:", style = "margin: 5px 0; font-size: 11px; color: #666;"),
            textInput(ns(paste0("text_search_", var_name)),
                     NULL,
                     placeholder = "关键词...",
                     width = "100%")
          )
        }
      )
    })
    
    # 将控件包装在div中以实现横向滚动布局
    div(
      class = "filter-controls-container",
      style = "overflow-x: auto; white-space: nowrap; padding: 5px; max-height: 200px;",
      controls
    )
  })
  
  variable_info_data <- reactive({
    req(data_store())
    data <- data_store()
    vars <- names(data)
    
    if (length(vars) == 0) {
      return(data.frame())
    }
    
    info <- lapply(vars, function(var_name) {
      raw_var_data <- data[[var_name]]
      auto_type <- determine_var_type(raw_var_data)
      current_type <- get_effective_var_type(var_name, raw_var_data)
      current_label <- get_var_label(var_name, raw_var_data)
      typed_data <- coerce_var_data(raw_var_data, current_type)
      na_rate <- if (length(typed_data) == 0) 0 else round(mean(is.na(typed_data)) * 100, 2)
      unique_count <- length(unique(typed_data[!is.na(typed_data)]))
      sample_values <- unique(as.character(typed_data[!is.na(typed_data)]))
      sample_preview <- if (length(sample_values) == 0) {
        ""
      } else {
        paste(head(sample_values, 3), collapse = ", ")
      }
      
      data.frame(
        变量名 = var_name,
        Label = current_label,
        自动类型 = auto_type,
        当前类型 = current_type,
        缺失率 = paste0(na_rate, "%"),
        唯一值数 = unique_count,
        示例值 = sample_preview,
        stringsAsFactors = FALSE
      )
    })
    
    do.call(rbind, info)
  })
  
  output$variable_info_table <- reactable::renderReactable({
    req(variable_info_data())
    reactable::reactable(
      variable_info_data(),
      searchable = TRUE,
      filterable = FALSE,
      striped = TRUE,
      compact = TRUE,
      bordered = TRUE,
      defaultPageSize = 8,
      showPageSizeOptions = TRUE,
      pageSizeOptions = c(8, 15, 30),
      resizable = TRUE,
      highlight = TRUE,
      fullWidth = TRUE
    )
  })
  
  output$variable_meta_controls <- renderUI({
    req(data_store(), input$meta_vars)
    selected_vars <- input$meta_vars
    data <- data_store()
    
    if (length(selected_vars) == 0) {
      return(NULL)
    }
    
    controls <- lapply(selected_vars, function(var_name) {
      raw_var_data <- data[[var_name]]
      auto_type <- determine_var_type(raw_var_data)
      current_type <- get_effective_var_type(var_name, raw_var_data)
      current_label <- get_var_label(var_name, raw_var_data)
      var_title <- if (!identical(current_label, var_name)) {
        paste0(var_name, " [", current_label, "]")
      } else {
        var_name
      }
      
      div(
        style = "border: 1px solid #ddd; padding: 10px; margin-bottom: 8px; border-radius: 4px; background-color: #f8f9fa;",
        h5(var_title, style = "margin-top: 0; font-size: 13px;"),
        div(paste0("自动类型: ", auto_type), style = "font-size: 12px; color: #666; margin-bottom: 8px;"),
        textInput(
          ns(paste0("meta_label_", var_name)),
          "Label:",
          value = current_label,
          width = "100%"
        ),
        selectInput(
          ns(paste0("meta_type_", var_name)),
          "变量类型:",
          choices = c("numeric", "factor", "date", "text"),
          selected = current_type,
          width = "100%"
        )
      )
    })
    
    tagList(controls)
  })
  
  observeEvent(input$apply_var_meta, {
    req(data_store())
    selected_vars <- input$meta_vars
    if (is.null(selected_vars) || length(selected_vars) == 0) {
      showNotification("请先选择要调整的变量", type = "warning")
      return()
    }
    
    data <- data_store()
    type_values <- var_type_overrides()
    label_values <- var_label_overrides()
    
    for (var_name in selected_vars) {
      input_type <- input[[paste0("meta_type_", var_name)]]
      input_label <- input[[paste0("meta_label_", var_name)]]
      auto_type <- determine_var_type(data[[var_name]])
      
      if (!is.null(input_type) && input_type %in% valid_var_types) {
        if (identical(input_type, auto_type)) {
          type_values <- remove_named_value(type_values, var_name)
        } else {
          type_values[[var_name]] <- input_type
        }
      }
      
      if (!is.null(input_label)) {
        trimmed_label <- trimws(input_label)
        if (nzchar(trimmed_label)) {
          label_values[[var_name]] <- trimmed_label
        } else {
          label_values <- remove_named_value(label_values, var_name)
        }
      }
    }
    
    var_type_overrides(type_values)
    var_label_overrides(label_values)
    
    all_choices <- build_column_choices(data)
    max_default_cols <- min(25, length(names(data)))
    default_display_cols <- head(names(data), max_default_cols)
    selected_display_cols <- input$selected_columns
    if (is.null(selected_display_cols) || length(selected_display_cols) == 0) {
      selected_display_cols <- default_display_cols
    } else {
      selected_display_cols <- intersect(selected_display_cols, names(data))
      if (length(selected_display_cols) == 0) {
        selected_display_cols <- default_display_cols
      }
    }
    
    updateSelectizeInput(session, "selected_var",
                         choices = all_choices,
                         selected = intersect(input$selected_var, names(data)),
                         server = TRUE)
    updateSelectizeInput(session, "selected_columns",
                         choices = all_choices,
                         selected = selected_display_cols,
                         server = TRUE)
    updateSelectizeInput(session, "meta_vars",
                         choices = all_choices,
                         selected = intersect(selected_vars, names(data)),
                         server = TRUE)
    
    showNotification("变量类型与Label设置已应用", type = "message")
  })
  
  observeEvent(input$reset_var_type_overrides, {
    var_type_overrides(setNames(character(0), character(0)))
    showNotification("已恢复自动类型识别", type = "message")
  })
  
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
          data <- data %>% select(all_of(existing_cols))
        }
      }
      # 添加行号列
      data <- data %>%
        mutate(行号 = row_number()) %>%
        select(行号, everything())
      return(data)
    }
    
    selected_vars <- input$selected_var
    
    # 使用dplyr管道提高筛选效率
    filter_start_time <- Sys.time()
    
    # 逐个应用筛选
    for (var_name in selected_vars) {
      raw_var_data <- data[[var_name]]
      var_type <- get_effective_var_type(var_name, raw_var_data)
      var_data <- coerce_var_data(raw_var_data, var_type)
      
      # 空值筛选 - 只对非分类变量应用
      if (var_type != "factor") {
        na_filter_val <- input[[paste0("na_filter_", var_name)]]
        
        if (!is.null(na_filter_val) && na_filter_val == "only") {
          data <- data[is.na(var_data), , drop = FALSE]
          if (nrow(data) == 0) break
          var_data <- coerce_var_data(data[[var_name]], var_type)
        } else if (!is.null(na_filter_val) && na_filter_val == "exclude") {
          data <- data[!is.na(var_data), , drop = FALSE]
          if (nrow(data) == 0) break
          var_data <- coerce_var_data(data[[var_name]], var_type)
        }
      }
      
      # 根据变量类型应用筛选条件
      if (var_type == "numeric") {
        min_val <- input[[paste0("num_min_", var_name)]]
        max_val <- input[[paste0("num_max_", var_name)]]
        
        if (!is.null(min_val) && !is.null(max_val) &&
            is.numeric(min_val) && is.numeric(max_val)) {
          na_filter_val <- input[[paste0("na_filter_", var_name)]]
          keep_idx <- if (!is.null(na_filter_val) && na_filter_val == "exclude") {
            !is.na(var_data) & var_data >= min_val & var_data <= max_val
          } else {
            is.na(var_data) | (var_data >= min_val & var_data <= max_val)
          }
          data <- data[keep_idx, , drop = FALSE]
        }
      } else if (var_type == "factor") {
        selected_values <- input[[paste0("cat_values_", var_name)]]
        if (!is.null(selected_values) && length(selected_values) > 0) {
          if ("NA" %in% selected_values) {
            non_na_selected <- setdiff(selected_values, "NA")
            if (length(non_na_selected) > 0) {
              keep_idx <- var_data %in% non_na_selected | is.na(var_data) | var_data == ""
            } else {
              keep_idx <- is.na(var_data) | var_data == ""
            }
            data <- data[keep_idx, , drop = FALSE]
          } else {
            data <- data[var_data %in% selected_values, , drop = FALSE]
          }
        }
      } else if (var_type == "date") {
        start_date <- input[[paste0("date_start_", var_name)]]
        end_date <- input[[paste0("date_end_", var_name)]]
        
        if (!is.null(start_date) && !is.null(end_date) &&
            inherits(start_date, "Date") && inherits(end_date, "Date")) {
          na_filter_val <- input[[paste0("na_filter_", var_name)]]
          keep_idx <- if (!is.null(na_filter_val) && na_filter_val == "exclude") {
            !is.na(var_data) & var_data >= start_date & var_data <= end_date
          } else {
            is.na(var_data) | (var_data >= start_date & var_data <= end_date)
          }
          data <- data[keep_idx, , drop = FALSE]
        }
      } else { # text
        search_text <- input[[paste0("text_search_", var_name)]]
        if (!is.null(search_text) && search_text != "") {
          pattern <- paste0(".*", search_text, ".*", sep = "")
          match_idx <- grepl(pattern, var_data, ignore.case = TRUE)
          na_filter_val <- input[[paste0("na_filter_", var_name)]]
          keep_idx <- if (!is.null(na_filter_val) && na_filter_val == "exclude") {
            !is.na(var_data) & match_idx
          } else {
            is.na(var_data) | match_idx
          }
          data <- data[keep_idx, , drop = FALSE]
        }
      }
    }
    
    # 应用列选择
    if (!is.null(input$selected_columns) && length(input$selected_columns) > 0) {
      # 确保选择的列在数据中存在
      existing_cols <- intersect(input$selected_columns, names(data))
      if (length(existing_cols) > 0) {
        data <- data %>% select(all_of(existing_cols))
      }
    }
    
    # 添加行号列
    data <- data %>%
      mutate(行号 = row_number()) %>%
      select(行号, everything())
    
    # 记录筛选时间
    filter_time <- Sys.time() - filter_start_time
    performance_metrics$filter_time <- filter_time
    
    return(data)
  })
  
  # 为分析模块准备的数据（去除行号列）
  analysis_data <- reactive({
    req(filtered_data())
    data <- filtered_data()
    # 移除行号列（如果存在）
    if ("行号" %in% names(data)) {
      data <- data %>% select(-`行号`)
    }
    label_values <- var_label_overrides()
    if (length(label_values) > 0) {
      for (var_name in names(label_values)) {
        if (var_name %in% names(data)) {
          label_text <- trimws(as.character(label_values[[var_name]]))
          if (nzchar(label_text)) {
            attr(data[[var_name]], "label") <- label_text
          }
        }
      }
    }
    data
  })
  
  # 显示数据表 - 优化渲染性能
  output$data_table <- reactable::renderReactable({
    req(filtered_data())
    
    # 设置渲染状态
    rendering_table(TRUE)
    on.exit(rendering_table(FALSE))
    
    data <- filtered_data()
    
    # 记录渲染开始时间
    render_start_time <- Sys.time()
    
    # 智能列限制 - 最多显示60列以避免性能问题
    total_rows <- nrow(data)
    total_cols <- ncol(data)
    
    max_display_cols <- min(60, total_cols)  # 提高到60列
    if (total_cols > max_display_cols) {
      display_cols <- c("行号", head(setdiff(names(data), "行号"), max_display_cols - 1))
      data <- data[, display_cols, drop = FALSE]
      showNotification(paste("检测到大数据集 (", total_cols, "列)，为提高性能仅显示前", max_display_cols, "列。"),
                     type = "warning", duration = 3000)
    }
    
    # 预先计算列定义以提高性能
    col_defs <- list()
    
    # 批量生成列定义而不是循环
    for (col_name in names(data)) {
      col_data <- data[[col_name]]
      col_defs[[col_name]] <- get_column_def_cached(col_name, col_data)
    }
    
    # 智能分页设置
    default_page_size <- if (total_rows > 100000) {
      25  # 超大数据集默认显示25行
    } else if (total_rows > 50000) {
      50  # 大数据集默认显示50行
    } else if (total_rows > 10000) {
      100  # 中等数据集默认显示100行
    } else {
      200  # 小数据集默认显示200行
    }
    
    page_size_options <- if (total_rows > 100000) {
      c(10, 25, 50)
    } else if (total_rows > 50000) {
      c(25, 50, 100)
    } else if (total_rows > 10000) {
      c(50, 100, 200)
    } else {
      c(100, 200, 500)
    }
    
    # 优化的Reactable配置
    table_output <- reactable(
      data,
      columns = col_defs,
      pagination = TRUE,
      searchable = TRUE,
      filterable = FALSE,  # 关闭内置筛选以提高性能
      striped = TRUE,
      highlight = TRUE,
      bordered = TRUE,
      compact = TRUE,
      defaultPageSize = default_page_size,
      showPageSizeOptions = TRUE,
      pageSizeOptions = page_size_options,
      resizable = TRUE,
      height = 600,  # 固定高度
      # 性能优化参数
      rownames = FALSE,
      fullWidth = TRUE,
      wrap = FALSE,  # 不自动换行提高性能
      showSortIcon = TRUE,
      showSortable = TRUE
    )
    
    # 记录渲染时间
    render_time <- Sys.time() - render_start_time
    performance_metrics$render_time <- render_time
    
    table_output
  })
  
  # 显示筛选统计
  output$filter_stats <- renderText({
    req(data_store(), filtered_data())
    
    original_rows <- nrow(data_store())
    filtered_rows <- nrow(filtered_data())
    
    condition_text <- format_filter_conditions(data_store(), input$selected_var)
    paste(
      "原始数据行数:", original_rows, "\n",
      "筛选后行数:", filtered_rows, "\n",
      "筛选比例:", round(filtered_rows/original_rows * 100, 2), "%", "\n",
      "当前筛选条件:", condition_text
    )
  })
  
  # 重置筛选
  observeEvent(input$reset_filters, {
    # 重置所有输入控件
    selected_vars <- input$selected_var
    if (!is.null(selected_vars)) {
      for (var_name in selected_vars) {
        raw_var_data <- data_store()[[var_name]]
        var_type <- get_effective_var_type(var_name, raw_var_data)
        var_data <- coerce_var_data(raw_var_data, var_type)
        
        if (var_type == "numeric") {
          # 使用安全函数计算数值范围
          range_vals <- safe_numeric_range(var_data)
          
          # 强制转换为标量并确保有效性
          safe_min <- as.numeric(range_vals$min)[1]
          safe_max <- as.numeric(range_vals$max)[1]
          
          # 最终防护：确保所有值都是有效数值
          if (length(safe_min) == 0 || is.na(safe_min) || !is.finite(safe_min)) safe_min <- 0.0
          if (length(safe_max) == 0 || is.na(safe_max) || !is.finite(safe_max)) safe_max <- 1.0
          
          # 确保最小值不大于最大值
          if (safe_min > safe_max) {
            temp <- safe_min
            safe_min <- safe_max
            safe_max <- temp + 1
          }
          
          # 使用固定的参数值，避免任何条件逻辑
          final_min_val <- as.numeric(safe_min)
          final_max_val <- as.numeric(safe_max)
          
          # 最终验证：确保所有参数都是长度为1的数值向量
          stopifnot(
            length(final_min_val) == 1 && is.numeric(final_min_val),
            length(final_max_val) == 1 && is.numeric(final_max_val)
          )
          
          updateNumericInput(session, paste0("num_min_", var_name),
                             value = final_min_val)
          updateNumericInput(session, paste0("num_max_", var_name),
                             value = final_max_val)
        } else if (var_type == "factor") {
          # 获取所有非空唯一值，排除NA和空字符串
          # 首先确保处理字符型变量中的空字符串
          if (is.character(var_data)) {
            # 对于字符型变量，将空字符串视为空值
            non_empty_values <- var_data[!is.na(var_data) & var_data != ""]
          } else {
            # 对于其他类型，只排除NA
            non_empty_values <- var_data[!is.na(var_data)]
          }
          unique_values <- unique(non_empty_values)
          
          # 检查是否存在空值（包括NA和空字符串）
          has_na_values <- any(is.na(var_data)) ||
                          (is.character(var_data) && any(var_data == "", na.rm = TRUE))
          
          # 使用与选项生成相同的逻辑
          if (length(unique_values) > 100) {
            # 如果唯一值超过100个，限制显示数量
            unique_non_na_values <- head(unique_values, 99)
            choices_with_na <- if (has_na_values) {
              c(unique_non_na_values, "NA")
            } else {
              head(unique_values, 100)
            }
            selected_with_na <- choices_with_na
          } else {
            # 唯一值不超过100个，显示所有非空值
            choices_with_na <- if (has_na_values) {
              c(unique_values, "NA")
            } else {
              unique_values
            }
            selected_with_na <- choices_with_na
          }
          
          updateSelectizeInput(session, paste0("cat_values_", var_name),
                               choices = choices_with_na,
                               selected = selected_with_na)
        } else if (var_type == "date") {
          # 预先计算日期范围以避免在更新函数中出现长度为零的向量
          valid_data <- var_data[!is.na(var_data)]
          has_valid_data <- length(valid_data) > 0
          
          min_val <- if(has_valid_data) {
            tryCatch(min(valid_data), error = function(e) NA)
          } else NA
          
          max_val <- if(has_valid_data) {
            tryCatch(max(valid_data), error = function(e) NA)
          } else NA
          
          # 确保日期是有效的，否则使用默认值
          final_start <- if(!is.na(min_val) && inherits(min_val, "Date")) min_val else Sys.Date()
          final_end <- if(!is.na(max_val) && inherits(max_val, "Date")) max_val else Sys.Date()
          
          updateDateInput(session, paste0("date_start_", var_name),
                          value = final_start)
          updateDateInput(session, paste0("date_end_", var_name),
                          value = final_end)
        } else {
          updateTextInput(session, paste0("text_search_", var_name), value = "")
        }
        
        # 只对非分类变量重置空值筛选单选按钮
        if (var_type != "factor") {
          updateRadioButtons(session, paste0("na_filter_", var_name), selected = "all")
        }
      }
    }
  })
  
  # 监听数据变化，重置筛选变量选择和列选择
  observeEvent(data_store(), {
    all_choices <- build_column_choices(data_store())
    updateSelectizeInput(session, "selected_var",
                         choices = all_choices,
                         server = TRUE)
    
    # 更新列选择 - 保持合理的默认显示列数
    max_default_cols <- min(25, length(names(data_store())))
    default_display_cols <- head(names(data_store()), max_default_cols)
    updateSelectizeInput(session, "selected_columns",
                         choices = all_choices,
                         selected = default_display_cols,
                         server = TRUE)
    
    updateSelectizeInput(session, "meta_vars",
                         choices = all_choices,
                         selected = character(0),
                         server = TRUE)
  })
  
  # 返回供分析模块使用的数据（已去除行号）
  return(analysis_data)
}
