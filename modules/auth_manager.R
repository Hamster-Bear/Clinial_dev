auth_manager_styles <- function() {
  tagList(
    app_card_dependencies(),
    tags$head(
      tags$style(HTML("
      .auth-page-shell {
        min-height: calc(100vh - 130px);
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 28px 12px 36px;
      }
      .auth-page-column {
        width: 100%;
        max-width: 620px;
      }
      .auth-page-column .app-card.box {
        margin-bottom: 16px;
      }
      .auth-intro {
        color: #5f6b7a;
        line-height: 1.75;
      }
      .auth-panel-list {
        display: grid;
        gap: 10px;
      }
      .auth-panel-list .app-card__panel {
        background: #fbfdff;
      }
      .auth-primary-button {
        border-radius: 8px !important;
        padding-top: 10px !important;
        padding-bottom: 10px !important;
        font-weight: 600 !important;
      }
      .auth-hint {
        color: #6b7785;
        font-size: 12px;
        line-height: 1.7;
      }
      .auth-secondary-actions {
        display: flex;
        gap: 10px;
        flex-wrap: wrap;
      }
      .auth-secondary-link {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-width: 140px;
        padding: 10px 14px;
        border: 1px solid #d2d9e1;
        border-radius: 8px;
        background: #f8fafc;
        color: #3c4b5b !important;
        font-weight: 600;
        text-decoration: none !important;
      }
      .auth-secondary-link:hover,
      .auth-secondary-link:focus {
        background: #eef3f8;
        color: #1f2d3d !important;
      }
    "))
    )
  )
}

auth_manager_tabs <- function(id) {
  ns <- NS(id)
  list(
    tabItem(
      tabName = "login",
      div(
        class = "auth-page-shell",
        div(
          class = "auth-page-column",
          app_card_box(
            width = 12,
            title = "欢迎进入 AutoTFL",
            subtitle = "登录、注册与密码找回",
            tone = "primary",
            status = "primary",
            solidHeader = FALSE,
            app_card_note("请先登录后进入工作台。支持用户名或邮箱登录；邮箱验证、邮箱换绑和协作邀请均使用邮箱完成。")
          ),
          app_card_box(
            width = 12,
            title = "登录",
            subtitle = "输入账号信息进入工作台",
            tone = "info",
            status = "info",
            solidHeader = FALSE,
            div(
              class = "auth-panel-list",
              app_card_panel(
                textInput(ns("login_identity"), "用户名或邮箱", placeholder = "请输入用户名或邮箱"),
                passwordInput(ns("login_password"), "密码", placeholder = "请输入密码"),
                actionButton(ns("login_submit"), "登录", class = "btn-primary auth-primary-button", width = "100%")
              )
            ),
            br(),
            div(
              class = "auth-secondary-actions",
              actionLink(ns("goto_register"), "注册账号", class = "auth-secondary-link"),
              actionLink(ns("goto_reset_password"), "忘记密码", class = "auth-secondary-link")
            )
          )
        )
      )
    ),
    tabItem(
      tabName = "register",
      div(
        class = "auth-page-shell",
        div(
          class = "auth-page-column",
          app_card_box(
            width = 12,
            title = "创建账号",
            subtitle = "创建基础账号",
            tone = "info",
            status = "info",
            solidHeader = FALSE,
            app_card_note("注册后可由管理员开放数据库管理能力，并可通过邮箱加入协作数据空间；邮箱验证在登录后的用户信息页面中完成。")
          ),
          app_card_box(
            width = 12,
            title = "注册",
            subtitle = "填写基础注册信息",
            tone = "info",
            status = "info",
            solidHeader = FALSE,
            div(
              class = "auth-panel-list",
              app_card_panel(
                textInput(ns("register_username"), "用户名", placeholder = "3-32 位小写字母、数字、下划线、点或中划线"),
                textInput(ns("register_email"), "邮箱", placeholder = "用于协作授权与找回密码"),
                passwordInput(ns("register_password"), "密码", placeholder = "至少 8 位"),
                passwordInput(ns("register_password_confirm"), "确认密码", placeholder = "请再次输入密码"),
                actionButton(ns("register_submit"), "注册", class = "btn-info auth-primary-button", width = "100%")
              )
            ),
            br(),
            tags$small(class = "auth-hint", "注册成功后可直接登录；邮箱验证请在登录后的用户信息中自行完成。数据库管理权限仍需由管理员开放。"),
            br(),
            br(),
            div(class = "auth-secondary-actions", actionLink(ns("goto_login_from_register"), "返回登录", class = "auth-secondary-link"))
          )
        )
      )
    ),
    tabItem(
      tabName = "reset_password",
      div(
        class = "auth-page-shell",
        div(
          class = "auth-page-column",
          app_card_box(
            width = 12,
            title = "找回密码",
            subtitle = "独立找回流程",
            tone = "warning",
            status = "warning",
            solidHeader = FALSE,
            app_card_note("通过注册邮箱申请重置验证码，再用验证码设置新密码。")
          ),
          app_card_box(
            width = 12,
            title = "忘记密码",
            subtitle = "使用验证码重置密码",
            tone = "warning",
            status = "warning",
            solidHeader = FALSE,
            div(
              class = "auth-panel-list",
              app_card_panel(
                textInput(ns("reset_email"), "邮箱", placeholder = "请输入注册邮箱"),
                textInput(ns("reset_code"), "重置验证码", placeholder = "请输入 6 位验证码"),
                passwordInput(ns("reset_new_password"), "新密码", placeholder = "至少 8 位"),
                fluidRow(
                  column(6, actionButton(ns("request_reset"), "获取重置码", class = "auth-primary-button", width = "100%")),
                  column(6, actionButton(ns("reset_submit"), "重置密码", class = "btn-warning auth-primary-button", width = "100%"))
                )
              )
            ),
            br(),
            tags$small(class = "auth-hint", "测试环境默认通过 console 输出重置验证码；生产环境接入真实邮件投递后再对外开放。"),
            br(),
            br(),
            div(class = "auth-secondary-actions", actionLink(ns("goto_login_from_reset"), "返回登录", class = "auth-secondary-link"))
          )
        )
      )
    )
  )
}

auth_manager_server <- function(id, pg_pool, on_login, goto_tab, send_loading = NULL) {
  moduleServer(id, function(input, output, session) {
    `%||%` <- function(x, y) if (is.null(x)) y else x

    set_loading <- function(action, text = NULL, delay_ms = NULL) {
      if (!is.null(send_loading) && is.function(send_loading)) {
        send_loading(action, text = text, delay_ms = delay_ms)
      }
    }

    observeEvent(input$register_submit, {
      set_loading("show", "正在连接服务...")
      on.exit(set_loading("hide"), add = TRUE)
      username <- input$register_username %||% ""
      email <- input$register_email %||% ""
      password <- input$register_password %||% ""
      password_confirm <- input$register_password_confirm %||% ""
      if (!identical(password, password_confirm)) {
        showNotification("两次输入的密码不一致", type = "warning")
        return()
      }
      result <- tryCatch(
        auth_register_user(pg_pool, username, email, password),
        error = function(e) list(success = FALSE, message = paste0("注册失败：", e$message), user = NULL)
      )
      if (!isTRUE(result$success)) {
        showNotification(result$message, type = "error")
        return()
      }
      updateTextInput(session, "register_username", value = "")
      updateTextInput(session, "register_email", value = "")
      updateTextInput(session, "register_password", value = "")
      updateTextInput(session, "register_password_confirm", value = "")
      updateTextInput(session, "login_identity", value = auth_normalize_email(email))
      updateTextInput(session, "reset_email", value = auth_normalize_email(email))
      goto_tab("login")
      showNotification(result$message, type = "message")
    })

    observeEvent(input$login_submit, {
      set_loading("show", "正在连接服务...")
      result <- tryCatch(
        auth_authenticate_user(pg_pool, input$login_identity %||% "", input$login_password %||% ""),
        error = function(e) list(success = FALSE, message = paste0("登录失败：", e$message), user = NULL)
      )
      if (!isTRUE(result$success)) {
        set_loading("hide")
        showNotification(result$message, type = "error")
        return()
      }
      tryCatch(
        service_claim_workspace_invites(pg_pool, result$user$id, result$user$email),
        error = function(e) invisible(NULL)
      )
      set_loading("show", "正在进入工作台...")
      updateTextInput(session, "login_password", value = "")
      updateTextInput(session, "login_identity", value = "")
      on_login(result$user)
      goto_tab("db_manage")
      showNotification(result$message, type = "message")
      if (!isTRUE(result$user$email_verified) && nzchar(result$user$email %||% "")) {
        showNotification("当前邮箱尚未验证，可在左侧账号设置区点击“验证邮箱”完成验证。", type = "warning", duration = 7)
      }
      set_loading("hide_delayed", delay_ms = 450)
    })

    observeEvent(input$goto_register, {
      goto_tab("register")
    })

    observeEvent(input$goto_reset_password, {
      goto_tab("reset_password")
    })

    observeEvent(input$goto_login_from_register, {
      goto_tab("login")
    })

    observeEvent(input$goto_login_from_reset, {
      goto_tab("login")
    })

    observeEvent(input$request_reset, {
      set_loading("show", "正在连接服务...")
      on.exit(set_loading("hide"), add = TRUE)
      result <- tryCatch(
        auth_request_password_reset(pg_pool, input$reset_email %||% ""),
        error = function(e) list(success = FALSE, message = paste0("重置验证码发送失败：", e$message))
      )
      if (!isTRUE(result$success)) {
        showNotification(result$message, type = "error")
        return()
      }
      showNotification(result$message, type = "message")
    })

    observeEvent(input$reset_submit, {
      set_loading("show", "正在连接服务...")
      on.exit(set_loading("hide"), add = TRUE)
      result <- tryCatch(
        auth_reset_password(
          pg_pool,
          input$reset_email %||% "",
          input$reset_code %||% "",
          input$reset_new_password %||% ""
        ),
        error = function(e) list(success = FALSE, message = paste0("密码重置失败：", e$message))
      )
      if (!isTRUE(result$success)) {
        showNotification(result$message, type = "error")
        return()
      }
      updateTextInput(session, "login_identity", value = auth_normalize_email(input$reset_email %||% ""))
      updateTextInput(session, "login_password", value = "")
      updateTextInput(session, "reset_code", value = "")
      updateTextInput(session, "reset_new_password", value = "")
      showNotification(result$message, type = "message")
    })
  })
}
