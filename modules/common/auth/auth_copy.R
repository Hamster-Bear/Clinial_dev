ACCOUNT_ENTRY_COPY <- list(
  concept = "用户和权限",
  page_keys = list(
    profile = "user_profile",
    permissions = "access_permissions",
    admin = "admin",
    db_manage = "db_manage",
    data_prep = "data_prep"
  ),
  actions = list(
    profile = "用户信息",
    permissions = "权限管理",
    logout = "退出登录",
    admin = "系统管理",
    db_manage = "数据空间",
    data_prep = "临时上传"
  ),
  status = list(
    role_admin = "系统管理员",
    role_user = "普通用户",
    email = "邮箱状态",
    email_verified = "已验证",
    email_unverified = "未验证",
    database = "数据空间功能",
    database_enabled = "已开通",
    database_disabled = "未开通（可临时上传）"
  ),
  sections = list(
    account = "账号设置",
    workspace = "工作台概况"
  ),
  copy = list(
    no_email = "未设置邮箱",
    account_summary = "当前账号设置区遵循统一卡片壳风格；后续新增账号相关入口也应沿用同一视觉规范。",
    workspace_manageable_prefix = "我创建并可管理的数据空间: ",
    workspace_accessible_prefix = "当前可访问的数据空间: "
  ),
  doc_rule = paste(
    "账号入口对外展示文案以 modules/common/auth/auth_copy.R 中 ACCOUNT_ENTRY_COPY 为唯一源；",
    "PROJECT_GUIDE.md、PROJECT_SPEC.md 等规范文档只描述结构职责，不重复维护按钮或摘要原句。"
  )
)

account_entry_copy_get <- function(...) {
  keys <- list(...)
  value <- ACCOUNT_ENTRY_COPY

  for (key in keys) {
    if (!is.list(value) || is.null(value[[key]])) {
      stop(sprintf("ACCOUNT_ENTRY_COPY 缺少键: %s", paste(unlist(keys), collapse = ".")), call. = FALSE)
    }
    value <- value[[key]]
  }

  value
}
