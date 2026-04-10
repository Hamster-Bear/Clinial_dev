admin_manager_ui <- function(id) {
  ns <- NS(id)
  tagList(
    tags$head(
      tags$style(HTML("
        .admin-note {
          color: #5f6b7a;
          line-height: 1.7;
        }
        .admin-form-note {
          color: #6b7785;
          font-size: 12px;
          line-height: 1.6;
          margin-top: 8px;
          margin-bottom: 10px;
        }
      "))
    ),
    fluidRow(
      box(
        width = 12,
        title = "系统管理入口",
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
    refresh_tick <- reactiveVal(0)

    get_current_user <- function() {
      if (is.null(current_user)) {
        return(NULL)
      }
      isolate(current_user())
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
        tags$div(
          class = "admin-note",
          "当前页面仅面向系统管理员，用于执行账号状态调整、数据空间负责人绑定和系统级协作授权。管理员入口保持独立，不并入普通用户侧边栏卡片。"
        )
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
      workspace_choices <- if (nrow(workspaces_df) == 0) character(0) else setNames(workspaces_df$id, workspaces_df$name)
      tagList(
        fluidRow(
          box(
            width = 4,
            title = "账号状态管理",
            status = "warning",
            solidHeader = TRUE,
            textInput(session$ns("admin_user_email"), "待处理账号邮箱", placeholder = "请输入账号邮箱"),
            verbatimTextOutput(session$ns("admin_user_meta")),
            fluidRow(
              column(6, actionButton(session$ns("activate_user"), "启用账号", class = "btn-success", width = "100%")),
              column(6, actionButton(session$ns("deactivate_user"), "停用账号", class = "btn-danger", width = "100%"))
            )
          ),
          box(
            width = 4,
            title = "负责人绑定",
            status = "primary",
            solidHeader = TRUE,
            selectInput(session$ns("owner_workspace_select"), "选择目标数据空间", choices = workspace_choices),
            textInput(session$ns("owner_email"), "新负责人邮箱", placeholder = "请输入负责人邮箱"),
            div(class = "admin-form-note", "用于系统级纠偏或初始化负责人。若邮箱尚未注册，会生成待领取的负责人迁移记录。"),
            actionButton(session$ns("assign_owner"), "绑定负责人", class = "btn-primary", width = "100%")
          ),
          box(
            width = 4,
            title = "协作权限调整",
            status = "info",
            solidHeader = TRUE,
            selectInput(session$ns("membership_workspace_select"), "选择目标数据空间", choices = workspace_choices),
            textInput(session$ns("membership_email"), "协作者邮箱", placeholder = "请输入协作者邮箱"),
            selectInput(
              session$ns("membership_role"),
              "协作权限等级",
              choices = c("只读成员" = "viewer", "可编辑成员" = "editor"),
              selected = "viewer"
            ),
            div(class = "admin-form-note", "管理员不展示库内用户选择器，系统级授权、撤销与负责人迁移统一通过邮箱完成。"),
            fluidRow(
              column(6, actionButton(session$ns("assign_membership"), "发送授权", class = "btn-info", width = "100%")),
              column(6, actionButton(session$ns("revoke_membership"), "撤销协作", class = "btn-danger", width = "100%"))
            )
          )
        ),
        fluidRow(
          tabBox(
            width = 12,
            title = "协作权限预览",
            id = session$ns("admin_preview_tabs"),
            tabPanel("当前成员", DTOutput(session$ns("membership_table"))),
            tabPanel("待领取邀请", DTOutput(session$ns("invite_table")))
          )
        )
      )
    })

    output$admin_user_meta <- renderText({
      req(is_admin())
      req(nzchar(input$admin_user_email %||% ""))
      row <- service_get_user_by_email(pg_pool, input$admin_user_email %||% "")
      if (nrow(row) == 0) {
        return("未找到用户信息")
      }
      paste0(
        "账号名: ", row$username[[1]], "\n",
        "联系邮箱: ", ifelse(is.na(row$email[[1]]) || !nzchar(row$email[[1]]), "未设置", row$email[[1]]), "\n",
        "管理员身份: ", ifelse(isTRUE(row$is_admin[[1]]), "是", "否"), "\n",
        "账号状态: ", service_label_user_status(row$status[[1]])
      )
    })

    output$membership_table <- renderDT({
      req(is_admin())
      refresh_tick()
      workspace_id <- input$membership_workspace_select %||% input$owner_workspace_select %||% ""
      memberships <- service_membership_preview_df(service_list_workspace_memberships(pg_pool, workspace_id = workspace_id))
      datatable(memberships, rownames = FALSE, options = list(pageLength = 8, scrollX = TRUE, dom = "tip"))
    })

    output$invite_table <- renderDT({
      req(is_admin())
      refresh_tick()
      workspace_id <- input$membership_workspace_select %||% input$owner_workspace_select %||% ""
      invites <- service_invite_preview_df(service_list_workspace_invites(pg_pool, workspace_id = workspace_id))
      datatable(invites, rownames = FALSE, options = list(pageLength = 8, scrollX = TRUE, dom = "tip"))
    })

    observeEvent(input$assign_owner, {
      req(is_admin())
      req(input$owner_workspace_select, input$owner_email)
      tryCatch({
        result <- service_transfer_workspace_owner_by_email(
          pg_pool,
          workspace_id = input$owner_workspace_select,
          invited_email = input$owner_email %||% "",
          acting_user = get_current_user()
        )
        refresh_tick(as.numeric(Sys.time()))
        showNotification(result$message, type = "message")
      }, error = function(e) {
        showNotification(paste0("绑定 Owner 失败：", e$message), type = "error")
      })
    })

    observeEvent(input$assign_membership, {
      req(is_admin())
      req(input$membership_workspace_select, input$membership_email)
      tryCatch({
        result <- service_grant_workspace_access_by_email(
          pg_pool,
          workspace_id = input$membership_workspace_select,
          invited_email = input$membership_email %||% "",
          role = input$membership_role,
          acting_user = get_current_user()
        )
        refresh_tick(as.numeric(Sys.time()))
        showNotification(result$message, type = "message")
      }, error = function(e) {
        showNotification(paste0("更新 Membership 失败：", e$message), type = "error")
      })
    })

    observeEvent(input$revoke_membership, {
      req(is_admin())
      req(input$membership_workspace_select, input$membership_email)
      tryCatch({
        service_revoke_workspace_access_by_email(
          pg_pool,
          workspace_id = input$membership_workspace_select,
          invited_email = input$membership_email %||% "",
          acting_user = get_current_user()
        )
        refresh_tick(as.numeric(Sys.time()))
        showNotification("权限已撤销", type = "message")
      }, error = function(e) {
        showNotification(paste0("撤销权限失败：", e$message), type = "error")
      })
    })

    observeEvent(input$activate_user, {
      req(is_admin())
      req(nzchar(input$admin_user_email %||% ""))
      tryCatch({
        service_set_user_status_by_email(pg_pool, input$admin_user_email %||% "", "active")
        refresh_tick(as.numeric(Sys.time()))
        showNotification("账号已启用", type = "message")
      }, error = function(e) {
        showNotification(paste0("启用失败：", e$message), type = "error")
      })
    })

    observeEvent(input$deactivate_user, {
      req(is_admin())
      req(nzchar(input$admin_user_email %||% ""))
      target_user <- service_get_user_by_email(pg_pool, input$admin_user_email %||% "")
      current <- get_current_user()
      if (nrow(target_user) > 0 && !is.null(current) && identical(current$id, target_user$id[[1]])) {
        showNotification("不能停用当前登录管理员账号", type = "warning")
        return()
      }
      tryCatch({
        service_set_user_status_by_email(pg_pool, input$admin_user_email %||% "", "inactive")
        refresh_tick(as.numeric(Sys.time()))
        showNotification("账号已停用", type = "message")
      }, error = function(e) {
        showNotification(paste0("停用失败：", e$message), type = "error")
      })
    })
  })
}
