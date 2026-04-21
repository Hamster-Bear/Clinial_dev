# 通用卡片 UI 壳层

app_card_dependencies <- function() {
  tags$head(
    singleton(
      tags$style(HTML("
        .app-card.box {
          border-radius: 14px;
          border: 1px solid #e7edf4;
          box-shadow: 0 10px 24px rgba(31, 45, 61, 0.06);
          overflow: hidden;
          background: #ffffff;
          margin-bottom: 18px;
        }
        .app-card > .box-header {
          background: #ffffff;
          color: #243447;
          border-bottom: 1px solid #edf2f7;
          padding: 14px 18px 12px;
        }
        .app-card > .box-header.with-border {
          border-bottom: 1px solid #edf2f7;
        }
        .app-card > .box-body {
          padding: 16px 18px 18px;
        }
        .app-card .box-title {
          display: flex;
          align-items: center;
          gap: 10px;
          width: 100%;
          color: #243447;
          font-weight: 600;
          font-size: 15px;
          line-height: 1.4;
        }
        .app-card__title-main {
          display: flex;
          flex-direction: column;
          gap: 2px;
          min-width: 0;
        }
        .app-card__title-text {
          font-weight: 600;
          color: #243447;
        }
        .app-card__title-subtitle {
          font-size: 12px;
          font-weight: 400;
          color: #7b8794;
          line-height: 1.5;
        }
        .app-card__tone {
          width: 8px;
          height: 32px;
          border-radius: 999px;
          flex: 0 0 auto;
          background: #5b8def;
        }
        .app-card--primary .app-card__tone {
          background: linear-gradient(180deg, #4f8df7 0%, #2f6de0 100%);
        }
        .app-card--info .app-card__tone {
          background: linear-gradient(180deg, #56b5f8 0%, #2e90d1 100%);
        }
        .app-card--success .app-card__tone {
          background: linear-gradient(180deg, #4dc98f 0%, #2f9d68 100%);
        }
        .app-card--warning .app-card__tone {
          background: linear-gradient(180deg, #f2b24f 0%, #dd8f1f 100%);
        }
        .app-card--danger .app-card__tone {
          background: linear-gradient(180deg, #f27c7c 0%, #de5252 100%);
        }
        .app-card__note {
          margin-top: 10px;
          color: #6b7785;
          line-height: 1.7;
        }
        .app-card__panel {
          padding: 12px 14px;
          border-radius: 12px;
          border: 1px solid #e8eef5;
          background: #f8fbff;
          color: #4f5f73;
        }
        .app-card__panel strong {
          color: #243447;
        }
        .app-result-panel {
          padding: 14px 16px;
          border-radius: 12px;
          border: 1px solid #e8eef5;
          background: #fbfdff;
          color: #4f5f73;
        }
        .app-result-panel--primary {
          background: #f7faff;
        }
        .app-result-panel--info {
          background: #f8fbff;
        }
        .app-result-panel--success {
          background: #f7fcf9;
        }
        .app-result-panel--warning {
          background: #fffaf2;
        }
        .app-result-panel__title {
          color: #243447;
          font-weight: 600;
          line-height: 1.5;
        }
        .app-result-panel__note {
          margin-top: 6px;
          margin-bottom: 10px;
          color: #6b7785;
          font-size: 12px;
          line-height: 1.6;
        }
        .app-result-panel__body {
          min-height: 0;
        }
        .app-result-panel__empty {
          padding: 10px 12px;
          border: 1px dashed #d6e1ec;
          border-radius: 10px;
          background: #ffffff;
          color: #7b8794;
          line-height: 1.6;
        }
        .app-result-panel pre {
          margin: 0;
          padding: 0;
          border: 0;
          background: transparent;
          color: #4f5f73;
          line-height: 1.7;
          white-space: pre-wrap;
          word-break: break-word;
        }
        .app-card .nav-tabs {
          border-bottom: 1px solid #e9eef5;
          margin-bottom: 14px;
        }
        .app-card .nav-tabs > li > a {
          color: #5f6b7a;
          font-weight: 500;
          border-radius: 10px 10px 0 0;
        }
        .app-card .nav-tabs > li.active > a,
        .app-card .nav-tabs > li.active > a:hover,
        .app-card .nav-tabs > li.active > a:focus {
          color: #243447;
          background: #f8fbff;
          border: 1px solid #e9eef5;
          border-bottom-color: transparent;
        }
        .app-stat-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
          gap: 12px;
          margin-bottom: 12px;
        }
        .app-stat-card {
          border: 1px solid #e7edf4;
          border-radius: 14px;
          background: #ffffff;
          box-shadow: 0 8px 20px rgba(31, 45, 61, 0.05);
          padding: 14px 16px;
          min-height: 108px;
          display: flex;
          flex-direction: column;
          justify-content: space-between;
        }
        .app-stat-card__label {
          color: #7b8794;
          font-size: 12px;
          line-height: 1.5;
        }
        .app-stat-card__value {
          color: #243447;
          font-size: 26px;
          font-weight: 700;
          line-height: 1.2;
          margin-top: 6px;
          word-break: break-word;
        }
        .app-stat-card__meta {
          color: #5f6b7a;
          font-size: 12px;
          line-height: 1.6;
          margin-top: 8px;
          word-break: break-word;
        }
        .app-stat-card--primary {
          border-top: 4px solid #4f8df7;
        }
        .app-stat-card--info {
          border-top: 4px solid #56b5f8;
        }
        .app-stat-card--success {
          border-top: 4px solid #4dc98f;
        }
        .app-stat-card--warning {
          border-top: 4px solid #f2b24f;
        }
        .app-stat-card--danger {
          border-top: 4px solid #f27c7c;
        }
        .app-stat-card__chips {
          display: flex;
          flex-wrap: wrap;
          gap: 8px;
          margin-top: 8px;
        }
        .app-stat-chip {
          display: inline-flex;
          align-items: center;
          gap: 6px;
          padding: 6px 10px;
          border-radius: 999px;
          background: #f4f7fb;
          color: #4f5f73;
          font-size: 12px;
          line-height: 1.4;
          white-space: normal;
        }
        .app-stat-chip strong {
          color: #243447;
        }
        .app-card .form-control,
        .app-card .selectize-input,
        .app-card .selectize-dropdown,
        .app-card .btn,
        .app-card .well,
        .app-card .help-block {
          font-size: 13px;
        }
        .app-card .btn {
          border-radius: 8px;
        }
        .app-card .shiny-input-container {
          margin-bottom: 14px;
        }
        .app-card .shiny-input-container:last-child {
          margin-bottom: 0;
        }
        .app-card .control-label {
          color: #4f5f73;
          font-weight: 600;
          margin-bottom: 6px;
        }
        .app-card .form-group {
          margin-bottom: 14px;
        }
        .app-card .form-group:last-child {
          margin-bottom: 0;
        }
      "))
    )
  )
}

app_card_title <- function(title, subtitle = NULL, tone = "primary") {
  tags$div(
    class = "app-card__title",
    tags$span(class = "app-card__tone"),
    tags$span(
      class = "app-card__title-main",
      tags$span(class = "app-card__title-text", title),
      if (!is.null(subtitle) && nzchar(subtitle)) {
        tags$span(class = "app-card__title-subtitle", subtitle)
      }
    )
  )
}

app_card_box <- function(...,
                         title,
                         subtitle = NULL,
                         width = 12,
                         tone = "primary",
                         status = tone,
                         solidHeader = FALSE,
                         collapsible = FALSE,
                         collapsed = FALSE,
                         class = NULL) {
  shinydashboard::box(
    ...,
    width = width,
    title = app_card_title(title, subtitle = subtitle, tone = tone),
    status = status,
    solidHeader = solidHeader,
    collapsible = collapsible,
    collapsed = collapsed,
    class = trimws(paste("app-card", paste0("app-card--", tone), class))
  )
}

app_card_note <- function(...) {
  tags$div(class = "app-card__note", ...)
}

app_card_panel <- function(...) {
  tags$div(class = "app-card__panel", ...)
}

app_result_panel <- function(..., title = NULL, note = NULL, tone = "info", class = NULL) {
  tags$div(
    class = trimws(paste("app-result-panel", paste0("app-result-panel--", tone), class)),
    if (!is.null(title) && nzchar(title)) tags$div(class = "app-result-panel__title", title),
    if (!is.null(note) && nzchar(note)) tags$div(class = "app-result-panel__note", note),
    tags$div(class = "app-result-panel__body", ...)
  )
}

app_result_empty <- function(text = "当前尚无结果。") {
  tags$div(class = "app-result-panel__empty", text)
}

app_stat_card <- function(label, value, meta = NULL, tone = "primary", chips = NULL) {
  tags$div(
    class = paste("app-stat-card", paste0("app-stat-card--", tone)),
    tags$div(
      class = "app-stat-card__body",
      tags$div(class = "app-stat-card__label", label),
      tags$div(class = "app-stat-card__value", value),
      if (!is.null(meta) && nzchar(meta)) tags$div(class = "app-stat-card__meta", meta),
      if (!is.null(chips) && length(chips) > 0) {
        tags$div(
          class = "app-stat-card__chips",
          lapply(chips, function(chip) {
            tags$span(class = "app-stat-chip", HTML(chip))
          })
        )
      }
    )
  )
}
