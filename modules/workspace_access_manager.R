workspace_access_manager_ui <- function(id) {
  ns <- NS(id)
  tagList(
    app_card_dependencies(),
    tags$head(
      tags$style(HTML("
        .access-note {
          color: #5f6b7a;
          line-height: 1.7;
        }
        .access-grid {
          display: grid;
          grid-template-columns: minmax(320px, 420px) minmax(420px, 1fr);
          gap: 18px;
        }
        .access-stack {
          display: grid;
          gap: 18px;
        }
        .access-panel-list {
          display: grid;
          gap: 12px;
        }
        .access-form-note {
          color: #6b7785;
          font-size: 12px;
          line-height: 1.6;
          margin-top: 8px;
          margin-bottom: 10px;
        }
        .access-inline-actions {
          display: grid;
          grid-template-columns: repeat(2, minmax(0, 1fr));
          gap: 10px;
        }
        .access-status-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
          gap: 10px;
        }
        .access-status-item {
          padding: 10px 12px;
          border-radius: 10px;
          border: 1px solid #e8eef5;
          background: #f8fbff;
        }
        .access-status-label {
          display: block;
          margin-bottom: 4px;
          color: #7b8794;
          font-size: 12px;
        }
        .access-status-value {
          display: block;
          color: #243447;
          font-size: 14px;
          font-weight: 600;
          line-height: 1.5;
        }
        .access-security-hint {
          color: #6b7785;
          font-size: 12px;
          line-height: 1.7;
        }
        @media (max-width: 991px) {
          .access-grid {
            grid-template-columns: 1fr;
          }
        }
      "))
    ),
    app_card_box(
      width = 12,
      title = "用户和权限",
      subtitle = "账号安全与数据空间协作统一收口",
      tone = "primary",
      status = "primary",
      solidHeader = FALSE,
      uiOutput(ns("access_notice"))
    ),
    uiOutput(ns("access_content"))
  )
}

workspace_access_manager_server <- function(id, pg_pool, current_user = NULL, on_user_updated = NULL) {
  moduleServer(id, function(input, output, session) {
    `%||%` <- function(x, y) if (is.null(x)) y else x
    refresh_tick <- reactiveVal(0)

    get_current_user <- function() {
      if (is.null(current_user)) {
        return(NULL)
      }
      current_user()
    }

    update_current_user <- function(user) {
      if (!is.null(on_user_updated) && is.function(on_user_updated)) {
        on_user_updated(user)
      }
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

    output$access_notice <- renderUI({
      user <- get_current_user()
      if (is.null(user)) {
        return(app_card_note("请先登录后查看用户信息并管理数据空间权限。"))
      }
      workspace_df <- manageable_workspaces()
      accessible_df <- accessible_workspaces()
      load_error <- attr(workspace_df, "load_error", exact = TRUE) %||% ""
      accessible_error <- attr(accessible_df, "load_error", exact = TRUE) %||% ""
      note_text <- if (nzchar(load_error) || nzchar(accessible_error)) {
        paste0("当前页面分为“用户信息”和“权限管理”两部分。权限相关数据暂时加载失败，已优先保留左侧用户信息与信息变更控件。", load_error, accessible_error)
      } else if (nrow(workspace_df) == 0 && nrow(accessible_df) > 0) {
        "左侧用于查看基础用户信息与少量信息变更；你当前暂无可管理空间，但右侧会展示已被授予访问权限的数据空间与当前角色。"
      } else if (nrow(workspace_df) == 0) {
        "当前页面分为“用户信息”和“权限管理”两部分。即使当前没有可管理空间，你仍可以在左侧查看基础资料并完成邮箱相关信息变更。"
      } else {
        "左侧用于查看基础用户信息与少量信息变更；右侧继续只负责数据空间协作权限。新增协作者、撤销协作和迁移负责人都通过邮箱完成，不展示库内用户选择器。"
      }
      app_card_note(note_text)
    })

    output$access_content <- renderUI({
      user <- get_current_user()
      req(!is.null(user))

      workspace_df <- manageable_workspaces()
      accessible_df <- accessible_workspaces()
      load_error <- attr(workspace_df, "load_error", exact = TRUE) %||% ""
      accessible_error <- attr(accessible_df, "load_error", exact = TRUE) %||% ""
      workspace_choices <- if (nrow(workspace_df) > 0) setNames(workspace_df$id, workspace_df$name) else character(0)

      right_column <- if (nzchar(load_error) || nzchar(accessible_error)) {
        app_card_box(
          width = 12,
          title = "权限管理",
          subtitle = "权限数据加载异常",
          tone = "danger",
          status = "danger",
          solidHeader = FALSE,
          app_card_note(paste0("当前无法加载可管理空间或已授权空间数据。", load_error, accessible_error, " 左侧用户信息仍可正常使用，请稍后重试或联系管理员检查数据连接。"))
        )
      } else if (nrow(workspace_df) == 0 && nrow(accessible_df) > 0) {
        app_card_box(
          width = 12,
          title = "我的已授权空间",
          subtitle = "查看当前被授予访问权限的数据空间与角色",
          tone = "primary",
          status = "primary",
          solidHeader = FALSE,
          app_card_note("当前账号不是这些数据空间的负责人，因此这里展示的是你被授予的访问权限信息，而不是成员管理表单。"),
          app_card_panel(
            DTOutput(session$ns("accessible_workspace_table"))
          )
        )
      } else if (nrow(workspace_df) == 0) {
        app_card_box(
          width = 12,
          title = "权限管理",
          subtitle = "当前暂无可管理空间",
          tone = "warning",
          status = "warning",
          solidHeader = FALSE,
          app_card_note("当前账号名下还没有可管理的数据空间，因此权限管理区暂时不显示协作设置表单。后续创建或获得可管理空间后，这里会自动出现成员授权、撤销和负责人迁移能力。")
        )
      } else {
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
              class = "access-panel-list",
              app_card_panel(
                selectInput(session$ns("managed_workspace_id"), "选择要管理的数据空间", choices = workspace_choices),
                div(class = "access-form-note", "未注册邮箱会自动记录为待领取邀请；已注册邮箱会直接更新成员权限。")
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
                  class = "access-inline-actions",
                  actionButton(session$ns("grant_access"), "发送授权", class = "btn-primary", width = "100%"),
                  actionButton(session$ns("revoke_access"), "撤销协作", class = "btn-danger", width = "100%")
                )
              ),
              app_card_panel(
                textInput(session$ns("owner_email"), "新负责人的邮箱", placeholder = "请输入新的负责人邮箱"),
                div(class = "access-form-note", "负责人迁移后，原负责人会自动降级为可编辑成员。若目标邮箱尚未注册，会先保留待领取迁移记录。"),
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
              id = session$ns("access_preview_tabs"),
              tabPanel("当前成员", DTOutput(session$ns("members_table"))),
              tabPanel("待领取邀请", DTOutput(session$ns("invite_table")))
            )
          )
        )
      }

      div(
        class = "access-grid",
        div(
          class = "access-stack",
          app_card_box(
            width = 12,
            title = "用户信息",
            subtitle = "基础资料与少量信息变更",
            tone = "info",
            status = "info",
            solidHeader = FALSE,
            div(
              class = "access-panel-list",
              app_card_panel(
                tags$strong("基础信息"),
                div(
                  class = "access-status-grid",
                  div(
                    class = "access-status-item",
                    span(class = "access-status-label", "用户名"),
                    span(class = "access-status-value", user$username %||% "")
                  ),
                  div(
                    class = "access-status-item",
                    span(class = "access-status-label", "账号类型"),
                    span(class = "access-status-value", if (isTRUE(user$is_admin)) "系统管理员" else "普通用户")
                  ),
                  div(
                    class = "access-status-item",
                    span(class = "access-status-label", "当前邮箱"),
                    span(class = "access-status-value", if (nzchar(user$email %||% "")) user$email else "未设置邮箱")
                  ),
                  div(
                    class = "access-status-item",
                    span(class = "access-status-label", "邮箱状态"),
                    span(class = "access-status-value", if (isTRUE(user$email_verified)) "已验证" else "未验证")
                  )
                )
              ),
              app_card_panel(
                tags$strong("绑定邮箱"),
                div(class = "access-security-hint", "当前邮箱验证改为登录后自助完成；未验证时可先发送验证码，再输入验证码确认。"),
                textInput(session$ns("current_email_verify_code"), "验证码", placeholder = "请输入 6 位验证码"),
                div(
                  class = "access-inline-actions",
                  actionButton(session$ns("request_current_email_verify"), "发送验证码", class = "btn-info", width = "100%"),
                  actionButton(session$ns("submit_current_email_verify"), "确认验证", class = "btn-primary", width = "100%")
                )
              ),
              app_card_panel(
                tags$strong("邮箱换绑"),
                div(class = "access-security-hint", "如需更换邮箱，可在这里完成邮箱换绑。先输入当前密码与新邮箱，发送换绑验证码后再确认换绑。"),
                passwordInput(session$ns("change_email_current_password"), "当前密码", placeholder = "请输入当前密码"),
                textInput(session$ns("change_email_new_email"), "新邮箱", placeholder = "请输入新的邮箱地址"),
                textInput(session$ns("change_email_code"), "换绑验证码", placeholder = "请输入 6 位验证码"),
                div(
                  class = "access-inline-actions",
                  actionButton(session$ns("request_email_change_code"), "发送换绑验证码", class = "btn-info", width = "100%"),
                  actionButton(session$ns("submit_email_change"), "确认换绑", class = "btn-primary", width = "100%")
                )
              ),
              app_card_panel(
                tags$strong("修改密码"),
                div(class = "access-security-hint", "通过当前密码验证后，直接在这里修改账号密码。该区域仅保留基础密码修改，不扩展其它账号管理能力。"),
                passwordInput(session$ns("password_change_current_password"), "当前密码", placeholder = "请输入当前密码"),
                passwordInput(session$ns("password_change_new_password"), "新密码", placeholder = "至少 8 位"),
                passwordInput(session$ns("password_change_confirm_password"), "确认新密码", placeholder = "请再次输入新密码"),
                actionButton(session$ns("submit_password_change"), "修改密码", class = "btn-warning", width = "100%")
              )
            )
          )
        ),
        div(class = "access-stack", right_column)
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
          class = "access-status-grid",
          div(
            class = "access-status-item",
            span(class = "access-status-label", "数据空间"),
            span(class = "access-status-value", workspace_row$name[[1]] %||% current_workspace_id())
          ),
          div(
            class = "access-status-item",
            span(class = "access-status-label", "当前负责人"),
            span(class = "access-status-value", if (nzchar(owner_email)) owner_email else "待补充")
          ),
          div(
            class = "access-status-item",
            span(class = "access-status-label", "当前成员数"),
            span(class = "access-status-value", as.character(nrow(memberships)))
          ),
          div(
            class = "access-status-item",
            span(class = "access-status-label", "待领取邀请"),
            span(class = "access-status-value", as.character(sum(invites$status == "pending", na.rm = TRUE)))
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

    observeEvent(input$request_current_email_verify, {
      user <- get_current_user()
      req(!is.null(user))
      result <- tryCatch(
        auth_request_current_email_verification(pg_pool, user$id, purpose = "register"),
        error = function(e) list(success = FALSE, message = paste0("发送邮箱验证码失败：", e$message))
      )
      if (!isTRUE(result$success)) {
        showNotification(result$message, type = "error")
        return()
      }
      showNotification(result$message, type = "message")
    })

    observeEvent(input$submit_current_email_verify, {
      user <- get_current_user()
      req(!is.null(user))
      result <- tryCatch(
        auth_verify_email_code(pg_pool, user$email %||% "", input$current_email_verify_code %||% "", purpose = "register"),
        error = function(e) list(success = FALSE, message = paste0("邮箱验证失败：", e$message))
      )
      if (!isTRUE(result$success)) {
        showNotification(result$message, type = "error")
        return()
      }
      update_current_user(result$user)
      refresh_tick(as.numeric(Sys.time()))
      updateTextInput(session, "current_email_verify_code", value = "")
      showNotification(result$message, type = "message")
    })

    observeEvent(input$request_email_change_code, {
      user <- get_current_user()
      req(!is.null(user))
      result <- tryCatch(
        auth_request_email_change(
          pg_pool,
          user$id,
          input$change_email_current_password %||% "",
          input$change_email_new_email %||% ""
        ),
        error = function(e) list(success = FALSE, message = paste0("发送换绑验证码失败：", e$message))
      )
      if (!isTRUE(result$success)) {
        showNotification(result$message, type = "error")
        return()
      }
      showNotification(result$message, type = "message")
    })

    observeEvent(input$submit_email_change, {
      user <- get_current_user()
      req(!is.null(user))
      result <- tryCatch(
        auth_confirm_email_change(
          pg_pool,
          user$id,
          input$change_email_current_password %||% "",
          input$change_email_new_email %||% "",
          input$change_email_code %||% ""
        ),
        error = function(e) list(success = FALSE, message = paste0("邮箱换绑失败：", e$message))
      )
      if (!isTRUE(result$success)) {
        showNotification(result$message, type = "error")
        return()
      }
      tryCatch(
        service_claim_workspace_invites(pg_pool, result$user$id, result$user$email),
        error = function(e) invisible(NULL)
      )
      update_current_user(result$user)
      refresh_tick(as.numeric(Sys.time()))
      updatePasswordInput(session, "change_email_current_password", value = "")
      updateTextInput(session, "change_email_new_email", value = "")
      updateTextInput(session, "change_email_code", value = "")
      showNotification(result$message, type = "message")
    })

    observeEvent(input$submit_password_change, {
      user <- get_current_user()
      req(!is.null(user))
      new_password <- input$password_change_new_password %||% ""
      confirm_password <- input$password_change_confirm_password %||% ""
      if (!identical(new_password, confirm_password)) {
        showNotification("两次输入的新密码不一致", type = "error")
        return()
      }
      result <- tryCatch(
        auth_change_password(
          pg_pool,
          user$id,
          input$password_change_current_password %||% "",
          new_password
        ),
        error = function(e) list(success = FALSE, message = paste0("修改密码失败：", e$message))
      )
      if (!isTRUE(result$success)) {
        showNotification(result$message, type = "error")
        return()
      }
      updatePasswordInput(session, "password_change_current_password", value = "")
      updatePasswordInput(session, "password_change_new_password", value = "")
      updatePasswordInput(session, "password_change_confirm_password", value = "")
      showNotification(result$message, type = "message")
    })
  })
}
