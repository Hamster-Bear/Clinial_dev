# Dev Log Index

| Round | Date | Time | Sub-plan | Phase | Summary | Files | Batch |
|-------|------|------|----------|-------|---------|-------|-------|
| R001 | 2026-05-20 | 22:00 | - | - | Review 2 架构债修复全计划执行 (P1-P5) | `inst/`, `modules/`, `tests/`, `docs/` | active/DEVLOG-R001-R040.md |
| R002 | 2026-05-20 | 23:30 | - | - | P5 测试回归与路径修复 | `tests/` (5 files) | active/DEVLOG-R001-R040.md |
| R003 | 2026-06-11 | 21:30 | - | - | Review 7 任务历史缺陷系统性修复 (P0-P2) | `modules/statistical_analysis.R`, `modules/tables.R`, `modules/task_history.R`, `postgres/init.sql` | active/DEVLOG-R001-R040.md |
| R004 | 2026-06-18 | 12:20 | P0-critical-remediation | P1-P5 | Review 8 P0 安全、权限、公式与门禁修复 | `modules/`, `docker-compose.server.yml`, `docs/`, `tests/` | active/DEVLOG-R001-R040.md |
| R005 | 2026-06-22 | 11:20 | P0-tech-debt | P2 | 依赖清单单源化、离线包链路、common 根层收口 | `config/`, `modules/common/`, `tests/`, `docs/` | active/DEVLOG-R001-R040.md |
| R006 | 2026-06-22 | 11:30 | - | - | 文档规范收口：移除旧规格目录 | `docs/main/PROJECT_GUIDE.md` | active/DEVLOG-R001-R040.md |
| R007 | 2026-06-22 | 11:45 | - | - | agent 入口规范收口 | `AGENTS.md`, `docs/dep/REVIEWS.md` | active/DEVLOG-R001-R040.md |
| R008 | 2026-06-22 | 15:25 | - | - | local 镜像重建与 Docker 构建上下文修复 | `.dockerignore`, `tests/root/test_dependency_manifest_contract.R` | active/DEVLOG-R001-R040.md |
| R009 | 2026-06-25 | 11:55 | - | - | 宿主机离线部署菜单与发布入口统一 | `scripts/offline-ops.sh`, `scripts/build_deploy_package.ps1`, `docs/deploy/` | active/DEVLOG-R001-R040.md |
| R010 | 2026-06-30 | 14:00 | P0-export-chain-remediation | P1-P2 | 导出链路质量修复：tryCatch、CJK fallback、listing RTF 统一 | `modules/tables.R`, `modules/common/export/table_export.R` | active/DEVLOG-R001-R040.md |
