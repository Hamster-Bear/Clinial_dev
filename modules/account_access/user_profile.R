user_profile_ui <- function(id) {
  ns <- NS(id)
  tagList(
    app_card_dependencies(),
    tags$head(
      tags$style(HTML("
        .profile-panel-list {
          display: grid;
          gap: 12px;
        }
        .profile-inline-actions {
          display: grid;
          grid-template-columns: repeat(2, minmax(0, 1fr));
          gap: 10px;
        }
        .profile-status-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
          gap: 10px;
        }
        .profile-status-item {
          padding: 10px 12px;
          border-radius: 10px;
          border: 1px solid #e8eef5;
          background: #f8fbff;
        }
        .profile-status-label {
          display: block;
          margin-bottom: 4px;
          color: #7b8794;
          font-size: 12px;
        }
        .profile-status-value {
          display: block;
          color: #243447;
          font-size: 14px;
          font-weight: 600;
          line-height: 1.5;
        }
        .profile-security-hint {
          color: #6b7785;
          font-size: 12px;
          line-height: 1.7;
        }
      "))
    ),
    app_card_box(
      width = 12,
      title = "用户信息",
      subtitle = "基础资料与少量信息变更",
      tone = "primary",
      status = "primary",
      solidHeader = FALSE,
      uiOutput(ns("profile_notice"))
    ),
    uiOutput(ns("profile_content"))
  )
}

user_profile_server <- function(id, pg_pool, current_user = NULL, on_user_updated = NULL) {
  moduleServer(id, function(input, output, session) {
    `%||%` <- function(x, y) if (is.null(x)) y else x

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

    build_profile_content <- function(user) {
      app_card_box(
        width = 12,
        title = "用户信息",
        subtitle = "基础资料与少量信息变更",
        tone = "info",
        status = "info",
        solidHeader = FALSE,
        div(
          class = "profile-panel-list",
          app_card_panel(
            tags$strong("基础信息"),
            div(
              class = "profile-status-grid",
              div(
                class = "profile-status-item",
                span(class = "profile-status-label", "用户名"),
                span(class = "profile-status-value", user$username %||% "")
              ),
              div(
                class = "profile-status-item",
                span(class = "profile-status-label", "账号类型"),
                span(class = "profile-status-value", if (isTRUE(user$is_admin)) "系统管理员" else "普通用户")
              ),
              div(
                class = "profile-status-item",
                span(class = "profile-status-label", "当前邮箱"),
                span(class = "profile-status-value", if (nzchar(user$email %||% "")) user$email else "未设置邮箱")
              ),
              div(
                class = "profile-status-item",
                span(class = "profile-status-label", "邮箱状态"),
                span(class = "profile-status-value", if (isTRUE(user$email_verified)) "已验证" else "未验证")
              )
            )
          ),
          app_card_panel(
            tags$strong("绑定邮箱"),
            div(class = "profile-security-hint", "当前邮箱验证改为登录后自助完成；未验证时可先发送验证码，再输入验证码确认。"),
            textInput(session$ns("current_email_verify_code"), "验证码", placeholder = "请输入 6 位验证码"),
            div(
              class = "profile-inline-actions",
              actionButton(session$ns("request_current_email_verify"), "发送验证码", class = "btn-info", width = "100%"),
              actionButton(session$ns("submit_current_email_verify"), "确认验证", class = "btn-primary", width = "100%")
            )
          ),
          app_card_panel(
            tags$strong("邮箱换绑"),
            div(class = "profile-security-hint", "如需更换邮箱，可在这里完成邮箱换绑。先输入当前密码与新邮箱，发送换绑验证码后再确认换绑。"),
            passwordInput(session$ns("change_email_current_password"), "当前密码", placeholder = "请输入当前密码"),
            textInput(session$ns("change_email_new_email"), "新邮箱", placeholder = "请输入新的邮箱地址"),
            textInput(session$ns("change_email_code"), "换绑验证码", placeholder = "请输入 6 位验证码"),
            div(
              class = "profile-inline-actions",
              actionButton(session$ns("request_email_change_code"), "发送换绑验证码", class = "btn-info", width = "100%"),
              actionButton(session$ns("submit_email_change"), "确认换绑", class = "btn-primary", width = "100%")
            )
          ),
          app_card_panel(
            tags$strong("修改密码"),
            div(class = "profile-security-hint", "通过当前密码验证后，直接在这里修改账号密码。该区域仅保留基础密码修改，不扩展其它账号管理能力。"),
            passwordInput(session$ns("password_change_current_password"), "当前密码", placeholder = "请输入当前密码"),
            passwordInput(session$ns("password_change_new_password"), "新密码", placeholder = "至少 8 位"),
            passwordInput(session$ns("password_change_confirm_password"), "确认新密码", placeholder = "请再次输入新密码"),
            actionButton(session$ns("submit_password_change"), "修改密码", class = "btn-warning", width = "100%")
          )
        )
      )
    }

    output$profile_notice <- renderUI({
      user <- get_current_user()
      if (is.null(user)) {
        return(app_card_note("请先登录后查看个人信息与账号设置。"))
      }
      if (isTRUE(user$email_verified)) {
        return(app_card_note("当前页仅保留基础用户信息与少量信息变更控件，如绑定邮箱、邮箱换绑和修改密码。"))
      }
      app_card_note("当前邮箱尚未验证，可在本页直接发送验证码并完成验证。邮箱验证不会阻断登录，但建议尽快完成，以便后续协作授权与邮箱换绑流程正常使用。")
    })

    output$profile_content <- renderUI({
      user <- get_current_user()
      req(!is.null(user))
      tryCatch(
        build_profile_content(user),
        error = function(e) {
          app_card_box(
            width = 12,
            title = "用户信息",
            subtitle = "基础资料与少量信息变更",
            tone = "danger",
            status = "danger",
            solidHeader = FALSE,
            app_card_note(paste0("用户信息区渲染失败：", e$message, "。请稍后重试。"))
          )
        }
      )
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
