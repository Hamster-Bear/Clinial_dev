# 应用源码注释与阶段词巡检设计

## 目标

- 继续清理 `modules/` 等应用运行时代码中的开发过程型残留。
- 覆盖两类对象：
  - 用户可见文案中的阶段词，如“后续可”“暂时”。
  - `#` inline 注释中的过程词，如“重构版”“优化”“暂时保留”。
- 不调整业务逻辑、不扩展到 `tests/`、安装脚本或辅助脚本。

## 范围

- 处理目录：应用运行时代码，优先 `modules/`。
- 不处理目录：`tests/`、安装/下载脚本、历史清理记录之外的辅助文件。
- 文档同步：
  - `PROJECT_GUIDE.md`
  - `PROJECT_SPEC.md`
  - `CODE_STYLE.md`
  - `TEST_GUIDE.md`
  - `dev_comments_to_cleanup.md`

## 处理原则

- 用户可见文案只保留能力、结果、限制，不写演进过程。
- inline 注释只保留当前约束、数据语义、调用前提，不记录实现历史。
- 注释改写尽量中性、短句、可验证。
- 若注释内容本身仍在说明真实约束，则保留语义，只删除过程口径。

## 测试与验证

- 先扩展现有守卫，验证当前残留确实能触发失败。
- 优先复用已有守卫：
  - `tests/root/test_frontend_auth_data_copy_guard.R`
- 回归：
  - `tests/root/test_frontend_auth_data_copy_guard.R`
  - `tests/root/test_project_docs_guard.R`
  - `tests/root/test_test_guide_index_contract.R`
- 额外检查编辑后文件诊断，确保无新增错误。

## 风险

- 纯 grep 巡检可能命中用户真实限制文案，需要按“用户可见”与“源码注释”区分处理。
- 注释清理若改得过泛，可能损失局部上下文，因此本轮坚持最小改写。

## 完成标准

- 应用源码优先范围内不再保留本轮巡检命中的开发过程型用户文案与 inline 注释。
- 相关守卫与文档索引回归通过。
