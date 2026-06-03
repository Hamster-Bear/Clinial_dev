# 组合图形子模块
# 负责生成多种图形类型的组合图形

# 加载必要的包
library(shiny)
library(ggplot2)
library(plotly)
library(DT)
library(shinyWidgets)
library(waiter)
library(shinyjs)
library(gridExtra)
library(cowplot)
library(RColorBrewer)
library(shinyalert)
library(scales)

if (!exists("app_card_box", mode = "function") ||
    !exists("app_card_note", mode = "function") ||
    !exists("app_result_panel", mode = "function")) {
  if (file.exists("modules/common/ui_shell.R")) {
    source("modules/common/ui_shell.R")
  } else {
    source(file.path("..", "modules", "common", "ui_shell.R"))
  }
}
if (file.exists("modules/common/graphics_result_copy.R")) {
  source("modules/common/graphics_result_copy.R")
} else {
  source(file.path("..", "modules", "common", "graphics_result_copy.R"))
}
if (file.exists("modules/common/graphics_export_copy.R")) {
  source("modules/common/graphics_export_copy.R")
} else {
  source(file.path("..", "modules", "common", "graphics_export_copy.R"))
}

combo_plot_ui <- function(id) {
  ns <- NS(id)
  copy <- GRAPHICS_RESULT_COPY$combo
  export_copy <- GRAPHICS_EXPORT_COPY$combo

  tagList(
    fluidRow(
      column(
        4,
        app_card_box(
          width = 12,
          title = "数据与变量",
          subtitle = "设置主映射、分组分面与组合方式",
          tone = "primary",
          status = "primary",
          solidHeader = FALSE,
          app_card_note("选择主 X / Y 映射、分组分面和图层组合方式。"),
          tags$div(
            style = "height: 680px; overflow-y: auto;",
            tabsetPanel(
                tabPanel(
                  "核心映射",
                  br(),
                  graphics_column_mapping_panel_ui(
                    ns,
                    title = "核心映射",
                    fields = list(
                      list(
                        list(id = "main_x_var", label = "主X轴变量", type = "selectize"),
                        list(id = "main_y_var", label = "主Y轴变量", type = "selectize")
                      )
                    ),
                    help_text = "当前组合图统一从主 X / Y 映射出发，按已选图层类型叠加或拆分。"
                  )
                ),
                tabPanel(
                  "分组/分面/轨道/附加变量",
                  br(),
                  graphics_column_mapping_panel_ui(
                    ns,
                    title = "分组/分面/附加变量",
                    fields = list(
                      list(
                        list(id = "group_var", label = "分组变量", type = "selectize", choices = c("无分组" = "none"), column = 6),
                        list(id = "facet_var", label = "分面变量", type = "selectize", choices = c("无分面" = "none"), column = 6)
                      )
                    ),
                    extra_ui = graphics_card_panel_ui(
                      "组合方式与图层选择",
                      tagList(
                        radioButtons(
                          ns("combo_method"),
                          "组合方式",
                          choices = c(
                            "叠加显示 (共享坐标轴)" = "overlay",
                            "并排显示 (独立子图)" = "side_by_side",
                            "上下显示 (独立子图)" = "top_bottom"
                          ),
                          selected = "overlay"
                        ),
                        checkboxGroupInput(
                          ns("plot_types"),
                          "选择图形类型 (多选)",
                          choices = c(
                            "散点图" = "scatter",
                            "折线图" = "line",
                            "柱状图" = "bar",
                            "箱线图" = "boxplot",
                            "密度图" = "density",
                            "直方图" = "histogram",
                            "面积图" = "area",
                            "小提琴图" = "violin"
                          ),
                          selected = c("scatter", "line"),
                          inline = TRUE
                        ),
                        helpText("组合图当前不提供轨道变量；高动态图层参数可在“图层样式”页签中设置。")
                      )
                    )
                  )
                )
              )
          )
        )
      ),
      column(
        4,
        app_card_box(
          width = 12,
          title = "图形与样式",
          subtitle = "设置标题、图层样式与参考项",
          tone = "warning",
          status = "warning",
          solidHeader = FALSE,
          app_card_note("配置标题说明、动态图层样式和参考项显示。"),
          tags$div(
            style = "height: 680px; overflow-y: auto;",
            tabsetPanel(
                tabPanel(
                  "标题与说明",
                  br(),
                  graphics_card_panel_ui(
                    "标题与说明",
                    tagList(
                      helpText("组合图标题默认按所选图层组合自动生成，可在本模块继续调整其他显示设置。")
                    )
                  )
                ),
                tabPanel(
                  "显示与坐标",
                  br(),
                  graphics_card_panel_ui(
                    "显示与坐标",
                    tagList(
                      helpText("组合方式、分组与分面在“数据与变量”页签中设置；坐标显示随当前图层类型和映射方式确定。")
                    )
                  )
                ),
                tabPanel(
                  "图层样式",
                  br(),
                  graphics_card_panel_ui(
                    "图层样式",
                    uiOutput(ns("dynamic_plot_settings"))
                  )
                ),
                tabPanel(
                  "参考线与阈值",
                  br(),
                  graphics_card_panel_ui(
                    "参考线与阈值",
                    tagList(
                      helpText("组合图当前未提供统一的参考线或阈值控件。")
                    )
                  )
                )
              )
          )
        )
      ),
      column(
        4,
        app_card_box(
          width = 12,
          title = "输出与导出",
          subtitle = export_copy$subtitle,
          tone = "info",
          status = "info",
          solidHeader = FALSE,
          app_card_note(export_copy$note),
          tags$div(
            style = "height: 680px; overflow-y: auto;",
            tabsetPanel(
                tabPanel(
                  "尺寸与画布",
                  br(),
                  graphics_card_panel_ui(
                    "尺寸与画布",
                    tagList(
                      helpText("组合图导出使用固定 12 x 8 英寸画布。")
                    )
                  )
                ),
                tabPanel(
                  "导出参数",
                  br(),
                  graphics_card_panel_ui(
                    "导出参数",
                    tagList(
                      fluidRow(
                        column(6, selectInput(ns("export_format"), "导出格式", choices = c("导出PNG" = "png", "导出PDF" = "pdf", "导出SVG" = "svg"), selected = "png", width = "100%")),
                        column(6, numericInput(ns("export_dpi"), "导出DPI", value = 300, min = 72, max = 1200, step = 10, width = "100%"))
                      )
                    )
                  )
                )
              )
          )
        )
      )
    ),
    fluidRow(
      column(
        12,
        app_card_box(
          width = 12,
          title = "结果区",
          subtitle = copy$result_card$subtitle,
          tone = "success",
          status = "success",
          solidHeader = FALSE,
          app_card_note(copy$result_card$note),
          graphics_output_action_bar_ui(ns, render_button_id = "generate_plot", download_id = "download_plot"),
          tabsetPanel(
            id = ns("output_tabs"),
            tabPanel(
              "静态图",
              app_result_panel(
                title = "静态图结果",
                note = copy$static_plot$note,
                tone = "success",
                plotOutput(ns("static_plot"), height = "700px")
              )
            ),
            tabPanel(
              "交互图",
              app_result_panel(
                title = "交互图结果",
                note = copy$interactive_plot$note,
                tone = "info",
                uiOutput(ns("interactive_plot_ui"))
              )
            ),
            tabPanel(
              "数据",
              app_result_panel(
                title = "组合图结果数据",
                note = copy$data_tab$note,
                tone = "warning",
                DTOutput(ns("combo_data_table"))
              )
            )
          )
        )
      )
    )
  )
}

combo_plot_server <- function(input, output, session, data) {
  ns <- session$ns
  
  # 存储图形参数状态
  graphics_state <- reactiveValues(
    plot_types = c("scatter", "line")
  )

  # committed state — Generate 时快照，导出和结果只读此对象
  committed_params <- reactiveVal(NULL)
  
  # 更新变量选择
  observe({
    req(data())
    vars <- names(data())
    
    # 获取数值型和分类型变量
    num_vars <- names(data())[sapply(data(), is.numeric)]
    cat_vars <- names(data())[sapply(data(), function(x) is.factor(x) || is.character(x))]
    
    # 更新选择器
    updateSelectizeInput(session, "main_x_var", choices = c("无" = "none", vars), selected = if(length(vars)>0) vars[1] else "none")
    updateSelectizeInput(session, "main_y_var", choices = c("无" = "none", vars), selected = if(length(num_vars)>0) num_vars[1] else "none")
    updateSelectizeInput(session, "group_var", choices = c("无分组" = "none", cat_vars), selected = "none")
    updateSelectizeInput(session, "facet_var", choices = c("无分面" = "none", cat_vars), selected = "none")
  })
  
  # 动态生成详细参数设置 Tabs
  output$dynamic_plot_settings <- renderUI({
    req(input$plot_types)
    
    # 定义每种图形类型的设置UI
    tabs <- lapply(input$plot_types, function(type) {
      type_name <- switch(type,
                         "scatter" = "散点图", "line" = "折线图", "bar" = "柱状图",
                         "boxplot" = "箱线图", "density" = "密度图", "histogram" = "直方图",
                         "area" = "面积图", "violin" = "小提琴图")
      
      content <- switch(type,
        "scatter" = tagList(
          fluidRow(
            column(4, numericInput(ns("scatter_size"), "点大小:", value = 2, min = 0.5, max = 10, step = 0.5)),
            column(4, sliderInput(ns("scatter_alpha"), "透明度:", min = 0, max = 1, value = 0.6, step = 0.1)),
            column(4, checkboxInput(ns("scatter_jitter"), "抖动显示", value = FALSE))
          )
        ),
        "line" = tagList(
          fluidRow(
            column(4, numericInput(ns("line_width"), "线宽:", value = 1, min = 0.5, max = 5, step = 0.5)),
            column(4, selectInput(ns("line_type"), "线型:", choices = c("实线"="solid", "虚线"="dashed", "点线"="dotted"))),
            column(4, checkboxInput(ns("line_smooth"), "添加平滑曲线", value = FALSE))
          )
        ),
        "bar" = tagList(
          fluidRow(
            column(4, selectInput(ns("bar_position"), "堆叠模式:", choices = c("堆叠"="stack", "并排"="dodge", "填充"="fill"))),
            column(4, sliderInput(ns("bar_width"), "柱宽:", min = 0.1, max = 1, value = 0.7, step = 0.1)),
            column(4, sliderInput(ns("bar_alpha"), "透明度:", min = 0, max = 1, value = 0.8, step = 0.1))
          )
        ),
        "boxplot" = tagList(
          fluidRow(
            column(4, sliderInput(ns("boxplot_width"), "箱宽:", min = 0.1, max = 1, value = 0.5, step = 0.1)),
            column(4, checkboxInput(ns("boxplot_outliers"), "显示异常值", value = TRUE)),
            column(4, checkboxInput(ns("boxplot_notch"), "缺口显示", value = FALSE))
          )
        ),
        "density" = tagList(
          fluidRow(
            column(4, sliderInput(ns("density_alpha"), "填充透明度:", min = 0, max = 1, value = 0.4, step = 0.1)),
            column(4, selectInput(ns("density_position"), "堆叠模式:", choices = c("重叠"="identity", "堆叠"="stack"))),
            column(4, numericInput(ns("density_adjust"), "平滑度:", value = 1, min = 0.1, max = 5, step = 0.1))
          )
        ),
        "histogram" = tagList(
          fluidRow(
            column(4, numericInput(ns("hist_bins"), "分箱数:", value = 30, min = 5, max = 100, step = 1)),
            column(4, selectInput(ns("hist_position"), "堆叠模式:", choices = c("堆叠"="stack", "并排"="dodge", "重叠"="identity"))),
            column(4, sliderInput(ns("hist_alpha"), "透明度:", min = 0, max = 1, value = 0.6, step = 0.1))
          )
        ),
        "area" = tagList(
          fluidRow(
            column(4, selectInput(ns("area_position"), "堆叠模式:", choices = c("堆叠"="stack", "重叠"="identity"))),
            column(4, sliderInput(ns("area_alpha"), "透明度:", min = 0, max = 1, value = 0.4, step = 0.1))
          )
        ),
        "violin" = tagList(
          fluidRow(
            column(4, checkboxInput(ns("violin_trim"), "裁剪尾部", value = TRUE)),
            column(4, checkboxInput(ns("violin_draw_quantiles"), "显示四分位数", value = TRUE)),
            column(4, sliderInput(ns("violin_alpha"), "透明度:", min = 0, max = 1, value = 0.7, step = 0.1))
          )
        )
      )
      
      tabPanel(type_name, br(), content)
    })
    
    do.call(tabsetPanel, tabs)
  })
  
  # 创建单个图形对象 (ggplot2)
  create_ggplot_object <- function(plot_type, data) {
    req(data)
    p <- ggplot(data)
    
    # 获取通用映射
    x_var <- if(input$main_x_var != "none") input$main_x_var else NULL
    y_var <- if(input$main_y_var != "none") input$main_y_var else NULL
    group_var <- if(input$group_var != "none") input$group_var else NULL
    
    # 基础映射
    mapping <- aes()
    if (!is.null(x_var)) mapping <- modifyList(mapping, aes_string(x = x_var))
    if (!is.null(y_var)) mapping <- modifyList(mapping, aes_string(y = y_var))
    
    # 分组映射
    if (!is.null(group_var)) {
      mapping <- modifyList(mapping, aes_string(color = group_var, fill = group_var, group = group_var))
    }
    
    p <- p + mapping
    
    # 根据类型添加图层
    if (plot_type == "scatter") {
      pos <- if(isTRUE(input$scatter_jitter)) position_jitter(width=0.2, height=0.2) else "identity"
      p <- p + geom_point(size = input$scatter_size, alpha = input$scatter_alpha, position = pos)
      
    } else if (plot_type == "line") {
      # 确保折线图有正确的分组
      if (is.null(group_var) && is.null(x_var)) {
         # 如果没有x轴和分组，无法画线
      } else {
        if (is.null(group_var)) p <- p + aes(group = 1)
        p <- p + geom_line(size = input$line_width, linetype = input$line_type)
        if (isTRUE(input$line_smooth)) p <- p + geom_smooth(se = FALSE)
      }
      
    } else if (plot_type == "bar") {
      # 柱状图通常只需要X，或者X+Y(如果是stat="identity")
      # 这里假设是计数(stat="count")如果只有X，或者是值(stat="identity")如果有Y
      stat_method <- if(!is.null(y_var)) "identity" else "count"
      p <- p + geom_bar(stat = stat_method, position = input$bar_position, 
                       width = input$bar_width, alpha = input$bar_alpha)
      
    } else if (plot_type == "boxplot") {
      # 箱线图通常需要离散X和连续Y
      p <- p + geom_boxplot(width = input$boxplot_width, 
                           outlier.shape = if(isTRUE(input$boxplot_outliers)) 19 else NA,
                           notch = isTRUE(input$boxplot_notch))
      
    } else if (plot_type == "density") {
      # 密度图通常只需要X(连续)
      p <- p + geom_density(alpha = input$density_alpha, position = input$density_position, 
                           adjust = input$density_adjust)
      
    } else if (plot_type == "histogram") {
      # 直方图通常只需要X(连续)
      p <- p + geom_histogram(bins = input$hist_bins, position = input$hist_position, 
                             alpha = input$hist_alpha)
      
    } else if (plot_type == "area") {
      # 面积图通常需要X和Y
      stat_method <- if(!is.null(y_var)) "identity" else "count"
      p <- p + geom_area(stat = stat_method, position = input$area_position, 
                        alpha = input$area_alpha)
      
    } else if (plot_type == "violin") {
      # 小提琴图通常需要离散X和连续Y
      draw_q <- if(isTRUE(input$violin_draw_quantiles)) c(0.25, 0.5, 0.75) else NULL
      p <- p + geom_violin(trim = isTRUE(input$violin_trim), draw_quantiles = draw_q, 
                          alpha = input$violin_alpha)
    }
    
    # 添加分面
    if (input$facet_var != "none") {
      p <- p + facet_wrap(as.formula(paste("~", input$facet_var)))
    }
    
    # 通用主题
    p <- p + theme_minimal() + 
      labs(title = paste0(switch(plot_type, "scatter"="散点", "line"="折线", "bar"="柱状", "boxplot"="箱线", 
                                "density"="密度", "histogram"="直方", "area"="面积", "violin"="小提琴"), "图"))
    
    return(p)
  }
  
  create_combo_plot_obj <- function(data_input, method, types) {
    
    if (method == "overlay") {
      # 叠加模式：在同一个 ggplot 对象上添加多个图层
      p <- ggplot(data_input)
      
      # 通用映射
      x_var <- if(input$main_x_var != "none") input$main_x_var else NULL
      y_var <- if(input$main_y_var != "none") input$main_y_var else NULL
      group_var <- if(input$group_var != "none") input$group_var else NULL
      
      mapping <- aes()
      if (!is.null(x_var)) mapping <- modifyList(mapping, aes_string(x = x_var))
      if (!is.null(y_var)) mapping <- modifyList(mapping, aes_string(y = y_var))
      if (!is.null(group_var)) mapping <- modifyList(mapping, aes_string(color = group_var, fill = group_var, group = group_var))
      
      p <- p + mapping
      
      # 逐个添加图层
      for (type in types) {
        if (type == "scatter") {
          pos <- if(isTRUE(input$scatter_jitter)) position_jitter(width=0.2, height=0.2) else "identity"
          p <- p + geom_point(size = input$scatter_size, alpha = input$scatter_alpha, position = pos)
        } else if (type == "line") {
          if (is.null(group_var)) p <- p + geom_line(aes(group=1), size = input$line_width, linetype = input$line_type)
          else p <- p + geom_line(size = input$line_width, linetype = input$line_type)
          if (isTRUE(input$line_smooth)) p <- p + geom_smooth(se = FALSE)
        } else if (type == "bar") {
          stat_method <- if(!is.null(y_var)) "identity" else "count"
          p <- p + geom_bar(stat = stat_method, position = input$bar_position, width = input$bar_width, alpha = input$bar_alpha)
        } else if (type == "boxplot") {
          p <- p + geom_boxplot(width = input$boxplot_width, outlier.shape = if(isTRUE(input$boxplot_outliers)) 19 else NA, notch = isTRUE(input$boxplot_notch))
        } else if (type == "density") {
          p <- p + geom_density(alpha = input$density_alpha, position = input$density_position, adjust = input$density_adjust)
        } else if (type == "histogram") {
          p <- p + geom_histogram(bins = input$hist_bins, position = input$hist_position, alpha = input$hist_alpha)
        } else if (type == "area") {
          stat_method <- if(!is.null(y_var)) "identity" else "count"
          p <- p + geom_area(stat = stat_method, position = input$area_position, alpha = input$area_alpha)
        } else if (type == "violin") {
          draw_q <- if(isTRUE(input$violin_draw_quantiles)) c(0.25, 0.5, 0.75) else NULL
          p <- p + geom_violin(trim = isTRUE(input$violin_trim), draw_quantiles = draw_q, alpha = input$violin_alpha)
        }
      }
      
      # 添加分面
      if (input$facet_var != "none") {
        p <- p + facet_wrap(as.formula(paste("~", input$facet_var)))
      }
      
      p <- p + theme_minimal() + labs(title = "组合图形 (叠加模式)")
      return(p)
      
    } else {
      # 并排或上下模式：创建多个独立的 ggplot 对象列表
      plot_list <- lapply(types, function(type) {
        create_ggplot_object(type, data_input)
      })
      return(plot_list)
    }
  }
  
  generated_plot_obj <- eventReactive(input$generate_plot, {
    req(input$plot_types, data(), input$combo_method)
    shinyjs::disable(selector = paste0("#", ns("generate_plot")))
    on.exit(shinyjs::enable(selector = paste0("#", ns("generate_plot"))), add = TRUE)
    withProgress(message = "正在生成组合图形...", value = 0, {
      incProgress(0.3, detail = "准备参数")
      method <- input$combo_method
      types <- input$plot_types
      df <- data()
      incProgress(0.6, detail = "构建图形对象")
      obj <- create_combo_plot_obj(df, method, types)
      incProgress(0.1, detail = "完成")

      # 快照当前参数到 committed state
      params <- list(
        main_x_var    = input$main_x_var,
        main_y_var    = input$main_y_var,
        group_var     = input$group_var,
        facet_var     = input$facet_var,
        combo_method  = input$combo_method,
        plot_types    = input$plot_types,
        export_format = input$export_format,
        export_dpi    = if (is.null(input$export_dpi)) 300 else input$export_dpi,
        scatter_size  = input$scatter_size,
        scatter_alpha = input$scatter_alpha,
        scatter_jitter = input$scatter_jitter,
        line_width    = input$line_width,
        line_type     = input$line_type,
        line_smooth   = input$line_smooth,
        bar_position  = input$bar_position,
        bar_width     = input$bar_width,
        bar_alpha     = input$bar_alpha,
        boxplot_width = input$boxplot_width,
        boxplot_outliers = input$boxplot_outliers,
        boxplot_notch = input$boxplot_notch,
        density_alpha = input$density_alpha,
        density_position = input$density_position,
        density_adjust = input$density_adjust,
        hist_bins     = input$hist_bins,
        hist_position = input$hist_position,
        hist_alpha    = input$hist_alpha,
        area_position = input$area_position,
        area_alpha    = input$area_alpha,
        violin_trim   = input$violin_trim,
        violin_draw_quantiles = input$violin_draw_quantiles,
        violin_alpha  = input$violin_alpha
      )
      committed_params(params)

      list(
        method = method,
        obj = obj
      )
    })
  })
  
  output$interactive_plot_ui <- renderUI({
    req(generated_plot_obj())
    plotlyOutput(
      ns("interactive_plot"),
      height = if (generated_plot_obj()$method == "overlay") "620px" else "800px"
    )
  })

  final_static_plot <- reactive({
    req(generated_plot_obj())
    obj <- generated_plot_obj()$obj
    if (inherits(obj, "ggplot")) {
      return(obj)
    }
    nrows <- if (generated_plot_obj()$method == "side_by_side") 1 else length(obj)
    plot_grid(plotlist = obj, nrow = nrows)
  })

  output$static_plot <- renderPlot({
    req(final_static_plot())
    print(final_static_plot())
  })

  output$interactive_plot <- renderPlotly({
    req(generated_plot_obj())
    if (generated_plot_obj()$method == "overlay") {
      return(ggplotly(generated_plot_obj()$obj))
    }
    plotly_list <- lapply(generated_plot_obj()$obj, ggplotly)
    nrows <- if (generated_plot_obj()$method == "side_by_side") 1 else length(plotly_list)
    subplot(plotly_list, nrows = nrows, shareX = FALSE, shareY = FALSE, titleX = TRUE, titleY = TRUE)
  })

  output$combo_data_table <- renderDT({
    req(data())
    datatable(data(), options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
  })

  # 下载处理（从 committed_params 读取导出参数）
  output$download_plot <- downloadHandler(
    filename = function() {
      cp <- committed_params()
      fmt <- if (!is.null(cp$export_format)) cp$export_format else input$export_format
      build_plot_export_filename("combo_plot", fmt)
    },
    content = function(file) {
      req(final_static_plot())
      cp <- committed_params()
      save_plot_export(
        file = file,
        plot_obj = final_static_plot(),
        format = if (!is.null(cp$export_format)) cp$export_format else input$export_format,
        width = 12,
        height = 8,
        dpi = if (!is.null(cp$export_dpi)) cp$export_dpi else 300
      )
    }
  )

  apply_state <- function(state) {
    if (!is.list(state)) return(invisible(FALSE))
    input_state <- graphics_task_payload_input_state(state)
    extra_state <- graphics_task_payload_extra_state(state)

    base_ids <- c(
      "main_x_var", "main_y_var", "group_var", "facet_var",
      "plot_types", "combo_method", "export_format", "export_dpi"
    )
    base_state <- input_state[names(input_state) %in% base_ids]
    dynamic_state <- input_state[!(names(input_state) %in% base_ids)]

    if (length(base_state) > 0) {
      graphics_restore_task_input_state(
        session,
        list(input_state = base_state, extra_state = list()),
        defer = FALSE
      )
    }
    if (length(base_state) == 0 && length(extra_state$plot_types %||% character(0)) > 0) {
      updateCheckboxGroupInput(session, "plot_types", selected = extra_state$plot_types)
    }
    if (length(base_state) == 0 && !is.null(extra_state$method)) {
      updateRadioButtons(session, "combo_method", selected = extra_state$method)
    }
    session$onFlushed(function() {
      if (length(dynamic_state) > 0) {
        graphics_restore_task_input_state(
          session,
          list(input_state = dynamic_state, extra_state = list()),
          defer = FALSE
        )
      }
    }, once = TRUE)
    invisible(TRUE)
  }

  list(
    state = reactive({
      cp <- committed_params()
      graphics_build_task_state(
        input,
        extra_state = list(
          plot_types = if (!is.null(cp$plot_types)) cp$plot_types else input$plot_types,
          method = if (!is.null(cp$combo_method)) cp$combo_method else input$combo_method
        )
      )
    }),
    apply_state = apply_state
  )
}
