# 通用数据筛选模块
# 提取自 data_preparation.R，用于在各个分析模块中提供统一的数据筛选功能

library(shiny)
library(dplyr)
library(shinyWidgets)
source("modules/common/data_metadata.R")
if (!exists("app_card_box", mode = "function") || !exists("app_card_note", mode = "function")) {
  if (file.exists("modules/common/ui_shell.R")) {
    source("modules/common/ui_shell.R")
  } else {
    source(file.path("..", "modules", "common", "ui_shell.R"))
  }
}

# ==============================================================================
# 辅助函数 (复制自 data_preparation.R)
# ==============================================================================

# 判断变量类型
determine_var_type <- function(x) metadata_determine_var_type(x)

# 安全计算数值范围
safe_numeric_range <- function(var_data) metadata_safe_numeric_range(var_data)

coerce_var_data <- function(x, var_type) metadata_coerce_var_data(x, var_type)

# ==============================================================================
# 模块 UI
# ==============================================================================
data_filter_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    tags$head(
      tags$style(HTML("
        .data-filter-card .app-card__panel {
          margin-top: 12px;
        }
        .data-filter-toolbar {
          display: flex;
          flex-wrap: wrap;
          gap: 12px;
          align-items: flex-end;
        }
        .data-filter-toolbar__field {
          flex: 1 1 260px;
          min-width: 220px;
        }
        .data-filter-toolbar__actions {
          display: flex;
          gap: 8px;
          align-items: flex-end;
          flex-wrap: wrap;
        }
        .data-filter-toolbar__stats {
          flex: 1 1 280px;
          min-width: 240px;
          padding: 10px 12px;
          border: 1px solid #e8eef5;
          border-radius: 10px;
          background: #f8fbff;
        }
        .data-filter-toolbar__stats .shiny-text-output,
        .data-filter-toolbar__stats pre {
          margin: 0;
          white-space: pre-wrap;
          word-break: break-word;
          background: transparent;
          border: 0;
          padding: 0;
        }
        .filter-group .selectize-control.multi .selectize-input > div {
          display: block !important;
          margin-bottom: 4px !important;
        }
        .filter-controls-container {
          scrollbar-width: thin;
          scrollbar-color: #888 #f1f1f1;
        }
        .filter-card-item {
          border: 1px solid #dce7f2;
          padding: 10px;
          margin: 4px;
          border-radius: 10px;
          background-color: #f8fbff;
          display: inline-block;
          vertical-align: top;
          width: 288px;
          margin-right: 8px;
        }
      "))
    ),
    
    app_card_box(
      width = 12,
      title = "数据筛选 (可选)",
      subtitle = "按需设置筛选条件；默认折叠显示，避免占用主工作区",
      tone = "info",
      status = "info",
      solidHeader = FALSE,
      collapsible = TRUE,
      collapsed = TRUE,
      class = "data-filter-card",
      app_card_note("按变量类型配置筛选条件，并在点击“应用筛选”后统一生效。"),
      app_card_panel(
        tags$div(
          class = "data-filter-toolbar",
          tags$div(
            class = "data-filter-toolbar__field",
            selectizeInput(
              ns("selected_var"),
              "添加筛选变量:",
              choices = NULL,
              multiple = TRUE,
              options = list(placeholder = "选择变量...")
            )
          ),
          tags$div(
            class = "data-filter-toolbar__actions",
            actionButton(
              ns("apply_filters"),
              "应用筛选",
              class = "btn-primary",
              icon = icon("play")
            ),
            actionButton(
              ns("reset_filters"),
              "重置筛选",
              class = "btn-warning",
              icon = icon("refresh")
            )
          ),
          tags$div(
            class = "data-filter-toolbar__stats",
            tags$strong("筛选统计"),
            verbatimTextOutput(ns("filter_stats"), placeholder = TRUE)
          )
        )
      ),
      
      app_card_panel(
        tags$strong("筛选条件"),
        app_card_note("按变量类型动态生成数值、分类、日期或文本条件；所选条件在点击“应用筛选”后统一生效。"),
        uiOutput(ns("filter_controls"))
      )
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
    get_df_metadata <- reactive({
      req(data())
      metadata_get_table(data = data())
    })
    get_var_label <- function(df, var_name) metadata_get_var_label(var_name, df[[var_name]], metadata = get_df_metadata())
    get_var_type <- function(df, var_name) metadata_get_var_type(var_name, df[[var_name]], metadata = get_df_metadata())
    
    format_filter_conditions <- function(df, selected_vars) {
      if (is.null(selected_vars) || length(selected_vars) == 0) {
        return("无")
      }
      condition_text <- character(0)
      for (var_name in selected_vars) {
        if (!(var_name %in% names(df))) {
          next
        }
        var_label <- get_var_label(df, var_name)
        var_type <- get_var_type(df, var_name)
        item <- NULL
        if (var_type == "numeric") {
          min_val <- input[[paste0("num_min_", var_name)]]
          max_val <- input[[paste0("num_max_", var_name)]]
          if (!is.null(min_val) && !is.null(max_val)) {
            item <- paste0(var_label, " 数值[", min_val, ", ", max_val, "]")
          }
        } else if (var_type == "factor") {
          vals <- input[[paste0("cat_values_", var_name)]]
          if (!is.null(vals) && length(vals) > 0) {
            item <- paste0(var_label, " 分类{", paste(vals, collapse = ", "), "}")
          }
        } else if (var_type == "date") {
          start_date <- input[[paste0("date_start_", var_name)]]
          end_date <- input[[paste0("date_end_", var_name)]]
          if (!is.null(start_date) && !is.null(end_date)) {
            item <- paste0(var_label, " 日期[", as.character(start_date), ", ", as.character(end_date), "]")
          }
        } else {
          txt <- input[[paste0("text_search_", var_name)]]
          if (!is.null(txt) && nzchar(trimws(txt))) {
            item <- paste0(var_label, " 文本包含\"", txt, "\"")
          }
        }
        if (var_type != "factor") {
          na_filter_val <- input[[paste0("na_filter_", var_name)]]
          if (!is.null(na_filter_val) && na_filter_val != "all") {
            na_text <- if (na_filter_val == "exclude") "排除空值" else "仅空值"
            if (is.null(item)) {
              item <- paste0(var_label, " ", na_text)
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
      updateSelectizeInput(session, "selected_var", choices = metadata_build_column_choices(data(), metadata = get_df_metadata()), server = TRUE)
    })
    
    # 动态生成筛选控件
    output$filter_controls <- renderUI({
      req(data(), input$selected_var)
      df <- data()
      selected_vars <- input$selected_var
      
      if (length(selected_vars) == 0) return(NULL)
      
      controls <- lapply(selected_vars, function(var_name) {
        var_label <- get_var_label(df, var_name)
        var_type <- get_var_type(df, var_name)
        var_data <- coerce_var_data(df[[var_name]], var_type)
        
        div(
          class = "filter-group",
          class = "filter-card-item",
          
          h5(if (!identical(var_label, var_name)) paste0(var_name, " [", var_label, "] (", var_type, ")") else paste0(var_name, " (", var_type, ")"), style = "margin-top: 0; color: #333; font-size: 13px;"),
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
          var_type <- get_var_type(df, var_name)
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
        metadata_attach_to_data(df, metadata = get_df_metadata())
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
