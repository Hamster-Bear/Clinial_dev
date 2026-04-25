# 统计分析子模块说明文案共享化设计

## 背景

- 前一轮已将四个入口层模块的标题、副标题和说明文案收口到 `modules/common/entry_copy.R`。
- 当前统计分析子模块 `desc`、`cox`、`logistic`、`linear`、`anova`、`chisq` 仍在各文件内硬编码大量 `app_card_note()` 说明文案。
- 这些说明文案具有高重复性，尤其集中在：
  - 参数总览说明
  - 结局/响应与分层说明
  - 总计列与事件映射说明
  - 协变量/预测变量与参考组说明
- 若后续继续微调用户文案，容易出现多个子模块口径不一致。

## 目标

- 为统计分析六个子模块新增共享说明文案源。
- 将子模块内部硬编码的 `app_card_note()` 迁移到共享文案 helper。
- 通过守卫测试确保这些子模块持续从共享文案源读取说明，而不是回到各文件硬编码。
- 同步更新项目规范文档与测试索引。

## 非目标

- 不修改统计分析业务逻辑、输入控件、按钮文本和结果输出结构。
- 不修改 `bsTooltip()`、`helpText()`、字段标签、结果解释或复现代码文案。
- 不扩展到统计图形子模块。
- 不把共享范围扩大到子模块标题、分组标题或 tab 名称。

## 范围

- 覆盖文件：
  - `modules/statistical_analysis/desc.R`
  - `modules/statistical_analysis/cox.R`
  - `modules/statistical_analysis/logistic.R`
  - `modules/statistical_analysis/linear.R`
  - `modules/statistical_analysis/anova.R`
  - `modules/statistical_analysis/chisq.R`
- 覆盖对象：
  - 上述文件中的 `app_card_note()` 说明文案
- 不覆盖对象：
  - `tags$strong(...)`
  - `selectInput()` / `selectizeInput()` / `checkboxInput()` 等字段标题
  - `bsTooltip()` / `helpText()`
  - server 端结果解释文案

## 方案对比

### 方案 A：只共享 `app_card_note()` 说明文案

- 优点：风险最小，能先验证共享模式与守卫策略。
- 缺点：标题和 tooltip 仍留在模块内。
- 结论：采用本方案。

### 方案 B：同时共享说明文案与卡片标题

- 优点：共享更彻底。
- 缺点：helper 结构更重，守卫更脆，当前收益不足。

### 方案 C：每个子模块各自维护独立 copy list

- 优点：局部修改简单。
- 缺点：仍然分散，不符合“共享文案源”的长期目标。

## 设计

### 1. 共享文案 helper

- 新增 `modules/common/stat_analysis_submodule_copy.R`
- 导出对象命名为 `STAT_ANALYSIS_SUBMODULE_COPY`
- 结构按“模块 -> 文案键”组织，例如：
  - `STAT_ANALYSIS_SUBMODULE_COPY$desc$intro`
  - `STAT_ANALYSIS_SUBMODULE_COPY$desc$variables`
  - `STAT_ANALYSIS_SUBMODULE_COPY$desc$options`
  - `STAT_ANALYSIS_SUBMODULE_COPY$cox$intro`
  - `STAT_ANALYSIS_SUBMODULE_COPY$cox$outcome`
  - `STAT_ANALYSIS_SUBMODULE_COPY$cox$total_cols`
  - `STAT_ANALYSIS_SUBMODULE_COPY$cox$covariates`
- 可补一个最小读取 helper，例如 `stat_analysis_copy_get()`，但不强制；关键是结构清晰、职责单一。

### 2. 子模块接入方式

- 每个统计分析子模块文件在公共依赖附近 `source("modules/common/stat_analysis_submodule_copy.R")`
- 在对应 UI 函数中绑定模块级 copy，例如：
  - `copy <- STAT_ANALYSIS_SUBMODULE_COPY$desc`
  - `copy <- STAT_ANALYSIS_SUBMODULE_COPY$cox`
- 将硬编码的 `app_card_note("...")` 替换为：
  - `app_card_note(copy$intro)`
  - `app_card_note(copy$variables)`
  - `app_card_note(copy$options)`
- 不修改其他 UI 元素和函数结构。

### 3. 守卫测试

- 新增一个统计分析子模块文案守卫测试，例如：
  - `tests/statistical_analysis/ui/test_statistical_analysis_copy_guard.R`
- 守卫目标：
  - 共享文案 helper 文件存在
  - helper 中存在 6 个子模块的 copy 结构
  - 6 个子模块已 `source()` 共享文案 helper
  - 关键 `app_card_note()` 已改为读取 `copy$...`
- 守卫不校验具体中文句子，避免后续正常润色导致测试脆弱。

### 4. TDD 顺序

1. 先新增统计分析子模块文案守卫测试并确认失败
2. 新建 `stat_analysis_submodule_copy.R`
3. 接入 6 个子模块并替换 `app_card_note()`
4. 执行守卫测试与现有统计分析 UI 测试
5. 同步更新文档与测试索引

## 文档同步

- `PROJECT_GUIDE.md`
  - 记录统计分析子模块说明文案已开始收口到共享源
- `PROJECT_SPEC.md`
  - 扩展前端共享文案边界说明
- `CODE_STYLE.md`
  - 约定统计分析子模块的 `app_card_note()` 优先复用共享文案
- `TEST_GUIDE.md`
  - 增加统计分析子模块文案守卫测试条目

## 风险与缓解

- 风险：`cox/logistic/linear` 的 copy key 命名不统一，后续新增模块时难以继承。
- 缓解：统一采用 `intro / section_xxx` 或等价的稳定键模式，不用整句命名。
- 风险：守卫测试若绑定完整中文句子，后续润色成本高。
- 缓解：守卫只检查共享结构和引用方式，不检查全文字面一致性。
- 风险：共享文案范围扩得太快，影响本轮稳定性。
- 缓解：仅覆盖 `app_card_note()`，标题、tooltip 和 helpText 暂不纳入。
