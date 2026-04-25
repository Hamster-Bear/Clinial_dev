# 统计图形结果区文案共享化设计

## 背景

- 入口层文案已收口到 `modules/common/entry_copy.R`。
- 统计分析子模块的 `app_card_note()` 已收口到 `modules/common/stat_analysis_submodule_copy.R`。
- 统计图形子模块仍在多个模块内部重复定义结果区相关文案，尤其集中在：
  - 结果卡 `subtitle`
  - 结果卡 `app_card_note()`
  - 结果页签 `app_result_panel(note = ...)`
- 图形模块数量多，文案既有共性，也有明显的模块专属边界说明；如果一次性做全量共享化，回归成本和维护风险都较高。

## 目标

- 为第一批统计图形子模块新增结果区共享文案源。
- 将结果区的通用 `subtitle`、`app_card_note()` 和 `note` 收口到共享 helper。
- 保留模块专属的边界说明和差异化提示，不为了统一而强行改写。
- 新增守卫测试，确保第一批模块持续从共享结果区文案源读取通用说明。
- 同步更新项目规范文档与测试索引。

## 非目标

- 不修改配置区文案。
- 不修改导出区文案。
- 不修改 `helpText()`、`bsTooltip()`、字段标签和 server 端结果解释。
- 不覆盖所有统计图形模块。
- 不要求模块专属结果提示全部迁移到共享源。

## 范围

### 第一批纳入模块

- `modules/statistical_graphics/survival_analysis.R`
- `modules/statistical_graphics/forest_plot.R`
- `modules/statistical_graphics/combo_plot.R`
- `modules/statistical_graphics/waterfall_plot.R`
- `modules/statistical_graphics/swimmer_plot.R`
- `modules/statistical_graphics/spider_plot.R`
- 视结果区结构一致性，可选纳入 `modules/statistical_graphics/boxplot.R`

### 暂不纳入模块

- `modules/statistical_graphics/heatmap.R`
- `modules/statistical_graphics/correlation_matrix.R`
- 其他结果区结构明显不一致或模块专属提示较重的图形模块

### 本轮覆盖位置

- 结果卡 `subtitle`
- 结果卡 `app_card_note()`
- 结果页签 `app_result_panel(note = ...)`

### 本轮保留在模块内的位置

- 模块专属结果边界说明
- 无交互图占位提示等特例文案
- 配置区与导出区所有说明
- `helpText()`、`bsTooltip()`、字段标签

## 方案对比

### 方案 A：只共享结果区通用文案

- 优点：重复度高、边界清晰、便于先跑通图形侧共享模式。
- 缺点：导出区和配置区文案仍分散。
- 结论：采用本方案。

### 方案 B：结果区 + 导出区一起共享

- 优点：一次性覆盖更多重复说明。
- 缺点：结果语义和导出语义混合，helper 结构更重，首批风险偏高。

### 方案 C：配置区、导出区、结果区全量共享

- 优点：统一程度最高。
- 缺点：范围失控，不适合作为第一批。

## 设计

### 1. 共享文案 helper

- 新增 `modules/common/graphics_result_copy.R`
- 导出对象命名为 `GRAPHICS_RESULT_COPY`
- 结构按“模块 -> 结果区分块”组织，例如：
  - `GRAPHICS_RESULT_COPY$survival$result_card`
  - `GRAPHICS_RESULT_COPY$survival$static_plot`
  - `GRAPHICS_RESULT_COPY$survival$interactive_plot`
  - `GRAPHICS_RESULT_COPY$survival$data_tab`
- 对常见三类结果分块保持统一键名：
  - `result_card`
  - `static_plot`
  - `interactive_plot`
  - `data_tab`
- 若模块存在报告页或其他稳定结构，可增加模块专属 key，但只在必要时添加。

### 2. 模块接入方式

- 每个纳入模块在公共依赖附近 `source("modules/common/graphics_result_copy.R")`
- 在 UI 构造结果区前绑定模块级 copy，例如：
  - `copy <- GRAPHICS_RESULT_COPY$waterfall`
  - `copy <- GRAPHICS_RESULT_COPY$swimmer`
- 将通用结果区文案替换为共享字段，例如：
  - `subtitle = copy$result_card$subtitle`
  - `app_card_note(copy$result_card$note)`
  - `note = copy$static_plot$note`

### 3. 模块专属文案边界

- 若某段结果区文案表达的是该模块独有能力边界，应继续保留在模块内，不强行纳入共享源。
- 典型例子：
  - `forest_plot` 的“当前没有独立交互图”提示
  - `survival_analysis` 中与统计报告结构强绑定的说明
- 共享优先级：
  - 先共享跨模块重复的结果区说明
  - 再保留少量必要的模块专属说明

### 4. 守卫测试

- 新增测试：
  - `tests/statistical_graphics/ui/test_graphics_result_copy_guard.R`
- 守卫目标：
  - `graphics_result_copy.R` 存在
  - 第一批模块已加载共享 helper
  - 结果区 `subtitle`、`app_card_note()`、`note` 位置开始读取 `copy$...`
- 守卫不校验完整中文句子，只校验结构和引用方式。

### 5. TDD 顺序

1. 先新增 `test_graphics_result_copy_guard.R` 并确认失败
2. 新建 `graphics_result_copy.R`
3. 接入第一批模块的结果区通用文案
4. 保留模块专属结果提示在原文件中
5. 跑守卫测试与现有图形布局/文案回归
6. 同步更新文档与测试索引

## 文档同步

- `PROJECT_GUIDE.md`
  - 记录统计图形结果区共享文案边界与第一批模块范围
- `PROJECT_SPEC.md`
  - 扩展前端共享文案覆盖到图形结果区
- `CODE_STYLE.md`
  - 增补图形结果区通用文案优先复用共享源的规则
- `TEST_GUIDE.md`
  - 登记新的图形结果区共享守卫测试

## 风险与缓解

- 风险：强行把模块专属提示也塞入共享源，导致 helper 冗长且难懂。
- 缓解：允许模块专属结果文案保留在模块内，只共享跨模块重复部分。
- 风险：第一批纳入模块过多，出现大量结构例外。
- 缓解：优先纳入结果区结构相近的模块，`heatmap` 和 `correlation_matrix` 暂缓。
- 风险：守卫测试绑定全文中文句子，后续润色成本高。
- 缓解：守卫只检查共享结构、引用方式和第一批模块覆盖范围。
