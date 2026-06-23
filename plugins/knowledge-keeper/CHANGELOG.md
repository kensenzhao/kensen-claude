# Changelog · knowledge-keeper

遵循语义化版本。每次发布由 `release.sh` 校验(回归全绿 + 版本已升 + 本文件有对应条目 + 工作树干净)后打 tag `knowledge-keeper-vX.Y.Z`。

## [0.4.0] — 全栈利器化

**机制修复(防误报 / 健壮 / 性能)**
- glob 收口:`source: src` 不再误匹配兄弟目录 `srcfoo`(裸前缀过匹配是 STALE 误报源)。
- `**` 含零层目录(`a/**/b` 匹配 `a/b`);尾部单 `*` 不跨目录。
- 浅克隆缺失 `verified_at` 的 SHA 时静默,不刷屏"锚点异常"。
- 按 `verified_at` 分组缓存 git diff(多篇同 SHA 只 diff 一次)。
- `--report` 的 GAP 措辞区分"已配/无缺口" vs "未配/跳过"。
- 回归套件 11 → 19 条(每个修复留用例)。

**前端 / 混合开发内容化**
- `knowledge-bootstrap` 测绘与选题分栈(后端 / 前端 / 前后端接缝)。
- 混合仓新增一等公民 `api-contract` 接缝文档约定。
- "慎锚热点宽文件"铁律改为分语境(前端共享契约文件应锚)。
- 模板补前端示例;README/playbook 点明栈无关 + 检测时机 + GAP 粒度。

**工程**
- 新增 `CHANGELOG.md` 与 `release.sh` 发布护栏。
- README 重排为同事优先(前置要求 / 安装 / quickstart / FAQ)。
- 本仓库吃自己狗粮:`.claude/knowledge` + `.claude/skills` 锚定知识库。

## [0.3.0] — 让位护栏
- 项目自带漂移脚本(`scripts/check-knowledge-drift.py` 等)时,插件 Stop hook 自动退让 exit 0,避免双触发 + 抢同一 `.drift-state`。

## [0.2.0] — 迭代工具包
- 健康报告 `--report`(新鲜度 + 覆盖度)。
- 回归测试套件 `test.sh`。
- 迭代/反哺指南 `ITERATING.md`。

## [0.1.0] — 初版
- kensen-claude 市场 + knowledge-keeper 插件:确定性漂移检测 + 安静 Stop hook + 维护技能 + 一键 bootstrap。
