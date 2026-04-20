# 检查并加载必要的包
required_packages <- c(
  "shiny", "shinydashboard", "shinyjs", "shinyBS", "bslib",
  "dplyr", "readr", "readxl", "haven", "ggplot2", "plotly",
  "DT", "gt", "purrr", "stringr", "survival", "broom", "survminer",
  "corrplot", "ggsci", "patchwork", "digest", "colourpicker", "reactable",
  "waiter", "shinyalert", "scales", "gridExtra", "cowplot", "RColorBrewer",
  "tidyr", "vroom", "memoise", "shinyWidgets", "gtsummary",
  "DBI", "RPostgres", "pool", "rmarkdown", "knitr", "flextable", "officer",
  "showtext", "sysfonts", "jsonlite"
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

# 启用 showtext 以增强跨平台字体渲染稳定性
if (requireNamespace("showtext", quietly = TRUE) && requireNamespace("sysfonts", quietly = TRUE)) {
  .or_else <- function(x, y) if (is.null(x)) y else x

  .first_existing_font_file <- function(paths) {
    valid_paths <- unique(Filter(function(path) {
      is.character(path) && length(path) == 1 && nzchar(path) && file.exists(path)
    }, paths))
    if (length(valid_paths) == 0) return(NULL)
    valid_paths[[1]]
  }

  .font_family_registered <- function(family) {
    if (is.null(family) || !nzchar(family)) return(FALSE)
    registered <- tryCatch(sysfonts::font_families(), error = function(e) character(0))
    family %in% registered
  }

  .register_font_family <- function(alias, regular_candidates, bold_candidates = NULL, italic_candidates = NULL, bolditalic_candidates = NULL, google_name = NULL) {
    if (.font_family_registered(alias)) return(invisible(TRUE))

    regular_path <- .first_existing_font_file(regular_candidates)
    if (!is.null(regular_path)) {
      font_args <- list(family = alias, regular = regular_path)
      bold_path <- .first_existing_font_file(.or_else(bold_candidates, regular_candidates))
      italic_path <- .first_existing_font_file(.or_else(italic_candidates, regular_candidates))
      bolditalic_path <- .first_existing_font_file(.or_else(bolditalic_candidates, .or_else(bold_candidates, regular_candidates)))
      if (!is.null(bold_path)) font_args$bold <- bold_path
      if (!is.null(italic_path)) font_args$italic <- italic_path
      if (!is.null(bolditalic_path)) font_args$bolditalic <- bolditalic_path
      ok <- tryCatch({
        do.call(sysfonts::font_add, font_args)
        TRUE
      }, error = function(e) FALSE)
      if (ok) return(invisible(TRUE))
    }

    if (!is.null(google_name) && nzchar(google_name)) {
      try(sysfonts::font_add_google(google_name, alias), silent = TRUE)
    }

    invisible(.font_family_registered(alias))
  }

  # 注册西文字体别名，便于旧配置继续工作
  .register_font_family(
    alias = "Arial",
    regular_candidates = c(
      "arial.ttf",
      "C:/Windows/Fonts/arial.ttf",
      "/usr/share/fonts/truetype/msttcorefonts/Arial.ttf"
    ),
    bold_candidates = c(
      "arialbd.ttf",
      "C:/Windows/Fonts/arialbd.ttf",
      "/usr/share/fonts/truetype/msttcorefonts/Arial_Bold.ttf"
    ),
    italic_candidates = c(
      "ariali.ttf",
      "C:/Windows/Fonts/ariali.ttf",
      "/usr/share/fonts/truetype/msttcorefonts/Arial_Italic.ttf"
    ),
    bolditalic_candidates = c(
      "arialbi.ttf",
      "C:/Windows/Fonts/arialbi.ttf",
      "/usr/share/fonts/truetype/msttcorefonts/Arial_Bold_Italic.ttf"
    ),
    google_name = "Arimo"
  )

  # 优先使用本地 CJK 字体，离线容器下也能稳定显示中文
  .register_font_family(
    alias = "Noto Sans SC",
    regular_candidates = c(
      "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
      "/usr/share/fonts/opentype/noto/NotoSansCJKsc-Regular.otf",
      "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
      "C:/Windows/Fonts/msyh.ttc",
      "C:/Windows/Fonts/simhei.ttf"
    ),
    bold_candidates = c(
      "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
      "/usr/share/fonts/opentype/noto/NotoSansCJKsc-Bold.otf",
      "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
      "C:/Windows/Fonts/msyhbd.ttc",
      "C:/Windows/Fonts/simhei.ttf"
    ),
    google_name = "Noto Sans SC"
  )

  .register_font_family(
    alias = "Microsoft YaHei",
    regular_candidates = c(
      "C:/Windows/Fonts/msyh.ttc",
      "C:/Windows/Fonts/msyh.ttf"
    ),
    bold_candidates = c(
      "C:/Windows/Fonts/msyhbd.ttc",
      "C:/Windows/Fonts/msyhbd.ttf"
    )
  )

  .register_font_family(
    alias = "SimHei",
    regular_candidates = c(
      "C:/Windows/Fonts/simhei.ttf"
    )
  )

  showtext::showtext_auto()
  showtext::showtext_opts(dpi = 96) # 匹配 Shiny 默认 DPI
}

# 加载所有模块
source("modules/common/storage_backend.R")
source("modules/common/data_metadata.R")
source("modules/common/email_service.R")
source("modules/common/auth.R")
source("modules/common/account_service.R")
source("modules/common/ui_shell.R")
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
    auth_manager_styles(),
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
        .sidebar-user-section-title {
          margin-top: 12px;
          margin-bottom: 8px;
          color: rgba(255,255,255,0.72);
          font-size: 11px;
          font-weight: 700;
          letter-spacing: 0.06em;
          text-transform: uppercase;
        }
        .sidebar-user-status-list {
          display: grid;
          gap: 8px;
        }
        .sidebar-user-status-item {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 10px;
          padding: 8px 10px;
          border-radius: 8px;
          background: rgba(255,255,255,0.08);
          font-size: 12px;
        }
        .sidebar-user-status-item strong {
          font-weight: 600;
        }
        .sidebar-user-status-badge {
          display: inline-flex;
          align-items: center;
          padding: 2px 8px;
          border-radius: 999px;
          font-size: 11px;
          font-weight: 700;
          white-space: nowrap;
        }
        .sidebar-user-status-badge--success {
          background: rgba(0, 166, 90, 0.22);
          color: #7ef0b4;
        }
        .sidebar-user-status-badge--warning {
          background: rgba(243, 156, 18, 0.22);
          color: #ffd27a;
        }
        .sidebar-user-status-badge--info {
          background: rgba(60, 141, 188, 0.22);
          color: #9fd8ff;
        }
        .sidebar-user-actions {
          margin-top: 12px;
          display: grid;
          gap: 8px;
        }
        .sidebar-user-actions a {
          color: #ffffff !important;
          display: block;
          padding: 8px 10px;
          border-radius: 6px;
          background: rgba(255,255,255,0.12);
          text-align: center;
          font-size: 12px;
          font-weight: 600;
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
        section.sidebar li[data-value='reset_password'] {
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

  refresh_current_user <- function(notify_on_logout = FALSE) {
    user <- isolate(current_user())
    if (is.null(user) || !nzchar(user$id %||% "")) {
      return(invisible(NULL))
    }
    fresh_row <- tryCatch(
      auth_get_user_by_id(pg_pool, user$id),
      error = function(e) data.frame()
    )
    if (nrow(fresh_row) == 0 || !identical(fresh_row$status[[1]] %||% "", "active")) {
      current_user(NULL)
      filtered_data(NULL)
      updateTabItems(session, "tabs", "login")
      if (isTRUE(notify_on_logout)) {
        showNotification("当前账号已被停用或删除，请联系系统管理员确认。", type = "error")
      }
      return(invisible(NULL))
    }
    current_user(auth_build_user_payload(fresh_row))
    invisible(current_user())
  }

  user_has_database_access <- function(user) {
    if (is.null(user)) {
      return(FALSE)
    }
    isTRUE(user$is_admin) || isTRUE(user$db_access_enabled)
  }

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
        menuItem("注册", tabName = "register", icon = icon("user-plus")),
        menuItem("找回密码", tabName = "reset_password", icon = icon("life-ring"))
      ))
    }
    allowed_tabs <- c("db_manage", "data_prep", "explore", "stats", "plots", "tables")
    if (!isTRUE(user$is_admin)) {
      allowed_tabs <- append(allowed_tabs, "access_manage", after = 1)
    }
    if (isTRUE(user$is_admin)) {
      allowed_tabs <- c(allowed_tabs, "admin")
    }
    default_tab <- if (user_has_database_access(user)) "db_manage" else "data_prep"
    selected_tab <- input$tabs %||% default_tab
    if (!(selected_tab %in% allowed_tabs)) {
      selected_tab <- default_tab
    }
    db_manage_badge_label <- if (user_has_database_access(user)) "管理" else "需授权"
    db_manage_badge_color <- if (user_has_database_access(user)) "blue" else "yellow"
    data_prep_badge_label <- if (user_has_database_access(user)) "处理" else "临时上传"
    data_prep_badge_color <- if (user_has_database_access(user)) "blue" else "yellow"
    sidebarMenu(
      id = "tabs",
      selected = selected_tab,
      menuItem("数据空间",
               tabName = "db_manage",
               icon = icon("database"),
               badgeLabel = db_manage_badge_label,
               badgeColor = db_manage_badge_color),
      if (!isTRUE(user$is_admin)) menuItem("我的权限管理", tabName = "access_manage", icon = icon("key")),
      menuItem("数据准备",
               tabName = "data_prep",
               icon = icon("upload"),
               badgeLabel = data_prep_badge_label,
               badgeColor = data_prep_badge_color),
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
    database_access_label <- if (user_has_database_access(user)) "已开通" else "未开通（可临时上传）"
    email_status_label <- if (isTRUE(user$email_verified)) "已验证" else "未验证"
    email_status_badge_class <- if (isTRUE(user$email_verified)) {
      "sidebar-user-status-badge sidebar-user-status-badge--success"
    } else {
      "sidebar-user-status-badge sidebar-user-status-badge--warning"
    }
    database_status_badge_class <- if (user_has_database_access(user)) {
      "sidebar-user-status-badge sidebar-user-status-badge--info"
    } else {
      "sidebar-user-status-badge sidebar-user-status-badge--warning"
    }
    div(
      class = "sidebar-user-card",
      div(
        class = "sidebar-user-card-header",
        div(
          div(class = "sidebar-user-name", user$username),
          if (isTRUE(user$is_admin)) div(class = "sidebar-user-role", "系统管理员")
        ),
        if (isTRUE(user$is_admin)) {
          actionButton("open_admin", "系统管理", icon = icon("users"), class = "sidebar-user-quick-entry")
        } else if (user_has_database_access(user)) {
          actionButton("open_db_manage", "数据空间", icon = icon("database"), class = "sidebar-user-quick-entry")
        } else {
          actionButton("open_data_prep", "临时上传", icon = icon("upload"), class = "sidebar-user-quick-entry")
        }
      ),
      div(class = "sidebar-user-meta", if (nzchar(user$email %||% "")) user$email else "未设置邮箱"),
      div(class = "sidebar-user-section-title", "账号设置"),
      div(
        class = "sidebar-user-status-list",
        div(
          class = "sidebar-user-status-item",
          tags$strong("邮箱状态"),
          tags$span(class = email_status_badge_class, email_status_label)
        ),
        div(
          class = "sidebar-user-status-item",
          tags$strong("数据空间功能"),
          tags$span(class = database_status_badge_class, database_access_label)
        )
      ),
      div(class = "sidebar-user-section-title", "工作台概况"),
      div(
        class = "sidebar-user-summary",
        paste0("我创建并可管理的数据空间: ", manageable_count),
        br(),
        paste0("当前可访问的数据空间: ", accessible_count)
      ),
      div(
        class = "sidebar-user-actions",
        if (!isTRUE(user$email_verified) && nzchar(user$email %||% "")) actionLink("open_email_verify", "验证邮箱"),
        actionLink("open_email_change", "邮箱换绑"),
        if (!isTRUE(user$is_admin) && manageable_count > 0) actionLink("open_access_manage", "权限管理"),
        actionLink("logout_submit", "退出登录")
      )
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

  observeEvent(input$open_email_verify, {
    user <- current_user()
    req(!is.null(user))
    showModal(modalDialog(
      title = "验证邮箱",
      tags$p(
        class = "text-muted",
        paste0(
          "当前邮箱：",
          if (nzchar(user$email %||% "")) user$email else "未设置邮箱",
          "。请先发送验证码，再输入验证码完成验证。"
        )
      ),
      textInput("current_email_verify_code", "验证码", value = "", placeholder = "请输入 6 位验证码"),
      footer = tagList(
        modalButton("取消"),
        actionButton("request_current_email_verify", "发送验证码", class = "btn-info"),
        actionButton("submit_current_email_verify", "确认验证", class = "btn-primary")
      ),
      easyClose = TRUE
    ))
  })

  observeEvent(input$open_email_change, {
    user <- current_user()
    req(!is.null(user))
    showModal(modalDialog(
      title = "邮箱换绑",
      textInput("change_email_new_email", "新邮箱", value = "", placeholder = "请输入新的邮箱地址"),
      passwordInput("change_email_current_password", "当前密码", placeholder = "请输入当前密码以确认换绑"),
      textInput("change_email_code", "换绑验证码", value = "", placeholder = "请输入 6 位验证码"),
      tags$p(
        class = "text-muted",
        paste0(
          "当前邮箱：",
          if (nzchar(user$email %||% "")) user$email else "未设置邮箱",
          "。先发送验证码到新邮箱，再输入验证码完成换绑。"
        )
      ),
      footer = tagList(
        modalButton("取消"),
        actionButton("request_email_change_code", "发送换绑验证码", class = "btn-info"),
        actionButton("submit_email_change", "确认换绑", class = "btn-primary")
      ),
      easyClose = TRUE
    ))
  })

  observeEvent(input$open_db_manage, {
    updateTabItems(session, "tabs", "db_manage")
  })

  observeEvent(input$open_data_prep, {
    updateTabItems(session, "tabs", "data_prep")
  })

  observeEvent(input$open_admin, {
    updateTabItems(session, "tabs", "admin")
  })

  observeEvent(input$request_email_change_code, {
    user <- current_user()
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

  observeEvent(input$request_current_email_verify, {
    user <- current_user()
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
    user <- current_user()
    req(!is.null(user))
    result <- tryCatch(
      auth_verify_email_code(pg_pool, user$email %||% "", input$current_email_verify_code %||% "", purpose = "register"),
      error = function(e) list(success = FALSE, message = paste0("邮箱验证失败：", e$message))
    )
    if (!isTRUE(result$success)) {
      showNotification(result$message, type = "error")
      return()
    }
    current_user(result$user)
    removeModal()
    showNotification(result$message, type = "message")
  })

  observeEvent(input$submit_email_change, {
    user <- current_user()
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
    current_user(result$user)
    tryCatch(
      service_claim_workspace_invites(pg_pool, result$user$id, result$user$email),
      error = function(e) invisible(NULL)
    )
    removeModal()
    showNotification(result$message, type = "message")
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
  statistical_graphics_server("plots", data = filtered_data, pg_pool = pg_pool, current_user = current_user)
  tables_server("tables", data = filtered_data)

  observe({
    if (is.null(current_user())) {
      return(invisible(NULL))
    }
    invalidateLater(5000, session)
    refresh_current_user(notify_on_logout = TRUE)
  })

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
