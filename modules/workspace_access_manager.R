workspace_access_manager_ui <- function(id) {
  ns <- NS(id)
  tagList(
    tags$head(
      tags$style(HTML("
        .access-note {
          color: #5f6b7a;
          line-height: 1.7;
        }
        .access-context-card {
          margin-bottom: 15px;
          padding: 14px 16px;
          border-radius: 10px;
          background: #f7fbff;
          border: 1px solid #d9ecf7;
        }
        .access-context-title {
          font-weight: 700;
          color: #2c3e50;
          margin-bottom: 8px;
        }
        .access-context-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
          gap: 10px;
        }
        .access-context-item {
          padding: 10px 12px;
          border-radius: 8px;
          background: #ffffff;
          border: 1px solid #e5eef5;
        }
        .access-context-label {
          display: block;
          font-size: 12px;
          color: #7b8794;
          margin-bottom: 4px;
        }
        .access-context-value {
          display: block;
          font-size: 14px;
          font-weight: 600;
          color: #1f2d3d;
        }
        .access-form-note {
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
        title = "我的数据空间权限",
        status = "primary",
        solidHeader = TRUE,
        uiOutput(ns("access_notice"))
      )
    ),
    uiOutput(ns("workspace_context")),
    uiOutput(ns("access_content"))
  )
}

workspace_access_manager_server <- function(id, pg_pool, current_user = NULL) {
  moduleServer(id, function(input, output, session) {
    `%||%` <- function(x, y) if (is.null(x)) y else x
    refresh_tick <- reactiveVal(0)

    get_current_user <- function() {
      if (is.null(current_user)) {
        return(NULL)
      }
      isolate(current_user())
    }

    current_workspace_id <- reactive({
      workspace_df <- manageable_workspaces()
      selected_id <- input$managed_workspace_id %||% ""
      if (nzchar(selected_id) && selected_id %in% (workspace_df$id %||% character(0))) {
        return(selected_id)
      }
      if (nrow(workspace_df) == 0) {
        return("")
      }
      workspace_df$id[[1]]
    })

    manageable_workspaces <- reactive({
      user <- get_current_user()
      if (is.null(user)) {
        return(data.frame())
      }
      service_list_manageable_workspaces(pg_pool, user)
    })

    output$access_notice <- renderUI({
      user <- get_current_user()
      if (is.null(user)) {
        return(tags$div("请先登录后管理数据空间权限。"))
      }
      workspace_df <- manageable_workspaces()
      if (nrow(workspace_df) == 0) {
        return(tags$div("当前账号尚未拥有可管理的数据空间。"))
      }
      tags$div(
        class = "access-note",
        "这里用于管理你自己创建的数据空间协作权限。新增协作者、撤销协作和迁移负责人都通过邮箱完成，不展示库内用户选择器。"
      )
    })

    output$workspace_context <- renderUI({
      req(nzchar(current_workspace_id()))
      access_data <- service_list_workspace_access(pg_pool, current_workspace_id())
      workspace_row <- access_data$workspace
      memberships <- access_data$memberships
      invites <- access_data$invites
      owner_email <- ""
      if (nrow(memberships) > 0 && any(memberships$role == "owner")) {
        owner_email <- memberships$email[match("owner", memberships$role)] %||% ""
      }
      div(
        class = "access-context-card",
        div(class = "access-context-title", "当前管理上下文"),
        div(
          class = "access-context-grid",
          div(
            class = "access-context-item",
            span(class = "access-context-label", "数据空间"),
            span(class = "access-context-value", workspace_row$name[[1]] %||% current_workspace_id())
          ),
          div(
            class = "access-context-item",
            span(class = "access-context-label", "当前负责人"),
            span(class = "access-context-value", if (nzchar(owner_email)) owner_email else "待补充")
          ),
          div(
            class = "access-context-item",
            span(class = "access-context-label", "当前成员数"),
            span(class = "access-context-value", as.character(nrow(memberships)))
          ),
          div(
            class = "access-context-item",
            span(class = "access-context-label", "待领取邀请"),
            span(class = "access-context-value", as.character(sum(invites$status == "pending", na.rm = TRUE)))
          )
        )
      )
    })

    output$access_content <- renderUI({
      workspace_df <- manageable_workspaces()
      if (nrow(workspace_df) == 0) {
        return(NULL)
      }
      workspace_choices <- setNames(workspace_df$id, workspace_df$name)
      fluidRow(
        column(
          width = 4,
          box(
            width = 12,
            title = "协作成员设置",
            status = "info",
            solidHeader = TRUE,
            selectInput(session$ns("managed_workspace_id"), "选择要管理的数据空间", choices = workspace_choices),
            textInput(session$ns("target_email"), "协作者邮箱", placeholder = "请输入协作者邮箱"),
            selectInput(
              session$ns("target_role"),
              "协作权限等级",
              choices = c("只读成员" = "viewer", "可编辑成员" = "editor"),
              selected = "viewer"
            ),
            div(class = "access-form-note", "未注册邮箱会自动记录为待领取邀请；已注册邮箱会直接更新成员权限。"),
            fluidRow(
              column(6, actionButton(session$ns("grant_access"), "发送授权", class = "btn-primary", width = "100%")),
              column(6, actionButton(session$ns("revoke_access"), "撤销协作", class = "btn-danger", width = "100%"))
            )
          ),
          box(
            width = 12,
            title = "负责人迁移",
            status = "warning",
            solidHeader = TRUE,
            textInput(session$ns("owner_email"), "新负责人的邮箱", placeholder = "请输入新的负责人邮箱"),
            div(class = "access-form-note", "负责人迁移后，原负责人会自动降级为可编辑成员。若目标邮箱尚未注册，会先保留待领取迁移记录。"),
            actionButton(session$ns("transfer_owner"), "确认迁移负责人", class = "btn-warning", width = "100%")
          )
        ),
        column(
          width = 8,
          tabBox(
            width = 12,
            title = "协作权限预览",
            id = session$ns("access_preview_tabs"),
            tabPanel("当前成员", DTOutput(session$ns("members_table"))),
            tabPanel("待领取邀请", DTOutput(session$ns("invite_table")))
          )
        )
      )
    })

    output$members_table <- renderDT({
      refresh_tick()
      req(nzchar(current_workspace_id()))
      access_data <- service_list_workspace_access(pg_pool, current_workspace_id())
      memberships <- service_membership_preview_df(access_data$memberships)
      datatable(memberships, rownames = FALSE, options = list(pageLength = 6, scrollX = TRUE, dom = "tip"))
    })

    output$invite_table <- renderDT({
      refresh_tick()
      req(nzchar(current_workspace_id()))
      access_data <- service_list_workspace_access(pg_pool, current_workspace_id())
      invites <- service_invite_preview_df(access_data$invites)
      datatable(invites, rownames = FALSE, options = list(pageLength = 6, scrollX = TRUE, dom = "tip"))
    })

    observeEvent(input$grant_access, {
      req(nzchar(current_workspace_id()))
      user <- get_current_user()
      tryCatch({
        result <- service_grant_workspace_access_by_email(
          pg_pool,
          workspace_id = current_workspace_id(),
          invited_email = input$target_email %||% "",
          role = input$target_role %||% "viewer",
          acting_user = user
        )
        refresh_tick(as.numeric(Sys.time()))
        showNotification(result$message, type = "message")
      }, error = function(e) {
        showNotification(paste0("授权失败：", e$message), type = "error")
      })
    })

    observeEvent(input$revoke_access, {
      req(nzchar(current_workspace_id()))
      user <- get_current_user()
      tryCatch({
        service_revoke_workspace_access_by_email(
          pg_pool,
          workspace_id = current_workspace_id(),
          invited_email = input$target_email %||% "",
          acting_user = user
        )
        refresh_tick(as.numeric(Sys.time()))
        showNotification("权限已撤销", type = "message")
      }, error = function(e) {
        showNotification(paste0("撤销失败：", e$message), type = "error")
      })
    })

    observeEvent(input$transfer_owner, {
      req(nzchar(current_workspace_id()))
      user <- get_current_user()
      tryCatch({
        result <- service_transfer_workspace_owner_by_email(
          pg_pool,
          workspace_id = current_workspace_id(),
          invited_email = input$owner_email %||% "",
          acting_user = user
        )
        refresh_tick(as.numeric(Sys.time()))
        showNotification(result$message, type = "message")
      }, error = function(e) {
        showNotification(paste0("迁移失败：", e$message), type = "error")
      })
    })
  })
}
