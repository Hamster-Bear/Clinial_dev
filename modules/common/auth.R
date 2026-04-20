`%||%` <- function(x, y) if (is.null(x)) y else x

if (!exists("email_service_send", mode = "function")) {
  auth_source_file <- NULL
  for (frame_index in rev(seq_len(sys.nframe()))) {
    frame_file <- sys.frame(frame_index)$ofile %||% NULL
    if (!is.null(frame_file) && nzchar(frame_file)) {
      auth_source_file <- frame_file
      break
    }
  }
  if (!is.null(auth_source_file) && nzchar(auth_source_file)) {
    email_service_path <- file.path(dirname(auth_source_file), "email_service.R")
    if (file.exists(email_service_path)) {
      source(email_service_path, local = FALSE)
    }
  }
}

auth_empty_registry <- function() {
  list(
    workspaces = data.frame(
      id = character(0),
      name = character(0),
      owner_user_id = character(0),
      created_at = as.POSIXct(character(0)),
      stringsAsFactors = FALSE
    ),
    folders = data.frame(
      id = character(0),
      workspace_id = character(0),
      name = character(0),
      created_at = as.POSIXct(character(0)),
      stringsAsFactors = FALSE
    ),
    datasets = data.frame(
      id = character(0),
      workspace_id = character(0),
      folder_id = character(0),
      name = character(0),
      file_name = character(0),
      data_path = character(0),
      nrow = numeric(0),
      ncol = numeric(0),
      created_at = as.POSIXct(character(0)),
      stringsAsFactors = FALSE
    )
  )
}

auth_generate_id <- function(prefix) {
  paste0(prefix, "_", as.integer(as.numeric(Sys.time())), "_", sample(1000:9999, 1))
}

auth_normalize_username <- function(username) {
  tolower(trimws(username %||% ""))
}

auth_normalize_email <- function(email) {
  tolower(trimws(email %||% ""))
}

auth_validate_username <- function(username) {
  normalized <- auth_normalize_username(username)
  if (!nzchar(normalized)) {
    return("请输入用户名")
  }
  if (!grepl("^[a-z0-9_.-]{3,32}$", normalized)) {
    return("用户名仅支持 3-32 位小写字母、数字、下划线、点和中划线")
  }
  NULL
}

auth_validate_email <- function(email) {
  normalized <- auth_normalize_email(email)
  if (!nzchar(normalized)) {
    return("请输入邮箱")
  }
  if (!grepl("^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$", normalized, ignore.case = TRUE)) {
    return("邮箱格式不正确")
  }
  NULL
}

auth_validate_password <- function(password) {
  password <- password %||% ""
  if (!nzchar(password)) {
    return("请输入密码")
  }
  if (nchar(password) < 8) {
    return("密码至少需要 8 位")
  }
  NULL
}

auth_is_true_env <- function(name, default = FALSE) {
  raw_value <- trimws(Sys.getenv(name, if (isTRUE(default)) "1" else "0"))
  tolower(raw_value) %in% c("1", "true", "yes", "on")
}

auth_email_verification_required <- function() {
  auth_is_true_env("AUTH_REQUIRE_EMAIL_VERIFICATION", default = FALSE)
}

auth_dev_show_email_code <- function() {
  auth_is_true_env("AUTH_DEV_SHOW_EMAIL_CODE", default = FALSE)
}

auth_email_delivery_mode <- function() {
  mode <- tolower(trimws(Sys.getenv("EMAIL_DELIVERY_MODE", "console")))
  if (!mode %in% c("console", "disabled")) {
    mode <- "console"
  }
  mode
}

auth_email_verification_expire_minutes <- function() {
  ttl <- suppressWarnings(as.integer(Sys.getenv("AUTH_EMAIL_VERIFICATION_EXPIRE_MINUTES", "30")))
  if (is.na(ttl) || ttl < 5L) {
    ttl <- 30L
  }
  ttl
}

auth_password_reset_expire_minutes <- function() {
  ttl <- suppressWarnings(as.integer(Sys.getenv("AUTH_PASSWORD_RESET_EXPIRE_MINUTES", "30")))
  if (is.na(ttl) || ttl < 5L) {
    ttl <- 30L
  }
  ttl
}

auth_generate_verification_code <- function(code_length = 6L) {
  paste0(sample(0:9, size = max(4L, as.integer(code_length)), replace = TRUE), collapse = "")
}

auth_hash_token <- function(token) {
  digest::digest(
    paste0("autotfl::token::", token %||% ""),
    algo = "sha256",
    serialize = FALSE
  )
}

auth_is_email_verified <- function(user_row) {
  if (is.null(user_row) || !is.data.frame(user_row) || nrow(user_row) == 0) {
    return(FALSE)
  }
  if (!"email_verified_at" %in% names(user_row)) {
    return(FALSE)
  }
  value <- user_row$email_verified_at[[1]] %||% NA
  !is.null(value) && !is.na(value)
}

auth_deliver_email_verification <- function(email, code, purpose = "register") {
  normalized_email <- auth_normalize_email(email)
  expires_minutes <- auth_email_verification_expire_minutes()
  delivery_mode <- auth_email_delivery_mode()
  subject <- "[AutoTFL] 邮箱验证码"
  body <- paste0(
    "用途: ", purpose, "\n",
    "邮箱: ", normalized_email, "\n",
    "验证码: ", code, "\n",
    "有效期(分钟): ", expires_minutes, "\n"
  )
  send_result <- email_service_send(normalized_email, subject, body)
  if (!isTRUE(send_result$success)) {
    return(list(success = FALSE, message = send_result$message, preview_code = NULL, delivery_mode = delivery_mode, expires_minutes = expires_minutes))
  }

  ui_message <- paste0("验证码已发送，请在 ", expires_minutes, " 分钟内完成邮箱验证。")
  preview_code <- NULL
  if (auth_dev_show_email_code() || identical(delivery_mode, "console")) {
    preview_code <- code
    ui_message <- paste0(ui_message, " 测试环境验证码：", code)
  }

  list(
    success = TRUE,
    message = ui_message,
    preview_code = preview_code,
    delivery_mode = delivery_mode,
    expires_minutes = expires_minutes
  )
}

auth_deliver_password_reset <- function(email, code) {
  normalized_email <- auth_normalize_email(email)
  expires_minutes <- auth_password_reset_expire_minutes()
  delivery_mode <- auth_email_delivery_mode()
  subject <- "[AutoTFL] 密码重置验证码"
  body <- paste0(
    "邮箱: ", normalized_email, "\n",
    "重置验证码: ", code, "\n",
    "有效期(分钟): ", expires_minutes, "\n"
  )
  send_result <- email_service_send(normalized_email, subject, body)
  if (!isTRUE(send_result$success)) {
    return(list(success = FALSE, message = send_result$message, preview_code = NULL, delivery_mode = delivery_mode, expires_minutes = expires_minutes))
  }

  ui_message <- paste0("重置验证码已发送，请在 ", expires_minutes, " 分钟内完成密码重置。")
  preview_code <- NULL
  if (auth_dev_show_email_code() || identical(delivery_mode, "console")) {
    preview_code <- code
    ui_message <- paste0(ui_message, " 测试环境验证码：", code)
  }

  list(
    success = TRUE,
    message = ui_message,
    preview_code = preview_code,
    delivery_mode = delivery_mode,
    expires_minutes = expires_minutes
  )
}

auth_resolve_bootstrap_admin_env <- function() {
  username <- auth_normalize_username(Sys.getenv("APP_ADMIN_USERNAME", ""))
  email <- auth_normalize_email(Sys.getenv("APP_ADMIN_EMAIL", ""))
  password <- Sys.getenv("APP_ADMIN_PASSWORD", "")

  provided_count <- sum(nzchar(c(username, email, password)))
  if (provided_count == 0) {
    return(list(valid = FALSE, reason = "missing_all", username = username, email = email, password = password))
  }
  if (provided_count < 3) {
    warning("管理员环境变量必须同时提供 APP_ADMIN_USERNAME、APP_ADMIN_EMAIL 和 APP_ADMIN_PASSWORD。当前已跳过管理员引导同步。", call. = FALSE)
    return(list(valid = FALSE, reason = "partial", username = username, email = email, password = password))
  }

  username_error <- auth_validate_username(username)
  if (!is.null(username_error)) {
    warning(paste0("管理员环境变量 APP_ADMIN_USERNAME 无效：", username_error, "。当前已跳过管理员引导同步。"), call. = FALSE)
    return(list(valid = FALSE, reason = "invalid_username", username = username, email = email, password = password))
  }
  email_error <- auth_validate_email(email)
  if (!is.null(email_error)) {
    warning(paste0("管理员环境变量 APP_ADMIN_EMAIL 无效：", email_error, "。当前已跳过管理员引导同步。"), call. = FALSE)
    return(list(valid = FALSE, reason = "invalid_email", username = username, email = email, password = password))
  }
  password_error <- auth_validate_password(password)
  if (!is.null(password_error)) {
    warning(paste0("管理员环境变量 APP_ADMIN_PASSWORD 无效：", password_error, "。当前已跳过管理员引导同步。"), call. = FALSE)
    return(list(valid = FALSE, reason = "invalid_password", username = username, email = email, password = password))
  }

  list(valid = TRUE, reason = "ready", username = username, email = email, password = password)
}

auth_generate_salt <- function() {
  digest::digest(
    paste(Sys.time(), runif(1), sample(c(letters, LETTERS, 0:9), 16, replace = TRUE), collapse = "|"),
    algo = "sha256",
    serialize = FALSE
  )
}

auth_hash_password <- function(password, salt) {
  digest::digest(
    paste0(salt, "::", password %||% ""),
    algo = "sha256",
    serialize = FALSE
  )
}

auth_verify_password <- function(password, salt, expected_hash) {
  identical(auth_hash_password(password, salt), expected_hash)
}

auth_create_pool <- function() {
  pool::dbPool(
    drv = RPostgres::Postgres(),
    dbname = Sys.getenv("POSTGRES_DB", "autotfl"),
    host = Sys.getenv("POSTGRES_HOST", "localhost"),
    port = as.integer(Sys.getenv("POSTGRES_PORT", "5432")),
    user = Sys.getenv("POSTGRES_USER", "autotfl_user"),
    password = Sys.getenv("POSTGRES_PASSWORD", "ChangeMe123!")
  )
}

auth_migrate_analysis_states_schema <- function(pool) {
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS workspace_id VARCHAR(50)")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS scope VARCHAR(50)")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS module_type VARCHAR(100)")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS state_name VARCHAR(255)")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS state_payload TEXT")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS state_note TEXT")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ALTER COLUMN state_payload TYPE TEXT USING state_payload::text")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ALTER COLUMN state_note TYPE TEXT USING state_note::text")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP")
  DBI::dbExecute(
    pool,
    paste(
      "UPDATE analysis_states",
      "SET updated_at = COALESCE(updated_at, created_at, CURRENT_TIMESTAMP),",
      "created_at = COALESCE(created_at, updated_at, CURRENT_TIMESTAMP)"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "DO $$",
      "BEGIN",
      "  IF NOT EXISTS (",
      "    SELECT 1",
      "    FROM pg_constraint",
      "    WHERE conrelid = 'analysis_states'::regclass",
      "      AND conname = 'analysis_states_workspace_fk'",
      "  ) THEN",
      "    ALTER TABLE analysis_states",
      "    ADD CONSTRAINT analysis_states_workspace_fk",
      "    FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE;",
      "  END IF;",
      "END $$;"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "DO $$",
      "DECLARE rec RECORD;",
      "BEGIN",
      "  FOR rec IN",
      "    SELECT conname",
      "    FROM pg_constraint",
      "    WHERE conrelid = 'analysis_states'::regclass",
      "      AND contype = 'u'",
      "  LOOP",
      "    EXECUTE format('ALTER TABLE analysis_states DROP CONSTRAINT IF EXISTS %I', rec.conname);",
      "  END LOOP;",
      "END $$;"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "WITH ranked AS (",
      "  SELECT ctid,",
      "         ROW_NUMBER() OVER (",
      "           PARTITION BY user_id, workspace_id, scope, module_type, state_name",
      "           ORDER BY COALESCE(updated_at, created_at, CURRENT_TIMESTAMP) DESC, created_at DESC, id DESC",
      "         ) AS rn",
      "  FROM analysis_states",
      "  WHERE workspace_id IS NOT NULL",
      "    AND COALESCE(BTRIM(scope), '') <> ''",
      "    AND COALESCE(BTRIM(module_type), '') <> ''",
      "    AND COALESCE(BTRIM(state_name), '') <> ''",
      ")",
      "DELETE FROM analysis_states target",
      "USING ranked",
      "WHERE target.ctid = ranked.ctid AND ranked.rn > 1"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "WITH ranked AS (",
      "  SELECT ctid,",
      "         ROW_NUMBER() OVER (",
      "           PARTITION BY user_id, scope, module_type, state_name",
      "           ORDER BY COALESCE(updated_at, created_at, CURRENT_TIMESTAMP) DESC, created_at DESC, id DESC",
      "         ) AS rn",
      "  FROM analysis_states",
      "  WHERE workspace_id IS NULL",
      "    AND COALESCE(BTRIM(scope), '') <> ''",
      "    AND COALESCE(BTRIM(module_type), '') <> ''",
      "    AND COALESCE(BTRIM(state_name), '') <> ''",
      ")",
      "DELETE FROM analysis_states target",
      "USING ranked",
      "WHERE target.ctid = ranked.ctid AND ranked.rn > 1"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "CREATE UNIQUE INDEX IF NOT EXISTS uq_analysis_states_user_workspace_scope_module_name",
      "ON analysis_states(user_id, workspace_id, scope, module_type, state_name)",
      "WHERE workspace_id IS NOT NULL",
      "  AND COALESCE(BTRIM(scope), '') <> ''",
      "  AND COALESCE(BTRIM(module_type), '') <> ''",
      "  AND COALESCE(BTRIM(state_name), '') <> ''"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "CREATE UNIQUE INDEX IF NOT EXISTS uq_analysis_states_user_scope_module_name_personal",
      "ON analysis_states(user_id, scope, module_type, state_name)",
      "WHERE workspace_id IS NULL",
      "  AND COALESCE(BTRIM(scope), '') <> ''",
      "  AND COALESCE(BTRIM(module_type), '') <> ''",
      "  AND COALESCE(BTRIM(state_name), '') <> ''"
    )
  )
}

auth_ensure_schema <- function(pool) {
  email_verified_exists <- nrow(DBI::dbGetQuery(
    pool,
    paste(
      "SELECT 1",
      "FROM information_schema.columns",
      "WHERE table_schema = CURRENT_SCHEMA()",
      "  AND table_name = 'users'",
      "  AND column_name = 'email_verified_at'"
    )
  )) > 0
  DBI::dbExecute(
    pool,
    paste(
      "CREATE TABLE IF NOT EXISTS workspaces (",
      "id VARCHAR(50) PRIMARY KEY,",
      "name VARCHAR(255) NOT NULL,",
      "owner_user_id VARCHAR(50),",
      "created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP",
      ")"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "CREATE TABLE IF NOT EXISTS folders (",
      "id VARCHAR(50) PRIMARY KEY,",
      "workspace_id VARCHAR(50) NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,",
      "name VARCHAR(255) NOT NULL,",
      "created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,",
      "UNIQUE(workspace_id, name)",
      ")"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "CREATE TABLE IF NOT EXISTS datasets (",
      "id VARCHAR(50) PRIMARY KEY,",
      "workspace_id VARCHAR(50) NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,",
      "folder_id VARCHAR(50),",
      "name VARCHAR(255) NOT NULL,",
      "file_name VARCHAR(255) NOT NULL,",
      "data_path VARCHAR(1024) NOT NULL,",
      "nrow INTEGER,",
      "ncol INTEGER,",
      "created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP",
      ")"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "CREATE TABLE IF NOT EXISTS users (",
      "id VARCHAR(50) PRIMARY KEY,",
      "username VARCHAR(64) NOT NULL UNIQUE,",
      "email VARCHAR(255),",
      "email_verified_at TIMESTAMP WITH TIME ZONE,",
      "password_salt VARCHAR(128) NOT NULL,",
      "password_hash VARCHAR(128) NOT NULL,",
      "is_admin BOOLEAN NOT NULL DEFAULT FALSE,",
      "db_access_enabled BOOLEAN NOT NULL DEFAULT FALSE,",
      "status VARCHAR(20) NOT NULL DEFAULT 'active',",
      "created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP",
      ")"
    )
  )
  DBI::dbExecute(
    pool,
    "ALTER TABLE workspaces ADD COLUMN IF NOT EXISTS owner_user_id VARCHAR(50)"
  )
  DBI::dbExecute(
    pool,
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(255)"
  )
  DBI::dbExecute(
    pool,
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMP WITH TIME ZONE"
  )
  DBI::dbExecute(
    pool,
    paste(
      "CREATE TABLE IF NOT EXISTS email_verification_tokens (",
      "id VARCHAR(50) PRIMARY KEY,",
      "user_id VARCHAR(50) NOT NULL REFERENCES users(id) ON DELETE CASCADE,",
      "target_email VARCHAR(255) NOT NULL,",
      "purpose VARCHAR(30) NOT NULL DEFAULT 'register',",
      "token_hash VARCHAR(128) NOT NULL,",
      "expires_at TIMESTAMP WITH TIME ZONE NOT NULL,",
      "consumed_at TIMESTAMP WITH TIME ZONE,",
      "created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP",
      ")"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "CREATE TABLE IF NOT EXISTS password_reset_tokens (",
      "id VARCHAR(50) PRIMARY KEY,",
      "user_id VARCHAR(50) NOT NULL REFERENCES users(id) ON DELETE CASCADE,",
      "email_snapshot VARCHAR(255) NOT NULL,",
      "token_hash VARCHAR(128) NOT NULL,",
      "expires_at TIMESTAMP WITH TIME ZONE NOT NULL,",
      "consumed_at TIMESTAMP WITH TIME ZONE,",
      "created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP",
      ")"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "CREATE TABLE IF NOT EXISTS workspace_memberships (",
      "id VARCHAR(50) PRIMARY KEY,",
      "workspace_id VARCHAR(50) NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,",
      "user_id VARCHAR(50) NOT NULL REFERENCES users(id) ON DELETE CASCADE,",
      "role VARCHAR(20) NOT NULL DEFAULT 'viewer',",
      "created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,",
      "UNIQUE(workspace_id, user_id)",
      ")"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "CREATE TABLE IF NOT EXISTS workspace_invites (",
      "id VARCHAR(50) PRIMARY KEY,",
      "workspace_id VARCHAR(50) NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,",
      "invited_email VARCHAR(255) NOT NULL,",
      "target_role VARCHAR(20) NOT NULL DEFAULT 'viewer',",
      "status VARCHAR(20) NOT NULL DEFAULT 'pending',",
      "created_by_user_id VARCHAR(50),",
      "claimed_user_id VARCHAR(50),",
      "created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,",
      "claimed_at TIMESTAMP WITH TIME ZONE,",
      "UNIQUE(workspace_id, invited_email)",
      ")"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "CREATE TABLE IF NOT EXISTS analysis_states (",
      "id VARCHAR(50) PRIMARY KEY,",
      "user_id VARCHAR(50) NOT NULL REFERENCES users(id) ON DELETE CASCADE,",
      "workspace_id VARCHAR(50) REFERENCES workspaces(id) ON DELETE CASCADE,",
      "scope VARCHAR(50) NOT NULL,",
      "module_type VARCHAR(100) NOT NULL,",
      "state_name VARCHAR(255) NOT NULL,",
      "state_payload TEXT NOT NULL,",
      "state_note TEXT,",
      "created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,",
      "updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP",
      ")"
    )
  )
  auth_migrate_analysis_states_schema(pool)
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_workspaces_owner_user ON workspaces(owner_user_id)")
  DBI::dbExecute(pool, "CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_unique ON users(email)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_users_email_verified ON users(email_verified_at)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_folders_workspace ON folders(workspace_id)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_datasets_workspace ON datasets(workspace_id)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_datasets_folder ON datasets(folder_id)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_workspace_memberships_workspace ON workspace_memberships(workspace_id)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_workspace_memberships_user ON workspace_memberships(user_id)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_workspace_invites_workspace ON workspace_invites(workspace_id)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_workspace_invites_email ON workspace_invites(invited_email)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_email_verification_tokens_user ON email_verification_tokens(user_id)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_email_verification_tokens_email ON email_verification_tokens(target_email)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_email_verification_tokens_expire ON email_verification_tokens(expires_at)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_user ON password_reset_tokens(user_id)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_email ON password_reset_tokens(email_snapshot)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_expire ON password_reset_tokens(expires_at)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_analysis_states_user_scope ON analysis_states(user_id, scope)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_analysis_states_workspace_module ON analysis_states(workspace_id, module_type)")
  if (!isTRUE(email_verified_exists)) {
    DBI::dbExecute(
      pool,
      paste(
        "UPDATE users",
        "SET email_verified_at = COALESCE(email_verified_at, created_at, CURRENT_TIMESTAMP)",
        "WHERE COALESCE(BTRIM(email), '') <> ''"
      )
    )
  }
}

auth_get_user_by_username <- function(pool, username) {
  normalized <- auth_normalize_username(username)
  if (!nzchar(normalized)) {
    return(data.frame())
  }
  DBI::dbGetQuery(
    pool,
    "SELECT * FROM users WHERE username = $1 LIMIT 1",
    params = list(normalized)
  )
}

auth_get_user_by_email <- function(pool, email) {
  normalized <- auth_normalize_email(email)
  if (!nzchar(normalized)) {
    return(data.frame())
  }
  DBI::dbGetQuery(
    pool,
    "SELECT * FROM users WHERE email = $1 LIMIT 1",
    params = list(normalized)
  )
}

auth_get_user_by_identity <- function(pool, identity) {
  normalized <- trimws(identity %||% "")
  if (!nzchar(normalized)) {
    return(data.frame())
  }
  if (grepl("@", normalized, fixed = TRUE)) {
    return(auth_get_user_by_email(pool, normalized))
  }
  auth_get_user_by_username(pool, normalized)
}

auth_get_user_by_id <- function(pool, user_id) {
  if (is.null(user_id) || !nzchar(user_id)) {
    return(data.frame())
  }
  DBI::dbGetQuery(
    pool,
    "SELECT * FROM users WHERE id = $1 LIMIT 1",
    params = list(user_id)
  )
}

auth_list_users <- function(pool) {
  DBI::dbGetQuery(pool, "SELECT * FROM users ORDER BY created_at ASC")
}

auth_build_user_payload <- function(user_row) {
  if (is.null(user_row) || !is.data.frame(user_row) || nrow(user_row) == 0) {
    return(NULL)
  }
  list(
    id = user_row$id[[1]],
    username = user_row$username[[1]],
    email = if (is.null(user_row$email[[1]]) || is.na(user_row$email[[1]])) "" else user_row$email[[1]],
    email_verified = auth_is_email_verified(user_row),
    is_admin = isTRUE(user_row$is_admin[[1]]),
    db_access_enabled = isTRUE(user_row$db_access_enabled[[1]]) || isTRUE(user_row$is_admin[[1]])
  )
}

auth_issue_email_verification <- function(pool, user_id, email, purpose = "register") {
  normalized_email <- auth_normalize_email(email)
  if (is.null(user_id) || !nzchar(user_id) || !nzchar(normalized_email)) {
    return(list(success = FALSE, message = "缺少待验证邮箱信息"))
  }

  expires_minutes <- auth_email_verification_expire_minutes()
  code <- auth_generate_verification_code()
  token_id <- auth_generate_id("evt")
  token_hash <- auth_hash_token(code)

  DBI::dbWithTransaction(pool, {
    DBI::dbExecute(
      pool,
      paste(
        "UPDATE email_verification_tokens",
        "SET consumed_at = COALESCE(consumed_at, NOW())",
        "WHERE user_id = $1 AND target_email = $2 AND purpose = $3 AND consumed_at IS NULL"
      ),
      params = list(user_id, normalized_email, purpose)
    )
    DBI::dbExecute(
      pool,
      paste(
        "INSERT INTO email_verification_tokens",
        "(id, user_id, target_email, purpose, token_hash, expires_at, consumed_at, created_at)",
        "VALUES ($1, $2, $3, $4, $5, NOW() + ($6 * INTERVAL '1 minute'), NULL, NOW())"
      ),
      params = list(token_id, user_id, normalized_email, purpose, token_hash, expires_minutes)
    )
  })

  delivery <- auth_deliver_email_verification(normalized_email, code, purpose = purpose)
  if (!isTRUE(delivery$success)) {
    return(delivery)
  }
  c(
    list(
      success = TRUE,
      token_id = token_id,
      email = normalized_email
    ),
    delivery
  )
}

auth_verify_email_code <- function(pool, email, code, purpose = "register") {
  normalized_email <- auth_normalize_email(email)
  normalized_code <- trimws(code %||% "")
  if (!nzchar(normalized_email)) {
    return(list(success = FALSE, message = "请输入邮箱"))
  }
  if (!grepl("^[0-9]{4,8}$", normalized_code)) {
    return(list(success = FALSE, message = "请输入有效验证码"))
  }

  token_row <- DBI::dbGetQuery(
    pool,
    paste(
      "SELECT t.*, u.status AS user_status, u.email AS user_email",
      "FROM email_verification_tokens t",
      "JOIN users u ON u.id = t.user_id",
      "WHERE t.target_email = $1",
      "  AND t.purpose = $2",
      "  AND t.token_hash = $3",
      "  AND t.consumed_at IS NULL",
      "  AND t.expires_at >= NOW()",
      "ORDER BY t.created_at DESC",
      "LIMIT 1"
    ),
    params = list(normalized_email, purpose, auth_hash_token(normalized_code))
  )
  if (nrow(token_row) == 0) {
    return(list(success = FALSE, message = "验证码无效或已过期"))
  }
  if (!identical(token_row$user_status[[1]] %||% "", "active")) {
    return(list(success = FALSE, message = "账号已停用"))
  }

  user_id <- token_row$user_id[[1]] %||% ""
  DBI::dbWithTransaction(pool, {
    DBI::dbExecute(
      pool,
      "UPDATE users SET email_verified_at = COALESCE(email_verified_at, NOW()) WHERE id = $1",
      params = list(user_id)
    )
    DBI::dbExecute(
      pool,
      paste(
        "UPDATE email_verification_tokens",
        "SET consumed_at = COALESCE(consumed_at, NOW())",
        "WHERE user_id = $1 AND target_email = $2 AND purpose = $3 AND consumed_at IS NULL"
      ),
      params = list(user_id, normalized_email, purpose)
    )
  })

  user_row <- auth_get_user_by_id(pool, user_id)
  list(success = TRUE, message = "邮箱验证成功，现在可以登录了", user = auth_build_user_payload(user_row))
}

auth_resend_email_verification <- function(pool, email, purpose = "register") {
  normalized_email <- auth_normalize_email(email)
  email_error <- auth_validate_email(normalized_email)
  if (!is.null(email_error)) {
    return(list(success = FALSE, message = email_error))
  }

  user_row <- auth_get_user_by_email(pool, normalized_email)
  if (nrow(user_row) == 0) {
    return(list(success = FALSE, message = "未找到对应账号"))
  }
  if (!identical(user_row$status[[1]] %||% "", "active")) {
    return(list(success = FALSE, message = "账号已停用"))
  }
  if (auth_is_email_verified(user_row)) {
    return(list(success = TRUE, message = "当前邮箱已验证，无需重复发送"))
  }
  auth_issue_email_verification(pool, user_row$id[[1]], normalized_email, purpose = purpose)
}

auth_request_current_email_verification <- function(pool, user_id, purpose = "register") {
  if (!nzchar(user_id %||% "")) {
    return(list(success = FALSE, message = "缺少当前账号信息"))
  }

  user_row <- auth_get_user_by_id(pool, user_id)
  if (nrow(user_row) == 0) {
    return(list(success = FALSE, message = "当前账号不存在"))
  }
  if (!identical(user_row$status[[1]] %||% "", "active")) {
    return(list(success = FALSE, message = "账号已停用"))
  }

  normalized_email <- auth_normalize_email(user_row$email[[1]] %||% "")
  email_error <- auth_validate_email(normalized_email)
  if (!is.null(email_error)) {
    return(list(success = FALSE, message = "当前账号邮箱无效，请先完成邮箱换绑"))
  }
  if (auth_is_email_verified(user_row)) {
    return(list(success = TRUE, message = "当前邮箱已验证，无需重复发送"))
  }

  delivery <- auth_issue_email_verification(pool, user_id, normalized_email, purpose = purpose)
  if (!isTRUE(delivery$success)) {
    return(delivery)
  }
  delivery$message <- paste0("验证码已发送到当前邮箱。", delivery$message)
  delivery
}

auth_request_email_change <- function(pool, user_id, current_password, new_email) {
  if (!nzchar(user_id %||% "")) {
    return(list(success = FALSE, message = "缺少当前账号信息"))
  }

  user_row <- auth_get_user_by_id(pool, user_id)
  if (nrow(user_row) == 0) {
    return(list(success = FALSE, message = "当前账号不存在"))
  }
  if (!identical(user_row$status[[1]] %||% "", "active")) {
    return(list(success = FALSE, message = "账号已停用"))
  }
  if (!auth_verify_password(current_password %||% "", user_row$password_salt[[1]], user_row$password_hash[[1]])) {
    return(list(success = FALSE, message = "当前密码错误"))
  }

  normalized_email <- auth_normalize_email(new_email)
  email_error <- auth_validate_email(normalized_email)
  if (!is.null(email_error)) {
    return(list(success = FALSE, message = email_error))
  }
  current_email <- auth_normalize_email(user_row$email[[1]] %||% "")
  if (identical(normalized_email, current_email)) {
    return(list(success = FALSE, message = "新邮箱不能与当前邮箱相同"))
  }

  existing_user <- auth_get_user_by_email(pool, normalized_email)
  if (nrow(existing_user) > 0 && !identical(existing_user$id[[1]] %||% "", user_id)) {
    return(list(success = FALSE, message = "邮箱已被使用"))
  }

  delivery <- auth_issue_email_verification(pool, user_id, normalized_email, purpose = "change_email")
  if (!isTRUE(delivery$success)) {
    return(delivery)
  }
  delivery$message <- paste0("换绑验证码已发送到新邮箱。", delivery$message)
  delivery
}

auth_confirm_email_change <- function(pool, user_id, current_password, new_email, code) {
  if (!nzchar(user_id %||% "")) {
    return(list(success = FALSE, message = "缺少当前账号信息"))
  }

  user_row <- auth_get_user_by_id(pool, user_id)
  if (nrow(user_row) == 0) {
    return(list(success = FALSE, message = "当前账号不存在"))
  }
  if (!identical(user_row$status[[1]] %||% "", "active")) {
    return(list(success = FALSE, message = "账号已停用"))
  }
  if (!auth_verify_password(current_password %||% "", user_row$password_salt[[1]], user_row$password_hash[[1]])) {
    return(list(success = FALSE, message = "当前密码错误"))
  }

  normalized_email <- auth_normalize_email(new_email)
  email_error <- auth_validate_email(normalized_email)
  if (!is.null(email_error)) {
    return(list(success = FALSE, message = email_error))
  }

  existing_user <- auth_get_user_by_email(pool, normalized_email)
  if (nrow(existing_user) > 0 && !identical(existing_user$id[[1]] %||% "", user_id)) {
    return(list(success = FALSE, message = "邮箱已被使用"))
  }

  normalized_code <- trimws(code %||% "")
  if (!grepl("^[0-9]{4,8}$", normalized_code)) {
    return(list(success = FALSE, message = "请输入有效验证码"))
  }

  token_row <- DBI::dbGetQuery(
    pool,
    paste(
      "SELECT * FROM email_verification_tokens",
      "WHERE user_id = $1",
      "  AND target_email = $2",
      "  AND purpose = 'change_email'",
      "  AND token_hash = $3",
      "  AND consumed_at IS NULL",
      "  AND expires_at >= NOW()",
      "ORDER BY created_at DESC",
      "LIMIT 1"
    ),
    params = list(user_id, normalized_email, auth_hash_token(normalized_code))
  )
  if (nrow(token_row) == 0) {
    return(list(success = FALSE, message = "换绑验证码无效或已过期"))
  }

  DBI::dbWithTransaction(pool, {
    DBI::dbExecute(
      pool,
      paste(
        "UPDATE users",
        "SET email = $1, email_verified_at = NOW()",
        "WHERE id = $2"
      ),
      params = list(normalized_email, user_id)
    )
    DBI::dbExecute(
      pool,
      paste(
        "UPDATE email_verification_tokens",
        "SET consumed_at = COALESCE(consumed_at, NOW())",
        "WHERE user_id = $1 AND purpose = 'change_email' AND consumed_at IS NULL"
      ),
      params = list(user_id)
    )
  })

  updated_user <- auth_get_user_by_id(pool, user_id)
  list(success = TRUE, message = "邮箱换绑成功", user = auth_build_user_payload(updated_user))
}

auth_request_password_reset <- function(pool, email) {
  normalized_email <- auth_normalize_email(email)
  email_error <- auth_validate_email(normalized_email)
  if (!is.null(email_error)) {
    return(list(success = FALSE, message = email_error))
  }

  user_row <- auth_get_user_by_email(pool, normalized_email)
  if (nrow(user_row) == 0 || !identical(user_row$status[[1]] %||% "", "active")) {
    return(list(success = TRUE, message = "如果该邮箱已注册，系统会发送重置验证码。"))
  }

  expires_minutes <- auth_password_reset_expire_minutes()
  code <- auth_generate_verification_code()
  token_id <- auth_generate_id("prt")
  token_hash <- auth_hash_token(code)
  user_id <- user_row$id[[1]] %||% ""

  DBI::dbWithTransaction(pool, {
    DBI::dbExecute(
      pool,
      paste(
        "UPDATE password_reset_tokens",
        "SET consumed_at = COALESCE(consumed_at, NOW())",
        "WHERE user_id = $1 AND consumed_at IS NULL"
      ),
      params = list(user_id)
    )
    DBI::dbExecute(
      pool,
      paste(
        "INSERT INTO password_reset_tokens",
        "(id, user_id, email_snapshot, token_hash, expires_at, consumed_at, created_at)",
        "VALUES ($1, $2, $3, $4, NOW() + ($5 * INTERVAL '1 minute'), NULL, NOW())"
      ),
      params = list(token_id, user_id, normalized_email, token_hash, expires_minutes)
    )
  })

  delivery <- auth_deliver_password_reset(normalized_email, code)
  if (!isTRUE(delivery$success)) {
    return(delivery)
  }
  c(
    list(
      success = TRUE,
      token_id = token_id,
      email = normalized_email
    ),
    delivery
  )
}

auth_reset_password <- function(pool, email, code, new_password) {
  normalized_email <- auth_normalize_email(email)
  normalized_code <- trimws(code %||% "")
  password_error <- auth_validate_password(new_password)
  if (!is.null(password_error)) {
    return(list(success = FALSE, message = password_error))
  }
  if (!nzchar(normalized_email)) {
    return(list(success = FALSE, message = "请输入邮箱"))
  }
  if (!grepl("^[0-9]{4,8}$", normalized_code)) {
    return(list(success = FALSE, message = "请输入有效验证码"))
  }

  token_row <- DBI::dbGetQuery(
    pool,
    paste(
      "SELECT t.*, u.status AS user_status",
      "FROM password_reset_tokens t",
      "JOIN users u ON u.id = t.user_id",
      "WHERE t.email_snapshot = $1",
      "  AND t.token_hash = $2",
      "  AND t.consumed_at IS NULL",
      "  AND t.expires_at >= NOW()",
      "ORDER BY t.created_at DESC",
      "LIMIT 1"
    ),
    params = list(normalized_email, auth_hash_token(normalized_code))
  )
  if (nrow(token_row) == 0) {
    return(list(success = FALSE, message = "重置验证码无效或已过期"))
  }
  if (!identical(token_row$user_status[[1]] %||% "", "active")) {
    return(list(success = FALSE, message = "账号已停用"))
  }

  user_id <- token_row$user_id[[1]] %||% ""
  salt <- auth_generate_salt()
  password_hash <- auth_hash_password(new_password, salt)
  DBI::dbWithTransaction(pool, {
    DBI::dbExecute(
      pool,
      paste(
        "UPDATE users",
        "SET password_salt = $1, password_hash = $2",
        "WHERE id = $3"
      ),
      params = list(salt, password_hash, user_id)
    )
    DBI::dbExecute(
      pool,
      paste(
        "UPDATE password_reset_tokens",
        "SET consumed_at = COALESCE(consumed_at, NOW())",
        "WHERE user_id = $1 AND consumed_at IS NULL"
      ),
      params = list(user_id)
    )
  })

  list(success = TRUE, message = "密码已重置，请使用新密码登录")
}

auth_register_user <- function(pool, username, email, password) {
  username_error <- auth_validate_username(username)
  if (!is.null(username_error)) {
    return(list(success = FALSE, message = username_error, user = NULL))
  }
  email_error <- auth_validate_email(email)
  if (!is.null(email_error)) {
    return(list(success = FALSE, message = email_error, user = NULL))
  }
  password_error <- auth_validate_password(password)
  if (!is.null(password_error)) {
    return(list(success = FALSE, message = password_error, user = NULL))
  }
  normalized <- auth_normalize_username(username)
  normalized_email <- auth_normalize_email(email)
  existing <- auth_get_user_by_username(pool, normalized)
  if (nrow(existing) > 0) {
    return(list(success = FALSE, message = "用户名已存在", user = NULL))
  }
  email_existing <- auth_get_user_by_email(pool, normalized_email)
  if (nrow(email_existing) > 0) {
    return(list(success = FALSE, message = "邮箱已被使用", user = NULL))
  }
  user_id <- auth_generate_id("usr")
  salt <- auth_generate_salt()
  password_hash <- auth_hash_password(password, salt)
  DBI::dbExecute(
    pool,
    paste(
      "INSERT INTO users (id, username, email, email_verified_at, password_salt, password_hash, is_admin, db_access_enabled, status, created_at)",
      "VALUES ($1, $2, $3, NULL, $4, $5, $6, $7, 'active', NOW())"
    ),
    params = list(user_id, normalized, normalized_email, salt, password_hash, FALSE, FALSE)
  )
  delivery <- auth_issue_email_verification(pool, user_id, normalized_email, purpose = "register")
  created <- auth_get_user_by_id(pool, user_id)
  list(
    success = TRUE,
    message = "注册成功，请登录。登录后可在用户信息中自行验证邮箱。",
    user = auth_build_user_payload(created)
  )
}

auth_authenticate_user <- function(pool, identity, password) {
  user_row <- auth_get_user_by_identity(pool, identity)
  if (nrow(user_row) == 0) {
    return(list(success = FALSE, message = "用户名或密码错误", user = NULL))
  }
  if (!identical(user_row$status[[1]], "active")) {
    return(list(success = FALSE, message = "账号已停用", user = NULL))
  }
  if (!auth_verify_password(password, user_row$password_salt[[1]], user_row$password_hash[[1]])) {
    return(list(success = FALSE, message = "用户名或密码错误", user = NULL))
  }
  list(success = TRUE, message = "登录成功", user = auth_build_user_payload(user_row))
}

auth_ensure_bootstrap_admin <- function(pool) {
  config <- auth_resolve_bootstrap_admin_env()
  if (!isTRUE(config$valid)) {
    return(invisible(list(status = "skipped", reason = config$reason)))
  }

  username <- config$username
  email <- config$email
  password <- config$password

  existing_by_email <- auth_get_user_by_email(pool, email)
  existing_by_username <- auth_get_user_by_username(pool, username)

  email_user_id <- if (nrow(existing_by_email) > 0) existing_by_email$id[[1]] %||% "" else ""
  username_user_id <- if (nrow(existing_by_username) > 0) existing_by_username$id[[1]] %||% "" else ""

  if (nzchar(email_user_id) && nzchar(username_user_id) && !identical(email_user_id, username_user_id)) {
    stop("管理员环境变量冲突：APP_ADMIN_EMAIL 与 APP_ADMIN_USERNAME 分别命中不同账号，请先清理历史账号后再启动。")
  }

  salt <- auth_generate_salt()
  password_hash <- auth_hash_password(password, salt)

  if (!nzchar(email_user_id) && !nzchar(username_user_id)) {
    user_id <- auth_generate_id("usr")
    DBI::dbExecute(
      pool,
      paste(
        "INSERT INTO users (id, username, email, email_verified_at, password_salt, password_hash, is_admin, db_access_enabled, status, created_at)",
        "VALUES ($1, $2, $3, NOW(), $4, $5, TRUE, TRUE, 'active', NOW())"
      ),
      params = list(user_id, username, email, salt, password_hash)
    )
    return(invisible(list(status = "inserted", user_id = user_id, username = username, email = email)))
  }

  target_row <- if (nrow(existing_by_email) > 0) existing_by_email else existing_by_username
  target_user_id <- target_row$id[[1]] %||% ""
  DBI::dbExecute(
    pool,
    paste(
      "UPDATE users",
      "SET username = $1, email = $2, password_salt = $3, password_hash = $4,",
      "is_admin = TRUE, db_access_enabled = TRUE, status = 'active', email_verified_at = COALESCE(email_verified_at, NOW())",
      "WHERE id = $5"
    ),
    params = list(username, email, salt, password_hash, target_user_id)
  )
  invisible(list(status = "updated", user_id = target_user_id, username = username, email = email))
}

auth_ensure_workspace_membership <- function(pool, workspace_id, user_id, role = "owner") {
  if (is.null(workspace_id) || !nzchar(workspace_id) || is.null(user_id) || !nzchar(user_id)) {
    return(invisible(FALSE))
  }
  DBI::dbExecute(
    pool,
    paste(
      "INSERT INTO workspace_memberships (id, workspace_id, user_id, role, created_at)",
      "VALUES ($1, $2, $3, $4, NOW())",
      "ON CONFLICT (workspace_id, user_id) DO UPDATE SET role = EXCLUDED.role"
    ),
    params = list(auth_generate_id("wsm"), workspace_id, user_id, role)
  )
  invisible(TRUE)
}

auth_filter_registry <- function(reg, workspace_ids, is_admin = FALSE) {
  workspace_ids <- unique(workspace_ids %||% character(0))
  if (length(workspace_ids) == 0) {
    return(auth_empty_registry())
  }
  workspaces <- reg$workspaces[reg$workspaces$id %in% workspace_ids, , drop = FALSE]
  folders <- reg$folders[reg$folders$workspace_id %in% workspace_ids, , drop = FALSE]
  datasets <- reg$datasets[reg$datasets$workspace_id %in% workspace_ids, , drop = FALSE]
  list(workspaces = workspaces, folders = folders, datasets = datasets)
}

auth_accessible_workspace_ids <- function(pool, user_id, is_admin = FALSE) {
  if (is.null(user_id) || !nzchar(user_id)) {
    return(character(0))
  }
  owned <- DBI::dbGetQuery(
    pool,
    "SELECT id FROM workspaces WHERE owner_user_id = $1",
    params = list(user_id)
  )
  member <- DBI::dbGetQuery(
    pool,
    "SELECT workspace_id FROM workspace_memberships WHERE user_id = $1",
    params = list(user_id)
  )
  unique(c(owned$id %||% character(0), member$workspace_id %||% character(0)))
}

auth_user_can_access_workspace <- function(pool, user_id, is_admin = FALSE, workspace_id) {
  if (is.null(workspace_id) || !nzchar(workspace_id)) {
    return(FALSE)
  }
  workspace_id %in% auth_accessible_workspace_ids(pool, user_id, is_admin)
}

auth_load_registry <- function(pool, user_id = NULL, is_admin = FALSE) {
  reg <- tryCatch(
    list(
      workspaces = DBI::dbGetQuery(pool, "SELECT * FROM workspaces ORDER BY created_at DESC"),
      folders = DBI::dbGetQuery(pool, "SELECT * FROM folders ORDER BY created_at DESC"),
      datasets = DBI::dbGetQuery(pool, "SELECT * FROM datasets ORDER BY created_at DESC")
    ),
    error = function(e) auth_empty_registry()
  )
  auth_filter_registry(reg, auth_accessible_workspace_ids(pool, user_id, is_admin = FALSE), is_admin = FALSE)
}
