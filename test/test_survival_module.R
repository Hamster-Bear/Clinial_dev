#!/usr/bin/env Rscript
# 测试生存分析模块的语法

cat("正在测试生存分析模块的语法...\n")

# 检查文件是否存在
if (!file.exists("modules/statistical_graphics/survival_analysis.R")) {
  stop("错误: 无法找到生存分析模块文件")
}

# 尝试解析文件以检查语法
cat("检查语法...\n")
syntax_check <- try(parse("modules/statistical_graphics/survival_analysis.R"), silent = TRUE)

if (inherits(syntax_check, "try-error")) {
  cat("语法错误:\n")
  print(syntax_check)
  stop("生存分析模块包含语法错误")
} else {
  cat("✅ 语法检查通过\n")
}

# 尝试加载必要的包
cat("检查依赖包...\n")
required_packages <- c("survival", "survminer", "plotly", "DT", "cowplot", "ggplot2")

for(pkg in required_packages) {
 if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    warning("包 ", pkg, " 无法加载，但可能不会影响语法检查")
  }
}

# 尝试source文件
cat("尝试加载模块...\n")
module_load <- try(source("modules/statistical_graphics/survival_analysis.R"), silent = TRUE)

if (inherits(module_load, "try-error")) {
  cat("加载错误:\n")
  print(module_load)
  stop("无法加载生存分析模块")
} else {
  cat("✅ 模块加载成功\n")
}

cat("所有测试通过！\n")