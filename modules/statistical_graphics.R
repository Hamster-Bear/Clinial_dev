# 统计图形主模块
# 负责集成所有统计图形子模块

library(shiny)
`%||%` <- function(x, y) if (is.null(x)) y else x
source("modules/common/plot_export.R")
source("modules/common/analysis_format.R")
source("modules/common/graphics_repro.R")
source("modules/common/graphics_common.R")
source("modules/common/ui_shell.R")
source("modules/common/graphics/forest_table_state_helpers.R")
source("modules/common/graphics/forest_result_schema_helpers.R")
source("modules/common/graphics/forest_model_helpers.R")
source("modules/common/graphics/forest_analysis_pipeline.R")
source("modules/statistical_graphics_ui/common_ui_shell.R")
source("modules/task_history.R")

source("modules/statistical_graphics/survival_analysis.R")
source("modules/statistical_graphics/boxplot.R")
source("modules/statistical_graphics/forest_plot.R")
source("modules/statistical_graphics/heatmap.R")
source("modules/statistical_graphics/correlation_matrix.R")
source("modules/statistical_graphics/combo_plot.R")
source("modules/statistical_graphics/waterfall_plot.R")
source("modules/statistical_graphics/swimmer_plot.R")
source("modules/statistical_graphics/spider_plot.R")
source("modules/common/data_filter.R")

statistical_graphics_ui <- function(id) {
  ns <- NS(id)

  tagList(
    data_filter_ui(ns("global_filter")),
    app_card_box(
      width = 12,
      title = "统计图形类型选择",
      subtitle = "继续保留图形子模块切换链路，只统一入口卡片视觉与说明块",
      tone = "primary",
      status = "primary",
      solidHeader = FALSE,
      app_card_note("全局筛选卡和任务历史卡已作为公共模块独立收口；这里仅保留图形类型选择入口。"),
      app_card_panel(
        selectInput(
          ns("fig_type"),
          "选择图形类型",
          choices = c(
            "生存曲线 (Kaplan-Meier)" = "km",
            "箱线图" = "boxplot",
            "森林图" = "forest",
            "热图" = "heatmap",
            "相关性矩阵" = "correlation",
            "组合图形" = "combo",
            "瀑布图" = "waterfall",
            "泳道图" = "swimmer",
            "蜘蛛图" = "spider"
          )
        )
      )
    ),
    task_history_ui(
      ns("task_history"),
      help_text = "当前已支持将图形参数、界面状态与模块类型保存为任务历史；按用户隔离，workspace 为空时保存为个人任务。"
    ),
    uiOutput(ns("selected_graphic_ui"))
  )
}

statistical_graphics_server <- function(id, data, pg_pool = NULL, current_user = NULL, workspace_id = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    resolve_workspace_id <- function() {
      raw_workspace_id <- if (is.null(workspace_id)) {
        NULL
      } else if (is.function(workspace_id)) {
        workspace_id()
      } else {
        workspace_id
      }
      service_normalize_analysis_state_workspace_id(raw_workspace_id)
    }

    resolve_current_user <- function() {
      if (is.null(current_user)) return(NULL)
      if (is.function(current_user)) return(current_user())
      current_user
    }

    module_handler_state <- function(handler) {
      if (is.list(handler) && is.function(handler$state)) {
        return(handler$state())
      }
      if (is.function(handler)) {
        return(handler())
      }
      list()
    }

    module_handler_repro_state <- function(handler) {
      state <- module_handler_state(handler)
      if (is.list(state) && is.list(state$extra_state)) {
        return(state$extra_state)
      }
      state
    }

    module_handler_apply_state <- function(handler, state) {
      if (is.list(handler) && is.function(handler$apply_state)) {
        return(handler$apply_state(state))
      }
      FALSE
    }

    filtered_data <- data_filter_server("global_filter", data)

    module_states <- reactiveValues(
      survival = NULL,
      boxplot = NULL,
      forest = NULL,
      heatmap = NULL,
      correlation = NULL,
      combo = NULL,
      waterfall = NULL,
      swimmer = NULL,
      spider = NULL
    )

    active_module_handler <- reactive({
      req(input$fig_type)
      switch(input$fig_type,
        "km" = module_states$survival,
        "boxplot" = module_states$boxplot,
        "forest" = module_states$forest,
        "heatmap" = module_states$heatmap,
        "correlation" = module_states$correlation,
        "combo" = module_states$combo,
        "waterfall" = module_states$waterfall,
        "swimmer" = module_states$swimmer,
        "spider" = module_states$spider,
        NULL
      )
    })

    output$selected_graphic_ui <- renderUI({
      tagList(
        switch(input$fig_type,
          "km" = survival_analysis_ui(ns("survival")),
          "boxplot" = boxplot_ui(ns("boxplot")),
          "forest" = forest_plot_ui(ns("forest")),
          "heatmap" = heatmap_ui(ns("heatmap")),
          "correlation" = correlation_matrix_ui(ns("correlation")),
          "combo" = combo_plot_ui(ns("combo")),
          "waterfall" = waterfall_plot_ui(ns("waterfall")),
          "swimmer" = swimmer_plot_ui(ns("swimmer")),
          "spider" = spider_plot_ui(ns("spider"))
        ),
        app_card_box(
          width = 12,
          title = "可复现代码",
          subtitle = "按当前图形类型和参数生成代码草稿",
          tone = "info",
          status = "info",
          solidHeader = FALSE,
          collapsible = TRUE,
          collapsed = TRUE,
          app_card_note("继续保留原有代码生成逻辑，只统一代码容器与说明块。"),
          app_result_panel(
            title = "图形复现代码",
            note = "根据当前图形模块和参数状态生成 R 代码草稿，便于本地复现或文档整理。",
            tone = "info",
            verbatimTextOutput(ns("graphic_repro_code_out"))
          )
        )
      )
    })

    observe({
      req(input$fig_type, filtered_data())
      switch(input$fig_type,
        "km" = {
          if (is.null(module_states$survival)) {
            module_states$survival <- callModule(survival_analysis_server, "survival", filtered_data)
          }
        },
        "boxplot" = {
          if (is.null(module_states$boxplot)) {
            module_states$boxplot <- callModule(boxplot_server, "boxplot", filtered_data)
          }
        },
        "forest" = {
          if (is.null(module_states$forest)) {
            module_states$forest <- callModule(forest_plot_server, "forest", filtered_data)
          }
        },
        "heatmap" = {
          if (is.null(module_states$heatmap)) {
            module_states$heatmap <- callModule(heatmap_server, "heatmap", filtered_data)
          }
        },
        "correlation" = {
          if (is.null(module_states$correlation)) {
            module_states$correlation <- callModule(correlation_matrix_server, "correlation", filtered_data)
          }
        },
        "combo" = {
          if (is.null(module_states$combo)) {
            module_states$combo <- callModule(combo_plot_server, "combo", filtered_data)
          }
        },
        "waterfall" = {
          if (is.null(module_states$waterfall)) {
            module_states$waterfall <- callModule(waterfall_plot_server, "waterfall", filtered_data)
          }
        },
        "swimmer" = {
          if (is.null(module_states$swimmer)) {
            module_states$swimmer <- callModule(swimmer_plot_server, "swimmer", filtered_data)
          }
        },
        "spider" = {
          if (is.null(module_states$spider)) {
            module_states$spider <- callModule(spider_plot_server, "spider", filtered_data)
          }
        }
      )
    })
    
    task_history_server(
      "task_history",
      pg_pool = pg_pool,
      current_user = resolve_current_user,
      workspace_id = resolve_workspace_id,
      scope = "graphics",
      module_type = reactive(input$fig_type),
      get_state = function() module_handler_state(active_module_handler()),
      apply_state = function(state) module_handler_apply_state(active_module_handler(), state),
      apply_failure_message = "当前模块暂未接入任务历史回填"
    )

    output$graphic_repro_code_out <- renderText({
      req(input$fig_type)
      active_state <- module_handler_repro_state(active_module_handler())
      if (!is.list(active_state)) {
        active_state <- list()
      }
      generate_graphics_repro_code(input$fig_type, active_state, data_name = "data")
    })

    return(reactive({
      module_handler_state(active_module_handler())
    }))
  })
}
