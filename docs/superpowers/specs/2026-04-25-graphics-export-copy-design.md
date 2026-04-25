# 统计图形导出卡通用文案共享化设计

## 背景

- 入口层文案已收口到 `modules/common/entry_copy.R`。
- 统计分析子模块说明文案已收口到 `modules/common/stat_analysis_submodule_copy.R`。
- 统计图形第一批结果区通用文案已收口到 `modules/common/graphics_result_copy.R`。
- 当前统计图形模块的导出卡仍在多个模块内重复定义通用文案，主要集中在：
  - 导出卡 `subtitle`
  - 导出卡 `app_card_note()`
- 导出区内的 `helpText()` 常包含模块专属尺寸语义、固定画布、宽高比或分层标签说明，不适合第一批强行共享。

## 目标

- 为第一批统计图形模块新增导出卡通用文案源。
- 将导出卡的通用 `subtitle` 和 `app_card_note()` 收口到共享 helper。
- 保留模块专属 `helpText()` 和导出语义在原模块内。
- 新增守卫测试，确保第一批模块持续从共享导出文案源读取通用说明。
- 同步更新项目规范文档与测试索引。

## 非目标

- 不修改导出区 `helpText()`。
- 不修改导出区字段标签、默认值、尺寸算法、DPI 逻辑和导出行为。
- 不修改配置区和结果区文案。
- 不覆盖所有统计图形模块。
- 不把分层标签、风险表或固定画布等模块专属导出语义强行纳入共享 helper。

## 范围

### 第一批纳入模块

- `modules/statistical_graphics/forest_plot.R`
- `modules/statistical_graphics/combo_plot.R`
- `modules/statistical_graphics/waterfall_plot.R`
- `modules/statistical_graphics/swimmer_plot.R`
- `modules/statistical_graphics/spider_plot.R`
- `modules/statistical_graphics/survival_analysis.R`

### 暂不纳入模块

- `modules/statistical_graphics/boxplot.R`
- `modules/statistical_graphics/heatmap.R`
- `modules/statistical_graphics/correlation_matrix.R`
- 其他导出区结构或尺寸语义明显不一致的图形模块

### 本轮覆盖位置

- 导出卡 `subtitle`
- 导出卡 `app_card_note()`

### 本轮保留在模块内的位置

- 导出区所有 `helpText()`
- 宽高比例、固定画布、PX/英寸换算等模块专属说明
- 分层标签、风险表、表格宽度比等专属导出语义
- 所有导出输入控件和导出逻辑

## 方案对比

### 方案 A：只共享导出卡 `subtitle` 与 `app_card_note()`

- 优点：重复度高、边界最清晰、适合作为第一批稳定落地。
- 缺点：`helpText()` 仍然分散。
- 结论：采用本方案。

### 方案 B：共享导出卡文案 + 通用 `helpText()`

- 优点：收口更彻底。
- 缺点：很多 `helpText()` 实际绑定模块专属导出语义，容易误抽。

### 方案 C：导出区整卡全量共享

- 优点：统一程度最高。
- 缺点：会演变成大重构，不适合作为当前小批次。

## 设计

### 1. 共享文案 helper

- 新增 `modules/common/graphics_export_copy.R`
- 导出对象命名为 `GRAPHICS_EXPORT_COPY`
- 结构按“模块 -> 导出卡文案”组织，例如：
  - `GRAPHICS_EXPORT_COPY$forest$subtitle`
  - `GRAPHICS_EXPORT_COPY$forest$note`
  - `GRAPHICS_EXPORT_COPY$waterfall$subtitle`
  - `GRAPHICS_EXPORT_COPY$waterfall$note`
- 第一批只提供稳定的两个键：
  - `subtitle`
  - `note`

### 2. 模块接入方式

- 每个纳入模块在公共依赖附近 `source("modules/common/graphics_export_copy.R")`
- 在导出卡附近绑定模块级 copy，例如：
  - `copy <- GRAPHICS_EXPORT_COPY$combo`
  - `copy <- GRAPHICS_EXPORT_COPY$survival`
- 将通用导出卡文案替换为：
  - `subtitle = copy$subtitle`
  - `app_card_note(copy$note)`
- 不调整导出区内其他控件、字段或帮助文案。

### 3. 模块专属导出边界

- 若导出区说明表达的是该模块特有尺寸语义或业务边界，应继续保留在模块内。
- 典型例子：
  - `combo_plot` 的固定 12 x 8 英寸画布
  - `forest_plot` 的表格/图形宽度比
  - `survival_analysis` 的分层标签与风险表关联说明
- 共享优先级：
  - 先共享跨模块重复的导出卡概览文案
  - 再保留少量必要的模块专属说明

### 4. 守卫测试

- 新增测试：
  - `tests/statistical_graphics/ui/test_graphics_export_copy_guard.R`
- 守卫目标：
  - `graphics_export_copy.R` 存在
  - 第一批模块已加载共享 helper
  - 导出卡 `subtitle` 和 `app_card_note()` 已开始读取 `copy$...`
- 守卫不校验完整中文句子，只校验结构和引用方式。

### 5. TDD 顺序

1. 先新增 `test_graphics_export_copy_guard.R` 并确认失败
2. 新建 `graphics_export_copy.R`
3. 接入第一批模块的导出卡通用文案
4. 保留模块专属 `helpText()` 和导出语义在原文件中
5. 跑守卫测试与现有图形布局/文案回归
6. 同步更新文档与测试索引

## 文档同步

- `PROJECT_GUIDE.md`
  - 记录统计图形导出卡共享文案边界与第一批模块范围
- `PROJECT_SPEC.md`
  - 扩展前端共享文案覆盖到图形导出卡
- `CODE_STYLE.md`
  - 增补图形导出卡通用文案优先复用共享源的规则
- `TEST_GUIDE.md`
  - 登记新的图形导出卡共享守卫测试

## 风险与缓解

- 风险：把模块专属导出说明也塞入共享 helper，导致 helper 冗长且失真。
- 缓解：只共享导出卡概览文案，`helpText()` 和专属语义全部保留在模块内。
- 风险：第一批纳入模块过多，出现结构例外。
- 缓解：固定只纳入六个结构相对稳定的模块，`boxplot` 暂缓。
- 风险：守卫测试绑定全文中文句子，后续润色成本高。
- 缓解：守卫只检查共享结构、引用方式和第一批模块覆盖范围。
