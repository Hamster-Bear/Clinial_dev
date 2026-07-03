---
phase_index: 1
status: ongoing
created: 2026-07-03
updated: 2026-07-03
priority: 1
estimated_rounds: 2-3
depends_on: ["P0-export-chain-remediation"]
tags: ["export", "charts", "tables", "error-handling", "dependencies"]
syncs_to:
  - TEST_GUIDE.md
  - PROJECT_GUIDE.md
---

# P1 导出链路深度修复

## 目标

修复预设图表（9 种统计图形）及预设表格 PNG/HTML/RTF 导出链路的阻断级缺陷，补齐错误处理、缺失依赖和导出尺寸一致性。

## 背景

导出链路全模块细致审核（2026-07-03）发现：
- 图表模块 9 个 downloadHandler 全部缺少 tryCatch 错误处理
- `save_table_png()` 零错误处理 + 缺少 `webshot2` 依赖导致表格 PNG 导出静默失败
- 图表模块导出尺寸逻辑不统一（部分硬编码、部分读 input、部分用 committed_params）
- HTML/RTF 导出缺少 pandoc 可用性前置检测
- `svglite` 未列入包清单
- PDF 格式依赖 Chromium 外部进程，破坏 Docker 容器自包含性

## 范围

### 包含

- P0: 全部 9 个图表 downloadHandler 加 tryCatch + showNotification
- P0: `save_table_png()` 加 tryCatch 错误处理
- P0: `webshot2` 加入 `required_packages.R` 和 `app.R` 启动清单
- P1: 统一图表模块导出尺寸逻辑（从 committed_params 读取）
- P1: HTML/RTF/PDF 导出加 pandoc/Chrome 可用性前置检测函数
- P2: `svglite` 加入 `required_packages.R`
- 文档同步：TEST_GUIDE.md, PROJECT_GUIDE.md

### 不包含

- PDF 格式 R 原生方案重写（P3，另行规划）
- 新增导出格式 (CSV/XLSX)
- Docker 镜像重建

## Phase 总览

| Phase | 目标 | 预估轮数 | 依赖 | 状态 |
|-------|------|---------|------|------|
| P1 | 阻断修复：tryCatch 全覆盖 + webshot2 依赖 | 1 | P0-export-chain-remediation 完成 | done |
| P2 | 一致性提升：前置检测函数 + svglite 依赖 | 1 | P1 | done |
| P3 | PDF R 原生方案实施 | 1 | P2 | done |

## P1 — 阻断修复

### 输入条件

- 代码审核完成，9 个图表模块下载处理器和 save_table_png 的缺陷已定位
- P0-export-chain-remediation 完成（表格模块已有 tryCatch 参考实现）

### 产出

- 全部 9 个图表模块 downloadHandler 有 tryCatch + showNotification（统一错误处理模式）
- `save_table_png()` 函数体有 tryCatch，每个分支独立错误保护
- `webshot2` 加入 `config/required_packages.R` 和 `app.R` 启动校验清单

### 完成标准

- [x] 图表导出失败时用户看到友好提示（`showNotification`）而非原始 R 错误
- [x] 表格 PNG 导出在安装 webshot2 后可正常工作
- [x] 所有导出路径的错误均有日志记录（`message("[GraphicsExportError]...")`）

### 边界

- 不改 save_plot_export 内部实现（已有 tryCatch for PDF fallback）
- 不修改表格模块 tables.R 的 tryCatch（已正确实现）
- 不改导出格式选择 UI

### 涉及文件

- `modules/statistical_graphics/boxplot.R` — 加 tryCatch
- `modules/statistical_graphics/survival_analysis.R` — 加 tryCatch
- `modules/statistical_graphics/forest_plot.R` — 加 tryCatch
- `modules/statistical_graphics/heatmap.R` — 加 tryCatch
- `modules/statistical_graphics/correlation_matrix.R` — 加 tryCatch
- `modules/statistical_graphics/combo_plot.R` — 加 tryCatch
- `modules/statistical_graphics/waterfall_plot.R` — 加 tryCatch
- `modules/statistical_graphics/swimmer_plot.R` — 加 tryCatch
- `modules/statistical_graphics/spider_plot.R` — 加 tryCatch
- `modules/common/export/table_export.R` — save_table_png 加 tryCatch
- `config/required_packages.R` — 加 webshot2
- `app.R` — 加 webshot2 启动校验

## P2 — 一致性提升

### 输入条件

- P1 完成

### 产出

- 新增 `graphics_check_export_prerequisites(format)` 通用前置检测函数
- `boxplot/combo_plot/heatmap/correlation_matrix` 导出尺寸从 committed_params 读取而非硬编码
- pandoc 可用性检测集成到 `save_table_export`

### 完成标准

- [x] HTML/RTF 导出前检测 pandoc 可用性，不可用时给出明确错误信息
- [x] PDF 导出前检测 Chrome 可用性，不可用时给出明确错误信息
- [x] `svglite` 加入 `config/required_packages.R`
- [x] 图表模块导出尺寸统一（9 个模块全部使用 `size_config()` + `graphics_collect_size_config(input)`）

### 边界

- 不改 survival/waterfall/swimmer/spider 的现有 size_config() 体系（已正确实现，仅作对齐）

### 涉及文件

- `modules/common/graphics/graphics_common.R` — 新增 `graphics_check_export_prerequisites()` 和 `graphics_check_png_prerequisites()`
- `modules/common/export/table_export.R` — 集成前置检测
- `config/required_packages.R` — 添加 svglite
- `modules/statistical_graphics/boxplot.R` — UI 改用 `graphics_export_size_controls_ui(include_size_mode=TRUE)` + 新增 size_config + downloadHandler 统一
- `modules/statistical_graphics/heatmap.R` — 同上
- `modules/statistical_graphics/correlation_matrix.R` — 同上
- `modules/statistical_graphics/combo_plot.R` — 同上
- `modules/statistical_graphics/forest_plot.R` — 同上，保留 `plot_ratio` 森林图专属控件

## P3 — PDF R 原生方案

### 背景

当前表格 PDF 导出链路：
```
table → rmarkdown::render(html_document) → pagedown::chrome_print() → PDF
```
依赖 Chromium 外部进程，破坏 Docker 容器自包含性。Chrome 不可用时 PDF 导出静默失败。

### R 原生方案

将表格提取为 data.frame → `gridExtra::tableGrob` 渲染为 grid grob → `grDevices::cairo_pdf` 设备输出 PDF。

```
table → extract_table_dataframe() → gridExtra::tableGrob() → cairo_pdf device → PDF
```

**优点**:
- 纯 R 原生，零外部依赖（`cairo_pdf` 为 R 内置）
- 与图表 PDF 导出路径一致（`save_plot_export(format="pdf")` 使用同一设备）
- Docker 镜像无需 Chromium，保持自包含性

**缺点**:
- `tableGrob` 渲染纯文本表格，无 gt/flextable 的富格式（无合并单元格、无 spanner header、无条件格式）
- 长文本需手动换行处理
- 宽表格需手动适配页面宽度

### 实施方向

1. 新建 `save_table_pdf_native(file, table_obj, title, footnotes)` 函数
2. 复用 `extract_table_dataframe()` 提取数据
3. 使用 `gridExtra::tableGrob` + `cairo_pdf` 渲染
4. 在 `save_table_export(format="pdf")` 中替换 `chrome_print` 路径
5. 保留 `pagedown` 作为可选依赖（不再强制）

### 完成标准

- [x] `save_table_pdf_native()` 函数实现
- [x] 表格 PDF 导出零外部依赖（仅 R 内置 Cairo）
- [x] `pagedown` 从 `save_table_export` 的 PDF 路径移除
- [x] `pagedown` 标记为可选依赖

### 涉及文件

- `modules/common/export/table_export.R` — 新增 `save_table_pdf_native()`，修改 PDF 分发
- `config/required_packages.R` — 可选：移除 `pagedown`（如不再需要）

## 执行中发现

| 编号 | 类型 | 来源 | 描述 | 处理 |
|------|------|------|------|------|
| - | - | - | 暂无 | - |

## 关键决策记录

- 2026-07-03：PDF 格式暂时搁置，待 P3 调研 R 原生方案（`grid::grid.draw` + `grDevices::cairo_pdf`），避免引入 Chromium 外部依赖破坏 Docker 自包含性。
- 2026-07-03：9 个图表模块统一使用 `tryCatch` + `showNotification` + `message("[GraphicsExportError]...")` 的错误处理模式，以 `tables.R` 为参考实现。
- 2026-07-03：导出尺寸读取逻辑统一为：优先 `committed_params()`，其次 `input$...`，最后默认值。使用 `graphics_collect_size_config()` 作为尺寸解析的统一入口。
