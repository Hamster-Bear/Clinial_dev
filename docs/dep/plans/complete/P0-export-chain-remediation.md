---
phase_index: 0
status: done
created: 2026-06-30
updated: 2026-06-30
priority: 2
estimated_rounds: 1-2
depends_on: []
tags: ["export", "tables", "quality"]
syncs_to:
  - TEST_GUIDE.md
---

# P0 导出链路质量修复

## 目标

修复各模块导出链路中已确认的质量缺陷，统一错误处理，补齐 CJK 字体支持。

## 背景

导出链路全模块审查发现：tables 导出缺少 tryCatch、表格导出字体硬编码 Times New Roman 缺 CJK fallback、listing_general RTF 导出未走专用高质量路径。均为非阻断质量缺陷。

## 范围

### 包含

- `table_download` 加 tryCatch 错误处理
- 表格导出字体加 CJK fallback 链
- listing_general RTF 导出统一到 `table_download` 分发

### 不包含

- 新增 CSV/XLSX 导出格式
- rtables→flextable 直连（rtables 无 `as_flextable` 方法，不可行）
- Docker 容器 CJK 字体安装（基础设施层）

## 主文档影响

| 文档 | 影响章节 |
|------|----------|
| TEST_GUIDE.md | 新增导出测试索引 |

## Phase 总览

| Phase | 目标 | 预估轮数 | 依赖 | 状态 |
|-------|------|---------|------|------|
| P1 | 确定性修复：tryCatch、CJK fallback | 1 | 无 | done |
| P2 | 质量提升：listing 导出统一 | 1 | P1 | done |

## P1 — 确定性修复

### 输入条件

- 导出链路审查完成，问题已确认

### 产出

- `tables.R` table_download 有 tryCatch + showNotification
- `table_export.R` apply_sci_gt_style 字体有 CJK fallback

### 完成标准

- [x] table_download 导出失败时用户看到友好提示而非原始错误
- [x] 中文表格在 PNG/HTML 导出时走 CJK fallback 字体链

### 边界

- 不改 t_ae_soc_pt 的导出对象类型
- 不改 listing_general 的导出分发逻辑（Phase 2）

### 涉及文件

- `modules/tables.R`
- `modules/common/export/table_export.R`

## P2 — 质量提升

### 输入条件

- P1 完成

### 产出

- listing_general 的 RTF 导出通过 `table_download` 统一分发到 `export_listing_general_rtf`

### 完成标准

- [x] listing_general RTF 走专用高质量路径（SAS Group 留白、列格式化）
- [x] 测试通过

### 边界

- 不新增 CSV/XLSX 格式
- 不重写 rtables 表格生成逻辑

### 涉及文件

- `modules/tables.R`

## 执行中发现

| 编号 | 类型 | 来源 | 描述 | 处理 |
|------|------|------|------|------|
| F1 | 信息 | P1 | `extract_table_dataframe` 文本回退路径已有 `graphics_with_showtext_paused` 保护（line 88），非 bug | 无需修复 |
| F2 | 阻断 | P2 | rtables 无 `as_flextable` / `tt_to_flextable` 方法，仅有 `export_as_tsv` | 放弃直连方案，保持文本回退 |
| F3 | 信息 | 审查 | `save_plot_export` 使用 `svglite` 但未列入 `required_packages.R`；有 fallback 到 `grDevices::svg` | 不处理，可选依赖 |

## 关键决策记录

- 2026-06-30：rtables 无 `as_flextable` 方法，t_ae_soc_pt DOCX 导出保持 `capture.output(print())` 文本回退路径。该路径已通过 `graphics_with_showtext_paused` 保护，输出无 ANSI 污染。
- 2026-06-30：CJK 字体采用 fallback 链方案（`c("Times New Roman", "SimSun", "sans")`），仅改 gt 的 `table.font.names`；flextable DOCX 依赖 Word 应用层 CJK 回退，无需代码改动。
- 2026-06-30：listing_general RTF 走 `export_listing_general_rtf` 专用函数，保留 SAS Group 留白和列格式化。
