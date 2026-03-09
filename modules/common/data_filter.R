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
    x_chr <- as.character(x)
    parsed <- tryCatch(
      suppressWarnings(as.Date(
        x_chr,
        tryFormats = c(
          "%Y-%m-%d", "%Y/%m/%d", "%Y.%m.%d",
          "%Y%m%d", "%Y-%m-%d %H:%M:%S", "%Y/%m/%d %H:%M:%S",
          "%d/%m/%Y", "%m/%d/%Y"
        )
      )),
      error = function(e) as.Date(rep(NA_character_, length(x_chr)))
    )
    return(parsed)
  }
  if (var_type == "factor") {
    return(as.character(x))
  }
  as.character(x)
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
            ns("apply_filters"),
            "应用筛选",
            class = "btn-primary",
            style = "margin-top: 25px;",
            icon = icon("play")
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
          width = 4,
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
    apply_tick <- reactiveVal(1)
    
    format_filter_conditions <- function(df, selected_vars) {
      if (is.null(selected_vars) || length(selected_vars) == 0) {
        return("无")
      }
      condition_text <- character(0)
      for (var_name in selected_vars) {
        if (!(var_name %in% names(df))) {
          next
        }
        var_type <- determine_var_type(df[[var_name]])
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
          txt <- input[[paste0("text_search_", var_name)]]
          if (!is.null(txt) && nzchar(trimws(txt))) {
            item <- paste0(var_name, " 文本包含\"", txt, "\"")
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
        var_type <- determine_var_type(df[[var_name]])
        var_data <- coerce_var_data(df[[var_name]], var_type)
        
        div(
          class = "filter-group",
          style = "border: 1px solid #ddd; padding: 8px; margin: 3px; border-radius: 4px; background-color: #f8f9fa; display: inline-block; vertical-align: top; width: 280px; margin-right: 8px;",
          
          h5(paste(var_name, "(", var_type, ")"), style = "margin-top: 0; color: #333; font-size: 13px;"),
          if (var_type != "factor") {
            radioButtons(ns(paste0("na_filter_", var_name)),
                        "空值筛选:",
                        choices = c("全部" = "all", "排除空值" = "exclude", "仅显示空值" = "only"),
                        selected = "all",
                        inline = TRUE,
                        width = "100%")
          },
          
          if (var_type == "numeric") {
            range_vals <- safe_numeric_range(var_data)
            tagList(
              fluidRow(
                column(6, numericInput(ns(paste0("num_min_", var_name)), "最小值:", value = range_vals$min, width = "100%")),
                column(6, numericInput(ns(paste0("num_max_", var_name)), "最大值:", value = range_vals$max, width = "100%"))
              )
            )
          } else if (var_type == "factor") {
            non_empty_values <- var_data[!is.na(var_data) & var_data != ""]
            unique_values <- unique(non_empty_values)
            has_na_values <- any(is.na(var_data)) || any(var_data == "", na.rm = TRUE)
            choices_with_na <- if (length(unique_values) > 100) {
              if (has_na_values) c(head(unique_values, 99), "NA") else head(unique_values, 100)
            } else {
              if (has_na_values) c(unique_values, "NA") else unique_values
            }
            selectizeInput(
              ns(paste0("cat_values_", var_name)),
              NULL,
              choices = choices_with_na,
              selected = choices_with_na,
              multiple = TRUE,
              options = list(
                placeholder = "选择值...",
                maxItems = 30,
                plugins = list("remove_button")
              )
            )
          } else if (var_type == "date") {
            valid_data <- var_data[!is.na(var_data)]
            has_valid_data <- length(valid_data) > 0
            min_val <- if (has_valid_data) tryCatch(min(valid_data), error = function(e) NA) else NA
            max_val <- if (has_valid_data) tryCatch(max(valid_data), error = function(e) NA) else NA
            final_start <- if (!is.na(min_val) && inherits(min_val, "Date")) min_val else Sys.Date()
            final_end <- if (!is.na(max_val) && inherits(max_val, "Date")) max_val else Sys.Date()
            tagList(
              dateInput(ns(paste0("date_start_", var_name)), "开始:", value = final_start, width = "100%"),
              dateInput(ns(paste0("date_end_", var_name)), "结束:", value = final_end, width = "100%")
            )
          } else {
            textInput(ns(paste0("text_search_", var_name)), NULL, placeholder = "关键词...", width = "100%")
          }
        )
      })
      
      div(
        class = "filter-controls-container",
        style = "overflow-x: auto; white-space: nowrap; padding: 5px; max-height: 200px;",
        controls
      )
    })
    
    observeEvent(data(), {
      req(data())
      apply_tick(apply_tick() + 1)
    })
    
    observeEvent(input$apply_filters, {
      apply_tick(apply_tick() + 1)
    })
    
    # 执行筛选
    filtered_data <- eventReactive(apply_tick(), {
      req(data())
      withProgress(message = "正在执行全局筛选...", value = 0, {
        df <- data()
        selected_vars <- input$selected_var
        if (is.null(selected_vars) || length(selected_vars) == 0) {
          incProgress(1)
          return(df)
        }
        step <- 1 / max(1, length(selected_vars))
        for (var_name in selected_vars) {
          var_type <- determine_var_type(df[[var_name]])
          var_data <- coerce_var_data(df[[var_name]], var_type)
          if (var_type != "factor") {
            na_filter_val <- input[[paste0("na_filter_", var_name)]]
            if (!is.null(na_filter_val) && na_filter_val == "only") {
              df <- df[is.na(var_data), , drop = FALSE]
              if (nrow(df) == 0) break
              var_data <- coerce_var_data(df[[var_name]], var_type)
            } else if (!is.null(na_filter_val) && na_filter_val == "exclude") {
              df <- df[!is.na(var_data), , drop = FALSE]
              if (nrow(df) == 0) break
              var_data <- coerce_var_data(df[[var_name]], var_type)
            }
          }
          
          if (var_type == "numeric") {
            min_val <- input[[paste0("num_min_", var_name)]]
            max_val <- input[[paste0("num_max_", var_name)]]
            if (!is.null(min_val) && !is.null(max_val)) {
              na_filter_val <- input[[paste0("na_filter_", var_name)]]
              keep_idx <- if (!is.null(na_filter_val) && na_filter_val == "exclude") {
                !is.na(var_data) & var_data >= min_val & var_data <= max_val
              } else {
                is.na(var_data) | (var_data >= min_val & var_data <= max_val)
              }
              df <- df[keep_idx, , drop = FALSE]
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
                df <- df[keep_idx, , drop = FALSE]
              } else {
                df <- df[var_data %in% selected_values, , drop = FALSE]
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
              df <- df[keep_idx, , drop = FALSE]
            }
          } else {
            txt <- input[[paste0("text_search_", var_name)]]
            if (!is.null(txt) && txt != "") {
              pattern <- paste0(".*", txt, ".*")
              match_idx <- grepl(pattern, var_data, ignore.case = TRUE)
              na_filter_val <- input[[paste0("na_filter_", var_name)]]
              keep_idx <- if (!is.null(na_filter_val) && na_filter_val == "exclude") {
                !is.na(var_data) & match_idx
              } else {
                is.na(var_data) | match_idx
              }
              df <- df[keep_idx, , drop = FALSE]
            }
          }
          incProgress(step)
        }
        df
      })
    })
    
    # 统计信息
    output$filter_stats <- renderText({
      req(data(), filtered_data())
      n_orig <- nrow(data())
      n_filt <- nrow(filtered_data())
      condition_text <- format_filter_conditions(data(), input$selected_var)
      paste0(
        "筛选结果: ", n_filt, " / ", n_orig, " 行 (", round(n_filt/n_orig*100, 1), "%)", "\n",
        "当前筛选条件: ", condition_text
      )
    })
    
    # 重置
    observeEvent(input$reset_filters, {
      updateSelectizeInput(session, "selected_var", selected = character(0))
      apply_tick(apply_tick() + 1)
    })
    
    return(filtered_data)
  })
}
