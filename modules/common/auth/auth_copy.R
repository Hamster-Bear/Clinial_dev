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
    account_summary = "在这里查看账号状态、常用入口和数据空间概况。",
    workspace_manageable_prefix = "我创建并可管理的数据空间: ",
    workspace_accessible_prefix = "当前可访问的数据空间: "
  ),
  profile = list(
    title = "用户信息",
    subtitle = "基础资料与少量信息变更",
    overview_title = "账号概览",
    overview_subtitle = "快速查看当前身份、邮箱与安全状态",
    workbench_title = "安全与验证",
    workbench_subtitle = "在这里完成邮箱验证、邮箱换绑和修改密码。",
    tabs = list(
      verify_email = "验证邮箱",
      change_email = "邮箱换绑",
      change_password = "修改密码"
    )
  ),
  permissions = list(
    title = "权限管理",
    subtitle = "数据空间协作与已授权空间",
    accessible_title = "我的已授权空间",
    accessible_subtitle = "集中查看当前被授予访问权限的数据空间与角色",
    empty_title = "权限管理",
    empty_subtitle = "当前暂无可管理空间或已授权空间",
    workbench_title = "协作管理",
    workbench_subtitle = "在这里处理成员协作、负责人迁移与预览",
    tabs = list(
      collaboration = "成员协作",
      ownership = "负责人迁移",
      members = "当前成员",
      invites = "待领取邀请",
      accessible = "已授权空间",
      usage = "使用说明"
    )
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
