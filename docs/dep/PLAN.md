---
updated: 2026-06-30
---

# 项目计划

## 进行中

| # | 子计划 | 文件 | 当前阶段 | 已用轮次 | 开始日期 |
|---|--------|------|----------|----------|----------|
| - | 当前无进行中子计划 | | | | |

## 待开始

| # | 子计划 | 文件 | 预估轮次 | 依赖 |
|---|--------|------|----------|------|
| - | 当前无待开始子计划 | | | |

## 最近完成

> 仅保留最近 3 条。更早的直接移除，内容已在子计划文件、主文档和 DEVLOG 中。

| 日期 | 子计划 | 文件 | 已同步到 |
|------|--------|------|----------|
| 2026-06-30 | 导出链路质量修复 | [P0-export-chain-remediation.md](plans/complete/P0-export-chain-remediation.md) | TEST_GUIDE |
| 2026-06-22 | 非阻断技术债收敛 | [P0-tech-debt.md](plans/complete/P0-tech-debt.md) | PROJECT_GUIDE, TEST_GUIDE |
| 2026-06-18 | Review 8 阻断级修复 | [P0-critical-remediation.md](plans/complete/P0-critical-remediation.md) | PROJECT_SPEC, PROJECT_GUIDE, TEST_GUIDE, CODE_STYLE |
| 2026-06-10 | 质量收敛计划（第二期） | _(历史记录，无独立子计划文件)_ | - |

## 延后

- MMRM / 多重填补分析链路 -> 属新功能开发，不纳入当前周期
- 组织级/项目级隔离 -> 需单独架构设计
- 远端 CI -> 用户确认本轮暂不处理，后续单独规划
- R 4.5.3 包正常卸载异常 -> 当前 shell 已验证通过，若复现再引入 renv.lock 或重建 R library
