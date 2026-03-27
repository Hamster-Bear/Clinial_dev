# 统计图形主模块
# 负责集成所有统计图形子模块

# 加载必要的包
library(shiny)
source("modules/common/plot_export.R")

# 加载子模块
source("modules/statistical_graphics/survival_analysis.R")
source("modules/statistical_graphics/boxplot.R")
source("modules/statistical_graphics/forest_plot.R")
source("modules/statistical_graphics/heatmap.R")
source("modules/statistical_graphics/correlation_matrix.R")
source("modules/statistical_graphics/combo_plot.R")
source("modules/statistical_graphics/waterfall_plot.R")
source("modules/statistical_graphics/swimmer_plot.R")
source("modules/common/data_filter.R") # 加载通用筛选模块

statistical_graphics_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      # 顶部：数据筛选（新增）
      column(
        width = 12,
        box(
          width = NULL,
          title = "全局数据筛选",
          status = "info",
          solidHeader = TRUE,
          collapsible = TRUE,
          collapsed = TRUE, # 默认折叠
          # 调用筛选模块 UI
          data_filter_ui(ns("global_filter"))
        )
      )
    ),
    fluidRow(
      box(
        width = 12,
        title = "统计图形类型选择",
        status = "primary",
        solidHeader = TRUE,
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
            "泳道图" = "swimmer"
          )
        )
      )
    ),
    
    # 动态显示选定的图形子模块
    uiOutput(ns("selected_graphic_ui"))
  )
}

statistical_graphics_server <- function(id, data) {
  moduleServer(id, function(input, output, session) {
  ns <- session$ns
  
  # 调用筛选模块，获取筛选后的数据
  filtered_data <- data_filter_server("global_filter", data)
  
  # 存储各子模块的状态
  module_states <- reactiveValues(
    survival = NULL,
    boxplot = NULL,
    forest = NULL,
    heatmap = NULL,
    correlation = NULL,
    combo = NULL,
    waterfall = NULL,
    swimmer = NULL
  )
  
  # 动态显示选定的图形子模块UI
  output$selected_graphic_ui <- renderUI({
    req(input$fig_type)
    
    switch(input$fig_type,
           "km" = survival_analysis_ui(ns("survival")),
           "boxplot" = boxplot_ui(ns("boxplot")),
           "forest" = forest_plot_ui(ns("forest")),
           "heatmap" = heatmap_ui(ns("heatmap")),
           "correlation" = correlation_matrix_ui(ns("correlation")),
           "combo" = combo_plot_ui(ns("combo")),
           "waterfall" = waterfall_plot_ui(ns("waterfall")),
           "swimmer" = swimmer_plot_ui(ns("swimmer"))
    )
  })
  
  # 调用相应的子模块服务器函数
  observe({
    req(input$fig_type, filtered_data())
    
    # 根据选择的图形类型调用相应的子模块
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
           }
    )
  })
  
  # 返回当前活动模块的状态
  return(reactive({
    switch(input$fig_type,
           "km" = module_states$survival(),
           "boxplot" = module_states$boxplot(),
           "forest" = module_states$forest(),
           "heatmap" = module_states$heatmap(),
           "correlation" = module_states$correlation(),
           "combo" = module_states$combo(),
           "waterfall" = module_states$waterfall(),
           "swimmer" = module_states$swimmer(),
           NULL
    )
  }))
  })
}
