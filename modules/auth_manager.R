auth_manager_tabs <- function(id) {
  ns <- NS(id)
  tagList(
    tabItem(
      tabName = "login",
      fluidRow(
        box(
          width = 6,
          title = "登录",
          status = "primary",
          solidHeader = TRUE,
          textInput(ns("login_identity"), "用户名或邮箱", placeholder = "请输入用户名或邮箱"),
          passwordInput(ns("login_password"), "密码", placeholder = "请输入密码"),
          actionButton(ns("login_submit"), "登录", class = "btn-primary", width = "100%")
        ),
        box(
          width = 6,
          title = "当前工具声明",
          status = "warning",
          solidHeader = TRUE,
          p("当前工具暂不负责数据安全；数据传到服务端后不保证安全，请使用方自行妥善保管数据。"),
          p("如需更高的数据隔离或运行保障，可提供独立部署服务。")
        )
      )
    ),
    tabItem(
      tabName = "register",
      fluidRow(
        box(
          width = 8,
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
          tags$small("当前先加入邮箱字段与格式校验，暂未接入真实邮箱验证与邮件发送服务。")
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
