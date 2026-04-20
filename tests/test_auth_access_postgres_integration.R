library(testthat)

args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_path <- if (length(script_path) > 0) script_path[[1]] else ""
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- if (length(script_path) > 0 && nzchar(script_path)) {
  normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)
} else {
  wd <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  if (basename(wd) == "tests") normalizePath(file.path(wd, ".."), winslash = "/", mustWork = TRUE) else wd
}

source(file.path(project_root, "modules", "common", "auth.R"), local = TRUE)
source(file.path(project_root, "modules", "common", "account_service.R"), local = TRUE)

load_env_file <- function(file_path) {
  if (!file.exists(file_path)) {
    return(invisible(FALSE))
  }
  lines <- readLines(file_path, warn = FALSE, encoding = "UTF-8")
  for (line in lines) {
    trimmed <- trimws(line)
    if (!nzchar(trimmed) || startsWith(trimmed, "#")) {
      next
    }
    idx <- regexpr("=", trimmed, fixed = TRUE)[[1]]
    if (idx <= 1) {
      next
    }
    key <- trimws(substr(trimmed, 1, idx - 1))
    value <- trimws(substr(trimmed, idx + 1, nchar(trimmed)))
    do.call(Sys.setenv, stats::setNames(list(value), key))
  }
  invisible(TRUE)
}

load_env_file(file.path(project_root, ".env.test"))

with_env_vars <- function(vars, code) {
  old_values <- Sys.getenv(names(vars), unset = NA_character_)
  on.exit({
    for (key in names(old_values)) {
      old_value <- old_values[[key]]
      if (is.na(old_value)) {
        Sys.unsetenv(key)
      } else {
        do.call(Sys.setenv, stats::setNames(list(old_value), key))
      }
    }
  }, add = TRUE)
  for (key in names(vars)) {
    value <- vars[[key]]
    if (is.null(value) || identical(value, "")) {
      Sys.unsetenv(key)
    } else {
        do.call(Sys.setenv, stats::setNames(list(as.character(value)), key))
    }
  }
  force(code)
}

skip_if_no_test_db <- function() {
  if (!requireNamespace("DBI", quietly = TRUE) || !requireNamespace("RPostgres", quietly = TRUE)) {
    skip("缺少 DBI 或 RPostgres，跳过 PostgreSQL 集成测试")
  }
  required_env <- c("POSTGRES_HOST", "POSTGRES_PORT", "POSTGRES_DB", "POSTGRES_USER", "POSTGRES_PASSWORD")
  values <- Sys.getenv(required_env, "")
  if (any(!nzchar(values))) {
    skip("未检测到完整的 PostgreSQL 测试环境变量，跳过集成测试")
  }
}

with_isolated_auth_schema <- function(code) {
  skip_if_no_test_db()

  conn <- tryCatch(
    DBI::dbConnect(
      RPostgres::Postgres(),
      host = Sys.getenv("POSTGRES_HOST"),
      port = as.integer(Sys.getenv("POSTGRES_PORT")),
      dbname = Sys.getenv("POSTGRES_DB"),
      user = Sys.getenv("POSTGRES_USER"),
      password = Sys.getenv("POSTGRES_PASSWORD")
    ),
    error = function(e) {
      skip(paste0("PostgreSQL 测试库不可达：", e$message))
    }
  )
  on.exit(try(DBI::dbDisconnect(conn), silent = TRUE), add = TRUE)

  schema_name <- paste0(
    "autotfl_auth_test_",
    format(Sys.time(), "%Y%m%d%H%M%S"),
    "_",
    paste(sample(c(letters, 0:9), 6, replace = TRUE), collapse = "")
  )
  quoted_schema <- DBI::dbQuoteIdentifier(conn, schema_name)
  DBI::dbExecute(conn, paste("CREATE SCHEMA", quoted_schema))
  on.exit(
    try(DBI::dbExecute(conn, paste("DROP SCHEMA IF EXISTS", quoted_schema, "CASCADE")), silent = TRUE),
    add = TRUE
  )
  DBI::dbExecute(conn, paste("SET search_path TO", quoted_schema))
  auth_ensure_schema(conn)

  force(code)(conn, schema_name)
}

test_that("管理员初始化必须依赖完整环境变量", {
  with_isolated_auth_schema(function(conn, schema_name) {
    expect_true(nzchar(schema_name))

    with_env_vars(
      c(APP_ADMIN_USERNAME = "bootstrap_admin", APP_ADMIN_EMAIL = "", APP_ADMIN_PASSWORD = "StrongPass123"),
      {
        auth_ensure_bootstrap_admin(conn)
      }
    )
    expect_equal(nrow(auth_list_users(conn)), 0)

    with_env_vars(
      c(
        APP_ADMIN_USERNAME = "bootstrap_admin",
        APP_ADMIN_EMAIL = "bootstrap_admin@example.com",
        APP_ADMIN_PASSWORD = "StrongPass123"
      ),
      {
        auth_ensure_bootstrap_admin(conn)
      }
    )
    users <- auth_list_users(conn)
    expect_equal(nrow(users), 1)
    expect_true(isTRUE(users$is_admin[[1]]))
    expect_true(isTRUE(users$db_access_enabled[[1]]))
    expect_identical(users$email[[1]], "bootstrap_admin@example.com")
    expect_false(is.na(users$email_verified_at[[1]]))
  })
})

test_that("管理员初始化会对齐已有账号并同步用户名邮箱与密码", {
  with_isolated_auth_schema(function(conn, schema_name) {
    expect_true(nzchar(schema_name))

    created <- auth_register_user(conn, "legacy_admin", "admin@example.com", "OldPass123")
    expect_true(isTRUE(created$success))

    with_env_vars(
      c(
        APP_ADMIN_USERNAME = "platform_admin",
        APP_ADMIN_EMAIL = "admin@example.com",
        APP_ADMIN_PASSWORD = "NewStrongPass123"
      ),
      {
        result <- auth_ensure_bootstrap_admin(conn)
        expect_identical(result$status, "updated")
      }
    )

    synced_by_email <- auth_get_user_by_email(conn, "admin@example.com")
    expect_equal(nrow(synced_by_email), 1)
    expect_identical(synced_by_email$username[[1]], "platform_admin")
    expect_true(isTRUE(synced_by_email$is_admin[[1]]))
    expect_true(isTRUE(synced_by_email$db_access_enabled[[1]]))
    expect_identical(synced_by_email$status[[1]], "active")
    expect_false(is.na(synced_by_email$email_verified_at[[1]]))
    expect_true(auth_verify_password("NewStrongPass123", synced_by_email$password_salt[[1]], synced_by_email$password_hash[[1]]))
    expect_false(auth_verify_password("OldPass123", synced_by_email$password_salt[[1]], synced_by_email$password_hash[[1]]))
  })
})

test_that("管理员初始化遇到邮箱和用户名分属不同账号时会拒绝同步", {
  with_isolated_auth_schema(function(conn, schema_name) {
    expect_true(nzchar(schema_name))

    first_user <- auth_register_user(conn, "admin_name", "name_owner@example.com", "StrongPass123")
    second_user <- auth_register_user(conn, "other_user", "admin@example.com", "StrongPass123")
    expect_true(isTRUE(first_user$success))
    expect_true(isTRUE(second_user$success))

    with_env_vars(
      c(
        APP_ADMIN_USERNAME = "admin_name",
        APP_ADMIN_EMAIL = "admin@example.com",
        APP_ADMIN_PASSWORD = "AnotherPass123"
      ),
      {
        expect_error(
          auth_ensure_bootstrap_admin(conn),
          "APP_ADMIN_EMAIL 与 APP_ADMIN_USERNAME 分别命中不同账号"
        )
      }
    )
  })
})

test_that("自注册用户不会自动成为管理员", {
  with_isolated_auth_schema(function(conn, schema_name) {
    expect_true(nzchar(schema_name))

    with_env_vars(
      c(APP_ADMIN_USERNAME = "", APP_ADMIN_EMAIL = "", APP_ADMIN_PASSWORD = ""),
      {
        result <- auth_register_user(conn, "plain_user", "plain_user@example.com", "StrongPass123")
        expect_true(isTRUE(result$success))
        expect_false(isTRUE(result$user$is_admin))
        expect_false(isTRUE(result$user$email_verified))
      }
    )

    created <- auth_get_user_by_username(conn, "plain_user")
    expect_equal(nrow(created), 1)
    expect_false(isTRUE(created$is_admin[[1]]))
    expect_false(isTRUE(created$db_access_enabled[[1]]))
    expect_true(is.na(created$email_verified_at[[1]]))
  })
})

test_that("注册后可直接登录，邮箱验证改为登录后自助完成", {
  with_isolated_auth_schema(function(conn, schema_name) {
    expect_true(nzchar(schema_name))

    with_env_vars(
      c(
        AUTH_REQUIRE_EMAIL_VERIFICATION = "0",
        AUTH_DEV_SHOW_EMAIL_CODE = "1",
        EMAIL_DELIVERY_MODE = "console"
      ),
      {
        created <- auth_register_user(conn, "verify_me", "verify_me@test.local", "StrongPass123")
        expect_true(isTRUE(created$success))
        expect_match(created$message, "注册成功，请登录")

        allowed_login <- auth_authenticate_user(conn, "verify_me@test.local", "StrongPass123")
        expect_true(isTRUE(allowed_login$success))
        expect_false(isTRUE(allowed_login$user$email_verified))

        request_verify <- auth_request_current_email_verification(conn, created$user$id, purpose = "register")
        expect_true(isTRUE(request_verify$success))
        expect_true(nzchar(request_verify$preview_code %||% ""))

        verify_result <- auth_verify_email_code(conn, "verify_me@test.local", request_verify$preview_code, purpose = "register")
        expect_true(isTRUE(verify_result$success))
        relogin <- auth_authenticate_user(conn, "verify_me@test.local", "StrongPass123")
        expect_true(isTRUE(relogin$success))
        expect_true(isTRUE(relogin$user$email_verified))
      }
    )
  })
})

test_that("重发验证码会替换旧验证码", {
  with_isolated_auth_schema(function(conn, schema_name) {
    expect_true(nzchar(schema_name))

    with_env_vars(
      c(
        AUTH_REQUIRE_EMAIL_VERIFICATION = "0",
        AUTH_DEV_SHOW_EMAIL_CODE = "1",
        EMAIL_DELIVERY_MODE = "console"
      ),
      {
        created <- auth_register_user(conn, "resend_me", "resend_me@test.local", "StrongPass123")
        expect_true(isTRUE(created$success))
        first_send <- auth_request_current_email_verification(conn, created$user$id, purpose = "register")
        expect_true(isTRUE(first_send$success))
        old_code <- first_send$preview_code %||% ""
        resend <- auth_request_current_email_verification(conn, created$user$id, purpose = "register")
        expect_true(isTRUE(resend$success))
        new_code <- resend$preview_code %||% ""
        expect_true(nzchar(new_code))
        expect_false(identical(old_code, new_code))

        old_verify <- auth_verify_email_code(conn, "resend_me@test.local", old_code, purpose = "register")
        expect_false(isTRUE(old_verify$success))
        expect_match(old_verify$message, "验证码无效或已过期")

        new_verify <- auth_verify_email_code(conn, "resend_me@test.local", new_code, purpose = "register")
        expect_true(isTRUE(new_verify$success))
      }
    )
  })
})

test_that("密码重置请求不泄露账号是否存在，且重置后旧密码失效", {
  with_isolated_auth_schema(function(conn, schema_name) {
    expect_true(nzchar(schema_name))

    with_env_vars(
      c(
        AUTH_REQUIRE_EMAIL_VERIFICATION = "0",
        AUTH_DEV_SHOW_EMAIL_CODE = "1",
        EMAIL_DELIVERY_MODE = "console",
        AUTH_PASSWORD_RESET_EXPIRE_MINUTES = "30"
      ),
      {
        created <- auth_register_user(conn, "reset_user", "reset_user@test.local", "StrongPass123")
        expect_true(isTRUE(created$success))

        missing_request <- auth_request_password_reset(conn, "unknown@test.local")
        expect_true(isTRUE(missing_request$success))
        expect_match(missing_request$message, "如果该邮箱已注册")

        reset_request <- auth_request_password_reset(conn, "reset_user@test.local")
        expect_true(isTRUE(reset_request$success))
        expect_true(nzchar(reset_request$preview_code %||% ""))

        reset_result <- auth_reset_password(conn, "reset_user@test.local", reset_request$preview_code, "NewStrongPass123")
        expect_true(isTRUE(reset_result$success))

        old_login <- auth_authenticate_user(conn, "reset_user@test.local", "StrongPass123")
        expect_false(isTRUE(old_login$success))
        new_login <- auth_authenticate_user(conn, "reset_user@test.local", "NewStrongPass123")
        expect_true(isTRUE(new_login$success))

        reused_reset <- auth_reset_password(conn, "reset_user@test.local", reset_request$preview_code, "AnotherStrongPass123")
        expect_false(isTRUE(reused_reset$success))
        expect_match(reused_reset$message, "重置验证码无效或已过期")
      }
    )
  })
})

test_that("邮箱换绑要求当前密码和新邮箱验证码，成功后会切换邮箱并认领邀请", {
  with_isolated_auth_schema(function(conn, schema_name) {
    expect_true(nzchar(schema_name))

    with_env_vars(
      c(
        AUTH_REQUIRE_EMAIL_VERIFICATION = "0",
        AUTH_DEV_SHOW_EMAIL_CODE = "1",
        EMAIL_DELIVERY_MODE = "console"
      ),
      {
        created <- auth_register_user(conn, "change_user", "change_user@test.local", "StrongPass123")
        expect_true(isTRUE(created$success))

        workspace <- service_create_workspace(conn, "mail-change-space", created$user$id)
        invite_result <- service_grant_workspace_access_by_email(
          conn,
          workspace$id,
          "new_mail@test.local",
          "viewer",
          created$user
        )
        expect_identical(invite_result$mode, "invite")

        bad_request <- auth_request_email_change(conn, created$user$id, "WrongPass123", "new_mail@test.local")
        expect_false(isTRUE(bad_request$success))
        expect_match(bad_request$message, "当前密码错误")

        change_request <- auth_request_email_change(conn, created$user$id, "StrongPass123", "new_mail@test.local")
        expect_true(isTRUE(change_request$success))
        expect_true(nzchar(change_request$preview_code %||% ""))

        bad_confirm <- auth_confirm_email_change(conn, created$user$id, "StrongPass123", "new_mail@test.local", "000000")
        expect_false(isTRUE(bad_confirm$success))
        expect_match(bad_confirm$message, "换绑验证码无效或已过期")

        confirmed <- auth_confirm_email_change(conn, created$user$id, "StrongPass123", "new_mail@test.local", change_request$preview_code)
        expect_true(isTRUE(confirmed$success))
        expect_identical(confirmed$user$email, "new_mail@test.local")
        expect_true(isTRUE(confirmed$user$email_verified))

        service_claim_workspace_invites(conn, confirmed$user$id, confirmed$user$email)
        accepted_invites <- service_list_workspace_invites(conn, workspace$id)
        expect_identical(accepted_invites$status[[1]], "accepted")
        memberships <- service_list_workspace_memberships(conn, workspace$id)
        expect_true(any(memberships$user_id %||% character(0) == confirmed$user$id))
      }
    )
  })
})

test_that("登录后可通过当前密码修改密码", {
  with_isolated_auth_schema(function(conn, schema_name) {
    expect_true(nzchar(schema_name))

    created <- auth_register_user(conn, "pwd_user", "pwd_user@test.local", "StrongPass123")
    expect_true(isTRUE(created$success))

    bad_change <- auth_change_password(conn, created$user$id, "WrongPass123", "NewStrongPass123")
    expect_false(isTRUE(bad_change$success))
    expect_match(bad_change$message, "当前密码错误")

    changed <- auth_change_password(conn, created$user$id, "StrongPass123", "NewStrongPass123")
    expect_true(isTRUE(changed$success))

    old_login <- auth_authenticate_user(conn, "pwd_user@test.local", "StrongPass123")
    expect_false(isTRUE(old_login$success))
    new_login <- auth_authenticate_user(conn, "pwd_user@test.local", "NewStrongPass123")
    expect_true(isTRUE(new_login$success))
  })
})

test_that("管理员不能自动访问或管理其他用户数据空间", {
  with_isolated_auth_schema(function(conn, schema_name) {
    expect_true(nzchar(schema_name))

    with_env_vars(
      c(
        APP_ADMIN_USERNAME = "bootstrap_admin",
        APP_ADMIN_EMAIL = "bootstrap_admin@example.com",
        APP_ADMIN_PASSWORD = "StrongPass123"
      ),
      {
        auth_ensure_bootstrap_admin(conn)
      }
    )

    admin_row <- auth_get_user_by_username(conn, "bootstrap_admin")
    admin_user <- auth_build_user_payload(admin_row)

    alice_result <- auth_register_user(conn, "alice_user", "alice_user@example.com", "StrongPass123")
    bob_result <- auth_register_user(conn, "bob_user", "bob_user@example.com", "StrongPass123")
    expect_true(isTRUE(alice_result$success))
    expect_true(isTRUE(bob_result$success))

    admin_workspace <- service_create_workspace(conn, "admin-space", admin_user$id)
    alice_workspace <- service_create_workspace(conn, "alice-space", alice_result$user$id)
    auth_ensure_workspace_membership(conn, alice_workspace$id, bob_result$user$id, role = "viewer")

    admin_accessible <- auth_accessible_workspace_ids(conn, admin_user$id, is_admin = TRUE)
    alice_accessible <- auth_accessible_workspace_ids(conn, alice_result$user$id, is_admin = FALSE)
    bob_accessible <- auth_accessible_workspace_ids(conn, bob_result$user$id, is_admin = FALSE)

    expect_true(admin_workspace$id %in% admin_accessible)
    expect_false(alice_workspace$id %in% admin_accessible)
    expect_true(alice_workspace$id %in% alice_accessible)
    expect_true(alice_workspace$id %in% bob_accessible)

    expect_true(service_can_manage_workspace(conn, admin_workspace$id, admin_user))
    expect_false(service_can_manage_workspace(conn, alice_workspace$id, admin_user))
    expect_false(auth_user_can_access_workspace(conn, admin_user$id, is_admin = TRUE, alice_workspace$id))
    expect_true(auth_user_can_access_workspace(conn, bob_result$user$id, is_admin = FALSE, alice_workspace$id))
  })
})
