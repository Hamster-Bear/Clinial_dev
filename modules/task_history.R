`%||%` <- function(x, y) if (is.null(x)) y else x

if (!exists("app_card_box", mode = "function") || !exists("app_card_note", mode = "function")) {
  if (file.exists("modules/common/ui_shell.R")) {
    source("modules/common/ui_shell.R")
  } else {
    source(file.path("..", "modules", "common", "ui_shell.R"))
  }
}

task_history_ui <- function(
  id,
  title = "任务历史",
  save_label = "保存当前任务",
  load_label = "加载所选任务",
  refresh_label = "刷新历史",
  help_text = "保存当前参数设置、页面选择和任务备注。"
) {
  ns <- NS(id)
  tagList(
    tags$head(
      tags$style(HTML("
        .task-history-toolbar {
          display: flex;
          gap: 8px;
          align-items: flex-end;
          flex-wrap: wrap;
          min-height: 74px;
        }
      "))
    ),
    app_card_box(
      width = 12,
      title = title,
      subtitle = "按用户保存、加载、刷新和删除任务历史；默认折叠显示",
      tone = "warning",
      status = "warning",
      solidHeader = FALSE,
      collapsible = TRUE,
      collapsed = TRUE,
      class = "task-history-card",
      app_card_note("在当前模块中保存、加载、刷新和删除任务历史。"),
      app_card_panel(
        fluidRow(
          column(4, textInput(ns("task_name"), "任务名称", value = "", placeholder = "如：KM-默认模板", width = "100%")),
          column(4, uiOutput(ns("task_choice_ui"))),
          column(
            4,
            tags$div(
              class = "task-history-toolbar",
              actionButton(ns("refresh_tasks"), refresh_label, class = "btn-default"),
              actionButton(ns("save_task"), save_label, class = "btn-primary"),
              actionButton(ns("load_task"), load_label, class = "btn-info"),
              actionButton(ns("delete_task"), "删除任务", class = "btn-danger")
            )
          )
        )
      ),
      app_card_panel(
        tags$strong("任务说明"),
        app_card_note(help_text),
        textAreaInput(ns("task_note"), "任务备注", value = "", placeholder = "记录任务目的、筛选口径或复核说明", width = "100%", rows = 3)
      ),
      app_card_panel(
        tags$strong("历史记录"),
        app_card_note("表格按最近更新时间展示当前模块下可加载的任务历史；选择后可同步回填任务名称和备注。"),
        DT::dataTableOutput(ns("task_history_table"))
      )
    )
  )
}

task_history_operation_user_message <- function(err, action = "保存") {
  raw <- trimws(conditionMessage(err))
  if (!nzchar(raw)) {
    return(paste0("任务历史", action, "失败，请稍后重试。"))
  }
  if (grepl("analysis_states", raw, ignore.case = TRUE) && grepl("does not exist|不存在", raw, ignore.case = TRUE)) {
    return("任务历史存储尚未初始化，请重启应用后重试；若仍失败，请联系管理员检查数据库表。")
  }
  if (grepl("Closing open result set|cancelling previous query", raw, ignore.case = TRUE)) {
    return("数据库正在处理上一条任务历史请求，请稍后重试。")
  }
  if (grepl("Parameter 3|长度.*3", raw, ignore.case = TRUE)) {
    return("任务历史保存失败：当前工作空间状态异常。请刷新页面后重试；若未选择工作空间，系统会按个人任务保存。")
  }
  if (grepl("Parameter 4|Parameter 5|Parameter 6|Parameter 7|Parameter 8|length 1|长度.*1", raw, ignore.case = TRUE)) {
    return(paste(
      "任务历史保存失败：存在未正确归一化的单值参数。",
      "请重点检查任务名称、任务备注以及当前模块选择状态；",
      "图形参数未选择时系统会按空值/默认值保存，不应因此失败。"
    ))
  }
  if (grepl("connection|连接|could not connect|server closed", raw, ignore.case = TRUE)) {
    return("数据库连接异常，当前无法操作任务历史，请稍后重试。")
  }
  if (grepl("json|lexical error|parse", raw, ignore.case = TRUE)) {
    return("当前任务中包含暂不支持保存的内容，请调整设置后重试。")
  }
  paste0("任务历史", action, "失败，请稍后重试。")
}

task_history_build_select_ui <- function(ns, tasks, selected = "") {
  choice_ids <- tasks$id
  choice_names <- tasks$state_name
  if (is.null(choice_ids) || is.null(choice_names) || nrow(tasks) == 0) {
    return(selectInput(ns("task_choice"), "已保存任务", choices = c("请选择" = ""), selected = "", width = "100%"))
  }
  selectInput(
    ns("task_choice"),
    "已保存任务",
    choices = c("请选择" = "", stats::setNames(choice_ids, choice_names)),
    selected = selected %||% "",
    width = "100%"
  )
}

task_history_display_df <- function(tasks) {
  if (nrow(tasks) == 0) {
    return(data.frame(
      任务名称 = character(0),
      模块类型 = character(0),
      工作空间 = character(0),
      最近更新 = character(0),
      备注 = character(0),
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    任务名称 = tasks$state_name %||% character(0),
    模块类型 = tasks$module_type %||% character(0),
    工作空间 = ifelse(is.na(tasks$workspace_id) | !nzchar(tasks$workspace_id %||% ""), "个人任务", tasks$workspace_id),
    最近更新 = as.character(tasks$updated_at %||% tasks$created_at %||% character(0)),
    备注 = tasks$state_note %||% character(0),
    stringsAsFactors = FALSE
  )
}

task_history_server <- function(
  id,
  pg_pool = NULL,
  current_user = NULL,
  workspace_id = NULL,
  scope = "graphics",
  module_type = NULL,
  get_state = NULL,
  apply_state = NULL,
  apply_failure_message = "当前模块暂未接入任务历史回填"
) {
  moduleServer(id, function(input, output, session) {
    resolve_user <- function() {
      if (is.null(current_user)) return(NULL)
      if (is.function(current_user)) return(current_user())
      current_user
    }

    resolve_workspace <- function() {
      raw_workspace_id <- if (is.null(workspace_id)) {
        NULL
      } else if (is.function(workspace_id)) {
        workspace_id()
      } else {
        workspace_id
      }
      service_normalize_analysis_state_workspace_id(raw_workspace_id)
    }

    resolve_module_type <- function() {
      raw_module_type <- if (is.null(module_type)) {
        NULL
      } else if (is.reactive(module_type)) {
        module_type()
      } else if (is.function(module_type)) {
        module_type()
      } else {
        module_type
      }
      if (length(raw_module_type) == 0 || is.null(raw_module_type)) return("")
      trimws(as.character(raw_module_type[[1]]))
    }

    collect_state <- function() {
      if (is.null(get_state)) return(list())
      state <- get_state()
      if (is.list(state)) return(state)
      list()
    }

    apply_task_state <- function(state) {
      if (is.null(apply_state)) return(FALSE)
      apply_state(state)
    }

    task_cache <- reactiveVal(data.frame())

    refresh_task_cache <- function(selected = "") {
      module_name <- resolve_module_type()
      if (is.null(pg_pool) || !nzchar(module_name)) {
        task_cache(data.frame())
        output$task_choice_ui <- renderUI(task_history_build_select_ui(session$ns, data.frame(), selected = ""))
        return(invisible(FALSE))
      }
      user <- resolve_user()
      if (is.null(user)) {
        task_cache(data.frame())
        output$task_choice_ui <- renderUI(task_history_build_select_ui(session$ns, data.frame(), selected = ""))
        return(invisible(FALSE))
      }
      if (!is.list(user)) {
        message(sprintf("[TaskHistoryDebug] resolve_user returned non-list: class=%s, typeof=%s",
          paste(class(user), collapse = "/"), typeof(user)))
        task_cache(data.frame())
        output$task_choice_ui <- renderUI(task_history_build_select_ui(session$ns, data.frame(), selected = ""))
        return(invisible(FALSE))
      }
      if (!nzchar(user$id %||% "")) {
        task_cache(data.frame())
        output$task_choice_ui <- renderUI(task_history_build_select_ui(session$ns, data.frame(), selected = ""))
        return(invisible(FALSE))
      }
      tryCatch({
        tasks <- service_list_analysis_states(
          pool = pg_pool,
          user_id = user$id,
          scope = scope,
          module_type = module_name,
          workspace_id = resolve_workspace()
        )
        task_cache(tasks)
        output$task_choice_ui <- renderUI(task_history_build_select_ui(session$ns, tasks, selected = selected))
        TRUE
      }, error = function(e) {
        message(sprintf("[TaskHistoryRefreshError] %s", conditionMessage(e)))
        task_cache(data.frame())
        output$task_choice_ui <- renderUI(task_history_build_select_ui(session$ns, data.frame(), selected = ""))
        FALSE
      })
    }

    output$task_choice_ui <- renderUI({
      task_history_build_select_ui(session$ns, task_cache(), selected = input$task_choice %||% "")
    })

    output$task_history_table <- DT::renderDT({
      display_df <- task_history_display_df(task_cache())
      if (nrow(display_df) == 0) {
        return(DT::datatable(display_df, options = list(dom = "t"), rownames = FALSE))
      }
      DT::datatable(
        display_df,
        options = list(pageLength = 5, dom = "tip", order = list(list(3, "desc"))),
        rownames = FALSE,
        selection = "single"
      )
    })

    observeEvent(input$task_history_table_rows_selected, {
      selected_row <- input$task_history_table_rows_selected
      tasks <- task_cache()
      if (length(selected_row) == 1 && nrow(tasks) >= selected_row) {
        updateSelectInput(session, "task_choice", selected = tasks$id[[selected_row]])
      }
    })

    observeEvent(input$task_choice, {
      task_id <- input$task_choice %||% ""
      tasks <- task_cache()
      if (!nzchar(task_id) || nrow(tasks) == 0) {
        return(invisible(NULL))
      }
      selected_task <- tasks[tasks$id == task_id, , drop = FALSE]
      if (nrow(selected_task) == 0) {
        return(invisible(NULL))
      }
      updateTextInput(session, "task_name", value = selected_task$state_name[[1]] %||% "")
      updateTextAreaInput(session, "task_note", value = selected_task$state_note[[1]] %||% "")
    }, ignoreInit = TRUE)

    observe({
      resolve_user()
      resolve_workspace()
      resolve_module_type()
      refresh_task_cache()
    })

    observeEvent(input$refresh_tasks, {
      refresh_task_cache(selected = input$task_choice %||% "")
    })

    observeEvent(input$save_task, {
      module_name <- resolve_module_type()
      if (is.null(pg_pool)) {
        showNotification("当前未连接数据库，无法保存任务历史", type = "warning")
        return(invisible(NULL))
      }
      if (!nzchar(module_name)) {
        showNotification("请先选择目标模块后再保存任务历史", type = "warning")
        return(invisible(NULL))
      }
      user <- resolve_user()
      if (is.null(user) || !is.list(user) || !nzchar(user$id %||% "")) {
        showNotification("请先登录后再保存任务历史", type = "warning")
        return(invisible(NULL))
      }
      state_name <- trimws(input$task_name %||% "")
      if (!nzchar(state_name)) {
        showNotification("请输入任务名称", type = "warning")
        return(invisible(NULL))
      }
      payload <- collect_state()
      tryCatch({
        state_id <- service_save_analysis_state(
          pool = pg_pool,
          user_id = user$id,
          module_type = module_name,
          state_name = state_name,
          payload = payload,
          scope = scope,
          workspace_id = resolve_workspace(),
          state_note = input$task_note
        )
        showNotification("任务历史已保存", type = "message")
        refresh_task_cache(selected = state_id %||% "")
      }, error = function(e) {
        message(sprintf("[TaskHistorySaveError] %s", conditionMessage(e)))
        showNotification(task_history_operation_user_message(e, action = "保存"), type = "error")
      })
    })

    observeEvent(input$load_task, {
      module_name <- resolve_module_type()
      if (is.null(pg_pool)) {
        showNotification("当前未连接数据库，无法加载任务历史", type = "warning")
        return(invisible(NULL))
      }
      if (!nzchar(module_name)) {
        showNotification("请先选择目标模块后再加载任务历史", type = "warning")
        return(invisible(NULL))
      }
      user <- resolve_user()
      if (is.null(user) || !is.list(user) || !nzchar(user$id %||% "")) {
        showNotification("请先登录后再加载任务历史", type = "warning")
        return(invisible(NULL))
      }
      state_id <- input$task_choice %||% ""
      if (!nzchar(state_id)) {
        showNotification("请先选择一条任务历史", type = "warning")
        return(invisible(NULL))
      }
      state_row <- service_get_analysis_state(pg_pool, state_id, user$id)
      if (nrow(state_row) == 0) {
        showNotification("未找到可加载的任务历史", type = "warning")
        return(invisible(NULL))
      }
      tryCatch({
        payload <- service_parse_analysis_state_payload(state_row$state_payload[[1]])
        applied <- apply_task_state(payload)
        if (isTRUE(applied)) {
          updateTextInput(session, "task_name", value = state_row$state_name[[1]] %||% "")
          updateTextAreaInput(session, "task_note", value = state_row$state_note[[1]] %||% "")
          showNotification("任务历史已加载到当前模块", type = "message")
        } else {
          showNotification(apply_failure_message, type = "warning")
        }
      }, error = function(e) {
        message(sprintf("[TaskHistoryLoadError] %s", conditionMessage(e)))
        showNotification(task_history_operation_user_message(e, action = "加载"), type = "error")
      })
    })

    observeEvent(input$delete_task, {
      task_id <- input$task_choice %||% ""
      if (!nzchar(task_id)) {
        showNotification("请先选择一条任务历史", type = "warning")
        return(invisible(NULL))
      }
      showModal(modalDialog(
        title = "删除任务历史",
        "确认删除当前选中的任务历史吗？该操作无法撤销。",
        footer = tagList(
          modalButton("取消"),
          actionButton(session$ns("confirm_delete_task"), "确认删除", class = "btn-danger")
        ),
        easyClose = TRUE
      ))
    })

    observeEvent(input$confirm_delete_task, {
      removeModal()
      if (is.null(pg_pool)) {
        showNotification("当前未连接数据库，无法删除任务历史", type = "warning")
        return(invisible(NULL))
      }
      user <- resolve_user()
      if (is.null(user) || !is.list(user) || !nzchar(user$id %||% "")) {
        showNotification("请先登录后再删除任务历史", type = "warning")
        return(invisible(NULL))
      }
      task_id <- input$task_choice %||% ""
      if (!nzchar(task_id)) {
        showNotification("请先选择一条任务历史", type = "warning")
        return(invisible(NULL))
      }
      tryCatch({
        deleted <- service_delete_analysis_state(pg_pool, task_id, user$id)
        if (isTRUE(deleted > 0)) {
          updateSelectInput(session, "task_choice", selected = "")
          updateTextInput(session, "task_name", value = "")
          updateTextAreaInput(session, "task_note", value = "")
          showNotification("任务历史已删除", type = "message")
          refresh_task_cache(selected = "")
        } else {
          showNotification("未找到可删除的任务历史", type = "warning")
        }
      }, error = function(e) {
        message(sprintf("[TaskHistoryDeleteError] %s", conditionMessage(e)))
        showNotification(task_history_operation_user_message(e, action = "删除"), type = "error")
      })
    })

    list(
      tasks = reactive(task_cache()),
      refresh = refresh_task_cache
    )
  })
}
