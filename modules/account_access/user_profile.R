user_profile_ui <- function(id) {
  ns <- NS(id)
  copy <- ACCOUNT_ENTRY_COPY$profile
  tagList(
    app_card_dependencies(),
    tags$head(
      tags$style(HTML("
        .profile-panel-list {
          display: grid;
          gap: 12px;
        }
        .profile-page-stack {
          display: grid;
          gap: 14px;
        }
        .profile-security-hint {
          color: #6b7785;
          font-size: 12px;
          line-height: 1.7;
        }
        .profile-workbench-note {
          margin-bottom: 12px;
        }
      "))
    ),
    uiOutput(ns("profile_content"))
  )
}

user_profile_server <- function(id, pg_pool, current_user = NULL, on_user_updated = NULL) {
  moduleServer(id, function(input, output, session) {
    `%||%` <- function(x, y) if (is.null(x)) y else x
    copy <- ACCOUNT_ENTRY_COPY$profile

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

    build_profile_notice <- function(user) {
      if (is.null(user)) {
        return("请先登录后查看个人信息与账号设置。")
      }
      if (isTRUE(user$email_verified)) {
        return("在这里查看账号信息，并完成邮箱验证、邮箱换绑和密码修改。")
      }
      "当前邮箱尚未验证，可在本页直接发送验证码并完成验证。邮箱验证不会阻断登录，但建议尽快完成，以便后续协作授权与邮箱换绑流程正常使用。"
    }

    build_profile_content <- function(user) {
      username_value <- user$username %||% ""
      role_value <- if (isTRUE(user$is_admin)) "系统管理员" else "普通用户"
      email_value <- if (nzchar(user$email %||% "")) user$email else "未设置邮箱"
      email_status_value <- if (isTRUE(user$email_verified)) "已验证" else "未验证"
      email_status_tone <- if (isTRUE(user$email_verified)) "success" else "warning"
      email_status_meta <- if (isTRUE(user$email_verified)) {
        "当前可直接用于协作授权与邮箱换绑。"
      } else {
        "建议先完成邮箱验证，避免后续协作与换绑流程受限。"
      }

      tagList(
        div(
          class = "profile-page-stack",
          app_card_box(
            width = 12,
            title = copy$title,
            subtitle = copy$subtitle,
            tone = "primary",
            status = "primary",
            solidHeader = FALSE,
            app_card_note(build_profile_notice(user)),
            div(
              class = "app-stat-grid",
              app_stat_card("用户名", username_value, meta = "当前登录账号", tone = "primary"),
              app_stat_card("账号类型", role_value, meta = "系统角色与入口能力边界", tone = "info"),
              app_stat_card("当前邮箱", email_value, meta = "账号主邮箱", tone = "primary"),
              app_stat_card("邮箱状态", email_status_value, meta = email_status_meta, tone = email_status_tone)
            )
          ),
          app_card_box(
            width = 12,
            title = copy$workbench_title,
            subtitle = copy$workbench_subtitle,
            tone = "info",
            status = "info",
            solidHeader = FALSE,
            div(
              class = "profile-workbench-note",
              app_card_note("可在这里完成邮箱验证、邮箱换绑和密码修改。")
            )
          ),
          tabBox(
            width = 12,
            title = NULL,
            id = session$ns("profile_action_tabs"),
            tabPanel(
              copy$tabs$verify_email,
              div(
                class = "profile-panel-list",
                app_card_panel(
                  tags$strong("邮箱验证"),
                  div(class = "profile-security-hint", "登录后可在这里完成邮箱验证；未验证时可先发送验证码，再输入验证码确认。"),
                  textInput(session$ns("current_email_verify_code"), "验证码", placeholder = "请输入 6 位验证码"),
                  div(
                    class = "app-action-row",
                    actionButton(session$ns("request_current_email_verify"), "发送验证码", class = "btn-info app-action-btn"),
                    actionButton(session$ns("submit_current_email_verify"), "确认验证", class = "btn-primary app-action-btn")
                  )
                )
              )
            ),
            tabPanel(
              copy$tabs$change_email,
              div(
                class = "profile-panel-list",
                app_card_panel(
                  tags$strong("邮箱换绑"),
                  div(class = "profile-security-hint", "如需更换邮箱，可在这里完成邮箱换绑。先输入当前密码与新邮箱，发送换绑验证码后再确认换绑。"),
                  passwordInput(session$ns("change_email_current_password"), "当前密码", placeholder = "请输入当前密码"),
                  textInput(session$ns("change_email_new_email"), "新邮箱", placeholder = "请输入新的邮箱地址"),
                  textInput(session$ns("change_email_code"), "换绑验证码", placeholder = "请输入 6 位验证码"),
                  div(
                    class = "app-action-row",
                    actionButton(session$ns("request_email_change_code"), "发送换绑验证码", class = "btn-info app-action-btn"),
                    actionButton(session$ns("submit_email_change"), "确认换绑", class = "btn-primary app-action-btn")
                  )
                )
              )
            ),
            tabPanel(
              copy$tabs$change_password,
              div(
                class = "profile-panel-list",
                app_card_panel(
                  tags$strong("修改密码"),
                  div(class = "profile-security-hint", "通过当前密码验证后，可在这里修改账号密码。"),
                  passwordInput(session$ns("password_change_current_password"), "当前密码", placeholder = "请输入当前密码"),
                  passwordInput(session$ns("password_change_new_password"), "新密码", placeholder = "至少 8 位"),
                  passwordInput(session$ns("password_change_confirm_password"), "确认新密码", placeholder = "请再次输入新密码"),
                  div(
                    class = "app-action-row",
                    actionButton(session$ns("submit_password_change"), "修改密码", class = "btn-warning app-action-btn")
                  )
                )
              )
            )
          )
        )
      )
    }

    output$profile_content <- renderUI({
      user <- get_current_user()
      req(!is.null(user))
      tryCatch(
        build_profile_content(user),
        error = function(e) {
          app_card_box(
            width = 12,
            title = copy$title,
            subtitle = copy$subtitle,
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
