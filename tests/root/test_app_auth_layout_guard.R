test_find_project_root <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- "--file="
  script_path <- sub(file_arg, "", args[grep(file_arg, args)])
  script_path <- if (length(script_path) > 0) script_path[[1]] else ""
  start_candidates <- unique(c(
    if (nzchar(script_path)) dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE)) else character(0),
    normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  ))

  for (candidate in start_candidates) {
    current <- candidate
    repeat {
      if (file.exists(file.path(current, "app.R")) &&
          dir.exists(file.path(current, "modules")) &&
          dir.exists(file.path(current, "tests"))) {
        return(normalizePath(current, winslash = "/", mustWork = TRUE))
      }
      parent <- dirname(current)
      if (identical(parent, current)) break
      current <- parent
    }
  }

  stop("无法定位项目根目录。", call. = FALSE)
}

project_root <- test_find_project_root()
setwd(file.path(project_root, "tests"))
args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- test_find_project_root()

read_utf8 <- function(...) {
  file_path <- file.path(project_root, ...)
  if (length(file_path) == 0 || !file.exists(file_path)) return("")
  paste(readLines(file_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

app_text <- read_utf8("app.R")
auth_manager_text <- read_utf8("modules", "auth_manager.R")
sidebar_account_card_text <- read_utf8("modules", "account_access", "sidebar_account_card.R")
ui_shell_text <- read_utf8("modules", "common", "ui_shell.R")
loading_css_path <- file.path(project_root, "www", "assets", "loading", "loading.css")
loading_svg_path <- file.path(project_root, "www", "assets", "loading", "hamster.svg")
if (!nzchar(app_text) || !nzchar(auth_manager_text) || !nzchar(sidebar_account_card_text) || !nzchar(ui_shell_text)) return(invisible(NULL))
if (!file.exists(loading_css_path) || !file.exists(loading_svg_path)) {
  stop("缺少 loading 静态资源文件。", call. = FALSE)
}

expect_contains <- function(text, pattern, label) {
  if (!grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
  }
}

expect_contains(app_text, "return\\(sidebarMenu\\(", "未登录侧边栏应立即返回登录注册菜单")
expect_contains(app_text, "selected = \"login\"", "未登录侧边栏默认选中登录页")
expect_contains(app_text, "title = \"Hamster Analysis · AutoTFL\"", "顶栏标题文本")
expect_contains(app_text, "includeCSS\\(\"style\\.css\"\\)", "应用内联加载 style.css，避免静态路径 404")
expect_contains(app_text, "source\\(\"modules/common/auth/auth_copy.R\"\\)", "应用加载账号入口共享文案模块")
expect_contains(app_text, "source\\(\"modules/account_access/sidebar_account_card.R\"\\)", "应用加载侧边栏账号卡模块")
expect_contains(app_text, "sidebar_account_card_ui\\(\"sidebar_account\"\\)", "侧边栏账号卡模块 UI 挂载")
expect_contains(app_text, "source\\(\"modules/common/auth/email_service.R\"\\)", "应用加载邮件投递模块")
expect_contains(app_text, "source\\(\"modules/common/ui_shell.R\"\\)", "应用加载公共 UI shell")
expect_contains(app_text, "tags\\$head\\(\\s*app_loading_overlay_dependencies\\(\\)", "应用在 tags$head 内挂载 loading 依赖")
expect_contains(app_text, "jsonlite::toJSON\\(selector, auto_unbox = TRUE\\)", "侧边栏步骤状态使用安全 JS 选择器转义")
expect_contains(app_text, "sidebar_account_card_styles\\(\\)", "侧边栏账号卡样式注入")
expect_contains(app_text, "sidebar_account_card_server\\(", "侧边栏账号卡模块 server 挂载")
expect_contains(app_text, "li\\[data-value='reset_password'\\]", "忘记密码侧边栏隐藏样式")
expect_contains(app_text, "app_loading_overlay_dependencies\\(\\)", "应用加载公共 loading 依赖")
expect_contains(app_text, "app_loading_overlay_ui\\(title = \"应用加载中\", subtitle = \"正在连接服务\\.\\.\\.\"\\)", "应用挂载公共 loading overlay")
expect_contains(app_text, "tabName = \"user_profile\"", "用户信息页签")
expect_contains(app_text, "tabName = \"access_permissions\"", "权限管理页签")
expect_contains(app_text, "badgeLabel = db_manage_badge_label", "数据空间页签 badge 根据权限动态显示")
expect_contains(app_text, "badgeLabel = data_prep_badge_label", "数据准备页签 badge 根据权限动态显示")
expect_contains(app_text, "default_tab <- if \\(user_has_database_access\\(user\\)\\) \"db_manage\" else \"data_prep\"", "未开通数据空间功能用户默认落到数据准备页")
expect_contains(sidebar_account_card_text, "tags\\$strong\\(copy\\$status\\$database\\)", "侧边栏用户卡片展示数据空间功能状态")
expect_contains(app_text, "refresh_current_user <- function", "当前用户会话刷新函数")
expect_contains(app_text, "invalidateLater\\(5000, session\\)", "当前用户会话定时刷新")
expect_contains(app_text, "user_profile_ui\\(\"user_profile\"\\)", "用户信息模块挂载")
expect_contains(app_text, "permission_manager_ui\\(\"access_permissions\"\\)", "权限管理模块挂载")
expect_contains(app_text, "user_profile_server\\(\"user_profile\", pg_pool = pg_pool, current_user = current_user, on_user_updated = current_user\\)", "用户信息模块回写当前用户")
expect_contains(app_text, "permission_manager_server\\(\"access_permissions\", pg_pool = pg_pool, current_user = current_user\\)", "权限管理模块挂载服务")
expect_contains(app_text, "auth_manager_tabs\\(\"auth\"\\)", "认证页面模块挂载")
expect_contains(app_text, "auth_manager_server\\(", "认证服务模块挂载")
expect_contains(app_text, "do.call\\(tabItems, tab_nodes\\)", "业务 tab 使用列表方式渲染，避免非管理员报错")
expect_contains(app_text, "#shiny-notification-panel", "通知面板位置样式")
expect_contains(app_text, "send_loading = function\\(action, text = NULL, delay_ms = NULL\\)", "应用发送 loading 文案与延时隐藏参数")
expect_contains(app_text, "list\\(action = action, text = text %\\|\\|% \"\", delay_ms = delay_ms %\\|\\|% 0\\)", "应用通过自定义消息发送 loading 状态与延时参数")
expect_contains(ui_shell_text, "app_loading_overlay_dependencies <- function\\(", "公共 UI shell 定义 loading 依赖")
expect_contains(ui_shell_text, "app_loading_overlay_ui <- function\\(", "公共 UI shell 定义 loading UI")
expect_contains(ui_shell_text, "#app-loading-overlay", "公共 UI shell 定义 loading 覆盖层样式")
expect_contains(ui_shell_text, "window\\.hamsterLoading = \\{", "公共 UI shell 定义全局 loading 控制器")
expect_contains(ui_shell_text, "hasBooted: false", "公共 UI shell 维护首屏启动状态")
expect_contains(ui_shell_text, "正在连接服务\\.\\.\\.", "公共 UI shell loading 第一阶段文案")
expect_contains(ui_shell_text, "正在初始化模块\\.\\.\\.", "公共 UI shell loading 第二阶段文案")
expect_contains(ui_shell_text, "href = \"assets/loading/loading\\.css\"", "公共 UI shell 通过静态资源加载 loading 样式")
expect_contains(ui_shell_text, "src = \"assets/loading/hamster\\.svg\"", "公共 UI shell 引用仓鼠 SVG 资源")
expect_contains(ui_shell_text, "app-loading-asset", "公共 UI shell 渲染仓鼠主视觉")
expect_contains(ui_shell_text, "app-loading-lane", "公共 UI shell 渲染跑道动效")
expect_contains(ui_shell_text, "hideDelayed: function\\(delayMs\\)", "公共 UI shell 支持延迟隐藏 loading")
expect_contains(ui_shell_text, "message.action === 'hide_delayed'", "公共 UI shell 处理延迟隐藏消息")
expect_contains(ui_shell_text, "\\$\\(document\\)\\.on\\('shiny:idle'", "公共 UI shell 在首次 idle 后隐藏 loading")
expect_contains(sidebar_account_card_text, "sidebar_account_card_ui <- function", "侧边栏账号卡模块 UI 定义")
expect_contains(sidebar_account_card_text, "sidebar_account_card_server <- function", "侧边栏账号卡模块 server 定义")
expect_contains(sidebar_account_card_text, "sidebar-user-card", "侧边栏账号卡模块样式")
expect_contains(sidebar_account_card_text, "copy <- ACCOUNT_ENTRY_COPY", "侧边栏账号卡复用共享文案")
expect_contains(sidebar_account_card_text, "actionLink\\(session\\$ns\\(\"open_user_profile\"\\), copy\\$actions\\$profile\\)", "侧边栏账号卡用户信息快捷入口")
expect_contains(sidebar_account_card_text, "actionLink\\(session\\$ns\\(\"open_access_permissions\"\\), copy\\$actions\\$permissions\\)", "侧边栏账号卡权限管理快捷入口")
expect_contains(sidebar_account_card_text, "a\\[href='#shiny-tab-user_profile'\\]", "侧边栏账号卡隐藏用户信息页签 CSS")
expect_contains(sidebar_account_card_text, "a\\[href='#shiny-tab-access_permissions'\\]", "侧边栏账号卡隐藏权限管理页签 CSS")
expect_contains(sidebar_account_card_text, "navigate_to\\(copy\\$page_keys\\$profile\\)", "侧边栏账号卡跳转用户信息页")
expect_contains(sidebar_account_card_text, "navigate_to\\(copy\\$page_keys\\$permissions\\)", "侧边栏账号卡跳转权限管理页")
expect_contains(app_text, "showNotification\\(\"已退出登录\"", "退出登录消息仍通过 app 回调处理")
expect_contains(auth_manager_text, "auth-page-shell", "认证页面使用上下居中外层容器")
expect_contains(auth_manager_text, "app_card_dependencies\\(", "认证页加载公共卡片壳依赖")
expect_contains(auth_manager_text, "app_card_box\\(", "认证页使用公共卡片壳")
expect_contains(auth_manager_text, "app_card_panel\\(", "认证页使用公共面板壳")
expect_contains(auth_manager_text, "app_card_note\\(", "认证页使用公共说明壳")
expect_contains(auth_manager_text, "欢迎进入 AutoTFL", "登录页欢迎卡片")
expect_contains(auth_manager_text, "创建账号", "注册页引导卡片")
expect_contains(auth_manager_text, "找回密码", "忘记密码页引导卡片")
expect_contains(auth_manager_text, "textInput\\(ns\\(\"login_identity\"\\), \"用户名或邮箱\"", "登录页支持用户名或邮箱")
expect_contains(auth_manager_text, "auth-secondary-actions", "登录页次级操作按钮容器")
expect_contains(auth_manager_text, "auth-secondary-link", "登录页次级操作按钮样式")
expect_not_contains <- function(text, pattern, label) {
  if (grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("发现应移除内容: %s", label), call. = FALSE)
  }
}
expect_contains(auth_manager_text, "goto_reset_password", "登录页忘记密码跳转链接")
expect_contains(auth_manager_text, "goto_register", "登录页注册跳转链接")
expect_contains(auth_manager_text, "tabName = \"reset_password\"", "独立忘记密码页签")
expect_contains(auth_manager_text, "title = \"忘记密码\"", "独立密码重置卡片")
expect_contains(auth_manager_text, "textInput\\(ns\\(\"reset_email\"\\), \"邮箱\"", "密码重置输入邮箱")
expect_contains(auth_manager_text, "textInput\\(ns\\(\"reset_code\"\\), \"重置验证码\"", "密码重置输入验证码")
expect_contains(auth_manager_text, "passwordInput\\(ns\\(\"reset_new_password\"\\), \"新密码\"", "密码重置输入新密码")
expect_contains(auth_manager_text, "auth_request_password_reset\\(", "密码重置请求逻辑")
expect_contains(auth_manager_text, "auth_reset_password\\(", "密码重置提交逻辑")
expect_contains(auth_manager_text, "textInput\\(ns\\(\"register_email\"\\), \"邮箱\"", "注册页包含邮箱字段")
expect_contains(auth_manager_text, "注册成功后可直接登录；邮箱验证请在登录后的用户信息中自行完成", "注册页邮箱验证提示")
expect_contains(auth_manager_text, "goto_tab\\(\"login\"\\)", "注册成功后跳回登录")
expect_contains(auth_manager_text, "set_loading <- function\\(action, text = NULL, delay_ms = NULL\\)", "认证模块支持发送 loading 文案与延迟参数")
expect_contains(auth_manager_text, "set_loading\\(\"show\", \"正在连接服务\\.\\.\\.\"\\)", "认证模块服务调用前显示连接文案")
expect_contains(auth_manager_text, "if \\(!isTRUE\\(result\\$success\\)\\) \\{\\s*set_loading\\(\"hide\"\\)", "认证模块登录失败时立即隐藏 loading")
expect_contains(auth_manager_text, "set_loading\\(\"show\", \"正在进入工作台\\.\\.\\.\"\\)", "认证模块登录成功后显示进入工作台文案")
expect_contains(auth_manager_text, "set_loading\\(\"hide_delayed\", delay_ms = 450\\)", "认证模块登录成功后延迟隐藏 loading")
expect_contains(auth_manager_text, "当前邮箱尚未验证，可在左侧账号设置区点击“验证邮箱”完成验证。", "未验证邮箱登录后提示")
expect_not_contains(auth_manager_text, "title = \"邮箱验证\"", "登录注册页不再展示邮箱验证卡片")
expect_not_contains(auth_manager_text, "auth_verify_email_code\\(", "认证页不再直接提交邮箱验证")
expect_not_contains(auth_manager_text, "auth_resend_email_verification\\(", "认证页不再直接重发邮箱验证")
expect_not_contains(app_text, "open_email_verify", "侧边栏不再保留邮箱验证弹窗入口")
expect_not_contains(app_text, "open_email_change", "侧边栏不再保留邮箱换绑弹窗入口")
expect_not_contains(app_text, "shinyjs::runjs\\(paste0\\('", "不再使用易出错的 runjs 直拼字符串")

cat("App auth layout guard passed.\n")

