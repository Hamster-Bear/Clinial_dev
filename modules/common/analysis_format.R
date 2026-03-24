# 格式化 P 值 (回归分析专用，当前映射为 AMA 标准)
format_p_value_regression <- function(p) {
  format_p_value_ama(p)
}

# 格式化回归统计量 (HR, OR, Beta 等)
# 针对学术论文要求的标准格式：保留两位小数，统一处理 NA 和极值，确保对齐
format_regression_stat <- function(est, low, high) {
  est <- suppressWarnings(as.numeric(est))
  low <- suppressWarnings(as.numeric(low))
  high <- suppressWarnings(as.numeric(high))
  
  # 如果估计值本身就是 NA，或者无法计算出置信区间，则返回标准占位符
  if (is.na(est)) return("—")
  if (is.na(low) || is.na(high)) return(sprintf("%.2f (—, —)", est))
  
  # 临床统计学论文标准：统计量和置信区间一般保留 2 位小数（而不是 4 位去零），以保证列对齐的美观度
  # 例如：1.20 (0.95, 1.50)
  sprintf("%.2f (%.2f, %.2f)", est, low, high)
}

# 提取交互作用 P 值的公共逻辑
# 该函数目前由 analysis_shared.R 中的逻辑内部处理，此处可作为占位扩展点

build_repro_code_template <- function(steps) {
  lines <- character(0)
  for (i in seq_along(steps)) {
    step <- steps[[i]]
    title <- if (!is.null(step$title)) as.character(step$title)[1] else paste0("Step ", i)
    body <- if (!is.null(step$lines)) as.character(step$lines) else character(0)
    lines <- c(lines, paste0("# ", i, ") ", title), body, "")
  }
  paste(lines, collapse = "\n")
}
