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
library(memoise) # 函数缓存
library(DBI)
library(RPostgres)
library(pool)

data_preparation_scalar_chr <- function(x, default = "") {
  if (is.null(x) || length(x) == 0) {
    return(default)
  }
  value <- x[[1]]
  if (is.null(value) || length(value) == 0 || is.na(value)) {
    return(default)
  }
  value_chr <- as.character(value)
  if (!nzchar(value_chr)) {
    return(default)
  }
  value_chr
}

data_preparation_build_fallback_dataset_path <- function(storage_root, ds_row) {
  workspace_id <- data_preparation_scalar_chr(ds_row$workspace_id, default = "")
  dataset_id <- data_preparation_scalar_chr(ds_row$id, default = "")
  folder_id <- data_preparation_scalar_chr(ds_row$folder_id, default = "")

  if (!nzchar(storage_root) || !nzchar(workspace_id) || !nzchar(dataset_id)) {
    return("")
  }

  path_parts <- c(storage_root, workspace_id)
  if (nzchar(folder_id)) {
    path_parts <- c(path_parts, folder_id)
  }

  do.call(file.path, as.list(c(path_parts, paste0(dataset_id, ".rds"))))
}

# 数据准备UI
data_preparation_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    app_card_dependencies(),
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
        /* 滚动条样式 */
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
        .data-prep-filter-shell {
          min-height: 340px;
          max-height: 340px;
          overflow-x: auto;
          overflow-y: auto;
          white-space: nowrap;
          padding: 8px 6px 2px;
          border-radius: 12px;
          background: #fbfdff;
          border: 1px solid #e8eef5;
        }
        .data-prep-filter-group {
          border: 1px solid #dde7f2;
          padding: 10px 12px;
          margin: 4px 8px 8px 0;
          border-radius: 10px;
          background-color: #ffffff;
          display: inline-block;
          vertical-align: top;
          width: 300px;
          word-wrap: break-word;
          white-space: normal;
          box-shadow: 0 4px 12px rgba(31, 45, 61, 0.04);
        }
        .data-prep-filter-group h5 {
          margin-top: 0;
          margin-bottom: 10px;
          color: #243447;
          font-size: 13px;
          line-height: 1.5;
          word-break: break-word;
        }
        .data-prep-filter-group h6 {
          margin: 6px 0;
          font-size: 11px;
          color: #6b7785;
          font-weight: 600;
        }
      "))
    ),
    fluidRow(
      app_card_box(
        width = 12,
        title = "数据加载",
        subtitle = "在这里完成本地上传与数据空间数据集加载",
        tone = "primary",
        status = "primary",
        solidHeader = FALSE,
        class = "data-load-card",
        tabsetPanel(
          id = ns("data_load_tabs"),
          type = "tabs",
          tabPanel(
            "本地上传",
            fileInput(
              ns("file"),
              "选择数据文件",
              accept = c(".csv", ".xlsx", ".xls", ".sas7bdat", ".sav", ".dta", ".por"),
              buttonLabel = "浏览",
              placeholder = "CSV/Excel/SAS/SPSS，最大 100MB",
              multiple = FALSE
            ),
            app_card_note(
              "支持 CSV、Excel、SAS、SPSS、Stata 格式，单文件上限 100MB。临时上传仅当前会话有效，不写入持久化数据空间。"
            )
          ),
          tabPanel(
            "数据库数据集加载",
            fluidRow(
              column(
                width = 4,
                selectInput(ns("db_workspace_select"), "选择数据空间", choices = character(0))
              ),
              column(
                width = 4,
                selectInput(ns("db_folder_select"), "选择文件夹", choices = c("根目录" = "__ROOT__"))
              ),
              column(
                width = 4,
                selectInput(ns("db_dataset_select"), "选择数据集", choices = character(0))
              )
            ),
            fluidRow(
              column(6, actionButton(ns("db_refresh"), "刷新数据库列表", class = "btn-default", width = "100%")),
              column(6, actionButton(ns("db_load_dataset"), "加载所选数据集", class = "btn-primary", width = "100%"))
            ),
            app_card_note("从已授权的数据空间、文件夹和数据集中加载数据，供当前分析使用。")
          )
        )
      )
    ),
    
    # 变量选择和筛选区域（条件显示）
    conditionalPanel(
      condition = "output.dataLoaded == true",
      ns = ns,
      
      fluidRow(
        column(
          width = 12,
          app_card_box(
            width = NULL,
            title = "变量与筛选控制",
            subtitle = "在同一块中完成筛选变量选择、显示列控制和筛选结果应用",
            tone = "info",
            status = "info",
            solidHeader = FALSE,
            fluidRow(
              column(
                width = 7,
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
              ),
              column(
                width = 5,
                fluidRow(
                  column(
                    width = 6,
                    actionButton(
                      ns("apply_filters"),
                      "应用筛选",
                      class = "btn-primary",
                      width = "100%",
                      icon = icon("play")
                    )
                  ),
                  column(
                    width = 6,
                    actionButton(
                      ns("reset_filters"),
                      "重置所有筛选",
                      class = "btn-default",
                      width = "100%",
                      icon = icon("refresh")
                    )
                  )
                ),
                br(),
                uiOutput(ns("filter_stats_panel"))
              )
            )
          )
        )
      ),
      
      # 高级筛选面板（在数据预览上方）
      fluidRow(
        column(
          width = 12,
          app_card_box(
            width = NULL,
            title = "高级筛选",
            subtitle = "筛选控件会按所选变量类型自动调整；增减筛选条件时尽可能保留已有设置。",
            tone = "primary",
            status = "primary",
            solidHeader = FALSE,
            # 动态筛选控件容器
            uiOutput(ns("filter_controls"))
          )
        )
      ),
      fluidRow(
        column(
          width = 12,
          uiOutput(ns("data_overview_cards"))
        )
      ),
      
      # 数据预览区域
      fluidRow(
        column(
          width = 12,
          app_card_box(
            width = NULL,
            title = "数据预览",
            subtitle = "查看当前筛选结果与表格渲染状态",
            tone = "success",
            status = "success",
            solidHeader = FALSE,
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
          app_card_box(
            width = NULL,
            title = "变量信息卡片",
            subtitle = "集中查看变量类型、Label，并批量调整元数据",
            tone = "primary",
            status = "primary",
            solidHeader = FALSE,
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

# 缓存列定义
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
  metadata_determine_var_type(x)
}

valid_var_types <- metadata_valid_var_types

coerce_var_data <- function(x, var_type) {
  metadata_coerce_var_data(x, var_type)
}

# 安全计算数值范围 - 处理全空值的情况
safe_numeric_range <- function(var_data) {
  metadata_safe_numeric_range(var_data)
}

# 数据准备服务器逻辑
data_preparation_server <- function(id, pg_pool = NULL, current_user = NULL) {
  moduleServer(id, function(input, output, session) {
  ns <- session$ns
  `%||%` <- function(x, y) if (is.null(x)) y else x
  
  # 数据存储
  data_store <- reactiveVal()
  # 当前数据集的来源元信息（供任务历史记录）
  dataset_meta <- reactiveVal(NULL)
  var_type_overrides <- reactiveVal(setNames(character(0), character(0)))
  var_label_overrides <- reactiveVal(setNames(character(0), character(0)))
  
  # 渲染状态
  rendering_table <- reactiveVal(FALSE)
  filter_input_cache <- reactiveVal(list())
  previous_selected_vars <- reactiveVal(character(0))
  
  # 性能监控
  performance_metrics <- reactiveValues(
    load_time = NULL,
    filter_time = NULL,
    render_time = NULL
  )
  filter_apply_tick <- reactiveVal(0)
  filter_profile_cache <- reactiveVal(list())
  base_var_info_cache <- reactiveVal(data.frame())
  root_folder_token <- "__ROOT__"
  pool <- if (is.null(pg_pool)) {
    tryCatch(auth_create_pool(), error = function(e) NULL)
  } else {
    pg_pool
  }
  if (is.null(pg_pool)) {
    onStop(function() {
      if (!is.null(pool)) {
        poolClose(pool)
      }
    })
  }
  if (!is.null(pool)) {
    tryCatch(auth_ensure_schema(pool), error = function(e) NULL)
  }

  get_current_user <- function() {
    if (is.null(current_user)) {
      return(NULL)
    }
    isolate(current_user())
  }

  require_logged_in <- function() {
    if (!is.null(get_current_user())) {
      return(TRUE)
    }
    showNotification("请先登录后再加载数据库数据集", type = "warning")
    FALSE
  }
  
  load_registry <- function() {
    if (is.null(pool)) {
      return(auth_empty_registry())
    }
    tryCatch({
      user <- get_current_user()
      if (is.null(user)) {
        return(auth_empty_registry())
      }
      service_registry_load(pool, user = user)
    }, error = function(e) {
      auth_empty_registry()
    })
  }
  
  refresh_db_workspace_choices <- function(selected = NULL) {
    reg <- load_registry()
    ws <- reg$workspaces
    ws_choices <- if (nrow(ws) == 0) character(0) else setNames(ws$id, ws$name)
    updateSelectInput(session, "db_workspace_select", choices = ws_choices, selected = selected)
  }
  
  refresh_db_folder_choices <- function(workspace_id = "", selected = root_folder_token) {
    reg <- load_registry()
    fd <- reg$folders
    if (is.null(workspace_id) || workspace_id == "") {
      fd_choices <- c("根目录" = root_folder_token)
    } else {
      fd_current <- fd[fd$workspace_id == workspace_id, , drop = FALSE]
      fd_choices <- c("根目录" = root_folder_token)
      if (nrow(fd_current) > 0) {
        fd_choices <- c(fd_choices, setNames(fd_current$id, fd_current$name))
      }
    }
    updateSelectInput(session, "db_folder_select", choices = fd_choices, selected = selected)
  }
  
  refresh_db_dataset_choices <- function(workspace_id = "", folder_id = root_folder_token) {
    reg <- load_registry()
    ds <- reg$datasets
    ds_choices <- character(0)
    if (!is.null(workspace_id) && workspace_id != "") {
      ds_current <- ds[ds$workspace_id == workspace_id, , drop = FALSE]
      if (!is.null(folder_id) && folder_id == root_folder_token) {
        ds_current <- ds_current[is.na(ds_current$folder_id) | ds_current$folder_id == "", , drop = FALSE]
      } else if (!is.null(folder_id) && folder_id != "") {
        ds_current <- ds_current[ds_current$folder_id == folder_id, , drop = FALSE]
      }
      if (nrow(ds_current) > 0) {
        labels <- paste0(ds_current$name, " (", ds_current$nrow, "x", ds_current$ncol, ")")
        ds_choices <- setNames(ds_current$id, labels)
      }
    }
    updateSelectInput(session, "db_dataset_select", choices = ds_choices)
  }

  map_data_path_to_storage_root <- function(raw_path, storage_root) {
    if (is.null(raw_path) || !nzchar(raw_path)) {
      return(raw_path)
    }
    normalized_raw <- gsub("\\\\", "/", raw_path)
    if (startsWith(normalized_raw, "s3://")) {
      return(raw_path)
    }
    if (startsWith(normalized_raw, "/app/data_storage/")) {
      relative_seg <- sub("^/app/data_storage/?", "", normalized_raw)
      return(file.path(storage_root, relative_seg))
    }
    marker <- "/data_storage/"
    marker_pos <- regexpr(marker, normalized_raw, fixed = TRUE)[1]
    if (!is.na(marker_pos) && marker_pos > 0) {
      relative_seg <- substr(normalized_raw, marker_pos + nchar(marker), nchar(normalized_raw))
      return(file.path(storage_root, relative_seg))
    }
    raw_path
  }

  resolve_dataset_data_path <- function(ds_row) {
    raw_path <- data_preparation_scalar_chr(ds_row$data_path, default = "")
    if (!nzchar(raw_path)) {
      return("")
    }
    if (grepl("^s3://", raw_path)) {
      return(raw_path)
    }
    if (file.exists(raw_path)) {
      return(raw_path)
    }
    storage_root <- normalizePath(
      Sys.getenv("STORAGE_ROOT", "data_storage"),
      winslash = "/",
      mustWork = FALSE
    )
    mapped_path <- map_data_path_to_storage_root(raw_path, storage_root)
    if (!identical(mapped_path, raw_path) && file.exists(mapped_path)) {
      tryCatch({
        if (!is.null(pool)) {
          dbExecute(
            pool,
            "UPDATE datasets SET data_path = $1 WHERE id = $2",
            params = list(mapped_path, data_preparation_scalar_chr(ds_row$id, default = ""))
          )
        }
      }, error = function(e) NULL)
      return(mapped_path)
    }
    fallback_path <- data_preparation_build_fallback_dataset_path(storage_root, ds_row)
    if (nzchar(fallback_path) && file.exists(fallback_path)) {
      tryCatch({
        if (!is.null(pool) && !identical(fallback_path, raw_path)) {
          dbExecute(
            pool,
            "UPDATE datasets SET data_path = $1 WHERE id = $2",
            params = list(fallback_path, data_preparation_scalar_chr(ds_row$id, default = ""))
          )
        }
      }, error = function(e) NULL)
      return(fallback_path)
    }
    matched_paths <- list.files(
      path = storage_root,
      pattern = paste0("^", data_preparation_scalar_chr(ds_row$id, default = ""), "\\.rds$"),
      recursive = TRUE,
      full.names = TRUE
    )
    if (length(matched_paths) > 0 && file.exists(matched_paths[[1]])) {
      resolved_path <- matched_paths[[1]]
      tryCatch({
        if (!is.null(pool) && !identical(resolved_path, raw_path)) {
          dbExecute(
            pool,
            "UPDATE datasets SET data_path = $1 WHERE id = $2",
            params = list(resolved_path, data_preparation_scalar_chr(ds_row$id, default = ""))
          )
        }
      }, error = function(e) NULL)
      return(resolved_path)
    }
    raw_path
  }
  
  apply_loaded_data <- function(data) {
    withProgress(message = "正在准备数据...", value = 0, {
      data_store(data)
      var_type_overrides(setNames(character(0), character(0)))
      var_label_overrides(setNames(character(0), character(0)))
      incProgress(0.2, detail = "构建变量缓存")
      build_data_caches(data)
      incProgress(0.4, detail = "更新变量选择器")
      all_choices <- build_column_choices(data)
      updateSelectizeInput(session, "selected_var", choices = all_choices, server = TRUE)
      max_default_cols <- min(25, length(names(data)))
      default_display_cols <- head(names(data), max_default_cols)
      updateSelectizeInput(session, "selected_columns",
                           choices = all_choices,
                           selected = default_display_cols,
                           server = TRUE)
      updateSelectizeInput(session, "meta_vars",
                           choices = all_choices,
                           selected = character(0),
                           server = TRUE)
      incProgress(0.4, detail = "完成")
      filter_apply_tick(filter_apply_tick() + 1)
    })
  }
  
  refresh_db_workspace_choices()
  refresh_db_folder_choices("")
  refresh_db_dataset_choices("", root_folder_token)
  observeEvent(current_user(), {
    workspace_id <- isolate(input$db_workspace_select %||% "")
    folder_id <- isolate(input$db_folder_select %||% root_folder_token)
    refresh_db_workspace_choices(selected = workspace_id)
    refresh_db_folder_choices(workspace_id, selected = folder_id)
    refresh_db_dataset_choices(workspace_id, folder_id)
  }, ignoreNULL = FALSE, ignoreInit = TRUE)
  get_var_label <- function(var_name, var_data) {
    metadata_get_var_label(var_name, var_data, label_overrides = var_label_overrides(), data = data_store())
  }
  
  get_effective_var_type <- function(var_name, var_data) {
    metadata_get_var_type(var_name, var_data, type_overrides = var_type_overrides(), data = data_store())
  }
  
  build_column_choices <- function(data) {
    metadata_build_column_choices(data, label_overrides = var_label_overrides())
  }

  build_factor_filter_choices <- function(var_data, profile) {
    unique_values <- if (!is.null(profile) && !is.null(profile$factor_values)) profile$factor_values else unique(var_data[!is.na(var_data)])
    has_na_values <- if (!is.null(profile) && !is.null(profile$factor_has_na)) isTRUE(profile$factor_has_na) else any(is.na(var_data))
    if (!is.null(profile) && !is.null(profile$factor_total_unique) && profile$factor_total_unique > 100) {
      unique_non_na_values <- head(unique_values, 99)
      if (has_na_values) {
        c(unique_non_na_values, "NA")
      } else {
        head(unique_values, 100)
      }
    } else if (has_na_values) {
      c(unique_values, "NA")
    } else {
      unique_values
    }
  }

  build_filter_ui_state <- function(var_name, raw_var_data, var_type, profile) {
    cached <- filter_input_cache()[[var_name]] %||% list()
    state <- list(na_filter = cached$na_filter %||% "all")
    if (var_type == "numeric") {
      range_vals <- if (!is.null(profile) && !is.null(profile$numeric_range)) profile$numeric_range else safe_numeric_range(coerce_var_data(raw_var_data, "numeric"))
      safe_min <- as.numeric(range_vals$min)[1]
      safe_max <- as.numeric(range_vals$max)[1]
      if (length(safe_min) == 0 || is.na(safe_min) || !is.finite(safe_min)) safe_min <- 0
      if (length(safe_max) == 0 || is.na(safe_max) || !is.finite(safe_max)) safe_max <- 1
      if (safe_min > safe_max) {
        tmp <- safe_min
        safe_min <- safe_max
        safe_max <- tmp + 1
      }
      cached_min <- suppressWarnings(as.numeric(cached$num_min %||% safe_min))
      cached_max <- suppressWarnings(as.numeric(cached$num_max %||% safe_max))
      state$num_min <- max(safe_min, min(cached_min, safe_max))
      state$num_max <- min(safe_max, max(cached_max, safe_min))
      if (state$num_min > state$num_max) {
        state$num_min <- safe_min
        state$num_max <- safe_max
      }
      state$range_min <- safe_min - 1
      state$range_max <- safe_max + 1
      state$step <- 1
    } else if (var_type == "factor") {
      choices_with_na <- build_factor_filter_choices(raw_var_data, profile)
      cached_values <- cached$cat_values %||% choices_with_na
      selected_values <- intersect(cached_values, choices_with_na)
      if (length(selected_values) == 0) {
        selected_values <- choices_with_na
      }
      state$choices_with_na <- choices_with_na
      state$selected_values <- selected_values
    } else if (var_type == "date") {
      final_start <- if (!is.null(profile) && !is.null(profile$date_start)) profile$date_start else Sys.Date()
      final_end <- if (!is.null(profile) && !is.null(profile$date_end)) profile$date_end else Sys.Date()
      cached_start <- suppressWarnings(as.Date(cached$date_start %||% final_start))
      cached_end <- suppressWarnings(as.Date(cached$date_end %||% final_end))
      if (is.na(cached_start)) cached_start <- final_start
      if (is.na(cached_end)) cached_end <- final_end
      state$date_start <- max(min(cached_start, final_end), final_start)
      state$date_end <- min(max(cached_end, final_start), final_end)
    } else {
      state$text_search <- cached$text_search %||% ""
    }
    state
  }

  capture_filter_state <- function(var_names) {
    if (is.null(data_store()) || length(var_names) == 0) {
      return(invisible(NULL))
    }
    cache <- filter_input_cache()
    data <- data_store()
    profile_map <- filter_profile_cache()
    for (var_name in var_names) {
      if (!(var_name %in% names(data))) {
        next
      }
      var_type <- get_effective_var_type(var_name, data[[var_name]])
      state <- list(na_filter = input[[paste0("na_filter_", var_name)]] %||% "all")
      if (var_type == "numeric") {
        state$num_min <- input[[paste0("num_min_", var_name)]]
        state$num_max <- input[[paste0("num_max_", var_name)]]
      } else if (var_type == "factor") {
        state$cat_values <- input[[paste0("cat_values_", var_name)]]
        state$choices_with_na <- build_factor_filter_choices(data[[var_name]], profile_map[[var_name]])
      } else if (var_type == "date") {
        state$date_start <- input[[paste0("date_start_", var_name)]]
        state$date_end <- input[[paste0("date_end_", var_name)]]
      } else {
        state$text_search <- input[[paste0("text_search_", var_name)]] %||% ""
      }
      cache[[var_name]] <- state
    }
    filter_input_cache(cache)
    invisible(NULL)
  }
  
  remove_named_value <- function(x, key) {
    if (length(x) == 0 || is.null(names(x))) {
      return(x)
    }
    x[names(x) != key]
  }
  
  build_data_caches <- function(data) {
    vars <- names(data)
    if (length(vars) == 0) {
      filter_profile_cache(list())
      base_var_info_cache(data.frame())
      return(invisible(NULL))
    }
    profiles <- vector("list", length(vars))
    names(profiles) <- vars
    info_rows <- vector("list", length(vars))
    for (idx in seq_along(vars)) {
      var_name <- vars[[idx]]
      raw_var_data <- data[[var_name]]
      auto_type <- determine_var_type(raw_var_data)
      effective_type <- get_effective_var_type(var_name, raw_var_data)
      typed_data <- coerce_var_data(raw_var_data, effective_type)
      na_rate <- if (length(typed_data) == 0) 0 else round(mean(is.na(typed_data)) * 100, 2)
      unique_count <- length(unique(typed_data[!is.na(typed_data)]))
      sample_values <- unique(as.character(typed_data[!is.na(typed_data)]))
      sample_preview <- if (length(sample_values) == 0) "" else paste(head(sample_values, 3), collapse = ", ")
      if (is.character(raw_var_data)) {
        non_empty_values <- raw_var_data[!is.na(raw_var_data) & raw_var_data != ""]
      } else {
        non_empty_values <- raw_var_data[!is.na(raw_var_data)]
      }
      unique_non_empty <- unique(non_empty_values)
      has_na_values <- any(is.na(raw_var_data)) || (is.character(raw_var_data) && any(raw_var_data == "", na.rm = TRUE))
      numeric_data <- coerce_var_data(raw_var_data, "numeric")
      numeric_range <- safe_numeric_range(numeric_data)
      date_data <- coerce_var_data(raw_var_data, "date")
      valid_dates <- date_data[!is.na(date_data)]
      date_start <- if (length(valid_dates) > 0) min(valid_dates) else Sys.Date()
      date_end <- if (length(valid_dates) > 0) max(valid_dates) else Sys.Date()
      profiles[[var_name]] <- list(
        factor_values = head(unique_non_empty, 100),
        factor_total_unique = length(unique_non_empty),
        factor_has_na = has_na_values,
        numeric_range = numeric_range,
        date_start = date_start,
        date_end = date_end
      )
      info_rows[[idx]] <- data.frame(
        变量名 = var_name,
        自动类型 = auto_type,
        当前类型 = effective_type,
        缺失率值 = na_rate,
        唯一值数 = unique_count,
        示例值 = sample_preview,
        stringsAsFactors = FALSE
      )
    }
    filter_profile_cache(profiles)
    base_var_info_cache(do.call(rbind, info_rows))
  }
  
  selected_var_debounced <- debounce(reactive(input$selected_var), 500)

  observeEvent(input$selected_var, {
    old_vars <- isolate(previous_selected_vars())
    if (length(old_vars) > 0) {
      capture_filter_state(old_vars)
    }
    previous_selected_vars(input$selected_var %||% character(0))
  }, ignoreNULL = FALSE)
  
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

    # 单文件上传大小限制：100MB
    single_max_bytes <- 100 * 1024^2
    if (isTRUE(input$file$size > single_max_bytes)) {
      file_mb <- round(input$file$size / 1024^2, 1)
      showNotification(
        paste0("文件大小 ", format(file_mb, big.mark = ","), " MB 超过 100 MB 上限"),
        type = "error", duration = 6
      )
      return()
    }

    # 显示加载提示
    notification_id <- showNotification("正在加载数据文件，请稍候...", type = "message", duration = NULL)
    
    # 记录开始时间
    start_time <- Sys.time()
    
    tryCatch({
      data <- data_read_file(input$file$datapath, original_file_name = input$file$name)
      
      # 强制垃圾回收以释放内存
      gc()
      
      apply_loaded_data(data)

      # 记录来源数据集元信息（临时上传）
      dataset_meta(list(
        dataset_name   = input$file$name %||% "未命名文件",
        workspace_name = NULL,
        folder_name    = NULL,
        nrow           = nrow(data),
        ncol           = ncol(data),
        source         = "upload"
      ))

      # 记录加载时间
      load_time <- Sys.time() - start_time
      performance_metrics$load_time <- load_time

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
  
  observeEvent(input$db_refresh, {
    workspace_id <- ifelse(is.null(input$db_workspace_select), "", input$db_workspace_select)
    folder_id <- ifelse(is.null(input$db_folder_select), root_folder_token, input$db_folder_select)
    refresh_db_workspace_choices(selected = workspace_id)
    refresh_db_folder_choices(workspace_id, selected = folder_id)
    refresh_db_dataset_choices(workspace_id, folder_id)
    showNotification("数据库列表已刷新", type = "message")
  })
  
  observeEvent(input$db_workspace_select, {
    workspace_id <- input$db_workspace_select
    refresh_db_folder_choices(workspace_id)
    refresh_db_dataset_choices(workspace_id, root_folder_token)
  }, ignoreNULL = FALSE)
  
  observeEvent(input$db_folder_select, {
    workspace_id <- input$db_workspace_select
    folder_id <- ifelse(is.null(input$db_folder_select), root_folder_token, input$db_folder_select)
    if (is.null(workspace_id) || workspace_id == "") {
      refresh_db_dataset_choices("", root_folder_token)
      return()
    }
    refresh_db_dataset_choices(workspace_id, folder_id)
  }, ignoreNULL = FALSE)
  
  observeEvent(input$db_load_dataset, {
    if (!require_logged_in()) {
      return()
    }
    dataset_id <- input$db_dataset_select
    if (is.null(dataset_id) || dataset_id == "") {
      showNotification("请先选择数据库数据集", type = "warning")
      return()
    }
    reg <- load_registry()
    ds <- reg$datasets[reg$datasets$id == dataset_id, , drop = FALSE]
    if (nrow(ds) == 0) {
      showNotification("未找到数据集记录", type = "error")
      return()
    }
    data_path <- resolve_dataset_data_path(ds)
    data <- withProgress(message = "正在加载数据库数据集...", value = 0, {
      incProgress(0.4, detail = "读取数据文件")
      tmp <- tryCatch(storage_load_dataset(data_path), error = function(e) e)
      if (!is.null(tmp) && is.data.frame(tmp)) {
        incProgress(0.6, detail = "初始化筛选与缓存")
      }
      tmp
    })
    if (inherits(data, "error")) {
      err_msg <- conditionMessage(data)
      if (grepl("No such file or directory|cannot open the connection|无法打开压缩文件", err_msg, ignore.case = TRUE)) {
        showNotification("加载失败：数据文件缺失。该记录仍在数据库中，但物理文件不存在，请重新上传该数据集。", type = "error", duration = NULL)
      } else {
        showNotification(paste0("加载失败：", err_msg), type = "error")
      }
      return()
    }
    if (is.null(data) || !is.data.frame(data)) {
      showNotification("加载失败，数据文件格式异常", type = "error")
      return()
    }
    apply_loaded_data(data)
    # 记录来源数据集元信息
    ws_name <- if (!is.null(ds$workspace_id) && nzchar(ds$workspace_id[[1]] %||% "")) {
      reg$workspaces$name[reg$workspaces$id == ds$workspace_id[[1]]][1] %||% ds$workspace_id[[1]]
    } else { NULL }
    fn <- if (!is.null(ds$folder_id) && nzchar(ds$folder_id[[1]] %||% "")) {
      reg$folders$name[reg$folders$id == ds$folder_id[[1]]][1] %||% NULL
    } else { NULL }
    dataset_meta(list(
      dataset_name    = ds$name[[1]] %||% "未知",
      workspace_name  = ws_name,
      folder_name     = fn,
      nrow            = nrow(data),
      ncol            = ncol(data),
      source          = "database"
    ))
    showNotification(paste0("已加载数据库数据集：", ds$name[[1]]), type = "message")
  })
  
  observeEvent(input$apply_filters, {
    req(data_store())
    filter_apply_tick(filter_apply_tick() + 1)
    showNotification("筛选条件已应用", type = "message", duration = 1.5)
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
  
  output$data_overview_cards <- renderUI({
    req(data_store())
    data <- data_store()
    total_rows <- nrow(data)
    total_cols <- ncol(data)
    total_na <- sum(is.na(data))
    na_ratio <- if (total_rows * total_cols == 0) 0 else round(total_na / (total_rows * total_cols) * 100, 2)
    var_info <- variable_info_data()
    numeric_count <- sum(var_info$当前类型 == "numeric")
    factor_count <- sum(var_info$当前类型 == "factor")
    date_count <- sum(var_info$当前类型 == "date")
    text_count <- sum(var_info$当前类型 == "text")
    tags$div(
      class = "app-stat-grid",
      app_stat_card("总行数", format(total_rows, big.mark = ","), meta = "当前已载入的数据记录总数", tone = "primary"),
      app_stat_card("总列数", total_cols, meta = "当前可分析的字段数量", tone = "info"),
      app_stat_card("整体缺失率", paste0(na_ratio, "%"), meta = paste0("缺失值总数 ", format(total_na, big.mark = ",")), tone = if (na_ratio > 30) "danger" else "success"),
      app_stat_card(
        "字段类型分布",
        paste0("共 ", total_cols, " 个字段"),
        meta = "类型数量会随变量元数据调整实时刷新",
        tone = "warning",
        chips = c(
          paste0("数值 <strong>", numeric_count, "</strong>"),
          paste0("分类 <strong>", factor_count, "</strong>"),
          paste0("日期 <strong>", date_count, "</strong>"),
          paste0("文本 <strong>", text_count, "</strong>")
        )
      )
    )
  })
  
  # 动态生成筛选控件
  output$filter_controls <- renderUI({
    req(data_store())
    
    data <- data_store()
    selected_vars <- selected_var_debounced()
    profile_map <- filter_profile_cache()
    
    if (is.null(selected_vars) || length(selected_vars) == 0) return(NULL)
    
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
      profile <- profile_map[[var_name]]
      
      # 创建控件组
      state <- build_filter_ui_state(var_name, raw_var_data, var_type, profile)
      div(
        class = "data-prep-filter-group",
        
        # 变量名和类型显示
        h5(
          if (!identical(var_label, var_name)) {
            paste0(var_name, " [", var_label, "] (", var_type, ")")
          } else {
            paste0(var_name, " (", var_type, ")")
          },
          style = "word-break: break-word;"
        ),
        
        # 空值筛选选项 - 只对非分类变量显示
        if (var_type != "factor") {
          radioButtons(ns(paste0("na_filter_", var_name)),
                      "空值筛选:",
                      choices = c("全部" = "all",
                                 "排除空值" = "exclude",
                                 "仅显示空值" = "only"),
                      selected = state$na_filter,
                      inline = TRUE,
                      width = "100%")
        },
        
        # 根据变量类型生成不同控件
        if (var_type == "numeric") {
          tagList(
            h6("数值范围:", style = "margin: 5px 0; font-size: 11px; color: #666;"),
            fluidRow(
              column(6,
                numericInput(
                  ns(paste0("num_min_", var_name)),
                  "最小值:",
                  value = state$num_min,
                  min = state$range_min,
                  max = state$num_max,
                  step = state$step,
                  width = "100%"
                )
              ),
              column(6,
                numericInput(
                  ns(paste0("num_max_", var_name)),
                  "最大值:",
                  value = state$num_max,
                  min = state$num_min,
                  max = state$range_max,
                  step = state$step,
                  width = "100%"
                )
              )
            )
          )
        } else if (var_type == "factor") {
          label_text <- if (!is.null(profile) && !is.null(profile$factor_total_unique) && profile$factor_total_unique > 100) "分类值 (前100):" else "分类值:"
          tagList(
            h6(label_text, style = "margin: 5px 0; font-size: 11px; color: #666;"),
            selectizeInput(ns(paste0("cat_values_", var_name)),
                           NULL,
                           choices = state$choices_with_na,
                           selected = state$selected_values,
                           multiple = TRUE,
                           options = list(
                             placeholder = "选择值...",
                             maxItems = 30,
                             plugins = list('remove_button'),
                             dropdownParent = "body"
                           ))
          )
        } else if (var_type == "date") {
          tagList(
            h6("日期范围:", style = "margin: 5px 0; font-size: 11px; color: #666;"),
            dateInput(ns(paste0("date_start_", var_name)), "开始:",
                      value = state$date_start,
                      width = "100%"),
            dateInput(ns(paste0("date_end_", var_name)), "结束:",
                      value = state$date_end,
                      width = "100%")
          )
        } else {
          tagList(
            h6("文本搜索:", style = "margin: 5px 0; font-size: 11px; color: #666;"),
            textInput(ns(paste0("text_search_", var_name)),
                     NULL,
                     value = state$text_search,
                     placeholder = "关键词...",
                     width = "100%")
          )
        }
      )
    })
    
    # 将控件包装在div中以实现横向滚动布局
    div(
      class = "filter-controls-container data-prep-filter-shell",
      controls
    )
  })
  
  variable_info_data <- reactive({
    req(data_store())
    base_info <- base_var_info_cache()
    if (nrow(base_info) == 0) {
      return(data.frame())
    }
    data <- data_store()
    label_col <- vapply(base_info$变量名, function(var_name) {
      get_var_label(var_name, data[[var_name]])
    }, character(1))
    current_type_col <- vapply(base_info$变量名, function(var_name) {
      get_effective_var_type(var_name, data[[var_name]])
    }, character(1))
    data.frame(
      变量名 = base_info$变量名,
      Label = label_col,
      自动类型 = base_info$自动类型,
      当前类型 = current_type_col,
      缺失率 = paste0(base_info$缺失率值, "%"),
      唯一值数 = base_info$唯一值数,
      示例值 = base_info$示例值,
      stringsAsFactors = FALSE
    )
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
  filtered_data <- eventReactive(filter_apply_tick(), {
    req(data_store())
    
    withProgress(message = "正在执行数据筛选...", value = 0, {
      data <- data_store()
      selected_vars <- input$selected_var
      filter_start_time <- Sys.time()
      
      # 如果没有选择筛选变量，返回原始数据
      if (is.null(selected_vars) || length(selected_vars) == 0) {
        if (!is.null(input$selected_columns) && length(input$selected_columns) > 0) {
          existing_cols <- intersect(input$selected_columns, names(data))
          if (length(existing_cols) > 0) {
            data <- data %>% select(all_of(existing_cols))
          }
        }
        data <- data %>%
          mutate(行号 = row_number()) %>%
          select(行号, everything())
        incProgress(1, detail = "完成")
        return(data)
      }
      
      step <- 0.8 / max(1, length(selected_vars))
      
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
      incProgress(step, detail = paste0("变量: ", var_name))
    }
      
    # 应用列选择
    if (!is.null(input$selected_columns) && length(input$selected_columns) > 0) {
      existing_cols <- intersect(input$selected_columns, names(data))
      if (length(existing_cols) > 0) {
        data <- data %>% select(all_of(existing_cols))
      }
    }
    
    data <- data %>%
      mutate(行号 = row_number()) %>%
      select(行号, everything())
    
    filter_time <- Sys.time() - filter_start_time
    performance_metrics$filter_time <- filter_time
    incProgress(0.2, detail = "完成")
    metadata_attach_to_data(data, type_overrides = var_type_overrides(), label_overrides = var_label_overrides())
    })
  })
  
  # 为分析模块准备的数据（去除行号列）
  analysis_data <- reactive({
    req(filtered_data())
    data <- filtered_data()
    # 移除行号列（如果存在）
    if ("行号" %in% names(data)) {
      data <- data %>% select(-`行号`)
    }
    metadata_attach_to_data(data, type_overrides = var_type_overrides(), label_overrides = var_label_overrides())
  })
  
  # 渲染数据表
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
    
    # Reactable 配置
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
      # 渲染参数
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

  output$filter_stats_panel <- renderUI({
    req(data_store(), filtered_data())
    original_rows <- nrow(data_store())
    filtered_rows <- nrow(filtered_data())
    ratio <- if (original_rows == 0) 0 else round(filtered_rows / original_rows * 100, 2)
    condition_text <- format_filter_conditions(data_store(), input$selected_var)
    app_card_panel(
      tags$div(tags$strong("筛选结果")),
      tags$div(style = "margin-top: 6px;", paste0("当前保留 ", filtered_rows, " / ", original_rows, " 行，约 ", ratio, "%。")),
      tags$div(style = "margin-top: 8px;", paste0("条件：", condition_text))
    )
  })
  
  # 重置筛选
  observeEvent(input$reset_filters, {
    # 重置所有输入控件
    selected_vars <- input$selected_var
    profile_map <- filter_profile_cache()
    cache <- filter_input_cache()
    if (!is.null(selected_vars)) {
      for (var_name in selected_vars) {
        raw_var_data <- data_store()[[var_name]]
        var_type <- get_effective_var_type(var_name, raw_var_data)
        var_data <- coerce_var_data(raw_var_data, var_type)
        profile <- profile_map[[var_name]]
        
        if (var_type == "numeric") {
          range_vals <- if (!is.null(profile) && !is.null(profile$numeric_range)) profile$numeric_range else safe_numeric_range(var_data)
          
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
          unique_values <- if (!is.null(profile) && !is.null(profile$factor_values)) profile$factor_values else unique(var_data[!is.na(var_data)])
          has_na_values <- if (!is.null(profile) && !is.null(profile$factor_has_na)) isTRUE(profile$factor_has_na) else any(is.na(var_data))
          
          # 使用与选项生成相同的逻辑
          if (!is.null(profile) && !is.null(profile$factor_total_unique) && profile$factor_total_unique > 100) {
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
          final_start <- if (!is.null(profile) && !is.null(profile$date_start)) profile$date_start else Sys.Date()
          final_end <- if (!is.null(profile) && !is.null(profile$date_end)) profile$date_end else Sys.Date()
          
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
        cache[[var_name]] <- NULL
      }
    }
    filter_input_cache(cache)
    filter_apply_tick(filter_apply_tick() + 1)
  })
  
  # 监听数据变化，重置筛选变量选择和列选择
  observeEvent(data_store(), {
    filter_input_cache(list())
    previous_selected_vars(character(0))
    all_choices <- build_column_choices(data_store())
    updateSelectizeInput(session, "selected_var",
                         choices = all_choices,
                         selected = character(0),
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
  
  # 返回供分析模块使用的数据（已去除行号）及来源元信息
  return(list(
    data = analysis_data,
    meta = dataset_meta
  ))
  })
}
