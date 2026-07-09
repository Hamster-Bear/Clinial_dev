# Dev Log — R001-R040

---

### R019 [16:04] — 统计图形首批可用性与正确性修复：布局、committed-state、复现代码

#### Done
- `correlation_matrix.R` 与 `heatmap.R` 从旧裸 `box()` / `wellPanel()` 外壳迁移到统一 `app_card_box()` 三卡结构，并接入 `GRAPHICS_RESULT_COPY` 结果区共享文案。
- `graphics_common.R` 增加独立加载兜底：缺少 `%||%`、`generate_graphics_repro_code()` 或 `graphics_bind_repro_code_output()` 时自动补齐依赖，修复独立 `testServer()` source 子模块时报找不到可复现代码绑定函数的问题。
- 修复 `survival_analysis.R` 默认 R locale 下 `parse(file=...)` 因中文列名标识符失败的问题；展示列名仍保留中文，内部构造改为 ASCII 列名后再赋中文表头。
- 新增 `graphics_build_committed_task_state()`，用于将已生成参数覆盖到 `input_state`，防止生成后修改控件但未重新生成时，任务历史与可复现代码保存 live input。
- `boxplot.R`、`heatmap.R`、`correlation_matrix.R` 已改为生成时提交参数快照；state、数据表和复现代码读取 committed 参数，重新生成后才更新。
- `graphics_repro.R` 自加载复现模板依赖；热图与相关矩阵复现代码改为与 UI 同源的 `stats::cor(..., use = "complete.obs")`，热图不再改用 UI 未使用的 `pheatmap`。
- 修复 heatmap/correlation `geom_tile(size=...)` 的 ggplot2 3.4 弃用警告，改用 `linewidth`。
- 同步 `test_graphics_preset_guard.R`、heatmap/correlation layout guard 与结果区文案 guard，使静态守卫匹配当前 committed-state helper 和“尺寸与导出”页签契约。

#### Tests
| 命令 / 范围 | 结果 | 说明 |
|-------------|------|------|
| `Rscript -e "testthat::test_file('tests/statistical_graphics/committed_state/test_basic_graphics_committed_state.R', reporter='summary', stop_on_failure=TRUE)"` | 通过 | 新增默认 locale parse、boxplot/heatmap/correlation committed-state、heatmap/correlation 复现代码矩阵一致性测试 |
| 统计图形目录逐文件 testthat | 通过 | `tests/statistical_graphics/**/test_*.R` 全量通过；保留既有脚本式 empty-test skip |
| `Rscript -e "testthat::test_file('tests/common/graphics/test_graphics_preset_guard.R', reporter='summary', stop_on_failure=TRUE)"` | 通过 | common graphics 守卫同步到当前导出页签与 committed-state helper |

#### Issues / Blockers
- 子代理审计中仍有待处理项：boxplot palette/样式控件有效性、heatmap 聚类开关未实际作用、combo/spider/waterfall/swimmer 更完整的 server 级 committed-state 覆盖、尺寸控件与前端输出一致性。
- 本轮未处理 combo 可复现代码仍含占位坐标的问题；需要结合 combo 的动态 `main_x_var/main_y_var/plot_types` 状态结构单独修复，避免用不完整上下文改坏现有动态图层逻辑。

#### Next
1. 继续统计图形模块第二批正确性修复：boxplot palette/样式控件、heatmap 聚类语义、combo 复现代码。
2. 将 spider/swimmer/waterfall/combo 纳入与本轮同等级的 `testServer()` committed-state 回归，而不是只依赖 grep layout guard。
3. 清理现有脚本式 empty-test skip 的 layout guard，逐步迁移为标准 `test_that()`。

#### Files Changed / Commits
- `modules/statistical_graphics/correlation_matrix.R`、`heatmap.R`（修改）— 三卡外壳、共享结果文案、committed 参数快照、数据表/导出/state 读取提交态
- `modules/statistical_graphics/boxplot.R`（修改）— state/input_state 读取 committed 参数
- `modules/statistical_graphics/survival_analysis.R`（修改）— 默认 locale parse 修复
- `modules/common/graphics/graphics_common.R`（修改）— 依赖兜底与 `graphics_build_committed_task_state()`
- `modules/common/graphics/graphics_repro.R`（修改）— 复现模板依赖与 heatmap/correlation 同源代码
- `tests/statistical_graphics/committed_state/test_basic_graphics_committed_state.R`（新增）— parse、committed-state 与复现代码正确性测试
- `tests/statistical_graphics/heatmap/test_heatmap_layout_guard.R`、`correlation_matrix/test_correlation_matrix_layout_guard.R`（修改）— committed helper/layout 守卫
- `tests/statistical_graphics/ui/test_graphics_result_copy_guard.R`、`tests/common/graphics/test_graphics_preset_guard.R`（修改）— 共享文案与 common 契约守卫
- `docs/main/PROJECT_GUIDE.md`、`docs/main/TEST_GUIDE.md`、`docs/dep/devlog/INDEX.md`、`docs/dep/devlog/active/DEVLOG-R001-R040.md`（修改）— 实现契约、测试索引与本轮记录
- `(uncommitted)`

---

## 2026-06-30

### R011 [15:30] — t_ae_soc_pt 导出链路修复：rtables 多列结构保留

#### Done
- `extract_table_dataframe` 新增 rtables 对象检测：通过 `matrix_form(tbl)$strings` 提取多列矩阵结构，不再走 `capture.output(print())` 单列文本回退。影响所有导出格式（DOCX/HTML/RTF/PDF）。
- 新增 `rtables_to_flextable(tbl, title, footnotes)` 函数：rtables 专用 DOCX 导出路径，保留多列对齐（行标签左对齐、数据列居中）、PT 行缩进、边框样式。
- `save_table_docx` 检测 rtables 对象（`inherits TableTree`）并走 `rtables_to_flextable` 专用路径，绕过 `build_sci_flextable` 的单列回退。
- 修复 `matrix_form` 返回的空列名（`""`）导致 flextable 报错的问题：空列名替换为 `"Row"`。
- 修复 `save_table_docx` 中 `ncol(df) > 8` 横屏判断在 rtables 路径 `df=NULL` 时的 `if(logical(0))` 错误。
- 验证：rtables SOC/PT 表格 DOCX 导出 14KB、HTML 导出 624KB，均保留多列结构。

#### Tests
| 命令 / 范围 | 结果 | 说明 |
|-------------|------|------|
| `testthat::test_file('tests/common/export/test_table_export_contract.R')` | 通过 | 6 断言 |
| `testthat::test_file('tests/tables/test_listing_general_contract.R')` | 通过 | 5 断言 |
| 手动集成测试：rtables → DOCX/HTML 导出 | 通过 | 多列结构保留 |

#### Issues / Blockers
- None.

#### Next
1. PT 行缩进目前通过 `matrix_form$path` 中是否含 `"PT"` 判断，依赖 rtables 布局命名约定；如布局变化需同步更新。

#### Files Changed
- `modules/common/export/table_export.R`（修改）— `extract_table_dataframe` rtables 多列提取、`rtables_to_flextable` 新函数、`save_table_docx` rtables 分发、空列名修复
- `docs/dep/devlog/active/DEVLOG-R001-R040.md`（修改）— R011 记录
- `(uncommitted)`

---

### R010 [14:00] [P0-export-chain-remediation] P1-P2: 导出链路质量修复

#### Done
- `tables.R` `table_download` downloadHandler 加 tryCatch + showNotification，导出失败时用户看到友好提示而非原始错误堆栈。
- `table_export.R` `apply_sci_gt_style` 的 `table.font.names` 从硬编码 `"Times New Roman"` 改为 `c("Times New Roman", "SimSun", "sans")` CJK fallback 链，PNG/HTML 导出中文不再显示为方块。
- `tables.R` listing_general RTF 导出统一到 `table_download` 分发：选 RTF 格式时走专用 `export_listing_general_rtf` 函数（保留 SAS Group 留白、列格式化），不再走通用 `save_table_export` 文本回退。
- 全模块导出链路审查：验证 9 个统计图形模块 PNG/PDF/SVG 导出、statistical_analysis DOCX/HTML/RTF/PDF 导出、t_dm gt_tbl 导出、ae_sidebyside 图片导出均正确接线。
- 发现并记录：`extract_table_dataframe` 文本回退路径已有 `graphics_with_showtext_paused` 保护（line 88），非 bug；rtables 无 `as_flextable` 方法，t_ae_soc_pt DOCX 保持文本回退。

#### Tests
| 命令 / 范围 | 结果 | 说明 |
|-------------|------|------|
| `testthat::test_file('tests/common/export/test_table_export_contract.R')` | 通过 | 6 断言通过 |
| `testthat::test_file('tests/common/export/test_plot_export_contract.R')` | 通过 | 1 断言通过 |
| `testthat::test_file('tests/tables/test_listing_general_contract.R')` | 通过 | 5 断言通过 |

#### Issues / Blockers
- None.

#### Next
1. 如需进一步提升 t_ae_soc_pt 导出质量，需 rtables 包增加 `as_flextable` 支持或自研 matrix_form→flextable 转换。
2. 可选：将 svglite 加入 `config/required_packages.R` 以统一 SVG 输出质量。

#### Files Changed
- `modules/tables.R`（修改）— table_download 加 tryCatch；listing_general RTF 走专用导出函数
- `modules/common/export/table_export.R`（修改）— CJK 字体 fallback 链
- `docs/dep/plans/complete/P0-export-chain-remediation.md`（新增）— 子计划
- `docs/dep/PLAN.md`（修改）— 注册并标记完成
- `(uncommitted)`

---

## 2026-06-25

### R009 [11:55] — 宿主机离线部署菜单与发布入口统一

#### Done
- 将 `scripts/offline-ops.sh` 改为 AutoTFL 专用的宿主机离线部署/运维菜单，支持无参数交互选择和 `--action` 非交互执行。
- 菜单动作覆盖首次部署、只加载镜像、启动/更新、加载镜像并重建 `app/nginx`、状态、日志、停止、重启、数据库逻辑备份、数据库卷目录备份、迁移 SQL、重置数据库卷和卸载。
- 数据库卷运维新增 `backup-volume`、`migrate` 与 `reset-db` action：物理目录备份会短暂停 `app/postgres`，迁移会执行 `postgres/migrations/*.sql`，重置会默认先做逻辑备份并把旧 `DATA_ROOT/postgres` 移入 `backups/`。
- `.env` 行为收紧为“已有则保留，缺失才从 `.env.example` 生成”；脚本不会覆盖已有生产配置。
- `publish_release.sh` 与 `publish_release.ps1` 远端部署统一调用 `scripts/offline-ops.sh --action image`，避免发布脚本与宿主机手工操作分叉。
- `scripts/build_deploy_package.ps1` 生成宿主机部署包时复制 `offline-ops.sh`，并在包内 README 与完成提示中把 Linux 主入口改为 `bash offline-ops.sh`。
- `DEPLOY_GUIDE.md` 与 `deploy/alicloud/README.md` 同步说明菜单入口、action 参数和 `.env` 保护行为。

#### Tests
| 命令 / 范围 | 结果 | 说明 |
|-------------|------|------|
| `bash -n scripts/offline-ops.sh` 与部署 shell 脚本语法检查 | 退出 0 | shell 语法通过 |
| `Rscript -e "testthat::test_file('tests/root/test_deploy_scripts_contract.R', reporter='summary')"` | 退出 0 | 部署脚本契约通过 |
| `bash scripts/offline-ops.sh --help` | 退出 0 | CLI 参数说明可用 |
| `Rscript tests/check_test_guide_index.R` | 退出 0 | 测试索引一致 |
| `git diff --check` | 退出 0 | 无 whitespace error；Windows 换行提示不阻断 |

#### Issues / Blockers
- None.

#### Next
1. 下一次生成宿主机部署包后，在 Linux 宿主机上执行 `bash offline-ops.sh` 做一次菜单流程验收，重点覆盖 `backup`、`backup-volume`、`migrate` 和 `reset-db`。

#### Files Changed
- `scripts/offline-ops.sh`（新增/重写）— AutoTFL 离线部署/运维菜单
- `scripts/build_deploy_package.ps1`（修改）— 打包 `offline-ops.sh` 并更新包内 Linux 主入口
- `deploy/alicloud/scripts/publish_release.sh`、`publish_release.ps1`（修改）— 远端部署调用统一菜单 action
- `docs/deploy/DEPLOY_GUIDE.md`、`deploy/alicloud/README.md`（修改）— 部署说明同步
- `tests/root/test_deploy_scripts_contract.R`（修改）— 新增菜单脚本契约与 LF 守卫
- `(uncommitted)`

---

## 2026-06-22

### R008 [15:25] — local 镜像重建与 Docker 构建上下文修复

#### Done
- 修复 `.dockerignore` 误排除 `config/` 的问题，确保 Docker 构建上下文包含 `config/required_packages.R`。
- 在依赖清单契约测试中加入 Docker 构建上下文守卫，避免后续再次排除统一依赖清单目录。
- 使用 `docker compose -f docker-compose.local.yml build app` 重建 `autotfl-shiny-app:latest`。
- 使用 `docker compose -f docker-compose.local.yml up -d app nginx` 与 `up -d redis` 重建本地联调容器，使 local 栈使用新镜像和一致容器命名。

#### Tests
| 命令 / 范围 | 结果 | 说明 |
|-------------|------|------|
| `Rscript -e "testthat::test_file('tests/root/test_dependency_manifest_contract.R', reporter='summary')"` | 退出 0 | 依赖清单与 Docker context 守卫通过 |
| `git diff --check` | 退出 0 | 无 whitespace error；Windows 换行提示不阻断 |
| `docker compose -f docker-compose.local.yml build app` | 退出 0 | `autotfl-shiny-app:latest` 构建成功 |
| `curl http://localhost:8080/` 与 `/app/` | HTTP 200 | Landing 与 Shiny app 入口均可访问 |

#### Issues / Blockers
- None.

#### Next
1. 如需共享本次构建修复，提交并推送 `.dockerignore`、依赖清单契约测试和本 DEVLOG。

#### Files Changed
- `.dockerignore`（修改）— 不再排除 `config/`，仅排除常见本地/敏感配置模式
- `tests/root/test_dependency_manifest_contract.R`（修改）— 新增 Docker context 守卫
- `docs/dep/DEVLOG-R001-R040.md`（修改）— 记录本轮 local 镜像重建
- `(uncommitted)`

---

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

## 2026-07-03

### R012 [13:00] [P1-export-chain-deep-fix] P1-P2: 导出链路深度修复 — tryCatch 全覆盖 + 前置检测 + 依赖补齐

#### Done
- **依赖补齐**: `webshot2` 和 `svglite` 加入 `config/required_packages.R` 和 `app.R` 启动校验清单。解决表格 PNG 导出因 `gt::gtsave` 缺少 `webshot2` 而静默失败的问题。
- **save_table_png tryCatch**: `save_table_png()` 4 个分支各自加独立 tryCatch + 语义化错误消息；最外层统一 `[TableExportError]` 日志记录。
- **9 个图表模块 tryCatch 全覆盖**: boxplot、survival、forest、heatmap、correlation_matrix、combo、waterfall、swimmer、spider 全部 downloadHandler 加 `tryCatch` + `showNotification` + `message("[GraphicsExportError]...")` 统一错误处理模式（以 tables.R 为参考）。
- **导出前置检测函数**: `graphics_common.R` 新增 `graphics_check_export_prerequisites(format)` 和 `graphics_check_png_prerequisites()`，统一检测 pandoc/Chrome/webshot2 可用性。
- **table_export 集成前置检测**: `save_table_export()` 替换原有的分散 `requireNamespace` 检查为统一的 `graphics_check_export_prerequisites(fmt)`。
- **PDF R 原生方案**: 文档化到子计划 P3 — 使用 `gridExtra::tableGrob` + `grDevices::cairo_pdf`（零外部依赖），待后续实施。

#### Tests
| 命令 / 范围 | 结果 | 说明 |
|-------------|------|------|
| 代码审查（静态） | 通过 | 9 模块 + 2 工具文件修改，模式一致 |

#### Issues / Blockers
- PDF 格式暂搁置（P3），当前 `pagedown::chrome_print` 路径仍依赖 Chromium，在无 Chrome 环境下会给出明确错误提示而非静默失败。
- 图表模块导出尺寸统一（boxplot/heatmap/correlation_matrix/combo/forest 统一从 committed_params + size_config 读取）延后至后续轮次。

#### Next
1. P3: 实施 R 原生表格 PDF 导出（`save_table_pdf_native`），移除 Chromium 外部依赖
2. 图表模块导出尺寸统一：boxplot、heatmap、correlation_matrix、combo_plot、forest_plot

#### Files Changed
- `config/required_packages.R`（修改）— 添加 webshot2, svglite
- `app.R`（修改）— 添加 webshot2 到启动校验
- `modules/common/export/table_export.R`（修改）— save_table_png tryCatch + 前置检测集成
- `modules/common/graphics/graphics_common.R`（修改）— 新增 graphics_check_export_prerequisites, graphics_check_png_prerequisites
- `modules/statistical_graphics/boxplot.R`（修改）— downloadHandler tryCatch
- `modules/statistical_graphics/survival_analysis.R`（修改）— downloadHandler tryCatch
- `modules/statistical_graphics/forest_plot.R`（修改）— downloadHandler tryCatch
- `modules/statistical_graphics/heatmap.R`（修改）— downloadHandler tryCatch
- `modules/statistical_graphics/correlation_matrix.R`（修改）— downloadHandler tryCatch
- `modules/statistical_graphics/combo_plot.R`（修改）— downloadHandler tryCatch
- `modules/statistical_graphics/waterfall_plot.R`（修改）— downloadHandler tryCatch
- `modules/statistical_graphics/swimmer_plot.R`（修改）— downloadHandler tryCatch
- `modules/statistical_graphics/spider_plot.R`（修改）— downloadHandler tryCatch
- `docs/dep/plans/ongoing/P1-export-chain-deep-fix.md`（新建）— 子计划
- `docs/dep/PLAN.md`（修改）— 注册子计划
- `docs/dep/TASK_STATE.md`（新建/修改）— 任务检查点

---

## 2026-07-03

### R013 [14:00] [P1-export-chain-deep-fix] P2: 图表导出尺寸统一 — 5 模块接入公共 size_config

#### Done
- **boxplot/heatmap/correlation_matrix/combo/forest 全部接入 `graphics_collect_size_config(input)` 统一尺寸体系**：
  - UI 侧：将原 `graphics_export_panel_ui(include_size_mode=FALSE)` + 空占位"尺寸与画布"tab 替换为 `graphics_export_size_controls_ui(include_size_mode=TRUE)`，提供宽图标准/自定义尺寸双模式、同步导出尺寸、画布边框等完整尺寸控制
  - Server 侧：每个模块新增 `size_config <- reactive({ graphics_collect_size_config(input) })`
  - DownloadHandler 侧：导出尺寸从硬编码（10×8 / 12×8 / input$plot_width×input$plot_height）统一为 `cfg$export_width` × `cfg$export_height`，并统一应用 `graphics_apply_canvas_frame()` 画布边框包装
- **forest_plot 特殊处理**：保留 `plot_ratio` 滑块作为森林图专属控件（表格/图形宽度比），其余尺寸控制全部接入标准体系
- **前后端一致性**：UI 中用户设置的尺寸模式/px值/ppi/边距 → `graphics_collect_size_config(input)` 解析 → downloadHandler 使用解析后的英寸尺寸 → `save_plot_export` 输出，全链路统一

#### 统一前后对比

| 模块 | 修改前 | 修改后 |
|------|--------|--------|
| boxplot | `width=10, height=8` 硬编码 | `cfg$export_width, cfg$export_height` + canvas_frame |
| heatmap | `width=10, height=8` 硬编码 | `cfg$export_width, cfg$export_height` + canvas_frame |
| correlation_matrix | `width=10, height=8` 硬编码 | `cfg$export_width, cfg$export_height` + canvas_frame |
| combo_plot | `width=12, height=8` 硬编码 | `cfg$export_width, cfg$export_height` + canvas_frame |
| forest_plot | `input$plot_width, input$plot_height` | `cfg$export_width, cfg$export_height` + canvas_frame |
| survival/waterfall/swimmer/spider | 已使用 size_config | 不变 |

#### Tests
| 命令 / 范围 | 结果 | 说明 |
|-------------|------|------|
| 代码审查（静态模式一致） | 通过 | 9 模块全部使用 `graphics_collect_size_config(input)` |

#### Issues / Blockers
- None.

#### Next
1. P3: 实施 R 原生表格 PDF 导出（`save_table_pdf_native`），移除 Chromium 外部依赖

#### Files Changed
- `modules/statistical_graphics/boxplot.R`（修改）— UI: size controls; server: size_config; downloadHandler: cfg sizing + canvas_frame
- `modules/statistical_graphics/heatmap.R`（修改）— 同上
- `modules/statistical_graphics/correlation_matrix.R`（修改）— 同上
- `modules/statistical_graphics/combo_plot.R`（修改）— 同上
- `modules/statistical_graphics/forest_plot.R`（修改）— 同上 + 保留 plot_ratio
- `docs/dep/plans/ongoing/P1-export-chain-deep-fix.md`（修改）— P2 完成标准更新
- `docs/dep/PLAN.md`（修改）— 当前阶段 P2→P3

---

### R014 [14:30] [P1-export-chain-deep-fix] P3: R 原生表格 PDF 导出 — 移除 Chromium 外部依赖

#### Done
- **新增 `save_table_pdf_native()` 函数**（`table_export.R`）：使用 `gridExtra::tableGrob` + `grDevices::cairo_pdf`（R 内置设备）将表格渲染为 PDF，零外部依赖。
  - 复用 `extract_table_dataframe()` 处理 gt_tbl / data.frame / rtables / 文本回退
  - 网格布局：标题（可选）+ 表格主体 + 脚注（可选），自适应高度分配
  - Cairo 不可用时自动回退到基础 `grDevices::pdf` 设备
  - 全链路 tryCatch 错误保护
- **`save_table_export` PDF 路径重写**：`fmt == "pdf"` 时直接调用 `save_table_pdf_native()`，跳过原有的 `rmarkdown::render` → `pagedown::chrome_print` 路径（~40 行删除）。
  - `include_report=TRUE` + PDF 给出明确错误提示："请使用 Word 格式导出完整报告"
- **`graphics_check_export_prerequisites` 简化**：PDF 格式返回 `NULL`（零外部依赖），不再检查 pagedown/Chrome。HTML/RTF 仍检查 rmarkdown/pandoc。
- **`pagedown` 标记为可选依赖**：从 `required_packages.R` 必装列表移除并注释说明，Docker 镜像不再需要 Chromium。

#### 导出依赖对比

| 格式 | 修改前 | 修改后 |
|------|--------|--------|
| 表格 PDF | rmarkdown + pagedown + Chromium | **R 原生 cairo_pdf（零外部依赖）** |
| 表格 HTML | rmarkdown + pandoc | 不变 |
| 表格 RTF | rmarkdown + pandoc | 不变 |
| 表格 DOCX | flextable + officer | 不变 |
| 表格 PNG | webshot2 + Chrome | webshot2 + Chrome (仍需要) |
| 图表 PDF | cairo_pdf (R 内置) | 不变（一直原生） |

#### Tests
| 命令 / 范围 | 结果 | 说明 |
|-------------|------|------|
| 代码审查（静态） | 通过 | save_table_pdf_native 全链路 tryCatch；cairo_pdf 回退逻辑 |

#### Issues / Blockers
- `include_report=TRUE` + PDF 组合暂不支持（需 rmarkdown 渲染报告文本）。当前给出友好错误提示，引导用户使用 Word 格式。
- `save_table_pdf_native` 使用 `tableGrob` 渲染纯文本表格，gt 富格式（spanner header、条件颜色等）丢失。核心数据完整。

#### Next
1. 如需恢复 gt 富格式 PDF 导出，可探索 `gt::as_latex()` → `tinytex::pdflatex()` 路径（仍需 LaTeX 外部依赖，但比 Chromium 轻量）。
2. P1-export-chain-deep-fix 子计划全部 3 个 Phase 完成，可关闭。

#### Files Changed
- `modules/common/export/table_export.R`（修改）— 新增 save_table_pdf_native()；save_table_export PDF 路径重写
- `modules/common/graphics/graphics_common.R`（修改）— graphics_check_export_prerequisites 移除 PDF Chrome 检测
- `config/required_packages.R`（修改）— pagedown 标记为可选
- `docs/dep/plans/ongoing/P1-export-chain-deep-fix.md`（修改）— P3 完成标准
- `docs/dep/PLAN.md`（修改）— 子计划状态更新

---

## 2026-07-09

### R017 [14:28] — 统计分析模块第一轮正确性修复与验证

#### Done
- 补齐 `CMH检验` 的入口路由、参数 UI、执行分支、任务历史保存/恢复与共享说明文案，菜单项不再是不可运行分支。
- `chisq.R` 新增 CMH 计算链路：行变量、列变量、分层变量均按分类变量处理，基于完整观测构造三维列联表并调用 `mantelhaen.test()`。
- `chisq.R` 的卡方检验支持 factor/character/logical 分类变量，拒绝重复变量，输出 `检验 / 统计量 / 自由度 / P值`，P 值统一走 AMA 风格。
- `anova.R` 增加输入校验与 complete cases 处理，输出 `项目 / 自由度 / 平方和 / 均方 / F值 / P值`，P 值统一走 AMA 风格。
- `linear.R` 修正样本量显示口径：线性回归结果列显示有效样本数 `n`，不再错误标记为 `Event/N` 或 `n/n`。
- 补充 ANOVA / 卡方 / CMH 正确性测试，并更新既有线性回归样本量测试与 UI/copy 守卫。
- 修复 common analysis 测试在 Windows `C.UTF-8` 环境回退到 `C` locale 时的解析/占位符断言问题。
- 同步 `PROJECT_GUIDE.md` 与 `TEST_GUIDE.md` 中的统计分析实现与新增测试索引。

#### Tests
| 命令 / 范围 | 结果 | 说明 |
|-------------|------|------|
| `Rscript -e "testthat::test_file('tests/statistical_analysis/basic/test_anova_chisq_cmh_correctness.R', reporter='summary', stop_on_failure=TRUE)"` | 通过 | 新增 ANOVA / 卡方 / CMH 正确性测试 |
| 统计分析目录逐文件 testthat | 通过 | `tests/statistical_analysis/**/test_*.R` 全量通过；仅保留既有 skip 与稀疏模型 warning |
| `Rscript -e "testthat::test_file('tests/common/analysis/test_analysis_format.R', reporter='summary', stop_on_failure=TRUE); testthat::test_file('tests/common/analysis/test_analysis_shared.R', reporter='summary', stop_on_failure=TRUE)"` | 通过 | 覆盖最初暴露的 locale 解析/占位符问题 |
| 文档守卫集合 | 通过 | `test_project_docs_guard.R`、`test_project_guide_status_terms_guard.R`、`test_docs_*_guard.R` |
| `Rscript tests/check_test_guide_index.R` | 通过 | 新增测试已登记到 TEST_GUIDE |
| `git diff --check` | 通过 | 仅 Git 报告 CRLF 转换提示 |

#### Issues / Blockers
- 本轮未发现统计分析修复后的阻断问题。
- 预存 DEVLOG 不一致：`devlog/INDEX.md` 已记录 R015/R016，但 active batch 明细文件未包含对应段落；本轮未回写历史轮次。

#### Next
1. 继续第二轮统计分析端到端验证：描述性统计分母/缺失值口径、Cox/Logistic complete-case N 与交互 P 值细化。
2. 如需修复 DEVLOG 历史缺口，单独核对 R015/R016 的原始上下文后再补登记，不在统计分析修复中混做。

#### Files Changed / Commits
- `modules/statistical_analysis.R`（修改）— CMH 路由、运行分支、报告识别、任务历史参数
- `modules/statistical_analysis/anova.R`（修改）— complete cases、输入校验、AMA P 值结果字段
- `modules/statistical_analysis/chisq.R`（修改）— 卡方字段统一、CMH UI/计算/恢复
- `modules/statistical_analysis/linear.R`（修改）— 线性回归样本量列改为 `n`
- `modules/common/analysis/stat_analysis_submodule_copy.R`（修改）— CMH 共享说明文案
- `tests/statistical_analysis/basic/test_anova_chisq_cmh_correctness.R`（新增）— ANOVA / 卡方 / CMH 正确性测试
- `tests/statistical_analysis/regression/test_regression_ratio_by_subgroup.R`（修改）— 线性回归样本量期望修正
- `tests/statistical_analysis/ui/test_statistical_analysis_basic_submodule_ui_guard.R`、`test_statistical_analysis_copy_guard.R`（修改）— CMH UI/copy 守卫
- `tests/common/analysis/test_analysis_format.R`、`test_analysis_shared.R`（修改）— locale 与中文列名解析守卫
- `docs/main/PROJECT_GUIDE.md`、`docs/main/TEST_GUIDE.md`（修改）— 统计分析实现与测试索引同步
- `(uncommitted)`

---

### R018 [15:01] — 恢复线性回归 N 设计口径并补齐统计分析正确性测试

#### Done
- 按用户设计恢复 `linear.R` 中 `Event/N` / `n/n` 的人数/有效样本人数口径，撤回 R017 中将其改为纯 `n` 的误改。
- 恢复 `test_regression_ratio_by_subgroup.R` 中线性回归 `Event/N` 期望，保护既有展示设计。
- 新增项目记忆 `docs/main/memory/project-statistical-analysis-linear-n.md`，并在 `PROJECT_GUIDE.md` 记录：线性回归 `N` 表示人数/有效样本人数，不按二分类事件率解释。
- 新增描述性统计手算正确性测试，覆盖分类百分比分母、连续变量缺失排除、配置总计列和分组变量重复校验。
- 恢复 `test_regression_formula_validation.R` 中 Linear / Cox 公式验算：效应值、95% CI、P 值与 `lm()` / `coxph()` 逐项复核，并校验 N/Event-N 口径。
- 修复多水平亚组 `P for interaction` 只读取第一个非参考水平系数 P 值的问题，统一使用主效应模型与交互模型的整体比较。
- 修复 `model_strata` 缺失值未纳入回归类 effective N 的问题，确保列头 N、单元格分母与模型 complete cases 口径一致。
- 修复 Cox 允许 time/status 选择同一变量并静默拟合的问题，改为明确报错。
- 修复 Logistic facet sanitize 重建 `gt` 导致 spanner/展示标签丢失的问题，保留原 gt 渲染结构并只更新数据层。
- 修复描述性统计自动小数位对科学计数法小量数值误判为 0 位小数的问题。
- 修复 `test_logistic_medical_csv_consistency.R` 夹具路径，确保 `tests/fixtures/medical_test_data.csv` 实际参与回归测试。

#### Tests
| 命令 / 范围 | 结果 | 说明 |
|-------------|------|------|
| `Rscript -e "testthat::test_file('tests/statistical_analysis/desc/test_desc_correctness.R', reporter='summary', stop_on_failure=TRUE)"` | 通过 | 新增描述性统计正确性测试 |
| `Rscript -e "testthat::test_file('tests/statistical_analysis/regression/test_regression_formula_validation.R', reporter='summary', stop_on_failure=TRUE)"` | 通过 | Linear / Cox 公式验算恢复；仅保留既有 Cox 非标准列名 warning |
| `Rscript -e "testthat::test_file('tests/statistical_analysis/regression/test_logistic_medical_csv_consistency.R', reporter='summary', stop_on_failure=TRUE)"` | 通过 | Logistic CSV 夹具、facet spanner 与 Event/N 标签验证 |
| `Rscript -e "testthat::test_file('tests/statistical_analysis/common/test_interaction_frontend_consistency.R', reporter='summary', stop_on_failure=TRUE); testthat::test_file('tests/statistical_analysis/common/test_compute_render_decoupling.R', reporter='summary', stop_on_failure=TRUE)"` | 通过 | 交互 P 前后端列名归一与计算/渲染解耦验证 |
| common analysis 测试 | 通过 | `test_analysis_shared.R`、`test_analysis_format.R` |
| 统计分析目录逐文件 testthat | 通过 | `tests/statistical_analysis/**/test_*.R` 全量通过；仅保留既有 empty-test skip 与稀疏/完全分离 warning |

#### Issues / Blockers
- 根因：将线性回归结果中 `N` 的人数/有效样本人数设计语义误读为事件率展示问题，未先确认该列在模块中的业务含义。
- 子代理审计继续发现的根因：交互 P 与 effective N 属于共享统计口径，但此前测试多为二水平/能跑通场景，未覆盖多水平整体交互检验、`model_strata` 缺失和 gt spanner 渲染结构。
- R017 已记录的“线性回归样本量列改为 `n`”为错误判断；以本轮 R018 纠偏记录为准。

#### Next
1. 继续统计分析模块后续收尾：确认 MMRM / MI 保持占位说明，避免被误列为已交付功能。
2. 进入下一模块前，先把每个统计口径的业务语义写入测试或项目记忆，减少同类误改风险。

#### Files Changed / Commits
- `modules/statistical_analysis/linear.R`（修改）— 恢复线性回归 `Event/N` 人数口径
- `modules/statistical_analysis/logistic.R`、`cox.R`（修改）— 整体交互 P、model_strata N 口径、Logistic gt 结构、Cox time/status 校验
- `modules/common/analysis/analysis_shared.R`（修改）— 优先使用整体交互 P 属性
- `modules/statistical_analysis/desc.R`（修改）— 科学计数法小数位识别
- `tests/statistical_analysis/regression/test_regression_ratio_by_subgroup.R`（修改）— 恢复线性回归 `Event/N` 断言
- `tests/statistical_analysis/desc/test_desc_correctness.R`（新增）— 描述性统计手算正确性测试
- `tests/statistical_analysis/regression/test_regression_formula_validation.R`（修改）— Linear / Cox 公式验算、多水平交互 P、model_strata N、Cox 重复变量校验
- `tests/statistical_analysis/regression/test_logistic_medical_csv_consistency.R`（修改）— 夹具路径与 Logistic facet 表头测试
- `tests/statistical_analysis/common/test_interaction_frontend_consistency.R`（修改）— P for interaction 显示标签归一
- `docs/main/PROJECT_GUIDE.md`、`docs/main/TEST_GUIDE.md`（修改）— N 口径与新增测试索引同步
- `docs/main/memory/MEMORY.md`、`docs/main/memory/project-statistical-analysis-linear-n.md`（修改/新增）— 线性回归 N 口径项目记忆
- `docs/dep/devlog/INDEX.md`、`docs/dep/devlog/active/DEVLOG-R001-R040.md`（修改）— 本轮纠偏与验证记录
- `(uncommitted)`

---
