args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)

read_utf8 <- function(...) {
  paste(readLines(file.path(project_root, ...), encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

database_manager_text <- read_utf8("modules", "database_manager.R")
readme_text <- read_utf8("README.md")
guide_text <- read_utf8("PROJECT_GUIDE.md")
deployment_text <- read_utf8("DEPLOYMENT_GUIDE.md")
compose_server_text <- read_utf8("docker-compose.server.yml")
env_example_text <- read_utf8("deploy", "alicloud", "env", ".env.example")

expect_contains <- function(text, pattern, label) {
  if (!grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
  }
}

expect_not_contains <- function(text, pattern, label) {
  if (grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("发现应移除内容: %s", label), call. = FALSE)
  }
}

expect_contains(database_manager_text, "从服务器目录导入数据空间", "数据库管理模块导入入口文案")
expect_contains(database_manager_text, "请输入服务器或容器可见的绝对路径", "数据库管理模块导入占位提示")
expect_contains(database_manager_text, "当前仅支持导入部署机器可见目录，不支持直接读取浏览器所在电脑的本地文件夹。", "数据库管理模块导入边界说明")
expect_contains(database_manager_text, "该入口当前仅面向系统管理员开放；多用户能力落地前不面向普通用户开放。", "数据库管理模块管理员限定说明")
expect_not_contains(database_manager_text, "从本地文件夹导入数据空间", "数据库管理模块旧导入文案")

expect_contains(readme_text, "当前 `/app/` 已实现应用内自注册、登录、退出与 workspace 级权限过滤。", "README 访问控制边界")
expect_contains(readme_text, "登录与注册已拆为两个页面；登录支持用户名或邮箱，注册会采集邮箱并做格式校验，但暂未接入真实邮箱验证。", "README 登录注册说明")
expect_contains(readme_text, "未登录状态下仅显示登录/注册入口；进入工作台前不展示业务侧边栏。", "README 未登录入口说明")
expect_contains(readme_text, "当前工具声明为：不负责数据安全、数据传到服务不保证安全，请使用方自行妥善保管数据；如需更高保障，可提供独立部署服务。", "README 免责声明")
expect_contains(readme_text, "且该入口只面向系统管理员开放。", "README 管理员限定")
expect_contains(readme_text, "当前多用户实现为自注册 \\+ 管理员账号 \\+ 按个人隔离", "README 多用户目标")
expect_contains(readme_text, "首个注册用户会自动成为系统管理员。", "README 首用户管理员说明")
expect_contains(readme_text, "当前已提供管理员操作入口，可为已有 workspace 绑定 owner、分配 membership，并停用用户账号。", "README 管理员入口")

expect_contains(guide_text, "当前仓库已实现应用内自注册、登录、退出与 workspace 级权限控制。", "PROJECT_GUIDE 访问控制边界")
expect_contains(guide_text, "登录支持用户名或邮箱；注册阶段会校验邮箱格式，但当前尚未接入真实邮箱验证或邮件发送。", "PROJECT_GUIDE 邮箱说明")
expect_contains(guide_text, "未登录状态下只渲染登录/注册入口，不渲染业务工作台侧边栏。", "PROJECT_GUIDE 未登录入口说明")
expect_contains(guide_text, "系统管理员可访问全部 workspace，并独占服务器目录导入入口。", "PROJECT_GUIDE 管理员能力")
expect_contains(guide_text, "当前工具暂不负责数据安全；数据传到服务端后不保证安全，请使用方自行妥善保管数据。", "PROJECT_GUIDE 免责声明-安全")
expect_contains(guide_text, "首个注册用户会自动成为系统管理员。", "PROJECT_GUIDE 首用户管理员说明")
expect_contains(guide_text, "服务器目录导入只面向系统管理员开放；在多用户能力真正落地前，不应向普通用户开放该入口。", "PROJECT_GUIDE 管理员限定")
expect_contains(guide_text, "当前仓库尚未实现 ZIP 数据空间导入；文档与功能描述不得把该能力写成已支持。", "PROJECT_GUIDE ZIP 未落地说明")
expect_contains(guide_text, "当前已支持用户自注册，并保留系统管理员账号。", "PROJECT_GUIDE 自注册目标")
expect_contains(guide_text, "当前首期隔离粒度以“个人空间”为主，每个用户默认拥有独立数据空间边界。", "PROJECT_GUIDE 个人隔离目标")
expect_contains(guide_text, "数据权限首期落到 workspace 级别", "PROJECT_GUIDE workspace 权限目标")
expect_contains(guide_text, "`account_service.R`", "PROJECT_GUIDE 服务层文件")
expect_contains(guide_text, "`auth.R`", "PROJECT_GUIDE 认证共享层文件")
expect_contains(guide_text, "评估组织级、项目级隔离、邮箱验证与共享协作模型。", "PROJECT_GUIDE 多用户路线")

expect_contains(deployment_text, "当前 `/app/` 已带应用层自注册、登录、退出与 workspace 级权限控制。", "DEPLOYMENT_GUIDE 访问控制边界")
expect_contains(deployment_text, "登录支持用户名或邮箱；注册阶段会保存邮箱并做格式校验，但当前尚未接入真实邮箱验证。", "DEPLOYMENT_GUIDE 邮箱说明")
expect_contains(deployment_text, "未登录状态下仅显示登录/注册入口，不展示业务工作台侧边栏。", "DEPLOYMENT_GUIDE 未登录入口说明")
expect_contains(deployment_text, "且该入口应只对系统管理员开放。", "DEPLOYMENT_GUIDE 管理员限定")
expect_contains(deployment_text, "当前工具暂不负责数据安全；数据传到服务端后不保证安全，使用方需自行妥善保管数据。", "DEPLOYMENT_GUIDE 免责声明")
expect_contains(deployment_text, "当前多用户实现为：支持自注册、保留系统管理员账号、默认按个人隔离", "DEPLOYMENT_GUIDE 多用户目标")
expect_contains(deployment_text, "否则首个注册用户自动成为管理员。", "DEPLOYMENT_GUIDE 首用户管理员说明")
expect_contains(deployment_text, "当前已提供管理员操作入口，可为已有 workspace 绑定 owner、分配 membership，并停用用户账号。", "DEPLOYMENT_GUIDE 管理员入口")
expect_contains(deployment_text, "当前仓库未实现 ZIP 数据空间导入；部署说明和对外口径不得把该能力写成既成事实。", "DEPLOYMENT_GUIDE ZIP 未落地说明")
expect_contains(deployment_text, "`APP_ADMIN_USERNAME`", "DEPLOYMENT_GUIDE 管理员环境变量")
expect_contains(compose_server_text, "APP_ADMIN_USERNAME", "docker-compose.server 管理员用户名变量")
expect_contains(compose_server_text, "APP_ADMIN_PASSWORD", "docker-compose.server 管理员密码变量")
expect_contains(env_example_text, "APP_ADMIN_USERNAME=admin", ".env.example 管理员用户名示例")
expect_contains(env_example_text, "APP_ADMIN_PASSWORD=__CHANGE_ME_ADMIN_PASSWORD__", ".env.example 管理员密码示例")
expect_not_contains(readme_text, "暂不负责数据结果正确", "README 已移除结果正确性免责声明")
expect_not_contains(guide_text, "暂不负责数据结果正确", "PROJECT_GUIDE 已移除结果正确性免责声明")
expect_not_contains(deployment_text, "暂不负责数据结果正确", "DEPLOYMENT_GUIDE 已移除结果正确性免责声明")

cat("Access boundary guard passed.\n")
