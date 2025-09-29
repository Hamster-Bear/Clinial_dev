# 生存分析模块图例生成逻辑说明文档

## 概述

本文档详细说明了AutoTFL项目中生存分析模块的图例生成逻辑，包括静态图例和交互式图例的实现方式。

## 代码位置

- 主要文件：`modules/statistical_graphics/survival_analysis.R`
- 图例相关代码行：第96-132行（UI部分）、第534-595行（静态图例逻辑）、第728-788行（交互式图例逻辑）

## UI组件

### 图例设置UI（第96-132行）

```r
# 图例设置
fluidRow(
  box(
    width = 12,
    title = "图例设置",
    status = "primary",
    collapsible = TRUE,
    collapsed = TRUE,
    fluidRow(
      column(3,
             selectInput(ns("legend_position"), "图例位置",
                       choices = c("顶部" = "top", "底部" = "bottom", "左侧" = "left", "右侧" = "right", "无" = "none"),
                       selected = "top")
      ),
      column(3,
             numericInput(ns("legend_size"), "图例文字大小", value = 12, min = 6, max = 20, step = 1)
      ),
      column(3,
             numericInput(ns("legend_width"), "图例宽度", value = 0.5, min = 0.1, max = 2, step = 0.1)
      ),
      column(3,
             numericInput(ns("legend_height"), "图例高度", value = 0.5, min = 0.1, max = 2, step = 0.1)
      )
    ),
    fluidRow(
      column(3,
             checkboxInput(ns("show_censor_legend"), "显示删失图例", value = TRUE)
      ),
      column(9,
             conditionalPanel(
               condition = "input.show_censor_legend == true",
               textInput(ns("censor_legend_title"), "删失图例标题", value = "删失")
             )
           )
    )
  )
)
```

## 图例生成逻辑

### 静态图例生成（第534-595行）

```r
# 处理图例显示 - 确保删失符号和线条图例分离
# 为线条和删失符号设置独立的图例
if (input$strata_var == "None" || is.null(fit()$strata)) {
  # 没有分层变量时，确保生存曲线有图例
  if (input$km_show_censor && input$show_censor_legend) {
    # 显示删失符号图例
    p$plot <- p$plot +
      guides(
        color = guide_legend(title = "生存曲线", order = 1),
        shape = guide_legend(title = input$censor_legend_title, order = 2, override.aes = list(shape = as.numeric(input$km_censor_shape), size = input$km_censor_size))
      )
  } else if (input$km_show_censor && !input$show_censor_legend) {
    # 不显示删失符号图例，只显示生存曲线图例
    p$plot <- p$plot +
      guides(
        color = guide_legend(title = "生存曲线", order = 1),
        shape = "none"
      )
 } else {
    # 不显示删失符号，只显示生存曲线图例
    p$plot <- p$plot +
      guides(color = guide_legend(title = "生存曲线", order = 1))
  }
} else {
  # 有分层变量时
  if (input$km_show_censor && input$show_censor_legend) {
    # 显示分层变量和删失符号两个图例
    p$plot <- p$plot +
      guides(
        color = guide_legend(title = input$strata_var, order = 1),
        shape = guide_legend(title = input$censor_legend_title, order = 2, override.aes = list(shape = as.numeric(input$km_censor_shape), size = input$km_censor_size))
      )
  } else if (input$km_show_censor && !input$show_censor_legend) {
    # 只显示分层变量图例，隐藏删失符号图例
    p$plot <- p$plot +
      guides(
        color = guide_legend(title = input$strata_var, order = 1),
        shape = "none"
      )
  } else {
    # 只显示分层变量图例
    p$plot <- p$plot +
      guides(color = guide_legend(title = input$strata_var, order = 1))
  }
}

# 应用图例大小设置
if (input$legend_position != "none" && !is.null(p$plot)) {
  p$plot <- p$plot +
    theme(
      legend.text = element_text(size = input$legend_size),
      legend.title = element_text(size = input$legend_size)
    )
}
```

### 交互式图例生成（第728-788行）

```r
# 处理图例显示 - 确保删失符号和线条图例分离
# 为线条和删失符号设置独立的图例
if (input$strata_var == "None" || is.null(fit()$strata)) {
  # 没有分层变量时，确保生存曲线有图例
  if (input$km_show_censor && input$show_censor_legend) {
    # 显示删失符号图例
    p <- p +
      guides(
        color = guide_legend(title = "生存曲线", order = 1),
        shape = guide_legend(title = input$censor_legend_title, order = 2, override.aes = list(shape = as.numeric(input$km_censor_shape), size = input$km_censor_size))
      )
  } else if (input$km_show_censor && !input$show_censor_legend) {
    # 不显示删失符号图例，只显示生存曲线图例
    p <- p +
      guides(
        color = guide_legend(title = "生存曲线", order = 1),
        shape = "none"
      )
  } else {
    # 不显示删失符号，只显示生存曲线图例
    p <- p +
      guides(color = guide_legend(title = "生存曲线", order = 1))
  }
} else {
 # 有分层变量时
  if (input$km_show_censor && input$show_censor_legend) {
    # 显示分层变量和删失符号两个图例
    p <- p +
      guides(
        color = guide_legend(title = input$strata_var, order = 1),
        shape = guide_legend(title = input$censor_legend_title, order = 2, override.aes = list(shape = as.numeric(input$km_censor_shape), size = input$km_censor_size))
      )
  } else if (input$km_show_censor && !input$show_censor_legend) {
    # 只显示分层变量图例，隐藏删失符号图例
    p <- p +
      guides(
        color = guide_legend(title = input$strata_var, order = 1),
        shape = "none"
      )
 } else {
    # 只显示分层变量图例
    p <- p +
      guides(color = guide_legend(title = input$strata_var, order = 1))
  }
}

# 应用图例大小设置
if (input$legend_position != "none") {
  p <- p +
    theme(
      legend.text = element_text(size = input$legend_size),
      legend.title = element_text(size = input$legend_size)
    )
}
```

## 关键组件和参数

### 1. 图例位置控制
- 参数：`input$legend_position`
- 选项：顶部(top)、底部(bottom)、左侧(left)、右侧(right)、无(none)
- 默认值：top

### 2. 图例大小控制
- 参数：`input$legend_size`
- 范围：6-20
- 默认值：12

### 3. 图例尺寸控制
- 参数：`input$legend_width` 和 `input$legend_height`
- 范围：0.1-2
- 默认值：0.5

### 4. 删失符号图例控制
- 参数：`input$show_censor_legend`
- 类型：布尔值
- 默认值：TRUE

### 5. 删失符号图例标题
- 参数：`input$censor_legend_title`
- 默认值："删失"

## 实现特点

### 优点：
1. **灵活的图例位置控制**：支持5种不同的图例位置选项
2. **独立的图例处理**：能够分别处理生存曲线图例和删失符号图例
3. **可配置的图例样式**：支持调整图例文字大小、宽度和高度
4. **条件性图例显示**：根据是否显示删失符号和是否显示删失图例来决定图例的显示方式
5. **分层变量支持**：能够根据是否使用分层变量来调整图例标题

### 缺点：
1. **重复代码**：静态图和交互式图的图例生成逻辑几乎完全相同，存在代码重复
2. **图例大小控制限制**：只控制文字大小，没有独立控制图例标记的大小
3. **图例方向固定**：没有提供控制图例方向（水平或垂直）的选项

## 代码流程

1. 检查是否有分层变量
2. 检查是否显示删失符号和删失图例
3. 根据条件设置相应的图例样式
4. 应用图例大小设置
5. 将图例设置应用到图形对象

## 使用场景

### 无分层变量的情况：
- 只有一条生存曲线时，图例显示"生存曲线"
- 如果显示删失符号，可选择是否显示删失符号图例

### 有分层变量的情况：
- 根据分层变量的名称显示图例标题
- 如果显示删失符号，可选择是否显示删失符号图例

## 扩展建议

1. 将重复的图例生成逻辑提取为独立函数
2. 添加图例方向控制选项
3. 增加更多图例样式自定义选项
4. 添加图例位置的更精确控制（如具体坐标）