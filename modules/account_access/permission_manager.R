permission_manager_ui <- function(id) {
  ns <- NS(id)
  tagList(
    app_card_dependencies(),
    tags$head(
      tags$style(HTML("
        .permission-panel-list {
          display: grid;
          gap: 12px;
        }
        .permission-form-note {
          color: #6b7785;
          font-size: 12px;
          line-height: 1.6;
          margin-top: 8px;
          margin-bottom: 10px;
        }
        .permission-inline-actions {
          display: grid;
          grid-template-columns: repeat(2, minmax(0, 1fr));
          gap: 10px;
        }
        .permission-status-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
          gap: 10px;
        }
        .permission-status-item {
          padding: 10px 12px;
          border-radius: 10px;
          border: 1px solid #e8eef5;
          background: #f8fbff;
        }
        .permission-status-label {
          display: block;
          margin-bottom: 4px;
          color: #7b8794;
          font-size: 12px;
        }
        .permission-status-value {
          display: block;
          color: #243447;
          font-size: 14px;
          font-weight: 600;
          line-height: 1.5;
        }
      "))
    ),
    app_card_box(
      width = 12,
      title = "权限管理",
      subtitle = "数据空间协作与已授权空间",
      tone = "primary",
      status = "primary",
      solidHeader = FALSE,
      uiOutput(ns("permission_notice"))
    ),
    uiOutput(ns("permission_content"))
  )
}

permission_manager_server <- function(id, pg_pool, current_user = NULL) {
  moduleServer(id, function(input, output, session) {
    `%||%` <- function(x, y) if (is.null(x)) y else x
    refresh_tick <- reactiveVal(0)

    get_current_user <- function() {
      if (is.null(current_user)) {
        return(NULL)
      }
      current_user()
    }

    manageable_workspaces <- reactive({
      user <- get_current_user()
      if (is.null(user)) {
        return(data.frame())
      }
      tryCatch(
        service_list_manageable_workspaces(pg_pool, user),
        error = function(e) {
          empty_df <- data.frame(
            id = character(),
            name = character(),
            stringsAsFactors = FALSE
          )
          attr(empty_df, "load_error") <- paste0("权限管理数据加载失败：", e$message)
          empty_df
        }
      )
    })

    accessible_workspaces <- reactive({
      user <- get_current_user()
      if (is.null(user)) {
        return(data.frame())
      }
      tryCatch(
        service_list_accessible_workspaces(pg_pool, user),
        error = function(e) {
          empty_df <- data.frame(
            id = character(),
            name = character(),
            role = character(),
            owner_username = character(),
            owner_email = character(),
            membership_created_at = character(),
            stringsAsFactors = FALSE
          )
          attr(empty_df, "load_error") <- paste0("已授权空间数据加载失败：", e$message)
          empty_df
        }
      )
    })

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

    build_permission_content <- function(user) {
      workspace_df <- manageable_workspaces()
      accessible_df <- accessible_workspaces()
      load_error <- attr(workspace_df, "load_error", exact = TRUE) %||% ""
      accessible_error <- attr(accessible_df, "load_error", exact = TRUE) %||% ""
      workspace_choices <- if (nrow(workspace_df) > 0) setNames(workspace_df$id, workspace_df$name) else character(0)

      if (nzchar(load_error) || nzchar(accessible_error)) {
        return(app_card_box(
          width = 12,
          title = "权限管理",
          subtitle = "权限数据加载异常",
          tone = "danger",
          status = "danger",
          solidHeader = FALSE,
          app_card_note(paste0("当前无法加载可管理空间或已授权空间数据。", load_error, accessible_error, " 你仍可以稍后重试或联系管理员检查数据连接。"))
        ))
      }

      if (nrow(workspace_df) == 0 && nrow(accessible_df) > 0) {
        return(app_card_box(
          width = 12,
          title = "我的已授权空间",
          subtitle = "查看当前被授予访问权限的数据空间与角色",
          tone = "primary",
          status = "primary",
          solidHeader = FALSE,
          app_card_note("当前账号不是这些数据空间的负责人，因此这里展示的是你被授予的访问权限信息，而不是成员管理表单。"),
          app_card_panel(DTOutput(session$ns("accessible_workspace_table")))
        ))
      }

      if (nrow(workspace_df) == 0) {
        return(app_card_box(
          width = 12,
          title = "权限管理",
          subtitle = "当前暂无可管理空间",
          tone = "warning",
          status = "warning",
          solidHeader = FALSE,
          app_card_note("当前账号名下还没有可管理的数据空间，因此权限管理区暂时不显示协作设置表单。后续创建或获得可管理空间后，这里会自动出现成员授权、撤销和负责人迁移能力。")
        ))
      }

      tagList(
        uiOutput(session$ns("workspace_context")),
        app_card_box(
          width = 12,
          title = "权限管理",
          subtitle = "通过邮箱管理成员、邀请与负责人迁移",
          tone = "info",
          status = "info",
          solidHeader = FALSE,
          div(
            class = "permission-panel-list",
            app_card_panel(
              selectInput(session$ns("managed_workspace_id"), "选择要管理的数据空间", choices = workspace_choices),
              div(class = "permission-form-note", "未注册邮箱会自动记录为待领取邀请；已注册邮箱会直接更新成员权限。")
            ),
            app_card_panel(
              textInput(session$ns("target_email"), "协作者邮箱", placeholder = "请输入协作者邮箱"),
              selectInput(
                session$ns("target_role"),
                "协作权限等级",
                choices = c("只读成员" = "viewer", "可编辑成员" = "editor"),
                selected = "viewer"
              ),
              div(
                class = "permission-inline-actions",
                actionButton(session$ns("grant_access"), "发送授权", class = "btn-primary", width = "100%"),
                actionButton(session$ns("revoke_access"), "撤销协作", class = "btn-danger", width = "100%")
              )
            ),
            app_card_panel(
              textInput(session$ns("owner_email"), "新负责人的邮箱", placeholder = "请输入新的负责人邮箱"),
              div(class = "permission-form-note", "负责人迁移后，原负责人会自动降级为可编辑成员。若目标邮箱尚未注册，会先保留待领取迁移记录。"),
              actionButton(session$ns("transfer_owner"), "确认迁移负责人", class = "btn-warning", width = "100%")
            )
          )
        ),
        app_card_box(
          width = 12,
          title = "协作权限预览",
          subtitle = "查看当前成员与待领取邀请",
          tone = "primary",
          status = "primary",
          solidHeader = FALSE,
          tabBox(
            width = 12,
            title = NULL,
            id = session$ns("permission_preview_tabs"),
            tabPanel("当前成员", DTOutput(session$ns("members_table"))),
            tabPanel("待领取邀请", DTOutput(session$ns("invite_table")))
          )
        )
      )
    }

    output$permission_notice <- renderUI({
      user <- get_current_user()
      if (is.null(user)) {
        return(app_card_note("请先登录后查看已授权空间并管理数据空间协作权限。"))
      }
      workspace_df <- manageable_workspaces()
      accessible_df <- accessible_workspaces()
      load_error <- attr(workspace_df, "load_error", exact = TRUE) %||% ""
      accessible_error <- attr(accessible_df, "load_error", exact = TRUE) %||% ""
      note_text <- if (nzchar(load_error) || nzchar(accessible_error)) {
        paste0("当前页只负责权限相关数据。若权限数据加载失败，不应影响“用户信息”页继续使用。", load_error, accessible_error)
      } else if (nrow(workspace_df) == 0 && nrow(accessible_df) > 0) {
        "你当前暂无可管理空间，但这里会展示已被授予访问权限的数据空间与当前角色。"
      } else if (nrow(workspace_df) == 0) {
        "当前账号尚无可管理空间，也未持有其它空间授权；页面保留明确的非空态说明。"
      } else {
        "当前页只负责数据空间协作权限。新增协作者、撤销协作和迁移负责人都通过邮箱完成，不展示库内用户选择器。"
      }
      app_card_note(note_text)
    })

    output$permission_content <- renderUI({
      user <- get_current_user()
      req(!is.null(user))
      tryCatch(
        build_permission_content(user),
        error = function(e) {
          app_card_box(
            width = 12,
            title = "权限管理",
            subtitle = "权限区渲染失败",
            tone = "danger",
            status = "danger",
            solidHeader = FALSE,
            app_card_note(paste0("权限区渲染失败：", e$message, "。请稍后重试。"))
          )
        }
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
      app_card_box(
        width = 12,
        title = "当前管理上下文",
        subtitle = "正在管理的数据空间与协作概况",
        tone = "primary",
        status = "primary",
        solidHeader = FALSE,
        div(
          class = "permission-status-grid",
          div(
            class = "permission-status-item",
            span(class = "permission-status-label", "数据空间"),
            span(class = "permission-status-value", workspace_row$name[[1]] %||% current_workspace_id())
          ),
          div(
            class = "permission-status-item",
            span(class = "permission-status-label", "当前负责人"),
            span(class = "permission-status-value", if (nzchar(owner_email)) owner_email else "待补充")
          ),
          div(
            class = "permission-status-item",
            span(class = "permission-status-label", "当前成员数"),
            span(class = "permission-status-value", as.character(nrow(memberships)))
          ),
          div(
            class = "permission-status-item",
            span(class = "permission-status-label", "待领取邀请"),
            span(class = "permission-status-value", as.character(sum(invites$status == "pending", na.rm = TRUE)))
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

    output$accessible_workspace_table <- renderDT({
      refresh_tick()
      accessible_df <- accessible_workspaces()
      req(nrow(accessible_df) > 0)
      role_label <- dplyr::case_when(
        accessible_df$role == "editor" ~ "可编辑成员",
        accessible_df$role == "viewer" ~ "只读成员",
        TRUE ~ accessible_df$role %||% ""
      )
      owner_label <- ifelse(
        nzchar(accessible_df$owner_email %||% ""),
        accessible_df$owner_email,
        accessible_df$owner_username %||% ""
      )
      joined_at <- if ("membership_created_at" %in% names(accessible_df)) {
        format(as.POSIXct(accessible_df$membership_created_at), "%Y-%m-%d %H:%M")
      } else {
        rep("", nrow(accessible_df))
      }
      table_df <- data.frame(
        数据空间 = accessible_df$name %||% character(0),
        我的角色 = role_label,
        负责人 = owner_label,
        加入时间 = joined_at,
        check.names = FALSE,
        stringsAsFactors = FALSE
      )
      datatable(
        table_df,
        rownames = FALSE,
        options = list(pageLength = 6, autoWidth = TRUE, dom = "tip"),
        class = "stripe hover compact"
      )
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
