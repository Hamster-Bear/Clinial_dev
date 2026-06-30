---
phase_index: 0
status: done
created: 2026-06-18
updated: 2026-06-18
priority: 1
estimated_rounds: 4-8
depends_on: []
syncs_to:
  - PROJECT_SPEC.md
  - PROJECT_GUIDE.md
  - TEST_GUIDE.md
  - CODE_STYLE.md
---

# P0 Critical Remediation

## 目标

修复 Review 8 识别的阻断级安全、权限、数据完整性与质量门禁问题，恢复项目审计链路和上线前可信度。

## 背景

Review 8 对文档治理、认证安全、权限写操作、统计公式构造、数据删除顺序、部署密钥默认值和测试门禁做了交叉审阅。当前存在多个会影响生产安全或全量测试可信度的问题，因此作为 P0 前置修复处理。

## 范围

### 包含

- SMTP 模式下验证码不得回显到前端。
- viewer 只读成员不得执行 workspace 写操作。
- 统计公式构造必须安全引用非标准列名。
- 数据删除链路不得在数据库删除失败后留下指向丢失物理文件的元数据。
- 生产部署不得使用弱默认或占位管理员密码。
- 测试门禁失败项必须修复，并恢复 `testthat` / 索引 / 文档守卫可信度。
- DEVLOG、Review、PLAN 与主文档同步。

### 不包含

- 新增 MMRM / MI 分析链路。
- 引入组织级/项目级权限模型。
- 大规模迁移 `modules/common/` 根层文件；只修复本轮阻断问题需要触及的边界。
- 引入全新 CI 平台；本轮只修复本地门禁与文档/脚本一致性。

## 主文档影响

| 文档 | 影响章节 |
|------|----------|
| PROJECT_SPEC.md | 权限模型、认证事务、统计公式安全、部署安全边界 |
| PROJECT_GUIDE.md | 访问控制、数据删除一致性、统计分析实现、测试与质量保障 |
| TEST_GUIDE.md | 回归入口、P0 回归测试索引、门禁说明 |
| CODE_STYLE.md | 公式构造、权限写操作、删除顺序、生产密钥约束 |

## Phase 总览

| Phase | 目标 | 预估轮数 | 依赖 | 状态 |
|-------|------|---------|------|------|
| P1 | 审阅同步与失败测试 | 1 | 无 | done |
| P2 | 安全与权限 P0 修复 | 1-2 | P1 | done |
| P3 | 统计公式与数据完整性修复 | 1-2 | P1 | done |
| P4 | 部署/测试门禁/文档漂移修复 | 1-2 | P2, P3 | done |
| P5 | 全量测试、DEVLOG、提交 | 1 | P4 | done |

## P1 - 审阅同步与失败测试

### 输入条件

- Review 8 的发现已在会话审阅中确认。
- 当前工作区无旧 `TASK_STATE.md`。
- `docs/dep/plans/` 尚未存在。

### 产出

- `docs/dep/REVIEWS.md` 追加 Review 8。
- `docs/dep/PLAN.md` 恢复为仪表盘指针。
- `docs/dep/plans/P0-critical-remediation.md` 与 `docs/dep/plans/P0-tech-debt.md` 建立。
- P0 行为补充失败测试。

### 完成标准

- [x] Review 8 追加完成，且不回写历史 Review。
- [x] PLAN.md 指向本 P0 子计划和 P0 技术债 track。
- [x] SMTP 验证码不回显测试先失败。
- [x] viewer 写操作阻断测试先失败。
- [x] 非标准列名公式安全测试先失败。
- [x] 删除顺序一致性测试先失败或现有测试证明缺口。

### 边界

- 不在本 Phase 写生产修复代码。
- 不删除旧 Review / DEVLOG。

### 涉及文件

- `docs/dep/REVIEWS.md`
- `docs/dep/PLAN.md`
- `docs/dep/plans/P0-critical-remediation.md`
- `docs/dep/plans/P0-tech-debt.md`
- `tests/common/auth/`
- `tests/root/`
- `tests/statistical_analysis/regression/`
- `tests/database_manager/`

## P2 - 安全与权限 P0 修复

### 输入条件

- P1 失败测试存在并验证为红。

### 产出

- SMTP 模式与 `AUTH_DEV_SHOW_EMAIL_CODE` 行为一致。
- workspace 写操作区分 owner/editor 与 viewer。
- 认证写操作按规范走事务入口或记录明确例外。

### 完成标准

- [x] SMTP 模式不会把验证码拼入 UI 消息。
- [x] viewer 无法创建 folder、上传 dataset、删除 dataset/folder/workspace。
- [x] owner/editor 写操作仍可用。
- [x] 相关测试通过。

### 边界

- 不改变现有角色枚举。
- 不新增组织级或 dataset 级权限模型。

## P3 - 统计公式与数据完整性修复

### 输入条件

- P1 失败测试存在并验证为红。

### 产出

- Linear/Cox/ANOVA/Forest 公式构造安全引用列名。
- 删除链路优先保证数据库与物理文件一致性，可通过补偿或顺序调整实现。
- Logistic facet Event/N 口径修复或测试按真实契约更新。

### 完成标准

- [x] 非标准列名 `Age (years)`、`PFS-month` 可建模。
- [x] 恶意列名不触发任意公式求值。
- [x] 数据库删除失败时不会删除物理文件，或会留下可恢复补偿记录。
- [x] Logistic facet Event/N 测试通过且符合 AMA/表格口径。

### 边界

- 不重写统计分析架构。
- 不改变已验证的 AMA P 值格式口径，除非现有代码违反规范。

## P4 - 部署、测试门禁与文档漂移修复

### 输入条件

- P2/P3 相关测试通过。

### 产出

- 生产 Compose / 发布脚本阻止弱默认密码和占位管理员密码。
- `USAGE.md`、`DEPLOY_GUIDE.md`、`TEST_GUIDE.md` 与实际脚本一致。
- 空壳 layout guard 转成有效 `test_that()` 或明确跳过原因。
- 旧文档名与端口漂移修复。

### 完成标准

- [x] Compose 与部署脚本配置校验通过。
- [x] 文档守卫测试通过。
- [x] 测试索引校验通过。
- [x] 主文档一致性检查无冲突。

### 边界

- 不新增远端 CI。
- 不引入 renv 锁定，除非全量测试要求。

## P5 - 全量测试、DEVLOG、提交

### 输入条件

- P1-P4 完成标准均已通过。

### 产出

- 全量 testthat 回归通过。
- `docs/dep/DEVLOG-R001-R040.md` 追加 R004。
- `docs/dep/TASK_STATE.md` 删除。
- Git commit 创建。

### 完成标准

- [x] 全量测试 0 退出码通过；临时 hard-exit runner 结果 `FAILURE_COUNT=0 TOTAL=101 NONZERO_EXIT_COUNT=0`。
- [x] DEVLOG R004 记录文件、测试、问题与下一步。
- [x] `git status` 只包含本轮预期变更。
- [x] commit 成功。

## 执行中发现

| 编号 | 类型 | 来源 | 描述 | 处理 |
|------|------|------|------|------|
| D1 | 阻断 | Review 8 | SMTP 模式验证码可能回显 | P2 |
| D2 | 阻断 | Review 8 | viewer 可能执行写操作 | P2 |
| D3 | 阻断 | Review 8 | 公式拼接未安全引用列名 | P3 |
| D4 | 阻断 | Review 8 | 删除顺序可能造成元数据指向丢失文件 | P3 |
| D5 | 阻断 | Review 8 | 生产部署弱默认/占位密码 | P4 |
| D6 | 阻断 | Review 8 | 测试门禁与文档守卫失败 | P4 |
| D7 | 环境债 | 全量测试 | 普通 R 进程加载新版 `cli`/`rlang` 后正常卸载退出 `-1073741819` | 临时 hard-exit runner 验证通过；后续依赖锁/环境修复进入技术债 |
| D8 | 中风险 | Review 8 | Forest raw-data P 值未完全复用 AMA 口径 | fixed |
| D9 | 中风险 | Review 8 | 部分认证写操作未统一走事务边界 | fixed |

## 关键决策记录

- 2026-06-18：阻断问题集中进入独立 P0 子计划；非阻断问题进入 `P0-tech-debt.md`。
- 2026-06-18：101 个 `test_*.R` 文件全量 hard-exit 枚举结果 `FAILURE_COUNT=0 TOTAL=101 NONZERO_EXIT_COUNT=0`；`tests/check_test_guide_index.R` hard-exit 校验退出 0。
