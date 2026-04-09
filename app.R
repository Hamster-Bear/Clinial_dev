# 检查并加载必要的包
required_packages <- c(
  "shiny", "shinydashboard", "shinyjs", "shinyBS", "bslib",
  "dplyr", "readr", "readxl", "haven", "ggplot2", "plotly",
  "DT", "gt", "purrr", "stringr", "survival", "broom", "survminer",
  "corrplot", "ggsci", "patchwork", "digest", "colourpicker", "reactable",
  "waiter", "shinyalert", "scales", "gridExtra", "cowplot", "RColorBrewer",
  "tidyr", "vroom", "memoise", "shinyWidgets", "gtsummary",
  "DBI", "RPostgres", "pool", "rmarkdown", "knitr", "flextable", "officer"
)

# 校验依赖包，不在 app.R 内执行安装
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  stop(
    paste0(
      "检测到缺失依赖包：",
      paste(missing_packages, collapse = ", "),
      "。请先运行 run_app.R 或 install_dependencies.R 完成安装。"
    )
  )
}

invisible(lapply(required_packages, function(pkg) {
  library(pkg, character.only = TRUE, quietly = TRUE, warn.conflicts = FALSE)
}))

# 加载所有模块
source("modules/common/storage_backend.R")
source("modules/common/data_metadata.R")
source("modules/common/auth.R")
source("modules/common/account_service.R")
source("modules/data_preparation.R")
source("modules/database_manager.R")
source("modules/admin_manager.R")
source("modules/exploratory_analysis.R")
source("modules/statistical_analysis.R")
source("modules/statistical_graphics.R")
source("modules/tables.R")

ui <- dashboardPage(
  skin = "black",
  dashboardHeader(
    title = "Hamster Analysis · AutoTFL",
    titleWidth = 300
  ),
  dashboardSidebar(
    width = 300,
    uiOutput("sidebar_content")
  ),
  dashboardBody(
    useShinyjs(),
    tags$head(
      tags$title("Hamster Analysis · AutoTFL"),
      tags$link(rel = "stylesheet", type = "text/css", href = "style.css"),
      tags$style(HTML("
        #shiny-notification-panel {
          top: auto !important;
          right: auto !important;
          bottom: 16px !important;
          left: 16px !important;
        }
        #auth-loading-overlay {
          display: none;
          position: fixed;
          inset: 0;
          z-index: 3000;
          background: rgba(0, 0, 0, 0.28);
          align-items: center;
          justify-content: center;
        }
        #auth-loading-overlay.is-visible {
          display: flex;
        }
        .auth-loading-card {
          min-width: 220px;
          padding: 24px 28px;
          border-radius: 12px;
          background: #ffffff;
          text-align: center;
          box-shadow: 0 10px 30px rgba(0,0,0,0.18);
        }
        .top-user-panel {
          position: fixed;
          top: 58px;
          right: 18px;
          z-index: 2000;
          min-width: 240px;
          padding: 12px 14px;
          border-radius: 10px;
          background: rgba(255,255,255,0.96);
          box-shadow: 0 8px 24px rgba(0,0,0,0.16);
        }
        .top-user-panel .user-name {
          font-weight: 700;
          margin-bottom: 4px;
        }
        .top-user-panel .user-meta {
          color: #666666;
          font-size: 12px;
          margin-bottom: 10px;
        }
      ")),
      tags$script(HTML("
        window.hamsterLoading = {
          show: function() {
            $('#auth-loading-overlay').addClass('is-visible');
          },
          hide: function() {
            $('#auth-loading-overlay').removeClass('is-visible');
          }
        };
        $(document).on('shiny:connected', function() {
          Shiny.setInputValue('plotly_pagination_info', 'Plotly目前不支持图形分页功能。对于大型数据集，建议使用数据筛选或抽样来减少数据点数量，或者使用交互式缩放功能来浏览数据的不同区域。');
        });
        $(document).on('click', '[data-value=\"login\"], [data-value=\"register\"]', function() {
          window.hamsterLoading.show();
          setTimeout(function() {
            window.hamsterLoading.hide();
          }, 250);
        });
        Shiny.addCustomMessageHandler('hamster-loading', function(message) {
          if (message.action === 'show') {
            window.hamsterLoading.show();
          } else {
            window.hamsterLoading.hide();
          }
        });
      "))
    ),
    div(
      id = "auth-loading-overlay",
      div(
        class = "auth-loading-card",
        waiter::spin_fading_circles(),
        tags$div(style = "margin-top: 12px;", "正在加载...")
      )
    ),
    uiOutput("top_right_user_panel"),
    uiOutput("body_content")
  )
)

server <- function(input, output, session) {
  `%||%` <- function(x, y) if (is.null(x)) y else x

  pg_pool <- auth_create_pool()
  onStop(function() {
    poolClose(pg_pool)
  })
  auth_ensure_schema(pg_pool)
  auth_ensure_bootstrap_admin(pg_pool)

  current_user <- reactiveVal(NULL)
  filtered_data <- reactiveVal(NULL)

  update_step_status <- function(step, status) {
    selector <- paste0('[data-value="', step, '"]')
    if (status == "accessible") {
      shinyjs::enable(selector = selector)
      shinyjs::runjs(paste0('
        $("', selector, '").find(".badge")
          .removeClass("bg-black")
          .addClass("bg-blue")
          .text("可访问");
      '))
    } else {
      shinyjs::disable(selector = selector)
      shinyjs::runjs(paste0('
        $("', selector, '").find(".badge")
          .removeClass("bg-blue")
          .addClass("bg-black")
          .text("需数据");
      '))
    }
  }

  output$sidebar_content <- renderUI({
    user <- current_user()
    if (is.null(user)) {
      return(sidebarMenu(
        id = "tabs",
        selected = "login",
        menuItem("登录", tabName = "login", icon = icon("sign-in")),
        menuItem("注册", tabName = "register", icon = icon("user-plus"))
      ))
    }
    allowed_tabs <- c("db_manage", "data_prep", "explore", "stats", "plots", "tables")
    if (isTRUE(user$is_admin)) {
      allowed_tabs <- c(allowed_tabs, "admin")
    }
    selected_tab <- input$tabs %||% "db_manage"
    if (!(selected_tab %in% allowed_tabs)) {
      selected_tab <- "db_manage"
    }
    sidebarMenu(
      id = "tabs",
      selected = selected_tab,
      menuItem("1. 数据库管理",
               tabName = "db_manage",
               icon = icon("database"),
               badgeLabel = "第一步",
               badgeColor = "blue"),
      menuItem("2. 数据准备",
               tabName = "data_prep",
               icon = icon("upload"),
               badgeLabel = "第二步",
               badgeColor = "blue"),
      menuItem("3. 探索与可视化",
               tabName = "explore",
               icon = icon("bar-chart"),
               badgeLabel = "可访问",
               badgeColor = "green"),
      menuItem("4. 统计分析",
               tabName = "stats",
               icon = icon("table"),
               badgeLabel = "可访问",
               badgeColor = "green"),
      menuItem("5. 统计图形",
               tabName = "plots",
               icon = icon("line-chart"),
               badgeLabel = "可访问",
               badgeColor = "green"),
      menuItem("6. 预设图表",
               tabName = "tables",
               icon = icon("table"),
               badgeLabel = "可访问",
               badgeColor = "green"),
      if (isTRUE(user$is_admin)) menuItem("7. 管理员", tabName = "admin", icon = icon("users"), badgeLabel = "管理", badgeColor = "red")
    )
  })

  output$top_right_user_panel <- renderUI({
    user <- current_user()
    if (is.null(user)) {
      return(NULL)
    }
    div(
      class = "top-user-panel",
      div(
        class = "user-name",
        user$username,
        if (isTRUE(user$is_admin)) tags$span(style = "margin-left: 8px; color: #dd4b39;", "管理员")
      ),
      div(class = "user-meta", if (nzchar(user$email %||% "")) user$email else "未设置邮箱"),
      actionButton("logout_submit", "退出登录", class = "btn-default btn-sm", width = "100%")
    )
  })

  output$body_content <- renderUI({
    user <- current_user()
    if (is.null(user)) {
      return(
        tabItems(
          tabItem(
            tabName = "login",
            fluidRow(
              box(
                width = 6,
                title = "登录",
                status = "primary",
                solidHeader = TRUE,
                textInput("login_identity", "用户名或邮箱", placeholder = "请输入用户名或邮箱"),
                passwordInput("login_password", "密码", placeholder = "请输入密码"),
                actionButton("login_submit", "登录", class = "btn-primary", width = "100%")
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
                textInput("register_username", "用户名", placeholder = "3-32 位小写字母、数字、下划线、点或中划线"),
                textInput("register_email", "邮箱", placeholder = "后续可用于协作授权与找回流程"),
                passwordInput("register_password", "密码", placeholder = "至少 8 位"),
                passwordInput("register_password_confirm", "确认密码", placeholder = "请再次输入密码"),
                actionButton("register_submit", "注册", class = "btn-info", width = "100%"),
                br(),
                br(),
                tags$small("当前先加入邮箱字段与格式校验，暂未接入真实邮箱验证与邮件发送服务。")
              )
            )
          )
        )
      )
    }
    tabItems(
      tabItem(tabName = "db_manage", database_manager_ui("db_manage")),
      tabItem(tabName = "data_prep", data_preparation_ui("data_prep")),
      tabItem(tabName = "explore", exploratory_analysis_ui("explore")),
      tabItem(tabName = "stats", statistical_analysis_ui("stats")),
      tabItem(tabName = "plots", statistical_graphics_ui("plots")),
      tabItem(tabName = "tables", tables_ui("tables")),
      if (isTRUE(user$is_admin)) tabItem(tabName = "admin", admin_manager_ui("admin"))
    )
  })

  observe({
    if (is.null(current_user())) {
      updateTabItems(session, "tabs", "login")
    }
  })

  observeEvent(input$register_submit, {
    session$sendCustomMessage("hamster-loading", list(action = "show"))
    on.exit(session$sendCustomMessage("hamster-loading", list(action = "hide")), add = TRUE)
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
    updateTabItems(session, "tabs", "login")
    showNotification(result$message, type = "message")
  })

  observeEvent(input$login_submit, {
    session$sendCustomMessage("hamster-loading", list(action = "show"))
    on.exit(session$sendCustomMessage("hamster-loading", list(action = "hide")), add = TRUE)
    result <- tryCatch(
      auth_authenticate_user(pg_pool, input$login_identity %||% "", input$login_password %||% ""),
      error = function(e) list(success = FALSE, message = paste0("登录失败：", e$message), user = NULL)
    )
    if (!isTRUE(result$success)) {
      showNotification(result$message, type = "error")
      return()
    }
    current_user(result$user)
    filtered_data(NULL)
    updateTextInput(session, "login_password", value = "")
    updateTextInput(session, "login_identity", value = "")
    updateTabItems(session, "tabs", "db_manage")
    showNotification(result$message, type = "message")
  })

  observeEvent(input$logout_submit, {
    current_user(NULL)
    filtered_data(NULL)
    updateTabItems(session, "tabs", "login")
    showNotification("已退出登录", type = "message")
  })

  database_manager_server("db_manage", pg_pool = pg_pool, current_user = current_user)
  data_prep_module <- data_preparation_server("data_prep", pg_pool = pg_pool, current_user = current_user)
  admin_manager_server("admin", pg_pool = pg_pool, current_user = current_user)

  observe({
    data <- data_prep_module()
    filtered_data(data)
  })

  exploratory_analysis_server("explore", data = filtered_data)
  statistical_analysis_server("stats", data = filtered_data)
  statistical_graphics_server("plots", data = filtered_data)
  tables_server("tables", data = filtered_data)

  observe({
    if (is.null(current_user())) {
      return(invisible(NULL))
    }
    data_available <- !is.null(filtered_data())
    steps <- c("explore", "stats", "plots", "tables")
    if (data_available) {
      lapply(steps, function(step) {
        update_step_status(step, "accessible")
      })
    } else {
      lapply(steps, function(step) {
        update_step_status(step, "need_data")
      })
    }
  })
}

# 运行应用
shinyApp(ui, server)
