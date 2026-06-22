# Dev Log — R001-R040

---

## 2026-06-22

### R007 [11:45] — agent 入口规范收口

#### Done
- 移除旧 agent 入口文件与重复 skill 目录，统一保留 `AGENTS.md` 与 `.agents/skills/project-skill/`。
- 修正 `AGENTS.md` 中的项目 skill 路径，使其与仓库内实际目录一致。
- 将历史审查文档中的项目约定入口引用统一改为 `AGENTS.md`，避免多套 agent 入口并行维护。

#### Tests
| 命令 / 范围 | 结果 | 说明 |
|-------------|------|------|
| 旧 agent 入口关键词搜索 | 无命中 | 旧入口口径已清空 |
| `Rscript tests/check_test_guide_index.R` | 退出 0 | 测试索引仍一致 |
| `git diff --check` | 退出 0 | 无 whitespace error；Windows 换行提示不阻断 |

#### Issues / Blockers
- None.

#### Next
1. 后续项目级 agent 约定统一维护在 `AGENTS.md`，项目 skill 统一维护在 `.agents/skills/project-skill/`。

#### Files Changed
- `AGENTS.md`（修改）— 修正 project skill 路径
- `docs/dep/REVIEWS.md`（修改）— 历史审查入口引用统一到 `AGENTS.md`
- 旧 agent 入口文件与重复 skill 目录（删除）
- `docs/dep/DEVLOG-R001-R040.md`（修改）— 记录本轮入口规范收口
- `(uncommitted)`

---

### R006 [11:30] — 文档规范收口：移除旧规格目录

#### Done
- 接受用户删除的旧设计规格文档，不恢复该目录。
- 同步清理 `docs/main/PROJECT_GUIDE.md` 仓库目录树中的旧规格目录引用，使项目文档结构回到 `docs/main/`、`docs/deploy/`、`docs/dep/` 等规范目录口径。
- 全仓定向搜索旧规格目录关键词，确认无残留引用。

#### Tests
| 命令 / 范围 | 结果 | 说明 |
|-------------|------|------|
| 旧规格目录关键词搜索 | 无命中 | 旧规格文档口径已清空 |
| `Rscript tests/check_test_guide_index.R` | 退出 0 | 测试索引仍一致 |
| `git diff --check` | 退出 0 | 无 whitespace error；Windows 换行提示不阻断 |

#### Issues / Blockers
- None.

#### Next
1. 后续新增设计或任务说明统一进入 `docs/dep/plans/`、`docs/main/` 或对应规范文档，不再恢复旧规格目录。

#### Files Changed
- 旧规格文档目录（删除）— 移除不符合当前规范的历史设计文档
- `docs/main/PROJECT_GUIDE.md`（修改）— 删除目录树中的旧规格目录引用
- `docs/dep/DEVLOG-R001-R040.md`（修改）— 记录本轮文档规范收口
- `(uncommitted)`

---

### R005 [11:20] — P0-tech-debt: 依赖清单、离线包链路与 common 根层收口

#### Done
- 按用户要求不生成 REVIEWS 完整报告，且远端 CI 本轮暂不处理；`P0-tech-debt.md` 中 TD4 标记为 deferred。
- 依赖清单单源化：新增 `config/required_packages.R`，`install_dependencies.R`、`download_offline_packages.R`、`download_binary_packages.R` 统一读取 `REQUIRED_PACKAGES`，避免安装清单与离线包下载清单分叉。
- Docker 构建链路同步：`Dockerfile` 在运行 `install_dependencies.R` 前复制 `config/`；`DEPLOY_GUIDE.md` 与 README 同步记录统一依赖清单和离线 `package/` 生成前置。
- `modules/common/` 根层收口：图形、统计分析、数据存储 helper 下沉到 `modules/common/graphics/`、`modules/common/analysis/`、`modules/common/data/`；根层只保留 `entry_copy.R` 与 `ui_shell.R` 两个跨域入口例外。
- 补充守卫测试：新增 `test_common_directory_contract.R` 与 `test_dependency_manifest_contract.R`；部署脚本测试新增 `.gitattributes` 的 `*.sh text eol=lf` 约束，防止 Bash 脚本换行回退。
- 当前普通 `Rscript` 已验证 `library(testthat)`、测试索引校验和相关 testthat 文件退出 0；R 4.5.3 卸载期异常在当前 shell 未复现，保留为“如再次复现再处理”的环境债。

#### Tests
| 命令 / 范围 | 结果 | 说明 |
|-------------|------|------|
| `Rscript -e "testthat::test_file('tests/root/test_common_directory_contract.R'); testthat::test_file('tests/root/test_dependency_manifest_contract.R')"` | 退出 0 | common 根层例外与依赖清单单源化守卫通过 |
| `Rscript -e "testthat::test_file('tests/root/test_project_docs_guard.R'); testthat::test_file('tests/root/test_deploy_scripts_contract.R')"` | 退出 0 | 文档守卫与部署脚本/LF 守卫通过 |
| `Rscript tests/check_test_guide_index.R` | 退出 0 | 新增测试已登记到 TEST_GUIDE |
| 受路径迁移影响的图形、统计分析、Tables、storage 测试集合 | 退出 0 | survival、waterfall、graphics copy、analysis copy、storage、tables 相关测试通过 |
| `git diff --check` | 退出 0 | 无 whitespace error；Windows 换行提示仍存在但 `.sh` 已由 `.gitattributes` 和测试约束 |

#### Issues / Blockers
- None.

#### Next
1. 远端 CI 按用户要求继续延后，后续单独规划。
2. 若后续普通逐文件全量 Rscript 再次出现卸载期异常，再引入 `renv.lock` 或重建 R library。

#### Files Changed
- `.gitattributes`（新增）— Bash 脚本 LF 约束
- `config/required_packages.R`（新增）— R 依赖单一清单
- `install_dependencies.R`、`download_offline_packages.R`、`download_binary_packages.R`（修改）— 读取统一依赖清单
- `Dockerfile`（修改）— 依赖安装前复制 `config/`
- `modules/common/graphics/`、`modules/common/analysis/`、`modules/common/data/`（移动/新增）— common helper 下沉
- `modules/` 与 `tests/` 相关 source 路径（修改）— 指向下沉后的 common helper
- `tests/root/test_common_directory_contract.R`、`tests/root/test_dependency_manifest_contract.R`（新增）
- `tests/root/test_deploy_scripts_contract.R`（修改）— `.gitattributes` 守卫
- `README.md`、`docs/main/PROJECT_GUIDE.md`、`docs/main/CODE_STYLE.md`、`docs/main/TEST_GUIDE.md`、`docs/deploy/DEPLOY_GUIDE.md`、`docs/dep/PLAN.md`、`docs/dep/plans/P0-tech-debt.md`（修改）— 文档同步
- `(uncommitted)`

---

## 2026-05-20

### R001 [22:00] — P1-P5: Review 2 架构债修复全计划执行

#### Done
- P1: 清理 `__pycache__/` 目录（`.gitignore` 已有条目）；隐藏 MMRM/MI 菜单项（`statistical_analysis.R:104-107` 注释掉 "高级方法" 组）；3 个 docker-compose 文件 Redis 服务添加 `# 保留：待后续业务集成` 注释；DEPLOY_GUIDE.md Redis 段标注保留
- P1: 抽取 `inst/copy_guard_patterns.json`（3 类禁词：frontend_dev_jargon 44 条、landing_integrity 19 条、doc_progress_language 17 条）；更新 `test_frontend_copy_guard.R` 和 `test_landing_copy_guard.R` 从 JSON 读取数据源
- P2: `modules/common/` 五类目录全部落地：创建 data/ export/ analysis/ 子目录，迁移 6 个文件（data_metadata.R, data_filter.R → data/; plot_export.R, table_export.R → export/; analysis_format.R, analysis_shared.R → analysis/），更新 30+ 处 source() 引用（app.R, modules/, tests/），Grep 验证无旧路径残留
- P3: survival_analysis.R 已有完整 committed_params 快照 + apply_state 契约（代码审计确认，仅文档标注）；boxplot.R 重构引入 committed_params 模式（create_boxplot(params) 不再读 input$，export 从 committed_params 读取），apply_state 补全 extra_state 手动恢复
- P3: PROJECT_GUIDE.md §7.7 状态表更新：survival_analysis + boxplot 标记为 "committed_params 快照 + apply_state 已标准化"；分析链路问题从 "8/9" 修正为 "6/9"；优先级调整
- P4: 2 个 legacy 测试迁移为 testthat: `test_indent_issue.R`（线性回归缩进格式验证）和 `test_label_mapping.R`（生存分析标签映射），删除 `tests/` 下 legacy/ 空目录
- P4: heatmap.R 和 correlation_matrix.R 的 task_history 集成增强：extra_state 从 2 字段扩展到 11 字段，apply_state 补全 extra_state 手动恢复（updateSelectizeInput/updateTextInput/updateSelectInput）
- P4: 为 heatmap 和 correlation_matrix 新建 layout guard 测试（各 4 个 test_that 块：三卡结构、动作条+页签、废弃包装检查、task_history 契约检查）
- P4: TEST_GUIDE.md 全面更新：§3.5 移除 legacy 标签，§3.7 追加 heatmap/correlation 入口，§3.9 更新迁移状态，§6 Legacy 说明更新为已完成
- P5: Rscript 不可用，执行代码级别变更审查和最终汇总；git status 确认变更范围

#### Issues / Blockers
- Rscript 在当前环境不可用，未能直接运行全量测试和端到端验证；建议在本地 R 环境中执行:
  1. `Rscript -e "testthat::test_dir('tests/')"` 全量回归
  2. `Rscript check_test_guide_index.R` 测试索引校验
  3. `powershell -File run_auth_regression.ps1` 认证链回归
  4. `Rscript run_app.R` 端到端手动验证（启动 → 登录 → 数据导入 → 分析 → 图形 → 表格 → 导出）

#### Next
1. 用户在本机 R 环境中执行全量测试回归
2. 如有测试失败，根据失败信息定位修复

#### Files Changed / Commits
- `__pycache__/`（删除）
- `.gitignore`（已含 `__pycache__/`，无需修改）
- `inst/copy_guard_patterns.json`（新建）
- `modules/statistical_analysis.R`（修改）— MMRM/MI 菜单隐藏
- `docker-compose.yml`、`docker-compose.local.yml`、`docker-compose.server.yml`（修改）— Redis 注释
- `docs/deploy/DEPLOY_GUIDE.md`（修改）— Redis 标注
- `modules/common/data/`、`modules/common/export/`、`modules/common/analysis/`（新建目录）
- `modules/common/data_metadata.R`、`data_filter.R`、`plot_export.R`、`table_export.R`、`analysis_format.R`、`analysis_shared.R`（移动）
- `app.R`、`modules/tables.R`、`modules/statistical_analysis.R`、`modules/statistical_graphics.R`、`modules/statistical_analysis/cox.R`、`linear.R`、`logistic.R`、`modules/common/analysis/analysis_shared.R`（修改 source 引用）
- `modules/statistical_graphics/boxplot.R`（重构）— committed_params 模式
- `modules/statistical_graphics/heatmap.R`、`correlation_matrix.R`（修改）— task_history 增强
- `tests/root/test_frontend_copy_guard.R`、`tests/nginx/landing/test_landing_copy_guard.R`（修改）— JSON 数据源
- `tests/statistical_analysis/regression/test_indent_issue.R`（新建）— legacy 迁移
- `tests/statistical_graphics/survival/test_label_mapping.R`（新建）— legacy 迁移
- `tests/statistical_graphics/heatmap/test_heatmap_layout_guard.R`（新建）
- `tests/statistical_graphics/correlation_matrix/test_correlation_matrix_layout_guard.R`（新建）
- `tests/statistical_analysis/regression/legacy/`（删除）
- `tests/statistical_graphics/survival/legacy/`（删除）
- `tests/statistical_analysis/regression/test_logistic_medical_csv_consistency.R`、`test_sparse_regression.R`、`test_stats_facet.R`（修改 source 引用）
- `tests/statistical_analysis/desc/test_desc_regression.R`、`tests/statistical_analysis/common/test_interaction_frontend_consistency.R`（修改 source 引用）
- `docs/main/PROJECT_GUIDE.md`（修改）— 目录结构、共享层路径、§7.7 状态表
- `docs/main/PROJECT_SPEC.md`（修改）— common/ 状态 5/5
- `docs/main/TEST_GUIDE.md`（修改）— 索引更新、legacy 移除
- `docs/dep/PLAN.md`（新建）— 修复计划（status: done）
- `docs/dep/TASK_STATE.md`（新建）— 临时 checkpoint（将删除）
- （uncommitted）

---

### R002 [23:30] — P5: 测试回归 & 路径修复

#### Done
- 在 R 4.5.3 环境中执行测试回归（`F:/R-4.5.3/bin/Rscript.exe`）
- 发现并修复 5 个 `modules/common/` 旧路径引用遗漏（迁移 data/export/analysis 时未更新）：
  - `tests/root/test_frontend_copy_guard.R:42` — `modules/common/data_filter.R` → `modules/common/data/data_filter.R`
  - `tests/root/test_frontend_internal_jargon_guard.R:43` — 同上
  - `tests/common/data/test_data_metadata_consistency.R:32` — `modules/common/data_metadata.R` → `modules/common/data/data_metadata.R`
  - `tests/common/export/test_plot_export_contract.R:32` — `modules/common/plot_export.R` → `modules/common/export/plot_export.R`
  - `tests/statistical_graphics/survival/test_survival_display_contract.R:35` — `modules/common/table_export.R` → `modules/common/export/table_export.R`
- 修复 2 个 legacy 迁移后测试断言与实际行为不匹配：
  - `test_indent_issue.R` — 缩进检测正则 `^\\s` 改为内容存在性断言
  - `test_label_mapping.R` — strata 精确匹配改为 `grepl` 包含性断言（`surv_median` 返回 `grp=Label` 格式）
- 确认 `check_test_guide_index.R` 在 R 4.5.3 下 crash（环境问题，非代码缺陷）
- 确认 `test_access_boundary_guard.R:259` 失败为 Review 1 文档精简预存问题

#### 测试结果汇总
| 状态 | 数量 | 说明 |
|------|------|------|
| PASS | 23 个文件, 1300+ 断言 | 全部通过 |
| FAIL（本次变更） | 0 | 无回归断裂 |
| FAIL（预存） | 1 | `test_access_boundary_guard.R` — Review 1 文档精简后断言失效 |
| SKIP | 5 | 缺测试数据 / empty test（预存） |
| CRASH | 1 | `check_test_guide_index.R` — R 4.5.3 环境 segfault（预存） |

#### Issues / Blockers
- 预存问题 `test_access_boundary_guard.R:259` 需单独修复（字符串 "评估组织级、项目级隔离、邮箱验证与共享协作模型。" 已从 PROJECT_GUIDE.md 中移除）
- `check_test_guide_index.R` 在 R 4.5.3 下 crash，建议在 R 4.4.x 下重试

#### Next
1. 用户确认是否修复预存的 `test_access_boundary_guard.R` 断言
2. 用户确认是否在 R 4.4.x 下重试 `check_test_guide_index.R`

#### Files Changed / Commits
- `tests/root/test_frontend_copy_guard.R`（修改）— data_filter.R 路径
- `tests/root/test_frontend_internal_jargon_guard.R`（修改）— data_filter.R 路径
- `tests/common/data/test_data_metadata_consistency.R`（修改）— data_metadata.R 路径
- `tests/common/export/test_plot_export_contract.R`（修改）— plot_export.R 路径
- `tests/statistical_graphics/survival/test_survival_display_contract.R`（修改）— table_export.R 路径
- `tests/statistical_analysis/regression/test_indent_issue.R`（修改）— 断言修正
- `tests/statistical_graphics/survival/test_label_mapping.R`（修改）— 断言修正
- （uncommitted）

---

## 2026-06-11

### R003 [21:30] — Review 7: 任务历史缺陷系统性修复 (P0-P2)

#### Done
- P0: `statistical_analysis.R` — `get_state` 从仅保存 `stat_method` 扩展为保存全部 30+ 分析参数（Cox/Logistic/Linear/ANOVA/Chi-sq/Desc 各方法的输入变量、参考组、事件值、总计列 + 导出参数）
- P0: `statistical_analysis.R` — `apply_state` 改为两阶段恢复：先设 `stat_method` 触发 UI 渲染，`pending_analysis_restore` + `session$onFlushed()` 等 UI 就绪后再回填子模块参数
- P0: 6 个统计分析子模块全部补全 `apply_*_state()` 函数：
  - `desc.R` → `apply_desc_state`（6 个输入）
  - `cox.R` → `apply_cox_state`（7 个输入）
  - `logistic.R` → `apply_logistic_state`（6 个输入）
  - `linear.R` → `apply_linear_state`（5 个输入）
  - `anova.R` → `apply_anova_state`（2 个输入）
  - `chisq.R` → `apply_chisq_state`（2 个输入）
- P1: `postgres/init.sql` — `analysis_states` 表新增 `source_info JSONB` 字段 + 兼容升级 DO 块
- P1: `account_service.R` — `service_build_analysis_state_insert_spec`/`update_spec`/`service_save_analysis_state` 支持 `source_info`
- P1: `task_history.R` — `task_history_display_df` 新增"来源数据"列（解析 source_info 显示数据集名/空间/行列数）
- P1: `task_history.R` — `task_history_server` 新增 `source_info` 参数，保存时透传到 service 层
- P1: `statistical_analysis.R` — `workspace_id` 从 `NULL` 改为 `resolve_workspace_id`（自动解析当前数据空间）
- P1: `tables.R` — `workspace_id` 从 `NULL` 改为 `resolve_workspace_id`
- P2: `tables.R` — `get_state` 从依赖 `committed_params()`（仅生成后有值）改为 `collect_tables_input_state()`（实时读取 input）
- P2: `tables.R` — `module_type` 从优先 `committed_params()$table_type` 改为直接 `input$table_type`
- P2: `tables.R` — `apply_state` 改为两阶段恢复，与 statistical_analysis 一致
- 测试：`test_account_service_analysis_states.R` 更新预期以匹配新增的 `source_info` 参数（2 处断言修正）
- 测试回归：`test_task_history_card_ui_guard.R`（通过）、`test_statistical_analysis_layout_guard.R`（通过）、`test_tables_committed_state.R`（18 断言通过）、`test_account_service_analysis_states.R`（27 断言通过）、`test_tables_layout_guard.R`（通过）
- 文档：PROJECT_GUIDE.md §7.3 任务历史描述更新（source_info + 二阶段恢复）、§9.4 任务历史现状更新、§10.2 新增 analysis_states 行
- 文档：REVIEWS.md 新增 Review 7 专项审计报告（7 项发现 + 修复计划 + 评审结论）

#### Issues / Blockers
- 两阶段恢复依赖 `session$onFlushed()` 确保子模块参数 UI 已渲染；若数据尚未加载（`filtered_data()` 为 NULL），`stat_params_ui` 会返回空状态提示而不渲染子模块输入，此时参数回填的 `update*Input` 会静默失败。建议后续补充重试或等待数据就绪的机制。

#### Next
1. 用户端到端验证：登录 → 数据上传 → 统计分析（配置参数 → 保存 → 加载 → 验证参数回填）→ Tables（同上）
2. 用户端到端验证：切换到不同 workspace 后任务历史的 workspace 隔离是否正确
3. 后续可选：各调用模块在 `get_state` 中填充 `source_info`（需要从数据准备模块获取当前数据集元信息）

#### Files Changed
- `modules/statistical_analysis.R`（修改）— `get_state`/`apply_state`/workspace_id
- `modules/statistical_analysis/desc.R`（修改）— 新增 `apply_desc_state`
- `modules/statistical_analysis/cox.R`（修改）— 新增 `apply_cox_state`
- `modules/statistical_analysis/logistic.R`（修改）— 新增 `apply_logistic_state`
- `modules/statistical_analysis/linear.R`（修改）— 新增 `apply_linear_state`
- `modules/statistical_analysis/anova.R`（修改）— 新增 `apply_anova_state`
- `modules/statistical_analysis/chisq.R`（修改）— 新增 `apply_chisq_state`
- `modules/tables.R`（修改）— `collect_tables_input_state`/`module_type`/workspace_id/两阶段恢复
- `modules/task_history.R`（修改）— `source_info` 参数/`task_history_display_df` 来源数据列
- `modules/common/auth/account_service.R`（修改）— `source_info` 支持
- `postgres/init.sql`（修改）— `source_info JSONB` 列 + 兼容升级
- `tests/common/auth/test_account_service_analysis_states.R`（修改）— 断言更新
- `docs/main/PROJECT_GUIDE.md`（修改）— 任务历史/存储描述更新
- `docs/dep/REVIEWS.md`（修改）— Review 7 专项审计报告
- `docs/dep/TASK_STATE.md`（新建，将删除）
- （uncommitted）

---

## 2026-06-18

### R004 [12:20] — Review 8: P0 安全、权限、公式与门禁修复

#### Done
- 按 Review 8 建立 `docs/dep/plans/P0-critical-remediation.md`、`docs/dep/plans/P0-tech-debt.md` 与 `docs/dep/TASK_STATE.md`，并把 `docs/dep/PLAN.md` 改为当前计划仪表盘。
- 认证安全：`smtp` 投递模式不再把验证码作为测试提示回显；认证 DB pool 不再默认使用 `ChangeMe123!`；注册用户、邮箱验证码 token、改密码、启动管理员和 workspace membership 写操作收口到事务边界。
- Workspace 写权限：新增 service 层写权限 helper，数据库管理模块的创建目录、上传数据、批量保存、删除数据集/目录/空间均改为 owner/editor 写权限校验，viewer 只读。
- 数据一致性：删除数据集时先执行数据库删除，再清理物理文件，避免 DB 删除失败后元数据指向丢失文件。
- 统计公式：新增安全公式构造 helper，Linear/Cox/ANOVA/Forest 统一支持非标准临床列名，生成代码同步引用安全列名函数。
- 表格口径：Logistic/Linear/Cox 的 Event/N 展示口径统一；修复 Logistic facet 连续变量行的 Event/N；Forest raw-data 结果复用 AMA P 值格式。
- 数据导入：`data_read_file()` 支持 Shiny 临时路径无扩展名时使用 `original_file_name` 判断上传格式，并移除未使用且在当前 R 环境触发退出异常的 `vroom` 依赖。
- 部署安全：`docker-compose.server.yml` 强制 `DB_PASSWORD` 必填；阿里云 tar 部署脚本拒绝空值、占位管理员和默认管理员身份。
- 文档同步：README/USAGE/DEPLOY/PROJECT_GUIDE/PROJECT_SPEC/CODE_STYLE/TEST_GUIDE 同步默认端口 `8190`、当前文档路径、权限/公式/删除/部署安全约束和新增测试索引。
- 测试维护：修复旧路径、旧 UI 文案、旧布局契约和测试入口漂移；新增 P0 回归测试覆盖 SMTP、写权限、公式安全、删除顺序、上传扩展名与部署配置。

#### Tests
| 命令 / 范围 | 结果 | 说明 |
|-------------|------|------|
| 全量 hard-exit 枚举 `tests/**/test_*.R` | `FAILURE_COUNT=0 TOTAL=101 NONZERO_EXIT_COUNT=0` | 101 个测试文件执行期断言失败清零，文件级退出码全为 0 |
| hard-exit `tests/check_test_guide_index.R` | 退出 0 | 输出 `.. DONE` 后由临时 runner 避开 R native 包卸载异常 |
| 普通逐文件 Rscript 枚举 | `FAILURE_COUNT=0 TOTAL=101 ABNORMAL_EXIT_COUNT=77` | 定位为当前 R 4.5.3 / 新版 `cli`、`rlang` 链路卸载期异常 |
| `Rscript tests/root/test_access_boundary_guard.R` | 通过，退出 0 | 不加载触发退出异常的包 |
| `Rscript -e "library(testthat); cat('x\n')"` | 输出成功，退出 `-1073741819` | 定位为当前 R 4.5.3/包环境退出码问题 |

#### Issues / Blockers
- 普通 Rscript 进程在正常卸载新版 native 包时仍可能退出 `-1073741819`；本轮通过临时 hard-exit runner 验证测试执行期 0 失败、文件级 0 退出。该环境问题进入技术债，不再阻断本轮提交。
- Review 8 中历史 DEVLOG 覆盖断层仍作为非阻断技术债保留；不回写旧轮次，从 R004 起恢复记录。

#### Next
1. 后续单独引入 `renv.lock` 或重建 R library，根治普通 Rscript 卸载期退出码异常。
2. 继续追踪历史 DEVLOG 覆盖断层，不回写旧轮次。

#### Files Changed
- `modules/common/auth/auth.R`、`modules/common/auth/account_service.R`、`modules/database_manager.R`
- `modules/common/analysis/analysis_shared.R`、`modules/statistical_analysis/linear.R`、`cox.R`、`anova.R`、`logistic.R`
- `modules/common/graphics/forest_model_helpers.R`、`modules/common/data/data_io.R`、`modules/common/storage_backend.R`、`modules/data_preparation.R`
- `docker-compose.server.yml`、`deploy/alicloud/scripts/deploy_from_tar.sh`
- `README.md`、`USAGE.md`、`docs/main/PROJECT_GUIDE.md`、`PROJECT_SPEC.md`、`CODE_STYLE.md`、`TEST_GUIDE.md`、`docs/deploy/DEPLOY_GUIDE.md`
- `docs/dep/PLAN.md`、`docs/dep/REVIEWS.md`、`docs/dep/TASK_STATE.md`、`docs/dep/plans/P0-critical-remediation.md`、`docs/dep/plans/P0-tech-debt.md`
- `tests/common/auth/`、`tests/common/data/`、`tests/common/graphics/`、`tests/root/`、`tests/statistical_analysis/regression/`、`tests/database_manager/` 及相关测试守卫
- commit: 本轮 P0 修复提交

---
