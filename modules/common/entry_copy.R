ENTRY_COPY <- list(
  statistical_analysis = list(
    filter = list(
      title = "全局数据筛选",
      subtitle = "先设置统计分析使用的数据过滤条件",
      note = "该筛选会作用于本页所有统计方法。"
    ),
    method = list(
      title = "统计方法选择",
      subtitle = "选择描述性统计、回归模型与组间比较方法",
      note = "选择统计方法后，再按需配置对应参数。"
    ),
    params = list(
      title = "变量选择和参数设置",
      subtitle = "根据所选方法显示变量映射、模型参数和执行入口",
      note = "按当前统计方法配置变量映射和参数。"
    ),
    result = list(
      title = "分析结果",
      subtitle = "查看统计结果、报告和可复现代码",
      note = "结果区包含统计表格、统计报告和可复现代码三个页签。",
      export_note = "按所选格式、报告开关、标题和脚注导出结果文件。"
    )
  ),
  statistical_graphics = list(
    selector = list(
      title = "统计图形类型选择",
      subtitle = "选择统计图形类型并进入对应模块",
      note = "从这里进入可用的统计图形模块。"
    ),
    repro = list(
      title = "可复现代码",
      subtitle = "查看当前图形类型和参数对应的可复现代码",
      note = "根据当前图形参数生成可复现的 R 代码。"
    )
  ),
  tables = list(
    method = list(
      title = "表格类型选择",
      subtitle = "选择预设表格类型",
      note = "选择表格类型后，按当前类型配置参数并执行生成。"
    ),
    params = list(
      title = "参数设置",
      subtitle = "配置当前表格类型的参数",
      note = "按当前表格类型配置参数，然后点击生成。"
    ),
    result = list(
      title = "预设图表结果",
      subtitle = "查看表格结果并获取可复现代码",
      note = "结果区提供“表格结果 / R代码”两个页签。",
      export_note = "按当前格式、文件名前缀和导出按钮设置导出结果。"
    )
  ),
  exploratory_analysis = list(
    tray = list(
      title = "变量托盘",
      subtitle = "浏览当前可用变量及其类型",
      note = "查看当前数据中的可用变量及其类型提示。"
    ),
    controller = list(
      title = "图形控制器",
      subtitle = "选择图形类型并设置变量映射",
      note = "根据图形类型设置变量映射、标题和显示参数。"
    ),
    result = list(
      title = "图形输出",
      subtitle = "查看交互式图形结果",
      note = "结果区展示交互式图形，并在需要时提供分页提示或异常提示。"
    )
  )
)

entry_copy_get <- function(...) {
  keys <- list(...)
  value <- ENTRY_COPY
  for (key in keys) {
    if (is.null(value[[key]])) {
      stop(sprintf("ENTRY_COPY 缺少键: %s", paste(unlist(keys), collapse = ".")), call. = FALSE)
    }
    value <- value[[key]]
  }
  value
}
