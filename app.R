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
source("modules/common/data/data_metadata.R")
source("modules/common/auth/email_service.R")
source("modules/common/auth/auth_copy.R")
source("modules/common/auth/auth.R")
source("modules/common/auth/account_service.R")
source("modules/common/ui_shell.R")
source("modules/account_access/sidebar_account_card.R")
source("modules/auth_manager.R")
source("modules/data_preparation.R")
source("modules/database_manager.R")
source("modules/admin_manager.R")
source("modules/account_access/user_profile.R")
source("modules/account_access/permission_manager.R")
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
    sidebar_account_card_ui("sidebar_account")
  ),
  dashboardBody(
    useShinyjs(),
    auth_manager_styles(),
    tags$head(
      app_loading_overlay_dependencies(),
      tags$title("Hamster Analysis · AutoTFL"),
      includeCSS("style.css"),
      sidebar_account_card_styles(),
      tags$style(HTML("
        #shiny-notification-panel {
          top: auto !important;
          right: auto !important;
          bottom: 16px !important;
          left: 16px !important;
        }
        section.sidebar li[data-value='reset_password'] {
          display: none !important;
        }
      ")),
      tags$script(HTML("
        $(document).on('shiny:connected', function() {
          Shiny.setInputValue('plotly_pagination_info', 'Plotly目前不支持图形分页功能。对于大型数据集，建议使用数据筛选或抽样来减少数据点数量，或者使用交互式缩放功能来浏览数据的不同区域。');
        });
      "))
    ),
    app_loading_overlay_ui(title = "应用加载中", subtitle = "正在连接服务..."),
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
    selector_js <- jsonlite::toJSON(selector, auto_unbox = TRUE)
    if (status == "accessible") {
      shinyjs::enable(selector = selector)
      shinyjs::runjs(sprintf(
        '$(%s).find(".badge").removeClass("bg-black").addClass("bg-blue").text("可访问");',
        selector_js
      ))
    } else {
      shinyjs::disable(selector = selector)
      shinyjs::runjs(sprintf(
        '$(%s).find(".badge").removeClass("bg-blue").addClass("bg-black").text("需数据");',
        selector_js
      ))
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
      allowed_tabs <- append(allowed_tabs, c("user_profile", "access_permissions"), after = 1)
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
      if (!isTRUE(user$is_admin)) menuItem("用户信息", tabName = "user_profile", icon = icon("id-card")),
      if (!isTRUE(user$is_admin)) menuItem("权限管理", tabName = "access_permissions", icon = icon("key")),
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

  output$body_content <- renderUI({
    user <- current_user()
    if (is.null(user)) {
      return(do.call(tabItems, as.list(auth_manager_tabs("auth"))))
    }
    tab_nodes <- list(
      tabItem(tabName = "db_manage", database_manager_ui("db_manage")),
      tabItem(tabName = "user_profile", user_profile_ui("user_profile")),
      tabItem(tabName = "access_permissions", permission_manager_ui("access_permissions")),
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
    send_loading = function(action, text = NULL, delay_ms = NULL) {
      session$sendCustomMessage(
        "hamster-loading",
        list(action = action, text = text %||% "", delay_ms = delay_ms %||% 0)
      )
    }
  )

  sidebar_account_card_server(
    "sidebar_account",
    pg_pool = pg_pool,
    current_user = current_user,
    user_has_database_access = user_has_database_access,
    goto_tab = function(tab_name) {
      updateTabItems(session, "tabs", tab_name)
    },
    on_logout = function() {
      current_user(NULL)
      filtered_data(NULL)
      updateTabItems(session, "tabs", "login")
      showNotification("已退出登录", type = "message")
    }
  )

  database_manager_server("db_manage", pg_pool = pg_pool, current_user = current_user)
  user_profile_server("user_profile", pg_pool = pg_pool, current_user = current_user, on_user_updated = current_user)
  permission_manager_server("access_permissions", pg_pool = pg_pool, current_user = current_user)
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
