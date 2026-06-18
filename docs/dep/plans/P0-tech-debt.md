---
phase_index: 0
status: in-progress
created: 2026-06-18
updated: 2026-06-18
priority: 5
estimated_rounds: 2-4
depends_on:
  - P0-critical-remediation.md
syncs_to:
  - PROJECT_GUIDE.md
  - TEST_GUIDE.md
---

# P0 Technical Debt Track

## 目标

集中追踪 Review 8 中非阻断但影响维护性、复现性或文档可信度的问题，避免它们继续散落在旧 Review 和 PLAN 叙述中。

## 当前技术债

| 编号 | 严重度 | 来源 | 问题 | 当前处理 |
|------|--------|------|------|----------|
| TD1 | medium | Review 8 | `modules/common/` 根层仍有共享文件，五类收口存在例外 | 本轮记录；后续决定迁移或在规范中明确例外 |
| TD2 | medium | Review 8 / P0 P5 | 依赖未锁定，且当前 R 4.5.3 包环境加载新版 `cli`/`rlang` 链路后普通进程卸载退出 `-1073741819` | 本轮以临时 hard-exit runner 完成门禁；后续需用 renv/依赖锁或重建 R library 根治 |
| TD3 | medium | Review 8 | 离线包链路维护风险，`package/` 缺失且下载清单可能漏包 | 已移除未使用的 `vroom` 依赖；离线链路完整性后续单独处理 |
| TD4 | medium | Review 8 | 缺少远端 CI，仅有本地 pre-commit | 本轮不新增平台，后续规划 |
| TD5 | low | Review 8 | README 仍引用旧文档名 | fixed：README/USAGE/部署文档已指向 `docs/main/`、`docs/deploy/` 当前路径 |
| TD6 | low | Review 8 | REVIEWS 历史状态格式不统一 | 不回写历史；后续新 Review 使用 `### Status:` |
| TD7 | low | Review 8 | DEVLOG 历史提交覆盖断层 | partial：不回写历史；R004 已恢复本轮严格记录 |

## Phase 总览

| Phase | 目标 | 状态 |
|-------|------|------|
| P1 | 在 P0 修复完成后清理可顺手解决的文档漂移 | done |
| P2 | 单独评估依赖锁、CI 与 common 目录迁移 | pending |

## 执行中发现

| 编号 | 类型 | 来源 | 描述 | 处理 |
|------|------|------|------|------|
| TD1-TD7 | 技术债 | Review 8 | 非阻断维护性问题 | 进入本 track |
| TD8 | 环境债 | P0 P5 | 普通逐文件 Rscript 全量枚举断言清零但 77 个进程异常退出 | mitigated：hard-exit runner 已证明测试执行期 0 失败、文件级 0 退出；保留为环境债 |
