# 数据库管理模块
library(shiny)
library(shinydashboard)
library(dplyr)
library(readxl)
library(haven)
library(vroom)
library(DBI)
library(RPostgres)
library(pool)

database_manager_ui <- function(id) {
  ns <- NS(id)
  tagList(
    app_card_dependencies(),
    tags$head(
      tags$style(HTML("
        .db-main-row {
          display: flex;
          gap: 14px;
          align-items: stretch;
        }
        .db-main-row > .col-sm-3,
        .db-main-row > .col-sm-9 {
          display: flex;
          flex-direction: column;
        }
        .db-panel {
          flex: 1;
          display: flex;
          flex-direction: column;
          background: #fff;
          border: 1px solid #e7edf4;
          border-radius: 10px;
          overflow: hidden;
        }
        /* 修正 tabBox 在 flex 容器内宽度塌缩 */
        .db-panel-body .tab-content {
          width: 100%;
        }
        .db-panel-body .shiny-input-container {
          width: 100%;
        }
        .db-panel-header {
          padding: 12px 16px 10px;
          border-bottom: 1px solid #edf2f7;
          background: #fafbfc;
        }
        .db-panel-header h4 {
          margin: 0 0 2px;
          font-size: 15px;
          font-weight: 600;
          color: #243447;
        }
        .db-panel-header .subtitle {
          font-size: 12px;
          color: #7b8794;
        }
        .db-panel-body {
          flex: 1;
          overflow-y: auto;
          padding: 12px 16px;
        }
        /* 顶部工具栏：扁平 inline */
        .db-toolbar {
          display: flex;
          align-items: center;
          gap: 8px;
          flex-wrap: wrap;
          margin-bottom: 10px;
        }
        .db-toolbar .form-group {
          margin-bottom: 0;
        }
        .db-toolbar .form-control {
          height: 32px;
          font-size: 13px;
          padding: 4px 10px;
        }
        .db-toolbar .btn {
          height: 32px;
          font-size: 12px;
          padding: 4px 12px;
          white-space: nowrap;
        }
        .db-toolbar .selectize-control {
          min-width: 160px;
        }
        /* 新建空间表单（可折叠） */
        .db-create-ws {
          display: flex;
          align-items: center;
          gap: 6px;
          margin-bottom: 10px;
          padding: 8px 10px;
          background: #f0f6ff;
          border-radius: 6px;
        }
        .db-create-ws .form-group {
          margin-bottom: 0;
          flex: 1;
        }
        .db-create-ws .form-control {
          height: 30px;
          font-size: 13px;
        }
        /* 导航树 */
        .db-nav-tree {
          flex: 1;
          overflow-y: auto;
          margin: 6px 0;
          min-height: 0;
        }
        .db-nav-tree ul {
          list-style: none;
          margin: 0;
          padding-left: 18px;
        }
        .db-nav-tree li {
          margin: 3px 0;
        }
        .db-nav-tree details > summary {
          cursor: pointer;
          outline: none;
        }
        .db-nav-item {
          display: inline-block;
          padding: 3px 8px;
          border-radius: 4px;
          cursor: pointer;
          font-size: 13px;
          color: #1f2d3d;
          text-decoration: none;
          transition: background 0.15s;
          border-left: 3px solid transparent;
        }
        .db-nav-item:hover {
          background: #e8f0fe;
        }
        .db-nav-item.active {
          background: #e8f0fe;
          border-left-color: #4285f4;
          font-weight: 600;
        }
        .db-nav-item .fa {
          margin-right: 4px;
          color: #7b8794;
        }
        /* 底部资源管理栏 */
        .db-resource-bar {
          border-top: 1px solid #edf2f7;
          padding: 10px 16px;
          background: #fafbfc;
        }
        .db-resource-bar .form-group {
          margin-bottom: 6px;
        }
        .db-resource-bar .form-control {
          height: 30px;
          font-size: 13px;
        }
        .db-resource-row {
          display: flex;
          gap: 6px;
          align-items: center;
        }
        .db-resource-row .form-group {
          flex: 1;
          margin-bottom: 0;
        }
        .db-resource-row .btn {
          height: 30px;
          font-size: 12px;
          padding: 4px 10px;
          white-space: nowrap;
        }
        /* 上下文摘要 */
        .db-context-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
          gap: 8px;
          margin-bottom: 10px;
        }
        .db-context-item {
          padding: 8px 10px;
          border-radius: 6px;
          background: #f7f9fc;
          border: 1px solid #e5eef5;
        }
        .db-context-label {
          display: block;
          font-size: 11px;
          color: #7b8794;
          margin-bottom: 2px;
        }
        .db-context-value {
          display: block;
          font-size: 13px;
          font-weight: 600;
          color: #1f2d3d;
        }
        /* 统计条 */
        .db-stat-bar {
          display: grid;
          grid-template-columns: repeat(4, 1fr);
          gap: 10px;
          margin-bottom: 10px;
        }
        /* 工具栏内 selectInput 紧凑化 */
        .db-toolbar .selectize-control {
          min-width: 0;
        }
        .db-toolbar .form-group {
          margin-bottom: 4px;
        }
        /* 上传区布局 */
        .db-upload-row {
          margin-bottom: 12px;
        }
        /* 锁定态 */
        .db-lock-actions {
          margin-top: 14px;
        }
      "))
    ),
    fluidRow(
      app_card_box(
        width = 12,
        title = "数据空间管理",
        subtitle = "浏览结构、管理目录与上传数据",
        tone = "primary",
        status = "primary",
        solidHeader = FALSE,
        uiOutput(ns("db_context_summary"))
      )
    ),
    uiOutput(ns("db_gate_content"))
  )
}

database_manager_server <- function(id, pg_pool = NULL, current_user = NULL) {
  moduleServer(id, function(input, output, session) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
  pool <- registry_init_pool(pg_pool)

  storage_root <- normalizePath(
    Sys.getenv("STORAGE_ROOT", "data_storage"),
    winslash = "/",
    mustWork = FALSE
  )
  dir.create(storage_root, recursive = TRUE, showWarnings = FALSE)

  server_selected_path <- reactiveVal("")
  if (requireNamespace("shinyFiles", quietly = TRUE)) {
    if (.Platform$OS.type == "windows") {
      volumes <- c(Home = normalizePath("~", winslash = "/", mustWork = FALSE))
      windows_drives <- tryCatch(shinyFiles::getVolumes()(), error = function(e) c("C:" = "C:", "D:" = "D:"))
      volumes <- c(volumes, windows_drives)
    } else {
      volumes <- c(Home = path.expand("~"), Root = "/")
    }
    shinyFiles::shinyDirChoose(input, "server_dir_choose", roots = volumes, session = session)
    observe({
      path <- shinyFiles::parseDirPath(volumes, input$server_dir_choose)
      if (length(path) > 0 && nzchar(path)) {
        server_selected_path(path)
        output$selected_server_path <- renderText(path)
      }
    })
  }

  registry_version <- reactiveVal(as.numeric(Sys.time()))
  root_folder_token <- "__ROOT__"
  supported_ext <- data_io_get_supported_extensions()

  db_access_state <- reactiveVal("no_user")
  observe({
    user <- if (is.null(current_user)) NULL else current_user()
    if (is.null(user)) {
      new_state <- "no_user"
    } else if (has_database_access()) {
      new_state <- "access"
    } else {
      new_state <- "locked"
    }
    if (!identical(isolate(db_access_state()), new_state)) {
      db_access_state(new_state)
    }
  })
  
  normalize_store_folder_id <- function(folder_id) {
    if (is.null(folder_id) || folder_id == "" || folder_id == root_folder_token) {
      return("")
    }
    folder_id
  }
  
  get_current_user <- function() {
    if (is.null(current_user)) {
      return(NULL)
    }
    isolate(current_user())
  }

  is_current_admin <- function() {
    isTRUE(get_current_user()$is_admin)
  }

  has_database_access <- function() {
    user <- get_current_user()
    if (is.null(user)) return(FALSE)
    
    # 获取最新用户信息确保权限状态最新
    fresh_user <- tryCatch(
      auth_get_user_by_id(pool, user$id),
      error = function(e) data.frame()
    )
    
    if (nrow(fresh_user) > 0) {
      return(isTRUE(fresh_user$is_admin[[1]]) || isTRUE(fresh_user$db_access_enabled[[1]]))
    }
    
    # 后备检查
    isTRUE(user$is_admin) || isTRUE(user$db_access_enabled)
  }

  require_logged_in <- function() {
    if (!is.null(get_current_user())) {
      return(TRUE)
    }
    showNotification("请先登录后再使用数据库管理功能", type = "warning")
    FALSE
  }

  require_admin <- function() {
    if (!require_logged_in()) {
      return(FALSE)
    }
    if (is_current_admin()) {
      return(TRUE)
    }
    showNotification("该功能仅系统管理员可用", type = "error")
    FALSE
  }

  require_database_access <- function(show_feedback = TRUE) {
    if (!require_logged_in()) {
      return(FALSE)
    }
    if (has_database_access()) {
      return(TRUE)
    }
    if (isTRUE(show_feedback)) {
      showNotification("数据库管理功能尚未开放，请联系系统管理员授权", type = "warning")
    }
    FALSE
  }

  require_workspace_access <- function(workspace_id) {
    if (!require_database_access()) {
      return(FALSE)
    }
    user <- get_current_user()
    if (is.null(user)) {
      showNotification("请先登录", type = "warning")
      return(FALSE)
    }
    if (auth_user_can_access_workspace(pool, user$id, isTRUE(user$is_admin), workspace_id)) {
      return(TRUE)
    }
    showNotification("当前账号无权访问该数据空间", type = "error")
    FALSE
  }

  require_workspace_manage <- function(workspace_id) {
    if (!require_database_access()) {
      return(FALSE)
    }
    user <- get_current_user()
    if (is.null(user)) {
      showNotification("请先登录", type = "warning")
      return(FALSE)
    }
    if (service_can_manage_workspace(pool, workspace_id, user)) {
      return(TRUE)
    }
    showNotification("当前账号无权管理该数据空间", type = "error")
    FALSE
  }

  load_registry <- function() {
    tryCatch({
      user <- get_current_user()
      if (is.null(user)) {
        return(auth_empty_registry())
      }
      service_registry_load(pool, user = user)
    }, error = function(e) {
      warning(paste("Database load failed:", e$message))
      auth_empty_registry()
    })
  }
  
  remove_dataset_files <- function(ds_rows) {
    if (nrow(ds_rows) == 0) {
      return(invisible(NULL))
    }
    paths <- unique(ds_rows$data_path)
    paths <- paths[nzchar(paths)]
    for (p in paths) {
      tryCatch(storage_delete_dataset(p), error = function(e) NULL)
    }
  }
  
  save_dataset_to_db <- function(workspace_id, folder_id, dataset_name, source_file_name, source_file_path, csv_encoding = "UTF-8") {
    folder_id_store <- normalize_store_folder_id(folder_id)

    # 检查重名
    check_sql <- "SELECT id FROM datasets WHERE workspace_id = $1 AND (folder_id = $2 OR ($2 = '' AND folder_id IS NULL) OR ($2 = '' AND folder_id = '')) AND name = $3"
    existing <- dbGetQuery(pool, check_sql, params = list(workspace_id, folder_id_store, dataset_name))

    if (nrow(existing) > 0) {
      return(list(success = FALSE, message = "同一目录下数据集名称已存在", dataset_id = NULL))
    }

    read_error <- NULL
    data <- tryCatch(data_read_file(source_file_path, csv_encoding = csv_encoding), error = function(e) {
      read_error <<- conditionMessage(e)
      NULL
    })
    if (is.null(data) || !is.data.frame(data)) {
      reason <- if (!is.null(read_error)) paste0(" - ", read_error) else ""
      return(list(success = FALSE, message = paste0("读取失败: ", source_file_name, reason), dataset_id = NULL))
    }
    
    dataset_id <- paste0("ds_", as.integer(as.numeric(Sys.time())), "_", sample(1000:9999, 1))
    data_file <- tryCatch(
      storage_save_dataset(
        data = data,
        workspace_id = workspace_id,
        folder_id = folder_id_store,
        dataset_id = dataset_id,
        storage_root = storage_root
      ),
      error = function(e) NULL
    )
    if (is.null(data_file) || !nzchar(data_file)) {
      return(list(success = FALSE, message = "数据保存失败", dataset_id = NULL))
    }
    
    # 插入数据库
    insert_sql <- "INSERT INTO datasets (id, workspace_id, folder_id, name, file_name, data_path, nrow, ncol, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())"
    tryCatch({
      dbExecute(pool, insert_sql, params = list(
        dataset_id,
        workspace_id,
        if(folder_id_store == "") NA else folder_id_store,
        dataset_name,
        source_file_name,
        data_file,
        nrow(data),
        ncol(data)
      ))
      list(success = TRUE, message = "ok", dataset_id = dataset_id)
    }, error = function(e) {
      tryCatch(storage_delete_dataset(data_file), error = function(e2) NULL)
      warning("数据库写入失败，已清理 RDS 文件: ", data_file, " 错误: ", conditionMessage(e))
      list(success = FALSE, message = "数据集保存失败，请稍后重试", dataset_id = NULL)
    })
  }
  
  refresh_workspace_choices <- function(selected = NULL) {
    reg <- load_registry()
    ws <- reg$workspaces
    ws_choices <- if (nrow(ws) == 0) character(0) else setNames(ws$id, ws$name)
    ws_ids <- ws$id %||% character(0)
    if (!nzchar(selected %||% "") || !(selected %in% ws_ids)) {
      selected <- if (length(ws_ids) > 0) ws_ids[[1]] else ""
    }
    updateSelectInput(session, "workspace_select", choices = ws_choices, selected = selected)
    selected
  }
  
  refresh_folder_choices <- function(workspace_id = "", selected = root_folder_token) {
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
    folder_ids <- unname(fd_choices)
    if (!nzchar(selected %||% "") || !(selected %in% folder_ids)) {
      selected <- root_folder_token
    }
    updateSelectInput(session, "folder_select", choices = fd_choices, selected = selected)
    selected
  }
  
  refresh_dataset_choices <- function(workspace_id = "", folder_id = root_folder_token, selected = NULL) {
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
        label <- paste0(ds_current$name, " (", ds_current$nrow, "x", ds_current$ncol, ")")
        ds_choices <- setNames(ds_current$id, label)
      }
    }
    dataset_ids <- unname(ds_choices)
    if (!nzchar(selected %||% "") || !(selected %in% dataset_ids)) {
      selected <- if (length(dataset_ids) > 0) dataset_ids[[1]] else ""
    }
    updateSelectInput(session, "dataset_select", choices = ds_choices, selected = selected)
    selected
  }

  output$db_gate_content <- renderUI({
    state <- db_access_state()
    if (state == "no_user") {
      return(NULL)
    }
    if (state == "locked") {
      return(
        fluidRow(
          app_card_box(
            width = 12,
            title = "数据库管理已锁定",
            subtitle = "当前账号尚未开通数据库管理功能，请联系管理员开通",
            tone = "warning",
            status = "warning",
            solidHeader = FALSE,
            app_card_panel(
              div("当前账号尚未开放数据库管理功能。请由系统管理员在“系统管理 > 账号状态管理”中为该账号开放数据库管理权限，开放后即可创建、整理和导入数据空间。"),
              div("在未开通该权限时，你仍可前往“数据准备”页临时上传单个文件用于当前会话分析；该数据不会写入持久化数据空间。"),
              div(
                class = "db-lock-actions",
                tags$button(
                  type = "button",
                  class = "btn btn-default",
                  onclick = "$(\"li[data-value='data_prep'] a\").trigger('click');",
                  "前往数据准备页"
                )
              )
            )
          )
        )
      )
    }
    reg <- load_registry()
    workspace_df <- reg$workspaces
    workspace_choices <- if (nrow(workspace_df) == 0) character(0) else setNames(workspace_df$id, workspace_df$name)
    selected_workspace <- isolate(input$workspace_select %||% "")
    workspace_ids <- workspace_df$id %||% character(0)
    if (!nzchar(selected_workspace) || !(selected_workspace %in% workspace_ids)) {
      selected_workspace <- if (length(workspace_ids) > 0) workspace_ids[[1]] else ""
    }
    folder_choices <- c("根目录" = root_folder_token)
    folder_df <- reg$folders
    if (nzchar(selected_workspace) && nrow(folder_df) > 0) {
      folder_current <- folder_df[folder_df$workspace_id == selected_workspace, , drop = FALSE]
      if (nrow(folder_current) > 0) {
        folder_choices <- c(folder_choices, setNames(folder_current$id, folder_current$name))
      }
    }
    selected_folder <- isolate(input$folder_select %||% root_folder_token)
    if (!(selected_folder %in% unname(folder_choices))) {
      selected_folder <- root_folder_token
    }
    dataset_choices <- character(0)
    dataset_df <- reg$datasets
    if (nzchar(selected_workspace) && nrow(dataset_df) > 0) {
      if (identical(selected_folder, root_folder_token)) {
        dataset_current <- dataset_df[dataset_df$workspace_id == selected_workspace & (is.na(dataset_df$folder_id) | dataset_df$folder_id == ""), , drop = FALSE]
      } else {
        dataset_current <- dataset_df[dataset_df$workspace_id == selected_workspace & dataset_df$folder_id == selected_folder, , drop = FALSE]
      }
      if (nrow(dataset_current) > 0) {
        dataset_choices <- setNames(dataset_current$id, dataset_current$name)
      }
    }
    selected_dataset <- isolate(input$dataset_select %||% "")
    if (!nzchar(selected_dataset) || !(selected_dataset %in% unname(dataset_choices))) {
      selected_dataset <- if (length(dataset_choices) > 0) unname(dataset_choices)[[1]] else ""
    }
    div(
      class = "db-main-row",
      column(
        width = 3,
        div(
          class = "db-panel",
          div(
            class = "db-panel-header",
            h4(icon("database"), "数据空间"),
            div(class = "subtitle", "浏览结构、管理目录与数据集")
          ),
          div(
            class = "db-panel-body",
            div(
              class = "db-toolbar",
              div(style = "flex: 1;", selectInput(session$ns("workspace_select"), NULL, choices = workspace_choices, selected = selected_workspace)),
              textInput(session$ns("workspace_name"), NULL, placeholder = "新空间名称"),
              actionButton(session$ns("create_workspace"), NULL, icon = icon("plus"), class = "btn-primary btn-sm", title = "新建空间"),
              actionButton(session$ns("delete_workspace"), NULL, icon = icon("trash"), class = "btn-danger btn-sm", title = "删除空间")
            ),
            div(
              class = "db-toolbar",
              div(style = "flex: 1;", selectInput(session$ns("folder_select"), "目录", choices = folder_choices, selected = selected_folder)),
              div(style = "flex: 1;", selectInput(session$ns("dataset_select"), "数据集", choices = dataset_choices, selected = selected_dataset))
            ),
            div(
              class = "db-toolbar",
              textInput(session$ns("folder_name"), NULL, placeholder = "新目录名称"),
              actionButton(session$ns("create_folder"), NULL, icon = icon("folder-plus"), class = "btn-info btn-sm", title = "创建目录"),
              actionButton(session$ns("delete_folder"), NULL, icon = icon("folder-minus"), class = "btn-warning btn-sm", title = "删除目录"),
              actionButton(session$ns("delete_dataset"), NULL, icon = icon("trash-alt"), class = "btn-danger btn-sm", title = "删除数据集")
            ),
            div(class = "db-nav-tree", uiOutput(session$ns("nav_tree")))
          )
        )
      ),
      column(
        width = 9,
        div(
          class = "db-panel",
          div(
            class = "db-panel-header",
            h4(icon("cloud-upload"), "上传与导入"),
            div(class = "subtitle", "选择文件上传到当前目录")
          ),
          div(
            class = "db-panel-body",
            tabBox(
              width = 12,
              id = session$ns("upload_tabs"),
              title = NULL,
              tabPanel(
                "单文件上传",
                div(class = "db-upload-row",
                  fluidRow(
                    column(3,
                      selectInput(session$ns("csv_encoding"), "CSV 编码",
                        choices = c("UTF-8" = "UTF-8", "GBK" = "GBK"), selected = "UTF-8", width = "100%")
                    ),
                    column(9,
                      fileInput(session$ns("file"), "选择数据文件",
                        accept = c(".csv", ".xlsx", ".xls", ".sas7bdat", ".sav", ".dta", ".por"),
                        buttonLabel = "浏览", placeholder = "CSV/Excel/SAS/SPSS", multiple = FALSE)
                    )
                  ),
                  actionButton(session$ns("save_dataset"), "上传并保存到当前目录", class = "btn-success", width = "100%")
                )
              ),
              tabPanel(
                "批量导入",
                div(class = "db-upload-row",
                  fluidRow(
                    column(3,
                      selectInput(session$ns("csv_encoding_batch"), "CSV 编码",
                        choices = c("UTF-8" = "UTF-8", "GBK" = "GBK"), selected = "UTF-8", width = "100%")
                    ),
                    column(9,
                      fileInput(session$ns("batch_files"), "选择多个数据文件",
                        accept = c(".csv", ".xlsx", ".xls", ".sas7bdat", ".sav", ".dta", ".por"),
                        buttonLabel = "浏览", placeholder = "支持多选，单文件 ≤100MB，总计 ≤2GB", multiple = TRUE)
                    )
                  ),
                  actionButton(session$ns("save_batch_datasets"), "批量保存到当前目录", class = "btn-primary", width = "100%")
                )
              ),
              tabPanel(
                "服务器导入",
                uiOutput(session$ns("server_import_section"))
              )
            )
          )
        )
      )
    )
  })
  
  output$server_import_section <- renderUI({
    user <- get_current_user()
    if (is.null(user)) {
      return(tags$small("请先登录后再使用数据库管理功能。"))
    }
    if (!isTRUE(user$is_admin)) {
      return(tags$small("服务器目录导入仅系统管理员可用。"))
    }
    if (requireNamespace("shinyFiles", quietly = TRUE)) {
      tagList(
        shinyFiles::shinyDirButton(session$ns("server_dir_choose"),
          label = "浏览服务器目录",
          title = "选择要导入的服务器文件夹",
          buttonType = "default", class = "btn-default", width = "100%"),
        verbatimTextOutput(session$ns("selected_server_path")),
        textInput(session$ns("workspace_name_import"), "数据空间名称（可选）", placeholder = "留空则自动使用文件夹名", width = "100%"),
        tags$small("浏览选择部署机器上的文件夹，系统将自动创建数据空间并导入所有支持的数据文件。仅对系统管理员开放。"),
        actionButton(session$ns("import_workspace_path"), "导入文件夹为数据空间", class = "btn-info", width = "100%")
      )
    } else {
      tagList(
        textInput(session$ns("workspace_path"), "从服务器目录导入数据空间", placeholder = "请输入服务器或容器可见的绝对路径"),
        tags$small("当前仅支持导入部署机器可见目录，不支持直接读取浏览器所在电脑的本地文件夹。"),
        tags$small("该入口当前仅面向系统管理员开放。"),
        actionButton(session$ns("import_workspace_path"), "导入文件夹为数据空间", class = "btn-info", width = "100%")
      )
    }
  })

  refresh_workspace_choices("")
  refresh_folder_choices("", root_folder_token)
  refresh_dataset_choices("", root_folder_token, "")

  observe({
    state <- db_access_state()
    registry_version()
    if (state != "access") {
      updateSelectInput(session, "workspace_select", choices = character(0), selected = "")
      refresh_folder_choices("", root_folder_token)
      refresh_dataset_choices("", root_folder_token, "")
      return(invisible(NULL))
    }
    selected_workspace <- isolate(input$workspace_select %||% "")
    selected_folder <- isolate(input$folder_select %||% root_folder_token)
    selected_dataset <- isolate(input$dataset_select %||% "")
    selected_workspace <- refresh_workspace_choices(selected_workspace)
    selected_folder <- refresh_folder_choices(selected_workspace, selected_folder)
    refresh_dataset_choices(selected_workspace, selected_folder, selected_dataset)
  })

  observeEvent(input$workspace_select, {
    req(has_database_access())
    selected_workspace <- input$workspace_select %||% ""
    selected_folder <- refresh_folder_choices(selected_workspace, isolate(input$folder_select %||% root_folder_token))
    refresh_dataset_choices(selected_workspace, selected_folder, isolate(input$dataset_select %||% ""))
  }, ignoreInit = TRUE)

  observeEvent(input$folder_select, {
    req(has_database_access())
    refresh_dataset_choices(input$workspace_select %||% "", input$folder_select %||% root_folder_token, isolate(input$dataset_select %||% ""))
  }, ignoreInit = TRUE)

  output$db_context_summary <- renderUI({
    registry_version()
    if (!has_database_access()) {
      return(NULL)
    }
    reg <- load_registry()
    selected_workspace <- input$workspace_select %||% ""
    selected_folder <- input$folder_select %||% root_folder_token
    selected_dataset <- input$dataset_select %||% ""
    workspace_label <- "未选择"
    if (nzchar(selected_workspace) && nrow(reg$workspaces) > 0) {
      workspace_match <- reg$workspaces[reg$workspaces$id == selected_workspace, , drop = FALSE]
      if (nrow(workspace_match) > 0) {
        workspace_label <- workspace_match$name[[1]] %||% selected_workspace
      }
    }
    folder_label <- "根目录"
    if (nzchar(selected_folder) && !identical(selected_folder, root_folder_token) && nrow(reg$folders) > 0) {
      folder_match <- reg$folders[reg$folders$id == selected_folder, , drop = FALSE]
      if (nrow(folder_match) > 0) {
        folder_label <- folder_match$name[[1]] %||% selected_folder
      }
    }
    dataset_label <- "未选择"
    if (nzchar(selected_dataset) && nrow(reg$datasets) > 0) {
      dataset_match <- reg$datasets[reg$datasets$id == selected_dataset, , drop = FALSE]
      if (nrow(dataset_match) > 0) {
        dataset_label <- dataset_match$name[[1]] %||% selected_dataset
      }
    }
    manage_label <- "当前仅读写权限未知"
    user <- get_current_user()
    if (!is.null(user) && nzchar(selected_workspace)) {
      manage_label <- if (service_can_manage_workspace(pool, selected_workspace, user)) "可管理当前数据空间" else "仅可访问当前数据空间"
    }
    div(
      class = "app-card__panel",
      div(
        class = "db-context-grid",
        div(
          class = "db-context-item",
          span(class = "db-context-label", "当前数据空间"),
          span(class = "db-context-value", workspace_label)
        ),
        div(
          class = "db-context-item",
          span(class = "db-context-label", "当前目录"),
          span(class = "db-context-value", folder_label)
        ),
        div(
          class = "db-context-item",
          span(class = "db-context-label", "当前数据集"),
          span(class = "db-context-value", dataset_label)
        ),
        div(
          class = "db-context-item",
          span(class = "db-context-label", "当前权限状态"),
          span(class = "db-context-value", manage_label)
        )
      )
    )
  })
  
  output$db_overview_cards <- renderUI({
    registry_version()
    req(has_database_access())
    reg <- load_registry()
    ws_count <- nrow(reg$workspaces)
    fd_count <- nrow(reg$folders)
    ds_count <- nrow(reg$datasets)
    total_rows <- if (ds_count == 0) 0 else sum(reg$datasets$nrow, na.rm = TRUE)
    tags$div(
      class = "app-stat-grid",
      app_stat_card("数据空间数", ws_count, meta = "当前可见的数据空间总数", tone = "primary"),
      app_stat_card("文件夹数", fd_count, meta = "当前已登记目录总数", tone = "info"),
      app_stat_card("数据集数", ds_count, meta = "当前已登记数据集总数", tone = "success"),
      app_stat_card("累计数据行数", format(total_rows, big.mark = ","), meta = "按数据集行数汇总", tone = "warning")
    )
  })
  
  output$nav_tree <- renderUI({
    registry_version()
    req(has_database_access())
    reg <- load_registry()
    ws <- reg$workspaces
    fd <- reg$folders
    ds <- reg$datasets
    if (nrow(ws) == 0) {
      return(div(span(style = "color: #7b8794; font-size: 13px;", "暂无数据空间")))
    }
    selected_folder <- isolate(input$folder_select %||% root_folder_token)
    selected_dataset <- isolate(input$dataset_select %||% "")

    ns <- session$ns
    click_js <- function(type, id) {
      paste0("Shiny.setInputValue('", ns("nav_click"), "', {type: '", type, "', id: '", id, "'}, {priority: 'event'})")
    }

    workspace_nodes <- lapply(seq_len(nrow(ws)), function(i) {
      ws_row <- ws[i, , drop = FALSE]
      ws_id <- ws_row$id
      ws_name <- ws_row$name

      fd_current <- fd[fd$workspace_id == ws_id, , drop = FALSE]
      ds_current <- ds[ds$workspace_id == ws_id, , drop = FALSE]
      root_ds <- ds_current[is.na(ds_current$folder_id) | ds_current$folder_id == "", , drop = FALSE]

      folder_nodes <- lapply(seq_len(nrow(fd_current)), function(j) {
        fd_row <- fd_current[j, , drop = FALSE]
        fd_id <- fd_row$id
        fd_name <- fd_row$name
        ds_folder <- ds_current[!is.na(ds_current$folder_id) & ds_current$folder_id == fd_id, , drop = FALSE]
        is_active_folder <- identical(selected_folder, fd_id)

        ds_nodes <- lapply(seq_len(nrow(ds_folder)), function(k) {
          ds_row <- ds_folder[k, , drop = FALSE]
          is_active_ds <- identical(selected_dataset, ds_row$id)
          tags$li(
            tags$a(
              class = paste0("db-nav-item", if (is_active_ds) " active" else ""),
              onclick = click_js("dataset", ds_row$id),
              icon("table"), " ",
              ds_row$name, " (", ds_row$nrow, "x", ds_row$ncol, ")"
            )
          )
        })
        tags$li(
          tags$details(
            open = "open",
            tags$summary(
              tags$a(
                class = paste0("db-nav-item", if (is_active_folder) " active" else ""),
                onclick = click_js("folder", fd_id),
                icon("folder-open"), " ",
                fd_name, " [", nrow(ds_folder), "]"
              )
            ),
            tags$ul(ds_nodes)
          )
        )
      })

      is_root_active <- identical(selected_folder, root_folder_token) && ws_id == isolate(input$workspace_select %||% "")
      root_nodes <- lapply(seq_len(nrow(root_ds)), function(k) {
        ds_row <- root_ds[k, , drop = FALSE]
        is_active_ds <- identical(selected_dataset, ds_row$id)
        tags$li(
          tags$a(
            class = paste0("db-nav-item", if (is_active_ds) " active" else ""),
            onclick = click_js("dataset", ds_row$id),
            icon("table"), " ",
            ds_row$name, " (", ds_row$nrow, "x", ds_row$ncol, ")"
          )
        )
      })

      tags$li(
        tags$details(
          open = "open",
          tags$summary(
            span(class = "node-label",
                 icon("database"), " ",
                 ws_name, " [文件夹:", nrow(fd_current), " | 数据集:", nrow(ds_current), "]")
          ),
          tags$ul(
            tags$li(
              tags$details(
                open = "open",
                tags$summary(
                  tags$a(
                    class = paste0("db-nav-item", if (is_root_active) " active" else ""),
                    onclick = click_js("folder", root_folder_token),
                    icon("folder"), " 根目录 [", nrow(root_ds), "]"
                  )
                ),
                tags$ul(root_nodes)
              )
            ),
            folder_nodes
          )
        )
      )
    })
    tags$ul(workspace_nodes)
  })

  observeEvent(input$nav_click, {
    req(has_database_access())
    click_type <- input$nav_click$type
    click_id <- input$nav_click$id
    if (is.null(click_type) || is.null(click_id)) return()

    workspace_id <- isolate(input$workspace_select %||% "")
    if (!nzchar(workspace_id)) return()

    if (click_type == "folder") {
      updateSelectInput(session, "folder_select", selected = click_id)
      refresh_dataset_choices(workspace_id, click_id, "")
    } else if (click_type == "dataset") {
      reg <- load_registry()
      ds_match <- reg$datasets[reg$datasets$id == click_id, , drop = FALSE]
      if (nrow(ds_match) > 0) {
        folder_id <- ds_match$folder_id[[1]]
        folder_id <- if (is.na(folder_id) || folder_id == "") root_folder_token else folder_id
        updateSelectInput(session, "folder_select", selected = folder_id)
        refresh_dataset_choices(workspace_id, folder_id, click_id)
      }
    }
  })
  
  observeEvent(input$create_workspace, {
    if (!require_database_access()) {
      return()
    }
    workspace_name <- input$workspace_name
    user <- get_current_user()

    tryCatch({
      workspace_result <- service_create_workspace(pool, workspace_name, user$id)
      registry_version(as.numeric(Sys.time()))
      refresh_workspace_choices()
      updateSelectInput(session, "workspace_select", selected = workspace_result$id)
      updateTextInput(session, "workspace_name", value = "")
      showNotification("数据空间创建成功", type = "message")
    }, error = function(e) {
      warning("创建数据空间失败: ", conditionMessage(e))
      showNotification("创建失败，请稍后重试", type = "error")
    })
  })
  
  observeEvent(input$delete_workspace, {
    workspace_id <- input$workspace_select
    if (is.null(workspace_id) || workspace_id == "") {
      showNotification("请先选择要删除的数据空间", type = "warning")
      return()
    }
    if (!require_workspace_manage(workspace_id)) {
      return()
    }
    showModal(modalDialog(
      title = "确认删除数据空间",
      "确定要删除该数据空间及其所有目录和数据集吗？此操作不可撤销。",
      footer = tagList(
        modalButton("取消"),
        actionButton(session$ns("confirm_delete_workspace"), "确认删除", class = "btn-danger")
      )
    ))
  })

  observeEvent(input$confirm_delete_workspace, {
    removeModal()
    workspace_id <- isolate(input$workspace_select)
    ds_to_remove <- dbGetQuery(pool, "SELECT data_path FROM datasets WHERE workspace_id = $1", params = list(workspace_id))
    remove_dataset_files(ds_to_remove)

    tryCatch({
      service_delete_workspace(pool, workspace_id, acting_user = get_current_user())

      ws_dir <- file.path(storage_root, workspace_id)
      if (dir.exists(ws_dir)) {
        unlink(ws_dir, recursive = TRUE, force = TRUE)
      }

      registry_version(as.numeric(Sys.time()))
      updateSelectInput(session, "workspace_select", selected = "")
      refresh_workspace_choices()
      refresh_folder_choices("")
      refresh_dataset_choices("", root_folder_token)
      showNotification("数据空间已删除（含文件夹与数据集）", type = "message")
    }, error = function(e) {
      warning("删除数据空间失败: ", conditionMessage(e))
      showNotification("删除失败，请稍后重试", type = "error")
    })
  })
  
  observeEvent(input$create_folder, {
    if (!require_database_access()) {
      return()
    }
    workspace_id <- input$workspace_select
    folder_name <- trimws(input$folder_name)
    if (is.null(workspace_id) || workspace_id == "") {
      showNotification("请先选择数据空间", type = "warning")
      return()
    }
    if (!nzchar(folder_name)) {
      showNotification("请输入文件夹名称", type = "warning")
      return()
    }
    if (!require_workspace_access(workspace_id)) {
      return()
    }
    
    existing <- dbGetQuery(pool, "SELECT id FROM folders WHERE workspace_id = $1 AND name = $2", params = list(workspace_id, folder_name))
    if (nrow(existing) > 0) {
      showNotification("文件夹名称已存在", type = "warning")
      return()
    }
    
    folder_id <- auth_generate_id("fd")
    
    tryCatch({
      dbExecute(pool, "INSERT INTO folders (id, workspace_id, name, created_at) VALUES ($1, $2, $3, NOW())",
                params = list(folder_id, workspace_id, folder_name))
      registry_version(as.numeric(Sys.time()))
      refresh_folder_choices(workspace_id)
      updateSelectInput(session, "folder_select", selected = folder_id)
      updateTextInput(session, "folder_name", value = "")
      showNotification("文件夹创建成功", type = "message")
    }, error = function(e) {
      warning("创建文件夹失败: ", conditionMessage(e))
      showNotification("创建失败，请稍后重试", type = "error")
    })
  })
  
  observeEvent(input$folder_select, {
    workspace_id <- input$workspace_select
    folder_id <- input$folder_select
    if (is.null(workspace_id) || workspace_id == "") {
      refresh_dataset_choices("", root_folder_token)
      return()
    }
    refresh_dataset_choices(workspace_id, ifelse(is.null(folder_id), root_folder_token, folder_id))
  }, ignoreNULL = FALSE)
  
  observeEvent(input$delete_folder, {
    if (!require_database_access()) {
      return()
    }
    workspace_id <- input$workspace_select
    folder_id <- input$folder_select
    if (is.null(workspace_id) || workspace_id == "") {
      showNotification("请先选择数据空间", type = "warning")
      return()
    }
    if (is.null(folder_id) || folder_id == root_folder_token) {
      showNotification("根目录不能删除，请选择具体文件夹", type = "warning")
      return()
    }
    if (!require_workspace_access(workspace_id)) {
      return()
    }
    showModal(modalDialog(
      title = "确认删除文件夹",
      "确定要删除该文件夹及其所有数据集吗？此操作不可撤销。",
      footer = tagList(
        modalButton("取消"),
        actionButton(session$ns("confirm_delete_folder"), "确认删除", class = "btn-danger")
      )
    ))
  })

  observeEvent(input$confirm_delete_folder, {
    removeModal()
    workspace_id <- isolate(input$workspace_select)
    folder_id <- isolate(input$folder_select)
    ds_to_remove <- dbGetQuery(pool, "SELECT data_path FROM datasets WHERE workspace_id = $1 AND folder_id = $2", params = list(workspace_id, folder_id))
    remove_dataset_files(ds_to_remove)

    tryCatch({
      dbExecute(pool, "DELETE FROM folders WHERE id = $1 AND workspace_id = $2", params = list(folder_id, workspace_id))

      fd_dir <- file.path(storage_root, workspace_id, folder_id)
      if (dir.exists(fd_dir)) {
        unlink(fd_dir, recursive = TRUE, force = TRUE)
      }

      registry_version(as.numeric(Sys.time()))
      updateSelectInput(session, "folder_select", selected = root_folder_token)
      refresh_folder_choices(workspace_id)
      refresh_dataset_choices(workspace_id, root_folder_token)
      showNotification("文件夹已删除（含该文件夹下数据集）", type = "message")
    }, error = function(e) {
      warning("删除文件夹失败: ", conditionMessage(e))
      showNotification("删除失败，请稍后重试", type = "error")
    })
  })
  
  observeEvent(input$file, {
    req(input$file)
    default_dataset_name <- tools::file_path_sans_ext(input$file$name)
    updateTextInput(session, "dataset_name", value = default_dataset_name)
  })
  
  observeEvent(input$save_dataset, {
    if (!require_database_access()) {
      return()
    }
    if (is.null(input$file)) {
      showNotification("请先选择要上传的文件", type = "warning")
      return()
    }
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
    workspace_id <- input$workspace_select
    if (is.null(workspace_id) || workspace_id == "") {
      showNotification("请先创建并选择数据空间", type = "warning")
      return()
    }
    if (!require_workspace_access(workspace_id)) {
      return()
    }
    folder_id <- ifelse(is.null(input$folder_select), root_folder_token, input$folder_select)
    ds_name <- trimws(input$dataset_name)
    if (!nzchar(ds_name)) {
      ds_name <- tools::file_path_sans_ext(input$file$name)
    }
    
    result <- save_dataset_to_db(
      workspace_id = workspace_id,
      folder_id = folder_id,
      dataset_name = ds_name,
      source_file_name = input$file$name,
      source_file_path = input$file$datapath,
      csv_encoding = input$csv_encoding %||% "UTF-8"
    )
    
    if (!isTRUE(result$success)) {
      showNotification(result$message, type = "warning")
      return()
    }
    
    registry_version(as.numeric(Sys.time()))
    refresh_dataset_choices(workspace_id, folder_id)
    updateSelectInput(session, "dataset_select", selected = result$dataset_id)
    showNotification("数据集已保存成功", type = "message")
  })
  
  observeEvent(input$save_batch_datasets, {
    if (!require_database_access()) {
      return()
    }
    workspace_id <- input$workspace_select
    if (is.null(workspace_id) || workspace_id == "") {
      showNotification("请先创建并选择数据空间", type = "warning")
      return()
    }
    if (!require_workspace_access(workspace_id)) {
      return()
    }
    folder_id <- ifelse(is.null(input$folder_select), root_folder_token, input$folder_select)
    files_df <- input$batch_files
    total_count <- nrow(files_df)
    if (is.null(total_count) || total_count == 0) {
      showNotification("未检测到可上传文件", type = "warning")
      return()
    }
    # 批量上传总大小限制：2GB
    batch_total_bytes <- sum(files_df$size, na.rm = TRUE)
    batch_max_bytes <- 2 * 1024^3
    if (batch_total_bytes > batch_max_bytes) {
      total_mb <- round(batch_total_bytes / 1024^2, 1)
      showNotification(
        paste0("批量文件总大小 ", format(total_mb, big.mark = ","), " MB 超过 2 GB 上限，请分批上传"),
        type = "error", duration = 6
      )
      return()
    }

    success_count <- 0
    fail_count <- 0
    fail_details <- list()
    last_dataset_id <- NULL
    seen_names <- list()

    withProgress(message = "正在批量上传数据集...", value = 0, {
      step <- 1 / max(1, total_count)
      for (i in seq_len(total_count)) {
        src_name <- files_df$name[[i]]
        src_path <- files_df$datapath[[i]]
        ext <- tolower(tools::file_ext(src_name))
        if (!(ext %in% supported_ext)) {
          fail_count <- fail_count + 1
          fail_details[[length(fail_details) + 1]] <- paste0(src_name, ": 不支持的文件格式")
          incProgress(step, detail = paste0("跳过不支持格式: ", src_name))
          next
        }
        base_name <- tools::file_path_sans_ext(src_name)
        if (!is.null(seen_names[[base_name]])) {
          seen_names[[base_name]] <- seen_names[[base_name]] + 1
          ds_name <- paste0(base_name, "_", seen_names[[base_name]])
        } else {
          seen_names[[base_name]] <- 1
          ds_name <- base_name
        }

        result <- save_dataset_to_db(
          workspace_id = workspace_id,
          folder_id = folder_id,
          dataset_name = ds_name,
          source_file_name = src_name,
          source_file_path = src_path,
          csv_encoding = input$csv_encoding_batch %||% "UTF-8"
        )

        if (isTRUE(result$success)) {
          success_count <- success_count + 1
          last_dataset_id <- result$dataset_id
        } else {
          fail_count <- fail_count + 1
          fail_details[[length(fail_details) + 1]] <- paste0(src_name, ": ", result$message)
        }
        incProgress(step, detail = paste0("处理: ", src_name))
      }
    })

    registry_version(as.numeric(Sys.time()))
    if (!is.null(last_dataset_id)) {
      updateSelectInput(session, "dataset_select", selected = last_dataset_id)
    }
    if (fail_count > 0) {
      showNotification(
        paste0("批量上传完成：成功 ", success_count, "，失败 ", fail_count, "\n",
               paste(utils::head(fail_details, 5), collapse = "\n"),
               if (length(fail_details) > 5) paste0("\n...及其他 ", length(fail_details) - 5, " 项") else ""),
        type = "warning", duration = 15
      )
    } else {
      showNotification(paste0("批量上传完成：全部 ", success_count, " 个文件成功"), type = "message")
    }
  })
  
  observeEvent(input$import_workspace_path, {
    if (!require_admin()) {
      return()
    }
    shiny_path <- server_selected_path()
    fallback_path <- trimws(input$workspace_path %||% "")
    path_input <- if (nzchar(shiny_path)) shiny_path else fallback_path
    if (length(path_input) == 0L || !nzchar(path_input)) {
      showNotification("请选择或输入文件夹路径", type = "warning")
      return()
    }
    if (!dir.exists(path_input)) {
      showNotification("文件夹路径不存在", type = "error")
      return()
    }
    workspace_name <- trimws(input$workspace_name_import %||% input$workspace_name)
    if (!nzchar(workspace_name)) {
      workspace_name <- basename(normalizePath(path_input, winslash = "/", mustWork = TRUE))
    }
    
    user <- get_current_user()
    workspace_result <- tryCatch(
      service_create_workspace(pool, workspace_name, user$id),
      error = function(e) {
        warning("导入失败: ", conditionMessage(e))
        showNotification("导入失败，请稍后重试", type = "error")
        NULL
      }
    )
    if (is.null(workspace_result)) {
      return()
    }
    workspace_id <- workspace_result$id
    
    abs_root <- normalizePath(path_input, winslash = "/", mustWork = TRUE)
    all_files <- list.files(abs_root, recursive = TRUE, full.names = TRUE, include.dirs = FALSE)
    
    if (length(all_files) > 0) {
      all_files <- all_files[file.exists(all_files)]
      all_ext <- tolower(tools::file_ext(all_files))
      data_files <- all_files[all_ext %in% supported_ext]
      
      if (length(data_files) > 0) {
        rel_paths <- substring(
          normalizePath(data_files, winslash = "/", mustWork = TRUE),
          nchar(abs_root) + 2
        )
        rel_dirs <- dirname(rel_paths)
        rel_dirs[rel_dirs == "."] <- ""
        unique_dirs <- unique(rel_dirs[rel_dirs != ""])
        dir_map <- list()
        
        if (length(unique_dirs) > 0) {
          for (rel_dir in unique_dirs) {
            folder_id <- auth_generate_id("fd")
            dbExecute(pool, "INSERT INTO folders (id, workspace_id, name, created_at) VALUES ($1, $2, $3, NOW())", 
                      params = list(folder_id, workspace_id, rel_dir))
            dir_map[[rel_dir]] <- folder_id
          }
        }
        
        import_success <- 0
        import_fail <- 0
        
        withProgress(message = "正在导入数据空间结构...", value = 0, {
          step <- 1 / max(1, length(data_files))
          for (i in seq_along(data_files)) {
            file_path <- data_files[[i]]
            file_name <- basename(file_path)
            rel_dir <- rel_dirs[[i]]
            target_folder_id <- if (rel_dir == "") root_folder_token else dir_map[[rel_dir]]
            ds_name <- tools::file_path_sans_ext(file_name)
            
            result <- save_dataset_to_db(
              workspace_id = workspace_id,
              folder_id = target_folder_id,
              dataset_name = ds_name,
              source_file_name = file_name,
              source_file_path = file_path
            )
            
            if (isTRUE(result$success)) {
              import_success <- import_success + 1
            } else {
              import_fail <- import_fail + 1
            }
            incProgress(step, detail = paste0("导入: ", file_name))
          }
        })
        
        registry_version(as.numeric(Sys.time()))
        refresh_workspace_choices()
        updateSelectInput(session, "workspace_select", selected = workspace_id)
        refresh_folder_choices(workspace_id)
        refresh_dataset_choices(workspace_id, root_folder_token)
        updateTextInput(session, "workspace_name", value = "")
        showNotification(paste0("导入完成：成功 ", import_success, "，失败 ", import_fail), type = "message")
        return()
      }
    }
    
    registry_version(as.numeric(Sys.time()))
    refresh_workspace_choices()
    updateSelectInput(session, "workspace_select", selected = workspace_id)
    refresh_folder_choices(workspace_id)
    refresh_dataset_choices(workspace_id, root_folder_token)
    updateTextInput(session, "workspace_name", value = "")
    showNotification("未发现支持的数据文件，已仅创建数据空间", type = "warning")
  })
  
  observeEvent(input$delete_dataset, {
    dataset_id <- input$dataset_select
    if (is.null(dataset_id) || dataset_id == "") {
      showNotification("请先选择数据集", type = "warning")
      return()
    }
    ds <- dbGetQuery(pool, "SELECT id, workspace_id, data_path, file_name FROM datasets WHERE id = $1", params = list(dataset_id))
    if (nrow(ds) == 0) {
      showNotification("数据集不存在", type = "warning")
      return()
    }
    if (!require_workspace_access(ds$workspace_id[[1]])) {
      return()
    }
    showModal(modalDialog(
      title = "确认删除数据集",
      paste0("确定要删除数据集 \"", ds$file_name[[1]], "\" 吗？此操作不可撤销。"),
      footer = tagList(
        modalButton("取消"),
        actionButton(session$ns("confirm_delete_dataset"), "确认删除", class = "btn-danger")
      )
    ))
  })

  observeEvent(input$confirm_delete_dataset, {
    removeModal()
    dataset_id <- isolate(input$dataset_select)
    ds <- dbGetQuery(pool, "SELECT data_path FROM datasets WHERE id = $1", params = list(dataset_id))
    if (nrow(ds) > 0) {
      tryCatch(storage_delete_dataset(ds$data_path[[1]]), error = function(e) NULL)
    }
    dbExecute(pool, "DELETE FROM datasets WHERE id = $1", params = list(dataset_id))

    registry_version(as.numeric(Sys.time()))
    workspace_id <- isolate(input$workspace_select)
    folder_id <- isolate(input$folder_select)
    refresh_dataset_choices(ifelse(is.null(workspace_id), "", workspace_id),
                            ifelse(is.null(folder_id), root_folder_token, folder_id))
    updateSelectInput(session, "dataset_select", selected = "")
    showNotification("数据集已删除", type = "message")
  })
  
  list(
    registry_updated = reactive(registry_version())
  )
  })
}
