# 数据库管理模块
library(shiny)
library(shinydashboard)
library(dplyr)
library(readxl)
library(haven)
library(vroom)

database_manager_ui <- function(id) {
  ns <- NS(id)
  tagList(
    tags$head(
      tags$style(HTML("
        .db-tree {
          background: #fafafa;
          border: 1px solid #e5e5e5;
          border-radius: 6px;
          padding: 10px 14px;
          max-height: 420px;
          overflow-y: auto;
        }
        .db-tree ul {
          list-style: none;
          margin: 0;
          padding-left: 18px;
        }
        .db-tree li {
          margin: 6px 0;
        }
        .db-tree .node-label {
          font-size: 13px;
        }
        .db-tree details > summary {
          cursor: pointer;
          outline: none;
        }
      "))
    ),
    fluidRow(
      box(
        width = 12,
        title = "数据库管理",
        status = "primary",
        solidHeader = TRUE,
        fluidRow(
          column(
            width = 4,
            selectInput(
              ns("workspace_select"),
              "选择数据空间",
              choices = character(0)
            ),
            textInput(ns("workspace_name"), "新建数据空间", placeholder = "请输入数据空间名"),
            fluidRow(
              column(6, actionButton(ns("create_workspace"), "创建空间", class = "btn-primary", width = "100%")),
              column(6, actionButton(ns("delete_workspace"), "删除空间", class = "btn-danger", width = "100%"))
            )
          ),
          column(
            width = 4,
            selectInput(
              ns("folder_select"),
              "选择文件夹",
              choices = c("根目录" = "__ROOT__")
            ),
            textInput(ns("folder_name"), "新建文件夹", placeholder = "请输入文件夹名"),
            fluidRow(
              column(6, actionButton(ns("create_folder"), "创建文件夹", class = "btn-info", width = "100%")),
              column(6, actionButton(ns("delete_folder"), "删除文件夹", class = "btn-warning", width = "100%"))
            )
          ),
          column(
            width = 4,
            selectInput(
              ns("dataset_select"),
              "选择数据集",
              choices = character(0)
            ),
            textInput(ns("dataset_name"), "数据集名称", placeholder = "为空则默认使用上传文件名"),
            fluidRow(
              column(12, actionButton(ns("delete_dataset"), "删除数据集", class = "btn-danger", width = "100%"))
            )
          )
        ),
        br(),
        fileInput(
          ns("file"),
          "上传数据文件 (CSV/Excel/SAS/SPSS)",
          accept = c(".csv", ".xlsx", ".xls", ".sas7bdat", ".sav", ".dta", ".por"),
          buttonLabel = "浏览文件",
          placeholder = "请选择一个文件进行上传",
          multiple = FALSE
        ),
        actionButton(ns("save_dataset"), "上传后保存到当前目录", class = "btn-success", width = "100%"),
        br(),
        br(),
        fileInput(
          ns("batch_files"),
          "批量上传数据文件",
          accept = c(".csv", ".xlsx", ".xls", ".sas7bdat", ".sav", ".dta", ".por"),
          buttonLabel = "选择多个文件",
          placeholder = "请选择多个文件进行批量上传",
          multiple = TRUE
        ),
        actionButton(ns("save_batch_datasets"), "批量保存到当前目录", class = "btn-primary", width = "100%"),
        br(),
        br(),
        textInput(ns("workspace_path"), "从本地文件夹导入数据空间", placeholder = "请输入服务器上的文件夹绝对路径"),
        actionButton(ns("import_workspace_path"), "导入文件夹为数据空间", class = "btn-info", width = "100%")
      )
    ),
    fluidRow(
      box(
        width = 12,
        title = "数据库结构总览",
        status = "info",
        solidHeader = TRUE,
        uiOutput(ns("db_overview_cards")),
        br(),
        uiOutput(ns("db_structure_tree"))
      )
    )
  )
}

database_manager_server <- function(id) {
  moduleServer(id, function(input, output, session) {
  storage_root <- normalizePath("data_storage", winslash = "/", mustWork = FALSE)
  dir.create(storage_root, recursive = TRUE, showWarnings = FALSE)
  registry_path <- file.path(storage_root, "registry.rds")
  registry_version <- reactiveVal(as.numeric(Sys.time()))
  root_folder_token <- "__ROOT__"
  supported_ext <- c("csv", "xlsx", "xls", "sas7bdat", "sav", "dta", "por")
  
  normalize_store_folder_id <- function(folder_id) {
    if (is.null(folder_id) || folder_id == "" || folder_id == root_folder_token) {
      return("")
    }
    folder_id
  }
  
  empty_registry <- function() {
    list(
      workspaces = data.frame(
        id = character(0),
        name = character(0),
        created_at = as.POSIXct(character(0)),
        stringsAsFactors = FALSE
      ),
      folders = data.frame(
        id = character(0),
        workspace_id = character(0),
        name = character(0),
        created_at = as.POSIXct(character(0)),
        stringsAsFactors = FALSE
      ),
      datasets = data.frame(
        id = character(0),
        workspace_id = character(0),
        folder_id = character(0),
        name = character(0),
        file_name = character(0),
        data_path = character(0),
        nrow = numeric(0),
        ncol = numeric(0),
        created_at = as.POSIXct(character(0)),
        stringsAsFactors = FALSE
      )
    )
  }
  
  load_registry <- function() {
    if (!file.exists(registry_path)) {
      reg <- empty_registry()
      saveRDS(reg, registry_path)
      return(reg)
    }
    reg <- tryCatch(readRDS(registry_path), error = function(e) empty_registry())
    required_tables <- c("workspaces", "folders", "datasets")
    for (tbl in required_tables) {
      if (is.null(reg[[tbl]]) || !is.data.frame(reg[[tbl]])) {
        reg[[tbl]] <- empty_registry()[[tbl]]
      }
    }
    reg
  }
  
  save_registry <- function(registry_obj) {
    saveRDS(registry_obj, registry_path)
    registry_version(as.numeric(Sys.time()))
  }
  
  remove_dataset_files <- function(ds_rows) {
    if (nrow(ds_rows) == 0) {
      return(invisible(NULL))
    }
    paths <- unique(ds_rows$data_path)
    paths <- paths[nzchar(paths)]
    for (p in paths) {
      if (file.exists(p)) {
        file.remove(p)
      }
    }
  }
  
  read_data_by_ext <- function(file_path) {
    ext <- tolower(tools::file_ext(file_path))
    if (ext %in% c("xlsx", "xls")) {
      data <- readxl::read_excel(file_path, guess_max = 1000)
    } else if (ext == "csv") {
      data <- vroom::vroom(file_path, progress = FALSE)
    } else if (ext == "sas7bdat") {
      data <- haven::read_sas(file_path, encoding = "UTF-8")
    } else if (ext %in% c("sav", "por")) {
      data <- haven::read_spss(file_path, encoding = "UTF-8")
    } else if (ext == "dta") {
      data <- haven::read_dta(file_path, encoding = "UTF-8")
    } else {
      stop("不支持的文件格式")
    }
    data %>%
      mutate(across(where(haven::is.labelled), ~ haven::as_factor(.x, levels = "labels")))
  }
  
  save_dataset_to_registry <- function(reg, workspace_id, folder_id, dataset_name, source_file_name, source_file_path) {
    folder_id_store <- normalize_store_folder_id(folder_id)
    ds_current <- reg$datasets[reg$datasets$workspace_id == workspace_id, , drop = FALSE]
    same_name <- ds_current$name == dataset_name
    same_folder <- ds_current$folder_id == folder_id_store
    if (any(same_name & same_folder)) {
      return(list(success = FALSE, message = "同一目录下数据集名称已存在", reg = reg, dataset_id = NULL))
    }
    data <- tryCatch(read_data_by_ext(source_file_path), error = function(e) NULL)
    if (is.null(data) || !is.data.frame(data)) {
      return(list(success = FALSE, message = paste0("读取失败: ", source_file_name), reg = reg, dataset_id = NULL))
    }
    dataset_id <- paste0("ds_", as.integer(as.numeric(Sys.time())), "_", sample(1000:9999, 1))
    workspace_dir <- file.path(storage_root, workspace_id)
    if (folder_id_store != "") {
      workspace_dir <- file.path(workspace_dir, folder_id_store)
    }
    dir.create(workspace_dir, recursive = TRUE, showWarnings = FALSE)
    data_file <- file.path(workspace_dir, paste0(dataset_id, ".rds"))
    saveRDS(as.data.frame(data), data_file)
    reg$datasets <- rbind(
      reg$datasets,
      data.frame(
        id = dataset_id,
        workspace_id = workspace_id,
        folder_id = folder_id_store,
        name = dataset_name,
        file_name = source_file_name,
        data_path = data_file,
        nrow = nrow(data),
        ncol = ncol(data),
        created_at = Sys.time(),
        stringsAsFactors = FALSE
      )
    )
    list(success = TRUE, message = "ok", reg = reg, dataset_id = dataset_id)
  }
  
  refresh_workspace_choices <- function() {
    reg <- load_registry()
    ws <- reg$workspaces
    ws_choices <- if (nrow(ws) == 0) character(0) else setNames(ws$id, ws$name)
    updateSelectInput(session, "workspace_select", choices = ws_choices)
  }
  
  refresh_folder_choices <- function(workspace_id = "") {
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
    updateSelectInput(session, "folder_select", choices = fd_choices, selected = root_folder_token)
  }
  
  refresh_dataset_choices <- function(workspace_id = "", folder_id = root_folder_token) {
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
    updateSelectInput(session, "dataset_select", choices = ds_choices)
  }
  
  refresh_workspace_choices()
  refresh_folder_choices("")
  refresh_dataset_choices("", root_folder_token)
  
  output$db_overview_cards <- renderUI({
    registry_version()
    reg <- load_registry()
    ws_count <- nrow(reg$workspaces)
    fd_count <- nrow(reg$folders)
    ds_count <- nrow(reg$datasets)
    total_rows <- if (ds_count == 0) 0 else sum(reg$datasets$nrow, na.rm = TRUE)
    fluidRow(
      valueBox(width = 3, value = ws_count, subtitle = "数据空间数", icon = icon("database"), color = "blue"),
      valueBox(width = 3, value = fd_count, subtitle = "文件夹数", icon = icon("folder-open"), color = "aqua"),
      valueBox(width = 3, value = ds_count, subtitle = "数据集数", icon = icon("table"), color = "green"),
      valueBox(width = 3, value = total_rows, subtitle = "累计数据行数", icon = icon("list-ol"), color = "purple")
    )
  })
  
  output$db_structure_tree <- renderUI({
    registry_version()
    reg <- load_registry()
    ws <- reg$workspaces
    fd <- reg$folders
    ds <- reg$datasets
    if (nrow(ws) == 0) {
      return(div(class = "db-tree", span("暂无结构数据，请先创建数据空间与数据集。")))
    }
    workspace_nodes <- lapply(seq_len(nrow(ws)), function(i) {
      ws_row <- ws[i, , drop = FALSE]
      ws_id <- ws_row$id[[1]]
      ws_name <- ws_row$name[[1]]
      fd_current <- fd[fd$workspace_id == ws_id, , drop = FALSE]
      ds_current <- ds[ds$workspace_id == ws_id, , drop = FALSE]
      root_ds <- ds_current[is.na(ds_current$folder_id) | ds_current$folder_id == "", , drop = FALSE]
      folder_nodes <- lapply(seq_len(nrow(fd_current)), function(j) {
        fd_row <- fd_current[j, , drop = FALSE]
        fd_id <- fd_row$id[[1]]
        fd_name <- fd_row$name[[1]]
        ds_folder <- ds_current[ds_current$folder_id == fd_id, , drop = FALSE]
        ds_nodes <- lapply(seq_len(nrow(ds_folder)), function(k) {
          ds_row <- ds_folder[k, , drop = FALSE]
          tags$li(
            span(class = "node-label",
                 icon("table"), " ",
                 ds_row$name[[1]], " (", ds_row$nrow[[1]], "x", ds_row$ncol[[1]], ")")
          )
        })
        tags$li(
          tags$details(
            open = "open",
            tags$summary(
              span(class = "node-label",
                   icon("folder-open"), " ",
                   fd_name, " [", nrow(ds_folder), "]")
            ),
            tags$ul(ds_nodes)
          )
        )
      })
      root_nodes <- lapply(seq_len(nrow(root_ds)), function(k) {
        ds_row <- root_ds[k, , drop = FALSE]
        tags$li(
          span(class = "node-label",
               icon("table"), " ",
               ds_row$name[[1]], " (", ds_row$nrow[[1]], "x", ds_row$ncol[[1]], ")")
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
                  span(class = "node-label", icon("folder"), " 根目录 [", nrow(root_ds), "]")
                ),
                tags$ul(root_nodes)
              )
            ),
            folder_nodes
          )
        )
      )
    })
    div(
      class = "db-tree",
      tags$ul(workspace_nodes)
    )
  })
  
  observeEvent(input$create_workspace, {
    workspace_name <- trimws(input$workspace_name)
    if (!nzchar(workspace_name)) {
      showNotification("请输入数据空间名称", type = "warning")
      return()
    }
    reg <- load_registry()
    if (workspace_name %in% reg$workspaces$name) {
      showNotification("数据空间名称已存在", type = "warning")
      return()
    }
    workspace_id <- paste0("ws_", as.integer(as.numeric(Sys.time())), "_", sample(1000:9999, 1))
    reg$workspaces <- rbind(
      reg$workspaces,
      data.frame(
        id = workspace_id,
        name = workspace_name,
        created_at = Sys.time(),
        stringsAsFactors = FALSE
      )
    )
    save_registry(reg)
    refresh_workspace_choices()
    updateSelectInput(session, "workspace_select", selected = workspace_id)
    updateTextInput(session, "workspace_name", value = "")
    showNotification("数据空间创建成功", type = "message")
  })
  
  observeEvent(input$workspace_select, {
    workspace_id <- input$workspace_select
    refresh_folder_choices(workspace_id)
    refresh_dataset_choices(workspace_id, root_folder_token)
  }, ignoreNULL = FALSE)
  
  observeEvent(input$delete_workspace, {
    workspace_id <- input$workspace_select
    if (is.null(workspace_id) || workspace_id == "") {
      showNotification("请先选择要删除的数据空间", type = "warning")
      return()
    }
    reg <- load_registry()
    ws <- reg$workspaces[reg$workspaces$id == workspace_id, , drop = FALSE]
    if (nrow(ws) == 0) {
      showNotification("数据空间不存在", type = "warning")
      return()
    }
    ds_to_remove <- reg$datasets[reg$datasets$workspace_id == workspace_id, , drop = FALSE]
    remove_dataset_files(ds_to_remove)
    reg$datasets <- reg$datasets[reg$datasets$workspace_id != workspace_id, , drop = FALSE]
    reg$folders <- reg$folders[reg$folders$workspace_id != workspace_id, , drop = FALSE]
    reg$workspaces <- reg$workspaces[reg$workspaces$id != workspace_id, , drop = FALSE]
    ws_dir <- file.path(storage_root, workspace_id)
    if (dir.exists(ws_dir)) {
      unlink(ws_dir, recursive = TRUE, force = TRUE)
    }
    save_registry(reg)
    updateSelectInput(session, "workspace_select", selected = "")
    refresh_workspace_choices()
    refresh_folder_choices("")
    refresh_dataset_choices("", root_folder_token)
    showNotification("数据空间已删除（含文件夹与数据集）", type = "message")
  })
  
  observeEvent(input$create_folder, {
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
    reg <- load_registry()
    fd_current <- reg$folders[reg$folders$workspace_id == workspace_id, , drop = FALSE]
    if (folder_name %in% fd_current$name) {
      showNotification("文件夹名称已存在", type = "warning")
      return()
    }
    folder_id <- paste0("fd_", as.integer(as.numeric(Sys.time())), "_", sample(1000:9999, 1))
    reg$folders <- rbind(
      reg$folders,
      data.frame(
        id = folder_id,
        workspace_id = workspace_id,
        name = folder_name,
        created_at = Sys.time(),
        stringsAsFactors = FALSE
      )
    )
    save_registry(reg)
    refresh_folder_choices(workspace_id)
    updateSelectInput(session, "folder_select", selected = folder_id)
    updateTextInput(session, "folder_name", value = "")
    showNotification("文件夹创建成功", type = "message")
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
    reg <- load_registry()
    fd <- reg$folders[reg$folders$id == folder_id & reg$folders$workspace_id == workspace_id, , drop = FALSE]
    if (nrow(fd) == 0) {
      showNotification("文件夹不存在", type = "warning")
      return()
    }
    ds_to_remove <- reg$datasets[reg$datasets$workspace_id == workspace_id & reg$datasets$folder_id == folder_id, , drop = FALSE]
    remove_dataset_files(ds_to_remove)
    reg$datasets <- reg$datasets[!(reg$datasets$workspace_id == workspace_id & reg$datasets$folder_id == folder_id), , drop = FALSE]
    reg$folders <- reg$folders[reg$folders$id != folder_id, , drop = FALSE]
    fd_dir <- file.path(storage_root, workspace_id, folder_id)
    if (dir.exists(fd_dir)) {
      unlink(fd_dir, recursive = TRUE, force = TRUE)
    }
    save_registry(reg)
    updateSelectInput(session, "folder_select", selected = root_folder_token)
    refresh_folder_choices(workspace_id)
    refresh_dataset_choices(workspace_id, root_folder_token)
    showNotification("文件夹已删除（含该文件夹下数据集）", type = "message")
  })
  
  observeEvent(input$file, {
    req(input$file)
    default_dataset_name <- tools::file_path_sans_ext(input$file$name)
    updateTextInput(session, "dataset_name", value = default_dataset_name)
  })
  
  observeEvent(input$save_dataset, {
    req(input$file)
    workspace_id <- input$workspace_select
    if (is.null(workspace_id) || workspace_id == "") {
      showNotification("请先创建并选择数据空间", type = "warning")
      return()
    }
    folder_id <- ifelse(is.null(input$folder_select), root_folder_token, input$folder_select)
    ds_name <- trimws(input$dataset_name)
    if (!nzchar(ds_name)) {
      ds_name <- tools::file_path_sans_ext(input$file$name)
    }
    reg <- load_registry()
    result <- save_dataset_to_registry(
      reg = reg,
      workspace_id = workspace_id,
      folder_id = folder_id,
      dataset_name = ds_name,
      source_file_name = input$file$name,
      source_file_path = input$file$datapath
    )
    if (!isTRUE(result$success)) {
      showNotification(result$message, type = "warning")
      return()
    }
    save_registry(result$reg)
    refresh_dataset_choices(workspace_id, folder_id)
    updateSelectInput(session, "dataset_select", selected = result$dataset_id)
    showNotification("数据集已保存到本地数据仓库", type = "message")
  })
  
  observeEvent(input$save_batch_datasets, {
    req(input$batch_files)
    workspace_id <- input$workspace_select
    if (is.null(workspace_id) || workspace_id == "") {
      showNotification("请先创建并选择数据空间", type = "warning")
      return()
    }
    folder_id <- ifelse(is.null(input$folder_select), root_folder_token, input$folder_select)
    files_df <- input$batch_files
    total_count <- nrow(files_df)
    if (is.null(total_count) || total_count == 0) {
      showNotification("未检测到可上传文件", type = "warning")
      return()
    }
    reg <- load_registry()
    success_count <- 0
    fail_count <- 0
    last_dataset_id <- NULL
    withProgress(message = "正在批量上传数据集...", value = 0, {
      step <- 1 / max(1, total_count)
      for (i in seq_len(total_count)) {
        src_name <- files_df$name[[i]]
        src_path <- files_df$datapath[[i]]
        ext <- tolower(tools::file_ext(src_name))
        if (!(ext %in% supported_ext)) {
          fail_count <- fail_count + 1
          incProgress(step, detail = paste0("跳过不支持格式: ", src_name))
          next
        }
        ds_name <- tools::file_path_sans_ext(src_name)
        result <- save_dataset_to_registry(
          reg = reg,
          workspace_id = workspace_id,
          folder_id = folder_id,
          dataset_name = ds_name,
          source_file_name = src_name,
          source_file_path = src_path
        )
        if (isTRUE(result$success)) {
          reg <- result$reg
          success_count <- success_count + 1
          last_dataset_id <- result$dataset_id
        } else {
          fail_count <- fail_count + 1
        }
        incProgress(step, detail = paste0("处理: ", src_name))
      }
    })
    save_registry(reg)
    refresh_dataset_choices(workspace_id, folder_id)
    if (!is.null(last_dataset_id)) {
      updateSelectInput(session, "dataset_select", selected = last_dataset_id)
    }
    showNotification(paste0("批量上传完成：成功 ", success_count, "，失败 ", fail_count), type = "message")
  })
  
  observeEvent(input$import_workspace_path, {
    path_input <- trimws(input$workspace_path)
    if (!nzchar(path_input)) {
      showNotification("请输入文件夹路径", type = "warning")
      return()
    }
    if (!dir.exists(path_input)) {
      showNotification("文件夹路径不存在", type = "error")
      return()
    }
    workspace_name <- trimws(input$workspace_name)
    if (!nzchar(workspace_name)) {
      workspace_name <- basename(normalizePath(path_input, winslash = "/", mustWork = TRUE))
    }
    reg <- load_registry()
    if (workspace_name %in% reg$workspaces$name) {
      showNotification("数据空间名称已存在，请修改名称后再导入", type = "warning")
      return()
    }
    workspace_id <- paste0("ws_", as.integer(as.numeric(Sys.time())), "_", sample(1000:9999, 1))
    reg$workspaces <- rbind(
      reg$workspaces,
      data.frame(
        id = workspace_id,
        name = workspace_name,
        created_at = Sys.time(),
        stringsAsFactors = FALSE
      )
    )
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
            folder_id <- paste0("fd_", as.integer(as.numeric(Sys.time())), "_", sample(1000:9999, 1))
            folder_name <- rel_dir
            reg$folders <- rbind(
              reg$folders,
              data.frame(
                id = folder_id,
                workspace_id = workspace_id,
                name = folder_name,
                created_at = Sys.time(),
                stringsAsFactors = FALSE
              )
            )
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
            result <- save_dataset_to_registry(
              reg = reg,
              workspace_id = workspace_id,
              folder_id = target_folder_id,
              dataset_name = ds_name,
              source_file_name = file_name,
              source_file_path = file_path
            )
            if (isTRUE(result$success)) {
              reg <- result$reg
              import_success <- import_success + 1
            } else {
              import_fail <- import_fail + 1
            }
            incProgress(step, detail = paste0("导入: ", file_name))
          }
        })
        save_registry(reg)
        refresh_workspace_choices()
        updateSelectInput(session, "workspace_select", selected = workspace_id)
        refresh_folder_choices(workspace_id)
        refresh_dataset_choices(workspace_id, root_folder_token)
        updateTextInput(session, "workspace_name", value = "")
        showNotification(paste0("导入完成：成功 ", import_success, "，失败 ", import_fail), type = "message")
        return()
      }
    }
    save_registry(reg)
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
    reg <- load_registry()
    ds <- reg$datasets[reg$datasets$id == dataset_id, , drop = FALSE]
    if (nrow(ds) == 0) {
      showNotification("数据集不存在", type = "warning")
      return()
    }
    data_path <- ds$data_path[[1]]
    if (file.exists(data_path)) {
      file.remove(data_path)
    }
    reg$datasets <- reg$datasets[reg$datasets$id != dataset_id, , drop = FALSE]
    save_registry(reg)
    workspace_id <- input$workspace_select
    folder_id <- input$folder_select
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
