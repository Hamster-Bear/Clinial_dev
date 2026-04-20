`%||%` <- function(x, y) if (is.null(x)) y else x

email_service_is_true_env <- function(name, default = FALSE) {
  raw_value <- trimws(Sys.getenv(name, if (isTRUE(default)) "1" else "0"))
  tolower(raw_value) %in% c("1", "true", "yes", "on")
}

email_service_mode <- function() {
  mode <- tolower(trimws(Sys.getenv("EMAIL_DELIVERY_MODE", "console")))
  if (!mode %in% c("console", "disabled", "smtp")) {
    mode <- "console"
  }
  mode
}

email_service_from_address <- function() {
  trimws(Sys.getenv("EMAIL_FROM_ADDRESS", ""))
}

email_service_from_label <- function() {
  trimws(Sys.getenv("EMAIL_FROM_LABEL", "AutoTFL"))
}

email_service_smtp_config <- function() {
  list(
    host = trimws(Sys.getenv("SMTP_HOST", "")),
    port = suppressWarnings(as.integer(Sys.getenv("SMTP_PORT", "587"))),
    username = trimws(Sys.getenv("SMTP_USERNAME", "")),
    password = Sys.getenv("SMTP_PASSWORD", ""),
    use_ssl = tolower(trimws(Sys.getenv("SMTP_USE_SSL", "try")))
  )
}

email_service_validate_smtp_config <- function(config = email_service_smtp_config()) {
  missing_fields <- character(0)
  if (!nzchar(config$host %||% "")) missing_fields <- c(missing_fields, "SMTP_HOST")
  if (is.na(config$port) || config$port <= 0) missing_fields <- c(missing_fields, "SMTP_PORT")
  if (!nzchar(config$username %||% "")) missing_fields <- c(missing_fields, "SMTP_USERNAME")
  if (!nzchar(config$password %||% "")) missing_fields <- c(missing_fields, "SMTP_PASSWORD")
  if (!((config$use_ssl %||% "") %in% c("force", "try", "no"))) missing_fields <- c(missing_fields, "SMTP_USE_SSL")
  if (!nzchar(email_service_from_address())) missing_fields <- c(missing_fields, "EMAIL_FROM_ADDRESS")

  list(
    valid = length(missing_fields) == 0,
    missing_fields = unique(missing_fields),
    config = config
  )
}

email_service_compose_message <- function(to, subject, body, from_address = email_service_from_address(), from_label = email_service_from_label()) {
  normalized_to <- trimws(to %||% "")
  normalized_subject <- trimws(subject %||% "")
  normalized_body <- gsub("\\r?\\n", "\r\n", body %||% "")
  normalized_from <- trimws(from_address %||% "")
  sender_label <- trimws(from_label %||% "AutoTFL")

  message_text <- paste0(
    "From: ", sender_label, " <", normalized_from, ">\r\n",
    "To: <", normalized_to, ">\r\n",
    "Subject: ", normalized_subject, "\r\n",
    "MIME-Version: 1.0\r\n",
    "Content-Type: text/plain; charset=UTF-8\r\n",
    "\r\n",
    normalized_body,
    "\r\n"
  )
  charToRaw(message_text)
}

email_service_send <- function(to, subject, body) {
  mode <- email_service_mode()
  normalized_to <- trimws(to %||% "")
  normalized_subject <- trimws(subject %||% "")
  normalized_body <- body %||% ""

  if (!nzchar(normalized_to)) {
    return(list(success = FALSE, mode = mode, message = "缺少收件邮箱"))
  }
  if (!nzchar(normalized_subject)) {
    return(list(success = FALSE, mode = mode, message = "缺少邮件主题"))
  }

  if (identical(mode, "disabled")) {
    return(list(success = TRUE, mode = mode, message = "邮件投递已禁用，当前跳过真实发送"))
  }

  if (identical(mode, "console")) {
    message(
      paste0(
        "[AutoTFL][EmailConsole] to=", normalized_to,
        " subject=", normalized_subject,
        " body=", normalized_body
      )
    )
    return(list(success = TRUE, mode = mode, message = "邮件内容已输出到控制台"))
  }

  validation <- email_service_validate_smtp_config()
  if (!isTRUE(validation$valid)) {
    return(list(
      success = FALSE,
      mode = mode,
      message = paste0("SMTP 配置不完整：", paste(validation$missing_fields, collapse = ", "))
    ))
  }
  if (!requireNamespace("curl", quietly = TRUE)) {
    return(list(success = FALSE, mode = mode, message = "缺少 curl 包，无法执行 SMTP 投递"))
  }

  smtp_config <- validation$config
  smtp_server <- paste0("smtp://", smtp_config$host, ":", smtp_config$port)
  smtp_message <- email_service_compose_message(
    to = normalized_to,
    subject = normalized_subject,
    body = normalized_body
  )

  tryCatch(
    {
      curl::send_mail(
        mail_from = email_service_from_address(),
        mail_rcpt = normalized_to,
        message = smtp_message,
        smtp_server = smtp_server,
        username = smtp_config$username,
        password = smtp_config$password,
        use_ssl = smtp_config$use_ssl
      )
      list(success = TRUE, mode = mode, message = "邮件已发送")
    },
    error = function(e) {
      list(success = FALSE, mode = mode, message = paste0("SMTP 发送失败：", e$message))
    }
  )
}

email_service_probe_summary <- function() {
  mode <- email_service_mode()
  validation <- email_service_validate_smtp_config()
  paste0(
    "邮件模式: ", mode, "\n",
    "发件邮箱: ", if (nzchar(email_service_from_address())) email_service_from_address() else "未设置", "\n",
    "发件标签: ", if (nzchar(email_service_from_label())) email_service_from_label() else "未设置", "\n",
    "SMTP_HOST: ", if (nzchar(validation$config$host %||% "")) validation$config$host else "未设置", "\n",
    "SMTP_PORT: ", if (!is.na(validation$config$port)) validation$config$port else "未设置", "\n",
    "SMTP_USERNAME: ", if (nzchar(validation$config$username %||% "")) validation$config$username else "未设置", "\n",
    "SMTP 配置状态: ", if (isTRUE(validation$valid)) "完整" else paste0("缺失 ", paste(validation$missing_fields, collapse = ", "))
  )
}

email_service_send_probe <- function(to) {
  probe_to <- trimws(to %||% "")
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
  subject <- paste0("[AutoTFL] SMTP 连通性测试 ", timestamp)
  body <- paste0(
    "这是一封 AutoTFL SMTP 连通性探针邮件。\n",
    "发送时间: ", timestamp, "\n",
    "当前模式: ", email_service_mode(), "\n"
  )
  email_service_send(probe_to, subject, body)
}
