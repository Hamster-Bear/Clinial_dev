auth_manager_styles <- function() {
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
      .auth-page-column .box {
        margin-bottom: 16px;
        box-shadow: 0 10px 24px rgba(31, 45, 61, 0.08);
      }
      .auth-intro {
        color: #5f6b7a;
        line-height: 1.75;
      }
      .auth-hint {
        color: #6b7785;
        font-size: 12px;
        line-height: 1.7;
      }
    "))
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
          box(
            width = 12,
            title = "欢迎进入 AutoTFL",
            status = "primary",
            solidHeader = TRUE,
            p(class = "auth-intro", "请先登录后进入工作台。当前支持用户名或邮箱登录，后续协作能力会继续围绕邮箱身份扩展。")
          ),
          box(
            width = 12,
            title = "登录",
            status = "primary",
            solidHeader = TRUE,
            textInput(ns("login_identity"), "用户名或邮箱", placeholder = "请输入用户名或邮箱"),
            passwordInput(ns("login_password"), "密码", placeholder = "请输入密码"),
            actionButton(ns("login_submit"), "登录", class = "btn-primary", width = "100%")
          ),
          box(
            width = 12,
            title = "当前工具声明",
            status = "warning",
            solidHeader = TRUE,
            p("当前工具暂不负责数据安全；数据传到服务端后不保证安全，请使用方自行妥善保管数据。"),
            p("如需更高的数据隔离或运行保障，可提供独立部署服务。")
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
          box(
            width = 12,
            title = "创建账号",
            status = "info",
            solidHeader = TRUE,
            p(class = "auth-intro", "注册后可由管理员开放数据库管理能力，并可通过邮箱加入协作数据空间。")
          ),
          box(
            width = 12,
            title = "注册",
            status = "info",
            solidHeader = TRUE,
            textInput(ns("register_username"), "用户名", placeholder = "3-32 位小写字母、数字、下划线、点或中划线"),
            textInput(ns("register_email"), "邮箱", placeholder = "后续可用于协作授权与找回流程"),
            passwordInput(ns("register_password"), "密码", placeholder = "至少 8 位"),
            passwordInput(ns("register_password_confirm"), "确认密码", placeholder = "请再次输入密码"),
            actionButton(ns("register_submit"), "注册", class = "btn-info", width = "100%"),
            br(),
            br(),
            tags$small(class = "auth-hint", "当前已支持邮箱格式校验，暂未接入真实邮箱验证与邮件发送服务。数据库管理权限需由管理员开放。")
          )
        )
      )
    )
  )
}

auth_manager_server <- function(id, pg_pool, on_login, goto_tab, send_loading = NULL) {
  moduleServer(id, function(input, output, session) {
    `%||%` <- function(x, y) if (is.null(x)) y else x

    set_loading <- function(action) {
      if (!is.null(send_loading) && is.function(send_loading)) {
        send_loading(action)
      }
    }

    observeEvent(input$register_submit, {
      set_loading("show")
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
      tryCatch(
        service_claim_workspace_invites(pg_pool, result$user$id, result$user$email),
        error = function(e) invisible(NULL)
      )
      updateTextInput(session, "register_username", value = "")
      updateTextInput(session, "register_email", value = "")
      updateTextInput(session, "register_password", value = "")
      updateTextInput(session, "register_password_confirm", value = "")
      updateTextInput(session, "login_identity", value = auth_normalize_email(email))
      goto_tab("login")
      showNotification(result$message, type = "message")
    })

    observeEvent(input$login_submit, {
      set_loading("show")
      on.exit(set_loading("hide"), add = TRUE)
      result <- tryCatch(
        auth_authenticate_user(pg_pool, input$login_identity %||% "", input$login_password %||% ""),
        error = function(e) list(success = FALSE, message = paste0("登录失败：", e$message), user = NULL)
      )
      if (!isTRUE(result$success)) {
        showNotification(result$message, type = "error")
        return()
      }
      tryCatch(
        service_claim_workspace_invites(pg_pool, result$user$id, result$user$email),
        error = function(e) invisible(NULL)
      )
      updateTextInput(session, "login_password", value = "")
      updateTextInput(session, "login_identity", value = "")
      on_login(result$user)
      goto_tab("db_manage")
      showNotification(result$message, type = "message")
    })
  })
}
