# 入口层共享文案与守卫稳定化设计

## 背景

- 前一轮已完成前端用户可见文案清理，并新增 `tests/root/test_frontend_copy_guard.R` 守卫测试。
- 当前仍有 3 个历史测试失败需要收口：
  - `tests/statistical_analysis/ui/test_statistical_analysis_layout_guard.R`
  - `tests/statistical_analysis/ui/test_statistical_analysis_submodule_ui_guard.R`
  - `tests/statistical_analysis/ui/test_statistical_analysis_regression_submodule_ui_guard.R`
- 入口层文案仍分散在多个模块文件中，后续继续修改时容易重复改多处。
- `.pre-commit-config.yaml` 当前会跑整套 `testthat::test_dir('tests')`，但还没有把前端文案守卫作为独立快速闸门单独收口。

## 目标

- 修复上述 3 个现存失败测试，使其重新反映当前实现而不是历史状态。
- 为入口层模块引入轻量共享 copy helper，减少相同类型文案散落在多个文件中。
- 把 `test_frontend_copy_guard.R` 纳入 pre-commit 的独立守卫入口，尽早阻断开发向文案回流。
- 保持本轮修改聚焦于测试稳定性、文案共享和工具链补强，不扩展到业务逻辑或子模块深层重构。

## 非目标

- 不调整统计分析、统计图形、表格或探索分析模块的业务流程。
- 不扩展共享文案到统计分析子模块或统计图形子模块内部。
- 不重构现有 `auth_copy.R` 的账号与权限共享文案域。
- 不改变现有全量 `r-testthat-guards` 的总体执行方式。

## 范围

### 测试修复

- 更新 `tests/statistical_analysis/ui/test_statistical_analysis_layout_guard.R`
  - 将过时的 `app_card_panel(` 断言调整为匹配当前真实实现的结果面板 helper。
- 更新 `tests/statistical_analysis/ui/test_statistical_analysis_submodule_ui_guard.R`
- 更新 `tests/statistical_analysis/ui/test_statistical_analysis_regression_submodule_ui_guard.R`
  - 在 `source()` 统计分析子模块文件之前，先提供最小 `bsTooltip()` stub，避免模块加载阶段直接报错。

### 入口层共享文案

- 新增一个仅面向入口层的共享文案 helper 文件，收口以下模块的标题、副标题和说明文案：
  - `modules/statistical_analysis.R`
  - `modules/statistical_graphics.R`
  - `modules/tables.R`
  - `modules/exploratory_analysis.R`
- helper 只承载入口层 copy，不承载按钮文本、结果 tab 名或子模块内部说明。

### 工具链接入

- 在 `.pre-commit-config.yaml` 中新增单独的前端文案守卫 hook。
- 该 hook 只执行 `tests/root/test_frontend_copy_guard.R`，作为快速质量闸门。
- 保留现有 `r-testthat-guards`，不把本轮演变成大规模 pre-commit 重构。

## 方案对比

### 方案 A：仅修测试

- 优点：最快。
- 缺点：入口层文案仍继续散落，后续维护收益有限。

### 方案 B：修测试 + 入口层共享文案 + pre-commit 独立守卫

- 优点：范围可控，同时解决当前失败测试、重复文案和工具链缺口。
- 缺点：会多出一个共享文案文件和对应守卫测试。
- 结论：采用本方案。

### 方案 C：修测试 + 入口层与子模块一起抽文案

- 优点：共享程度更高。
- 缺点：改动面明显变大，回归成本上升，不适合作为当前收尾任务。

## 设计

### 1. 测试修复策略

- `test_statistical_analysis_layout_guard.R` 当前失败是因为测试仍断言 `app_card_panel(`，但 `modules/statistical_analysis.R` 实现已切到 `app_result_panel(`。
- 这类失败属于测试落后于实现，应优先修测试，而不是为迎合旧测试回退实现。
- 两个 `bsTooltip()` 相关失败属于测试依赖初始化顺序问题：
  - 统计分析子模块文件在 `source()` 时就会执行包含 `bsTooltip()` 的 UI 构造。
  - 测试里虽然定义了 stub，但位置在 `source()` 之后，导致来不及生效。
- 本轮应把 stub 提前到 `source()` 前，保持测试对真实 UI 结构的验证不变。

### 2. 共享文案 helper 设计

- 新文件建议放在 `modules/common/`，命名为入口层语义明确的文件，例如 `entry_copy.R`。
- 对象建议采用清晰的分模块 list 结构，例如：
  - `ENTRY_COPY$statistical_analysis`
  - `ENTRY_COPY$statistical_graphics`
  - `ENTRY_COPY$tables`
  - `ENTRY_COPY$exploratory_analysis`
- 每个入口模块只读取以下字段：
  - `title`
  - `subtitle`
  - `note`
  - 若该入口有多个顶层卡片，可再补 `cards` 子结构，但仍限定在入口层。
- 设计原则：
  - 与 `ACCOUNT_ENTRY_COPY` 职责分离，避免混入账号域文案。
  - 只收入口层 copy，不把子模块内部说明提前抽进去。
  - 不抽按钮名、tab 名和业务字段标签，避免 helper 过重。

### 3. 守卫与工具链设计

- 为入口层共享文案新增守卫测试，至少确认：
  - helper 文件存在并提供 4 个入口模块的 copy。
  - 对应 4 个模块已改为读取共享文案，而不是继续硬编码原句。
- `.pre-commit-config.yaml` 新增快速 hook：
  - 执行 `Rscript -e "testthat::test_file('tests/root/test_frontend_copy_guard.R', reporter = 'summary')"`
- 这样即使将来整套 `test_dir('tests')` 因历史测试波动，前端文案回流仍能被单独快速拦截。

## TDD 顺序

1. 先修改并执行 3 个现存失败测试，确认它们按预期失败或报出正确原因。
2. 新增入口层共享文案守卫测试，先让其失败，证明当前尚未接入共享文案。
3. 实现最小共享文案 helper，并接入 4 个入口层模块。
4. 更新 `.pre-commit-config.yaml`，并补对应契约测试或索引文档。
5. 重新执行针对性测试，确认全部转绿。

## 文档同步

- `PROJECT_GUIDE.md`
  - 补充入口层共享文案 helper 的职责边界。
- `PROJECT_SPEC.md`
  - 声明入口层共享文案源与前端文案守卫的存在。
- `CODE_STYLE.md`
  - 增补入口层共享文案应优先收口到 helper 的规则。
- `TEST_GUIDE.md`
  - 登记新的入口层共享文案守卫测试及前端文案守卫的 pre-commit 地位。

## 风险与缓解

- 风险：helper 命名和 `auth_copy.R` 过于接近，造成职责混淆。
- 缓解：用“入口层 copy”命名，明确只覆盖统计分析/统计图形/Tables/探索分析入口。
- 风险：过早把子模块内部文案一并抽出，导致本轮范围失控。
- 缓解：只收入口层文案，子模块维持现状。
- 风险：pre-commit 新增重复测试，提交耗时上升。
- 缓解：只增加单文件快速守卫，不替代也不复制整套全量测试流程。
