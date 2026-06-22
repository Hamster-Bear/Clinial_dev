---
status: done
created: 2026-06-18
updated: 2026-06-22
---

# AutoTFL 计划仪表盘

## 进行中

| 子计划 | 当前 Phase | 优先级 | 状态 | 说明 |
|--------|------------|--------|------|------|
| - | - | - | 当前无进行中子计划 |

## 待开始

| 子计划 | 优先级 | 依赖 | 说明 |
|--------|--------|------|------|
| - | - | - | 当前无其他待开始子计划 |

## 最近完成

| 子计划 | 完成日期 | 说明 |
|--------|----------|------|
| [P0-critical-remediation.md](plans/P0-critical-remediation.md) | 2026-06-18 | Review 8 阻断级安全、权限、数据一致性、部署与测试门禁修复完成；全量 hard-exit 门禁 0 退出 |
| [P0-tech-debt.md](plans/P0-tech-debt.md) | 2026-06-22 | 除远端 CI 外的 Review 8 非阻断技术债已收敛：依赖清单单源化、离线包链路守卫、common 根层例外收口 |
| AutoTFL 质量收敛计划（第二期） | 2026-06-10 | combo_plot / 文档 / Tables 质量收敛已在历史 PLAN 与 Review 6/7 中记录 |

## 延后

| 项目 | 来源 | 说明 |
|------|------|------|
| MMRM / 多重填补分析链路 | PROJECT_SPEC.md §5 | 属新功能开发，不纳入本轮 P0 |
| 组织级/项目级隔离 | PROJECT_SPEC.md §5 | 需单独架构设计 |
| 远端 CI | Review 8 | 用户确认本轮暂不处理，后续单独规划 |
| R 4.5.3 包正常卸载异常 | P0-critical-remediation.md P5 | 当前 shell 中普通 `Rscript` 已验证 `library(testthat)`、索引校验与索引契约测试退出 0；若后续全量普通枚举再次复现，再引入 `renv.lock` 或重建 R library |
