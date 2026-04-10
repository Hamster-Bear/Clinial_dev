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
source("modules/auth_manager.R")
source("modules/data_preparation.R")
source("modules/database_manager.R")
source("modules/admin_manager.R")
source("modules/workspace_access_manager.R")
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
    uiOutput("sidebar_content"),
    uiOutput("sidebar_user_panel")
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
        .sidebar-user-card {
          margin: 12px;
          padding: 14px 14px 12px;
          border-radius: 10px;
          background: rgba(255, 255, 255, 0.08);
          color: #ffffff;
        }
        .sidebar-user-card-header {
          display: flex;
          align-items: flex-start;
          justify-content: space-between;
          gap: 10px;
        }
        .sidebar-user-name {
          font-weight: 700;
          font-size: 15px;
          color: #ffffff;
        }
        .sidebar-user-role {
          margin-top: 4px;
          color: #f39c12;
          font-size: 12px;
          font-weight: 600;
        }
        .sidebar-user-meta {
          margin-top: 6px;
          color: rgba(255,255,255,0.82);
          font-size: 12px;
          word-break: break-all;
        }
        .sidebar-user-summary {
          margin-top: 10px;
          color: rgba(255,255,255,0.9);
          font-size: 12px;
          line-height: 1.5;
        }
        .sidebar-user-actions {
          margin-top: 12px;
        }
        .sidebar-user-actions a {
          color: #ffffff !important;
          display: inline-block;
          padding: 6px 10px;
          border-radius: 6px;
          background: rgba(255,255,255,0.12);
        }
        .sidebar-user-quick-entry {
          padding: 4px 10px !important;
          border-radius: 999px !important;
          border: none !important;
          background: #3c8dbc !important;
          color: #ffffff !important;
          font-size: 12px !important;
          white-space: nowrap;
        }
        section.sidebar li[data-value='access_manage'] {
          display: none !important;
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
    if (!isTRUE(user$is_admin)) {
      allowed_tabs <- append(allowed_tabs, "access_manage", after = 1)
    }
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
      menuItem("数据空间",
               tabName = "db_manage",
               icon = icon("database"),
               badgeLabel = "管理",
               badgeColor = "blue"),
      if (!isTRUE(user$is_admin)) menuItem("我的权限管理", tabName = "access_manage", icon = icon("key")),
      menuItem("数据准备",
               tabName = "data_prep",
               icon = icon("upload"),
               badgeLabel = "处理",
               badgeColor = "blue"),
      menuItem("探索与可视化",
               tabName = "explore",
               icon = icon("bar-chart"),
               badgeLabel = "可访问",
               badgeColor = "green"),
      menuItem("统计分析",
               tabName = "stats",
               icon = icon("table"),
               badgeLabel = "可访问",
               badgeColor = "green"),
      menuItem("统计图形",
               tabName = "plots",
               icon = icon("line-chart"),
               badgeLabel = "可访问",
               badgeColor = "green"),
      menuItem("预设图表",
               tabName = "tables",
               icon = icon("table"),
               badgeLabel = "可访问",
               badgeColor = "green"),
      if (isTRUE(user$is_admin)) menuItem("系统管理", tabName = "admin", icon = icon("users"), badgeLabel = "管理", badgeColor = "red")
    )
  })

  output$sidebar_user_panel <- renderUI({
    user <- current_user()
    if (is.null(user)) {
      return(NULL)
    }
    manageable_df <- service_list_manageable_workspaces(pg_pool, user)
    manageable_count <- nrow(manageable_df)
    accessible_count <- length(auth_accessible_workspace_ids(pg_pool, user$id, isTRUE(user$is_admin)))
    div(
      class = "sidebar-user-card",
      div(
        class = "sidebar-user-card-header",
        div(
          div(class = "sidebar-user-name", user$username),
          if (isTRUE(user$is_admin)) div(class = "sidebar-user-role", "系统管理员")
        ),
        if (!isTRUE(user$is_admin) && manageable_count > 0) {
          actionButton("open_access_manage", "权限管理", icon = icon("key"), class = "sidebar-user-quick-entry")
        }
      ),
      div(class = "sidebar-user-meta", if (nzchar(user$email %||% "")) user$email else "未设置邮箱"),
      div(
        class = "sidebar-user-summary",
        paste0("我创建并可管理的数据空间: ", manageable_count),
        br(),
        paste0("当前可访问的数据空间: ", accessible_count)
      ),
      div(class = "sidebar-user-actions", actionLink("logout_submit", "退出登录"))
    )
  })

  output$body_content <- renderUI({
    user <- current_user()
    if (is.null(user)) {
      return(do.call(tabItems, as.list(auth_manager_tabs("auth"))))
    }
    tab_nodes <- list(
      tabItem(tabName = "db_manage", database_manager_ui("db_manage")),
      tabItem(tabName = "access_manage", workspace_access_manager_ui("access_manage")),
      tabItem(tabName = "data_prep", data_preparation_ui("data_prep")),
      tabItem(tabName = "explore", exploratory_analysis_ui("explore")),
      tabItem(tabName = "stats", statistical_analysis_ui("stats")),
      tabItem(tabName = "plots", statistical_graphics_ui("plots")),
      tabItem(tabName = "tables", tables_ui("tables"))
    )
    if (isTRUE(user$is_admin)) {
      tab_nodes <- c(tab_nodes, list(tabItem(tabName = "admin", admin_manager_ui("admin"))))
    }
    do.call(tabItems, tab_nodes)
  })

  observe({
    if (is.null(current_user())) {
      updateTabItems(session, "tabs", "login")
    }
  })

  auth_manager_server(
    "auth",
    pg_pool = pg_pool,
    on_login = function(user) {
      current_user(user)
      filtered_data(NULL)
    },
    goto_tab = function(tab_name) {
      updateTabItems(session, "tabs", tab_name)
    },
    send_loading = function(action) {
      session$sendCustomMessage("hamster-loading", list(action = action))
    }
  )

  observeEvent(input$logout_submit, {
    current_user(NULL)
    filtered_data(NULL)
    updateTabItems(session, "tabs", "login")
    showNotification("已退出登录", type = "message")
  })

  observeEvent(input$open_access_manage, {
    updateTabItems(session, "tabs", "access_manage")
  })

  database_manager_server("db_manage", pg_pool = pg_pool, current_user = current_user)
  workspace_access_manager_server("access_manage", pg_pool = pg_pool, current_user = current_user)
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
