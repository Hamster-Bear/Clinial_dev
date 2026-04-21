# AutoTFL 代码规范 (CODE_STYLE.md)

## 1. 通用开发原则
- **字符编码**: 所有源码、文档、配置必须使用 **UTF-8** 编码。
- **文档先行**: 任何功能变更必须同步更新 `PROJECT_GUIDE.md` 和 `PROJECT_SPEC.md`。
- **测试契约**: 所有核心计算逻辑及 Bug 修复必须在 `tests/` 编写配套测试。

## 2. R 语言规范
- **命名规范**: 
  - 变量、函数、文件名统一使用 `snake_case` (例: `load_raw_data.R`)。
  - Shiny 模块 UI/Server 函数建议以模块名加 `_ui` / `_server` 后缀。
- **代码结构**: 
  - 严格执行 UI 与 Server 逻辑分离。
  - 跨模块复用的逻辑必须沉淀至 `modules/common/`，禁止模块间交叉引用。
  - 任务历史、权限管理、任务列表等跨业务复用的 Shiny 区块，应先抽为共享模块并嵌入现有业务页验证；未形成跨统计图形/统计分析稳定契约前，不应直接升级为左侧一级菜单。
  - 接入任务历史的业务模块必须显式维护 `state` / `apply_state` 契约；凡写入 `state_payload` 的图形子模块参数，应尽量提供对称的回填逻辑，目标是覆盖当前子模块全部用户可配置参数，避免“可保存不可载入”。
  - 任务历史快照仅保存业务输入；`DT`/`plotly`/输出表格产生的派生交互输入（如行选择、列过滤、relayout、hover）以及 `config_tabs` 等导航态不得写入 `state_payload`，恢复旧快照时也必须跳过这些临时字段。
  - Shiny module 的 server 端若在 `renderUI()` / `renderPlot()` / `renderPlotly()` 中动态创建 namespaced output/input，必须显式定义 `ns <- session$ns`，避免运行时出现“没有 ns 这个函数”。
  - 在 Shiny `reactive()` / `render*()` 链路中使用校验时，必须显式写成 `shiny::validate()` 与 `shiny::need()`，不要依赖裸函数名，避免被其他包的同名函数覆盖。
- **依赖管理**: 
  - 统一在入口文件及部署脚本中声明依赖。
  - 禁止在业务逻辑中直接调用 `install.packages()`。
- **代码格式化**: 
  - 缩进使用 2 个空格。
  - 推荐使用 `styler` 包进行自动格式化。
  - 提交前优先通过仓库根目录 `.pre-commit-config.yaml` 执行 `styler`、`lintr` 与 `testthat` 守卫，避免多文件改动后出现格式漂移或文档/实现不一致。
  - 注意：项目根目录的 `.lintr` 配置文件遵循 DCF (Debian Control File) 格式，如果配置项的值跨越多行，**所有换行后的内容必须至少缩进一个空格**（例如闭合括号 `)` 不能顶格写），否则会导致 lintr 解析失败并引发全局诊断错误。
- **图形与字体**: 
  - 统计图形统一启用 `showtext_auto()`（已在 `app.R` 入口初始化），确保在不同操作系统环境下字体（特别是 CJK 字符）渲染的一致性。
  - 开发新图形模块时不得硬编码具体物理字体路径；默认中文场景优先使用已注册的 `Noto Sans SC`，并允许通过 `graphics_font_family_ui()` 暴露给用户选择。
  - 字体解析需拆分为三层：`graphics_resolve_device_safe_family()` 只负责设备安全映射（如 `Arial -> sans`），`graphics_resolve_font_spec()` / `graphics_resolve_text_family()` 负责拉丁字体与中文 fallback，`graphics_resolve_layout_family()` 专门处理 `cowplot` / `grid` / `draw_label()` 这类需要先做版式测量的文本，避免把设备兼容、中文 fallback 与布局测量混在一个函数里。
  - 所有自由文本层（如 `geom_text()`、`annotate("text")`、`draw_label()`、底部 caption、自绘图例/表格文本）必须显式继承解析后的字体族；纯英文可落到拉丁字体，包含 CJK 的文本应优先落到已注册的 CJK 字体。单个文本 grob 若中英混排且不能按片段拆分，应优先使用覆盖中英字符集的统一字体；但进入 `cowplot/grid` 测量链路时必须切回 `layout_family`，不得直接把 `Noto Sans SC` 之类自定义字体名传给 `draw_label()`.
  - 图形尺寸、页面距、画布边框、参考线与前端/导出换算必须优先复用 `graphics_common.R` 和 `common_ui_shell.R`；默认保持 PX 与英寸尺寸同步，禁止在子模块私写另一套尺寸/导出容器或 `geom_hline/geom_vline` 组装逻辑。
  - 坐标范围、刻度格式、时间轴单位换算等高重复图形控件，应优先复用 `graphics_axis_range_controls_ui()`、`graphics_axis_tick_format_controls_ui()`、`graphics_time_axis_settings_ui()` 等 common UI 组件。
  - 首批图形参数抽象类统一限定为 `graphics_column_mapping_panel_ui()`、`graphics_time_axis_panel_ui()`、`graphics_export_panel_ui()` 三类；模块复用时允许字段命名不同，但不得再平行复制同语义卡片布局。

## 3. UI/UX 规范
- **样式管理**: 优先使用 `bslib` 主题变量，自定义 CSS 统一存放在 `www/` 目录下。
- **交互反馈**: 
  - 耗时操作（如模型拟合）必须配合 `withProgress` 进度条。
  - 涉及数据删除或权限变更的操作需使用通知或模态框二次确认。

## 4. 数据库与存储规范
- **SQL 编写**: 参数化查询以防止 SQL 注入。
- **存储访问**: 必须通过 `storage_backend.R` 提供的抽象接口读写数据，禁止直接拼接物理路径。

## 5. 测试规范
- **框架**: 使用 `testthat` 或配套工具。
- **目录约定**: 所有测试文件统一置于 `tests/` 目录，文件名以 `test_` 开头；`tests/` 内部优先按项目架构分层，例如 `tests/common/auth/`、`tests/statistical_analysis/`、`tests/statistical_graphics/`、`tests/root/`。
- **夹具约定**: 共享测试数据与夹具统一放在 `tests/fixtures/`。
- **测试文档约定**: 整体性测试说明统一维护在项目根目录 `TEST_GUIDE.md`，按项目架构归类；`tests/` 目录仅放测试代码、测试数据和暂未标准化的专项验证脚本。
- **执行要求**: 合并代码或发布前，确保测试套件运行通过。
- **交互状态**: 新增任务历史、状态回填或复杂 UI 交互时，至少补一条 `tests/` 守卫测试；高风险输入交互优先纳入 `shinytest2` 规划范围。
- **任务历史操作**: 新增 note、删除、覆盖保存等状态资产操作时，必须同时覆盖 service 层测试与 UI/契约守卫测试。
- **数据库集成测试**: 涉及账号、权限、workspace 隔离或持久化行为时，优先补充 PostgreSQL 集成测试；测试应通过 `.env.test` 指向测试库，并在隔离 schema 中建表和清理，禁止污染现有业务数据。
- **统一回归入口**: 账号/权限相关改动提交前，优先执行 `run_auth_regression.ps1`，确保 helper、文档守卫与 PostgreSQL 集成测试按固定顺序通过。
- **索引校验**: 调整测试目录或新增测试后，至少执行一次 `check_test_guide_index.R` 或对应守卫测试，确保 `TEST_GUIDE.md` 与 `tests/` 实际文件一致。
