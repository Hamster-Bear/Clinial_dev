# 统计图形主模块
# 负责集成所有统计图形子模块

# 加载必要的包
library(shiny)

# 加载子模块
source("modules/statistical_graphics/survival_analysis.R")
source("modules/statistical_graphics/boxplot.R")
source("modules/statistical_graphics/forest_plot.R")
source("modules/statistical_graphics/heatmap.R")
source("modules/statistical_graphics/correlation_matrix.R")

statistical_graphics_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
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
            "相关性矩阵" = "correlation"
          )
        )
      )
    ),
    
    # 动态显示选定的图形子模块
    uiOutput(ns("selected_graphic_ui"))
  )
}

statistical_graphics_server <- function(input, output, session, data) {
  ns <- session$ns
  
  # 存储各子模块的状态
  module_states <- reactiveValues(
    survival = NULL,
    boxplot = NULL,
    forest = NULL,
    heatmap = NULL,
    correlation = NULL
  )
  
  # 动态显示选定的图形子模块UI
  output$selected_graphic_ui <- renderUI({
    req(input$fig_type)
    
    switch(input$fig_type,
           "km" = survival_analysis_ui(ns("survival")),
           "boxplot" = boxplot_ui(ns("boxplot")),
           "forest" = forest_plot_ui(ns("forest")),
           "heatmap" = heatmap_ui(ns("heatmap")),
           "correlation" = correlation_matrix_ui(ns("correlation"))
    )
  })
  
  # 调用相应的子模块服务器函数
  observe({
    req(input$fig_type, data())
    
    # 根据选择的图形类型调用相应的子模块
    switch(input$fig_type,
           "km" = {
             if (is.null(module_states$survival)) {
               module_states$survival <- callModule(survival_analysis_server, "survival", data)
             }
           },
           "boxplot" = {
             if (is.null(module_states$boxplot)) {
               module_states$boxplot <- callModule(boxplot_server, "boxplot", data)
             }
           },
           "forest" = {
             if (is.null(module_states$forest)) {
               module_states$forest <- callModule(forest_plot_server, "forest", data)
             }
           },
           "heatmap" = {
             if (is.null(module_states$heatmap)) {
               module_states$heatmap <- callModule(heatmap_server, "heatmap", data)
             }
           },
           "correlation" = {
             if (is.null(module_states$correlation)) {
               module_states$correlation <- callModule(correlation_matrix_server, "correlation", data)
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
           NULL
    )
  }))
}
