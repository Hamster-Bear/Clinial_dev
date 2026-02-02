############################################################
# Clinical AE Summary Generator (Corrected N-Count)
############################################################

library(shiny)
library(bslib)
library(dplyr)
library(tern)
library(rtables)
library(haven)
library(DT)
library(pharmaverseadam)

# ==============================================================================
# 1. 模块 UI
# ==============================================================================
ae_module_ui <- function(id) {
  ns <- NS(id)
  page_sidebar(
    title = "Clinical AE Reporting System",
    theme = bs_theme(version = 5, bootswatch = "flatly"),
    sidebar = sidebar(
      width = 350,
      title = "控制面板",
      accordion(
        accordion_panel("1. 数据来源",
                        radioButtons(ns("data_mode"), "数据模式:",
                                     choices = c("行业示例 (ADAE)" = "example", "上传 ADAE" = "upload")),
                        conditionalPanel(
                          condition = sprintf("input['%s'] == 'upload'", ns("data_mode")),
                          fileInput(ns("adae_in"), "选择 ADAE 文件", accept = ".sas7bdat")
                        )
        ),
        accordion_panel("2. 变量映射", uiOutput(ns("ui_mapping")))
      ),
      hr(),
      actionButton(ns("run"), "生成报表", class = "btn-primary w-100"),
      downloadButton(ns("dl_txt"), "导出 ASCII (.txt)", class = "w-100 mt-2")
    ),
    navset_card_pill(
      nav_panel("分析报表", 
                div(style = "background-color: #ffffff; padding: 20px; border: 1px solid #dee2e6; font-family: monospace;",
                    verbatimTextOutput(ns("ae_rtable")))),
      nav_panel("数据预览", DTOutput(ns("adae_dt")))
    )
  )
}

# ==============================================================================
# 2. 模块 Server
# ==============================================================================
ae_module_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    adae_raw <- reactive({
      if (input$data_mode == "example") {
        return(pharmaverseadam::adae %>% df_explicit_na())
      } else {
        req(input$adae_in)
        read_sas(input$adae_in$datapath) %>% df_explicit_na()
      }
    })
    
    output$ui_mapping <- renderUI({
      req(adae_raw())
      nms <- names(adae_raw())
      tagList(
        selectInput(ns("trt"), "治疗组变量:", choices = nms, 
                    selected = intersect(c("ACTARM", "TRTA"), nms)[1]),
        selectInput(ns("soc"), "SOC 变量:", choices = nms, 
                    selected = intersect(c("AEBODSYS", "AESOC"), nms)[1]),
        selectInput(ns("pt"), "PT 变量:", choices = nms, 
                    selected = intersect(c("AEDECOD", "AETERM"), nms)[1])
      )
    })
    
    output$adae_dt <- renderDT({ datatable(adae_raw(), options = list(pageLength = 10, scrollX = TRUE)) })
    
    table_obj <- eventReactive(input$run, {
      req(adae_raw(), input$trt, input$soc, input$pt)
      
      # 1. 数据过滤
      df_ana <- adae_raw() %>% filter(SAFFL == "Y")
      
      # 2. 标签分配
      attr(df_ana[[input$soc]], "label") <- "MedDRA System Organ Class"
      attr(df_ana[[input$pt]], "label")  <- "MedDRA Preferred Term"
      
      # 3. 核心修正：手动计算列计数 (唯一受试者数)
      # 这样确保表头的 (N=xx) 也是基于 unique USUBJID 计算的
      col_counts <- df_ana %>%
        group_by(across(all_of(input$trt))) %>%
        summarise(n = n_distinct(USUBJID), .groups = "drop")
      
      # 计算整体 (Overall) 的唯一受试者数
      total_n <- n_distinct(df_ana$USUBJID)
      
      # 4. 构建 Layout
      lyt <- basic_table(show_colcounts = TRUE) %>%
        split_cols_by(var = input$trt) %>%
        add_overall_col(label = "All Patients") %>%
        # 统计部分：明确使用 unique 统计人数
        analyze_num_patients(
          vars = "USUBJID",
          .stats = c("unique", "nonunique"),
          .labels = c(
            unique = "Total number of patients with at least one adverse event",
            nonunique = "Overall total number of events"
          )
        ) %>%
        split_rows_by(
          var = input$soc,
          child_labels = "visible",
          nested = FALSE,
          split_fun = drop_split_levels,
          label_pos = "topleft",
          split_label = "MedDRA System Organ Class"
        ) %>%
        summarize_num_patients(
          var = "USUBJID",
          .stats = c("unique", "nonunique"),
          .labels = c(
            unique = "Total number of patients with at least one adverse event",
            nonunique = "Total number of events"
          )
        ) %>%
        count_occurrences(vars = input$pt, .indent_mods = -1L) %>%
        append_varlabels(df_ana, input$pt, indent = 1L)
      
      # 5. 构建表格
      tbl <- build_table(lyt, df = df_ana)
      
      # 6. 强制修正表头 N 值（确保 N = Unique Patients）
      # 我们根据计算好的唯一人数更新表格的列计数
      trts <- col_counts[[input$trt]]
      counts <- col_counts$n
      
      # 设置各治疗组的 N
      col_counts(tbl) <- c(counts, total_n)
      
      return(tbl)
    })
    
    output$ae_rtable <- renderPrint({ req(table_obj()); table_obj() })
    
    output$dl_txt <- downloadHandler(
      filename = function() { paste0("AE_Table_", format(Sys.Date(), "%Y%m%d"), ".txt") },
      content = function(file) { export_as_txt(table_obj(), file = file) }
    )
  })
}

# ==============================================================================
# 3. Entry Point
# ==============================================================================
ui <- page_navbar(
  title = "Sponsor-Ready AE Generator",
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  nav_panel("报表分析", ae_module_ui("analysis"))
)

server <- function(input, output, session) {
  ae_module_server("analysis")
}

shinyApp(ui, server)