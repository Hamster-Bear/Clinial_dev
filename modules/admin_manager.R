admin_manager_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      box(
        width = 12,
        title = "管理员操作入口",
        status = "danger",
        solidHeader = TRUE,
        uiOutput(ns("admin_access_notice"))
      )
    ),
    uiOutput(ns("admin_content"))
  )
}

admin_manager_server <- function(id, pg_pool, current_user = NULL) {
  moduleServer(id, function(input, output, session) {
    `%||%` <- function(x, y) if (is.null(x)) y else x

    get_current_user <- function() {
      if (is.null(current_user)) {
        return(NULL)
      }
      current_user()
    }

    is_admin <- reactive({
      user <- get_current_user()
      !is.null(user) && isTRUE(user$is_admin)
    })

    list_users <- reactive({
      req(is_admin())
      service_list_users(pg_pool)
    })

    list_workspaces <- reactive({
      req(is_admin())
      service_list_workspaces(pg_pool)
    })

    output$admin_access_notice <- renderUI({
      if (isTRUE(is_admin())) {
        tags$div("当前账号可执行 owner 绑定、membership 分配与账号停用。")
      } else {
        tags$div("当前页面仅系统管理员可用。")
      }
    })

    output$admin_content <- renderUI({
      if (!isTRUE(is_admin())) {
        return(NULL)
      }
      users_df <- list_users()
      workspaces_df <- list_workspaces()
      user_choices <- if (nrow(users_df) == 0) character(0) else setNames(users_df$id, paste0(users_df$username, " <", ifelse(is.na(users_df$email) | !nzchar(users_df$email), "未设置邮箱", users_df$email), ">"))
      workspace_choices <- if (nrow(workspaces_df) == 0) character(0) else setNames(workspaces_df$id, workspaces_df$name)
      tagList(
        fluidRow(
          box(
            width = 4,
            title = "账号状态管理",
            status = "warning",
            solidHeader = TRUE,
            selectInput(session$ns("admin_user_select"), "选择用户", choices = user_choices),
            verbatimTextOutput(session$ns("admin_user_meta")),
            fluidRow(
              column(6, actionButton(session$ns("activate_user"), "启用账号", class = "btn-success", width = "100%")),
              column(6, actionButton(session$ns("deactivate_user"), "停用账号", class = "btn-danger", width = "100%"))
            )
          ),
          box(
            width = 4,
            title = "绑定 Workspace Owner",
            status = "primary",
            solidHeader = TRUE,
            selectInput(session$ns("owner_workspace_select"), "选择数据空间", choices = workspace_choices),
            selectInput(session$ns("owner_user_select"), "选择负责人", choices = user_choices),
            actionButton(session$ns("assign_owner"), "绑定 Owner", class = "btn-primary", width = "100%")
          ),
          box(
            width = 4,
            title = "分配 Membership",
            status = "info",
            solidHeader = TRUE,
            selectInput(session$ns("membership_workspace_select"), "选择数据空间", choices = workspace_choices),
            selectInput(session$ns("membership_user_select"), "选择成员", choices = user_choices),
            selectInput(session$ns("membership_role"), "角色", choices = c("viewer", "editor", "owner"), selected = "viewer"),
            actionButton(session$ns("assign_membership"), "保存 Membership", class = "btn-info", width = "100%")
          )
        ),
        fluidRow(
          box(
            width = 12,
            title = "当前 Workspace Membership",
            status = "info",
            solidHeader = TRUE,
            DTOutput(session$ns("membership_table"))
          )
        )
      )
    })

    output$admin_user_meta <- renderText({
      req(is_admin())
      req(input$admin_user_select)
      users_df <- list_users()
      row <- users_df[users_df$id == input$admin_user_select, , drop = FALSE]
      if (nrow(row) == 0) {
        return("未找到用户信息")
      }
      paste0(
        "用户名: ", row$username[[1]], "\n",
        "邮箱: ", ifelse(is.na(row$email[[1]]) || !nzchar(row$email[[1]]), "未设置", row$email[[1]]), "\n",
        "管理员: ", ifelse(isTRUE(row$is_admin[[1]]), "是", "否"), "\n",
        "状态: ", row$status[[1]]
      )
    })

    output$membership_table <- renderDT({
      req(is_admin())
      workspace_id <- input$membership_workspace_select %||% input$owner_workspace_select %||% ""
      memberships <- service_list_workspace_memberships(pg_pool, workspace_id = workspace_id)
      datatable(memberships, rownames = FALSE, options = list(pageLength = 8, scrollX = TRUE))
    })

    observeEvent(input$assign_owner, {
      req(is_admin())
      req(input$owner_workspace_select, input$owner_user_select)
      tryCatch({
        service_assign_workspace_owner(pg_pool, input$owner_workspace_select, input$owner_user_select)
        showNotification("Workspace Owner 已更新", type = "message")
      }, error = function(e) {
        showNotification(paste0("绑定 Owner 失败：", e$message), type = "error")
      })
    })

    observeEvent(input$assign_membership, {
      req(is_admin())
      req(input$membership_workspace_select, input$membership_user_select)
      tryCatch({
        service_upsert_workspace_membership(
          pg_pool,
          workspace_id = input$membership_workspace_select,
          user_id = input$membership_user_select,
          role = input$membership_role
        )
        showNotification("Membership 已更新", type = "message")
      }, error = function(e) {
        showNotification(paste0("更新 Membership 失败：", e$message), type = "error")
      })
    })

    observeEvent(input$activate_user, {
      req(is_admin())
      req(input$admin_user_select)
      tryCatch({
        service_set_user_status(pg_pool, input$admin_user_select, "active")
        showNotification("账号已启用", type = "message")
      }, error = function(e) {
        showNotification(paste0("启用失败：", e$message), type = "error")
      })
    })

    observeEvent(input$deactivate_user, {
      req(is_admin())
      req(input$admin_user_select)
      current <- get_current_user()
      if (!is.null(current) && identical(current$id, input$admin_user_select)) {
        showNotification("不能停用当前登录管理员账号", type = "warning")
        return()
      }
      tryCatch({
        service_set_user_status(pg_pool, input$admin_user_select, "inactive")
        showNotification("账号已停用", type = "message")
      }, error = function(e) {
        showNotification(paste0("停用失败：", e$message), type = "error")
      })
    })
  })
}
