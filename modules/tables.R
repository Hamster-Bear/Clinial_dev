# Tables模块 - 临床数据表格展示模块
# 支持多种表格类型：人口统计表格 (t_dm)、AE SOC/PT 汇总表 (t_ae_soc_pt)
# 基于 gtsummary 和 rtables/tern，支持自动类型检测、自定义总计列和代码输出

library(shiny)
library(dplyr)
library(gt)
library(shinyjs)
source("modules/common/entry_copy.R")
source("modules/common/ui_shell.R")

# 加载子模块分析函数
source("modules/tables/t_dm.R")
source("modules/tables/t_ae_soc_pt.R")
source("modules/tables/listing_general.R")
source("modules/tables/ae_sidebyside.R") # 加载并列对比图模块
source("modules/common/data_filter.R") # 加载通用筛选模块
source("modules/common/table_export.R")
source("modules/common/plot_export.R")

# Tables模块UI
tables_ui <- function(id) {
  ns <- NS(id)
  copy <- ENTRY_COPY$tables
  
  tagList(
    useShinyjs(),
    data_filter_ui(ns("global_filter")),
    fluidRow(
      # 左侧：参数设置
      column(
        width = 3,
        app_card_box(
          width = NULL,
          title = copy$params$title,
          subtitle = copy$params$subtitle,
          tone = "primary",
          status = "primary",
          solidHeader = FALSE,
          collapsible = TRUE,
          collapsed = FALSE,
          app_card_note(copy$params$note),
          app_card_panel(
            selectizeInput(
              ns("table_type"),
              "选择图表类型",
              choices = c(
                "人口统计表格 (t_dm)" = "t_dm",
                "分级统计表 (t_ae_soc_pt)" = "t_ae_soc_pt",
                "一般列表 (listing_general)" = "listing_general",
                "不良事件并列对比图 (ae_sidebyside)" = "ae_sidebyside"
              ),
              selected = "t_dm"
            )
          ),
          app_card_panel(
            tags$strong("参数设置"),
            app_card_note("根据所选表格类型显示对应参数，便于完成当前表格设置。"),
            uiOutput(ns("dm_params_ui"))
          ),
          app_card_panel(
            tags$strong("执行"),
            app_card_note("参数设置完整后即可生成结果；未满足必填项时按钮会保持不可用。"),
            actionButton(
              ns("generate"),
              "生成表格",
              icon = icon("table"),
              class = "btn-success",
              width = "100%"
            )
          )
        )
      ),
      # 右侧：结果展示
      column(
        width = 9,
        app_card_box(
          width = NULL,
          title = copy$result$title,
          subtitle = copy$result$subtitle,
          tone = "success",
          status = "success",
          solidHeader = FALSE,
          collapsible = TRUE,
          collapsed = FALSE,
          app_card_note(copy$result$note),
          tabsetPanel(
            tabPanel(
              "表格结果",
              app_result_panel(
                title = "表格结果",
                note = "展示当前所选表格类型生成的表格结果。",
                tone = "success",
                uiOutput(ns("table_output"))
              )
            ),
            tabPanel(
              "R代码",
              app_result_panel(
                title = "R 代码",
                note = "展示当前表格参数对应的 R 代码，便于复现或写入报告。",
                tone = "info",
                verbatimTextOutput(ns("code_output"), placeholder = TRUE)
              )
            )
          ),
          app_result_panel(
            title = "导出配置",
            note = copy$result$export_note,
            tone = "warning",
            fluidRow(
              column(
                width = 4,
                selectInput(
                  ns("table_export_format"),
                  "导出格式",
                  choices = c("Word (.docx)" = "docx", "PNG (.png)" = "png"),
                  selected = "docx"
                )
              ),
              column(
                width = 4,
                textInput(ns("table_export_name"), "文件名前缀", value = "table_result")
              ),
              column(
                width = 4,
                br(),
                downloadButton(ns("table_download"), "导出结果", class = "btn-primary")
              )
            )
          )
        )
      )
    )
  )
}

# Tables模块服务器逻辑
tables_server <- function(id, data) {
  moduleServer(id, function(input, output, session) {
  ns <- session$ns
  
  # 反应式值：存储生成的表格
  table_result <- reactiveVal(NULL)
  # 存储生成的代码
  code_result <- reactiveVal("# 请先上传数据并选择变量，然后点击'生成表格'")
  
  # 调用筛选模块，获取筛选后的数据
  filtered_data <- data_filter_server("global_filter", data)
  
  # 动态生成参数 UI
  ae_sidebyside_params_server("ae_sidebyside_params", filtered_data)
  
  # 渲染动态参数UI（根据表格类型）
  output$dm_params_ui <- renderUI({
    req(filtered_data(), input$table_type)
    df <- filtered_data()
    if (input$table_type == "t_dm") {
      t_dm_params_ui(ns, df)
    } else if (input$table_type == "t_ae_soc_pt") {
      t_ae_soc_pt_params_ui(ns, df)
    } else if (input$table_type == "listing_general") {
      listing_general_params_ui(ns, df)
    } else if (input$table_type == "ae_sidebyside") {
      ae_sidebyside_params_ui(ns("ae_sidebyside_params"), df)
    } else {
      NULL
    }
  })
  
  # 获取分组变量的水平（用于总计列设置）
  dm_group_levels <- reactive({
    req(filtered_data(), input$dm_by_var, input$dm_by_var != "无")
    unique(filtered_data()[[input$dm_by_var]])
  })
  
  # 动态生成总计列设置UI
  output$dm_total_cols_ui <- renderUI({
    req(input$dm_enable_total_cols == TRUE, input$dm_total_cols_count >= 1, dm_group_levels())
    
    total_cols <- lapply(1:input$dm_total_cols_count, function(i) {
      wellPanel(
        textInput(
          ns(paste0("dm_total_col_name_", i)),
          paste("总计列", i, "名称"),
          value = paste("总计", i)
        ),
        selectizeInput(
          ns(paste0("dm_total_col_groups_", i)),
          paste("选择总计列", i, "包含的组"),
          choices = dm_group_levels(),
          multiple = TRUE
        )
      )
    })
    do.call(tagList, total_cols)
  })
  
  # 获取总计列设置
  dm_total_cols_settings <- reactive({
    req(input$dm_enable_total_cols == TRUE, input$dm_total_cols_count >= 1, input$dm_by_var != "无")
    
    settings <- list()
    for (i in 1:input$dm_total_cols_count) {
      name_id <- paste0("dm_total_col_name_", i)
      groups_id <- paste0("dm_total_col_groups_", i)
      
      if (!is.null(input[[name_id]]) && !is.null(input[[groups_id]])) {
        settings[[i]] <- list(
          name = input[[name_id]],
          groups = input[[groups_id]]
        )
      }
    }
    settings
  })
  
  # 访问锁：控制生成按钮状态（根据表格类型）
  observe({
    req(input$table_type)
    if (is.null(filtered_data())) {
      shinyjs::disable("generate")
      return()
    }
    if (input$table_type == "t_dm") {
      if (length(input$dm_variables) == 0) {
        shinyjs::disable("generate")
      } else {
        shinyjs::enable("generate")
      }
    } else if (input$table_type == "t_ae_soc_pt") {
      if (is.null(input$ae_trt_var) || is.null(input$ae_soc_var) || is.null(input$ae_pt_var)) {
        shinyjs::disable("generate")
      } else {
        shinyjs::enable("generate")
      }
    } else if (input$table_type == "listing_general") {
       if (is.null(input$listing_disp_cols) || length(input$listing_disp_cols) == 0) {
          shinyjs::disable("generate")
       } else {
          shinyjs::enable("generate")
       }
    } else if (input$table_type == "ae_sidebyside") {
         # 这里的输入在子模块 ns("ae_sidebyside_params") 下，需要通过 input 访问
         # 但由于 UI 是动态渲染的，input 可能需要通过 session$input 访问，或者直接假设它们在顶层 input 中（如果使用 ns）
         # 修正：ae_sidebyside_params_ui 使用了 ns，所以 input ID 会带有前缀
         # 但在这里访问时，input 对象已经包含了当前模块的 namespace
         # 所以 input[["ae_sidebyside_params-ae_term_col"]]
         
         term_col <- input[["ae_sidebyside_params-ae_term_col"]]
         sev_col <- input[["ae_sidebyside_params-ae_sev_col"]]
         
         if (is.null(term_col) || is.null(sev_col)) {
            shinyjs::disable("generate")
         } else {
            shinyjs::enable("generate")
         }
      } else {
      shinyjs::disable("generate")
    }
  })
  
  # 切换表格类型时清空之前的结果
  observeEvent(input$table_type, {
    table_result(NULL)
    code_result("# 请先上传数据并选择变量，然后点击'生成表格'")
  })

  observeEvent(input$table_type, {
    req(input$table_type)
    export_choices <- switch(
      input$table_type,
      "ae_sidebyside" = c("PNG (.png)" = "png", "PDF (.pdf)" = "pdf", "SVG (.svg)" = "svg"),
      c("Word (.docx)" = "docx", "PNG (.png)" = "png", "PDF (.pdf)" = "pdf", "HTML (.html)" = "html", "RTF (.rtf)" = "rtf")
    )
    selected_format <- if ("docx" %in% unname(export_choices)) "docx" else unname(export_choices)[1]
    updateSelectInput(session, "table_export_format", choices = export_choices, selected = selected_format)
  }, ignoreInit = FALSE)
  
  # 生成表格
  observeEvent(input$generate, {
    req(filtered_data(), input$table_type)
    if (input$table_type == "t_dm") {
      req(input$dm_variables)
    } else if (input$table_type == "t_ae_soc_pt") {
        req(input$ae_trt_var, input$ae_soc_var, input$ae_pt_var)
      } else if (input$table_type == "listing_general") {
        req(input$listing_disp_cols)
      } else if (input$table_type == "ae_sidebyside") {
        # 注意：ae_sidebyside_params_ui 生成的输入带有 ae_sidebyside_params- 前缀
        req(input[["ae_sidebyside_params-ae_term_col"]], input[["ae_sidebyside_params-ae_sev_col"]])
      }
    
      # 禁用按钮，防止重复点击
    shinyjs::disable("generate")
    # on.exit(shinyjs::enable("generate")) # 移至末尾，确保在异步或错误时也能恢复
    
    tryCatch({
      df <- filtered_data()
      
      # 调试信息
      print(paste("Generating table type:", input$table_type))
      
      # ... (t_dm 逻辑保持不变)
      
      if (input$table_type == "t_dm") {
        # ... (t_dm 调用逻辑)
         vars <- input$dm_variables
         by_var <- input$dm_by_var
         if (by_var == "无") by_var <- NULL
         
         total_settings <- NULL
         if (input$dm_enable_total_cols == TRUE && input$dm_by_var != "无") {
            total_settings <- dm_total_cols_settings()
         }
         
         result <- perform_t_dm_analysis(
            data = df,
            variables = vars,
            by_var = by_var,
            total_cols_settings = total_settings,
            table_title = input$dm_table_title,
            table_footnote = input$dm_table_footnote
         )
         
         # 生成代码
         code <- generate_t_dm_code(
            variables = vars,
            by_var = by_var,
            total_cols_settings = total_settings,
            table_title = input$dm_table_title,
            table_footnote = input$dm_table_footnote
         )
         
      } else if (input$table_type == "t_ae_soc_pt") {
        # 获取 AE/分级统计相关参数
        pop_var <- if (input$ae_enable_pop) input$ae_pop_var else NULL
        pop_val <- if (input$ae_enable_pop) input$ae_pop_val else "Y"
        
        result <- perform_t_ae_soc_pt_analysis(
          data = df,
          trt_var = input$ae_trt_var,
          soc_var = input$ae_soc_var,
          pt_var = input$ae_pt_var,
          id_var = input$subject_id_var,
          pop_var = pop_var,
          pop_val = pop_val
        )
        
        # 生成代码
        code <- generate_t_ae_soc_pt_code(
          trt_var = input$ae_trt_var,
          soc_var = input$ae_soc_var,
          pt_var = input$ae_pt_var,
          id_var = input$subject_id_var,
          pop_var = pop_var,
          pop_val = pop_val
        )
      } else if (input$table_type == "listing_general") {
        # 一般列表分析
        normalized_listing <- normalize_listing_columns(
          data = df,
          key_cols = input$listing_key_cols,
          disp_cols = input$listing_disp_cols
        )
        if (length(normalized_listing$disp_cols) == 0) {
          stop("当前展示列已失效，请重新选择有效字段。")
        }
        if (length(normalized_listing$missing_cols) > 0) {
          showNotification("部分已选 Listing 字段已失效，系统已自动忽略不可用字段。", type = "warning")
        }
        result <- perform_listing_general_analysis(
          data = df,
          key_cols = normalized_listing$key_cols,
          disp_cols = normalized_listing$disp_cols
        )
        
        code <- generate_listing_general_code(
          key_cols = normalized_listing$key_cols,
          disp_cols = normalized_listing$disp_cols,
          landscape = input$listing_landscape,
          font_size = input$listing_font_size
        )
      } else if (input$table_type == "ae_sidebyside") {
        # 不良事件并列对比图
        # 需要手动提取带命名空间的输入
        prefix <- "ae_sidebyside_params-"
        result <- perform_ae_sidebyside_analysis(
          data = df,
          term_col = input[[paste0(prefix, "ae_term_col")]],
          sev_col = input[[paste0(prefix, "ae_sev_col")]],
          subj_col = input[[paste0(prefix, "ae_subj_col")]],
          group_col = input[[paste0(prefix, "ae_group_col")]],
          flag_col = input[[paste0(prefix, "ae_flag_col")]],
          flag_val = input[[paste0(prefix, "ae_flag_val")]],
          rel_col = input[[paste0(prefix, "ae_rel_col")]],
          rel_val = input[[paste0(prefix, "ae_rel_val")]],
          count_mode = input[[paste0(prefix, "ae_count_mode")]],
          min_pct = input[[paste0(prefix, "ae_min_pct")]]
        )
        
        code <- generate_ae_sidebyside_code()
      } else {
        showNotification(paste("未知的表格类型:", input$table_type), type = "error")
        result <- NULL
        code <- "# 未知表格类型"
      }
      
      if (!is.null(result)) {
        table_result(result)
        code_result(code)
        showNotification("表格生成成功", type = "default")
      } else {
        showNotification("未生成表格，请检查参数设置", type = "warning")
        code_result("# 表格生成失败")
      }
      
    }, error = function(e) {
      message(sprintf("[TablesGenerateError] %s", conditionMessage(e)))
      showNotification("表格生成失败，请检查当前变量选择或数据状态后重试。", type = "error")
      table_result(NULL)
      code_result("# 表格生成失败，请检查变量选择与数据状态。")
    }, finally = {
      shinyjs::enable("generate")
    })
  })
  
  # 渲染表格（根据表格类型动态选择渲染器）
  output$table_output <- renderUI({
    req(table_result(), input$table_type)
    if (input$table_type == "t_dm") {
      gt::gt_output(ns("table_gt"))
    } else if (input$table_type == "t_ae_soc_pt") {
      verbatimTextOutput(ns("table_text"), placeholder = TRUE)
    } else if (input$table_type == "listing_general") {
      verbatimTextOutput(ns("listing_text"), placeholder = TRUE)
    } else if (input$table_type == "ae_sidebyside") {
      plotOutput(ns("ae_plot"), height = "800px")
    } else {
      NULL
    }
  })
  
  # GT 表格渲染
  output$table_gt <- gt::render_gt({
    req(table_result(), input$table_type == "t_dm")
    if (!inherits(table_result(), "gt_tbl")) {
      # 如果不是 gt 对象，返回空 gt 表格
      return(gt::gt(data.frame(Note = "表格类型不匹配")))
    }
    table_result()
  })
  
  # 文本表格渲染（用于 rtables）
  output$table_text <- renderPrint({
    req(table_result(), input$table_type == "t_ae_soc_pt")
    print(table_result())
  })
  
  # Listing 渲染
  output$listing_text <- renderText({
    req(table_result(), input$table_type == "listing_general")
    toString(table_result())
  })
  
  # AE Side-by-Side Plot 渲染
  output$ae_plot <- renderPlot({
    req(table_result(), input$table_type == "ae_sidebyside")
    table_result()
  })
  
  # RTF 下载处理
  output$listing_download_rtf <- downloadHandler(
    filename = function() paste0("Listing_", Sys.Date(), ".rtf"),
    content = function(file) {
      req(filtered_data(), input$listing_disp_cols)
      
      tryCatch({
        normalized_listing <- normalize_listing_columns(
          data = filtered_data(),
          key_cols = input$listing_key_cols,
          disp_cols = input$listing_disp_cols
        )
        if (length(normalized_listing$disp_cols) == 0) {
          stop("当前导出列与数据不匹配，请重新选择变量后重试。")
        }
        if (length(normalized_listing$missing_cols) > 0) {
          showNotification("部分已选导出字段已失效，系统将仅导出当前仍有效的字段。", type = "warning")
        }
        export_listing_general_rtf(
          data = filtered_data(),
          key_cols = normalized_listing$key_cols,
          disp_cols = normalized_listing$disp_cols,
          file = file,
          landscape = input$listing_landscape,
          font_size = input$listing_font_size
        )
      }, error = function(e) {
        message(sprintf("[ListingExportError] %s", conditionMessage(e)))
        showNotification("RTF 导出失败，请检查当前导出字段与数据是否一致。", type = "error")
      })
    }
  )

  output$table_download <- downloadHandler(
    filename = function() {
      req(table_result())
      prefix <- ifelse(nzchar(input$table_export_name), input$table_export_name, "table_result")
      if (identical(input$table_type, "ae_sidebyside")) {
        build_plot_export_filename(prefix = prefix, format = input$table_export_format)
      } else {
        build_table_export_filename(prefix = prefix, format = input$table_export_format)
      }
    },
    content = function(file) {
      req(table_result())
      obj <- table_result()
      if (identical(input$table_type, "ae_sidebyside")) {
        save_plot_export(
          file = file,
          plot_obj = obj,
          format = input$table_export_format,
          width = 12,
          height = 8,
          dpi = 300
        )
      } else {
        export_title <- switch(
          input$table_type,
          "t_dm" = "人口统计表格 (t_dm)",
          "t_ae_soc_pt" = "分级统计表 (t_ae_soc_pt)",
          "listing_general" = "一般列表 (listing_general)",
          "ae_sidebyside" = "不良事件并列对比图 (ae_sidebyside)",
          "导出结果"
        )
        if (identical(input$table_export_format, "png")) {
          save_table_png(file = file, table_obj = obj, width = 12, height = 8, dpi = 300)
        } else {
          save_table_export(
            file = file,
            result_obj = list(table = obj),
            format = input$table_export_format,
            title = export_title,
            include_report = FALSE
          )
        }
      }
    }
  )
  
  # 渲染代码输出
  output$code_output <- renderText({
    code_result()
  })
  
  # 返回表格结果
  return(table_result)
  })
}
