---
name: knowledge-bootstrap
description: 给当前项目从零自举一套 AI 知识体系(.claude/knowledge + .claude/skills,带源码锚定 frontmatter)。当用户想"给本项目建知识库/skills""让 AI 精通这个项目""按 playbook 建库""onboard 这个 codebase"时使用。漂移检测与 Stop hook 由 knowledge-keeper 插件自带,本技能只负责产出内容文档。
---

# knowledge-bootstrap — 给项目自举知识体系

把一个陌生/无文档的项目，建成"AI 一上来就懂"的状态。**机制(漂移检测+Stop hook)由 knowledge-keeper 插件提供，你不用装脚本/改 settings**——本技能只管产出**内容**。

## 两条铁律（违反则前功尽弃）

1. **分层**：`skills = 怎么做`(程序性、自动触发)，`knowledge = 是什么/为什么`(参考、按需读)。别混。
2. **准确性纪律**：只基于**实际读到的代码**写，**禁止凭记忆/猜测**；关键断言标 `文件:行号`；拿不准标 `⚠️未验证`；**宁缺毋编**。

## 流程（按序执行）

### Phase 1 — 测绘（先摸地形，产出"域→源码路径"表给用户确认）
- 模块/包结构(`find . -maxdepth 3 -type d`、读 build 文件)、各模块规模、`git log` 看活跃区。
- 找分层入口：controller/handler/route、service、数据访问、entity/model。
- 复用已有的 README/ADR/`.claude`，别推倒。
- **产出一张"域→源码路径"映射表 → 给用户确认范围后再继续。**

### Phase 2 — 多 agent 并行抽取 + 对抗式审查（质量关键）
- **抽取**：每个域派一个子 agent 读真实代码，写成代码级文档(带锚定 frontmatter + `文件:行号` + `⚠️未验证`)，各写各文件。
- **对抗式审查**：每篇再派一个"怀疑论者"子 agent 抽查带行号的断言、核对源码、`sources` 是否覆盖正文；核不实即标 issue 并修。
- 顺带挖出的真实代码 bug：**只记进 landmines，不在建库流程里改代码**，单独汇报用户定夺。

### Phase 3 — 组织成两层 + landmines
- knowledge：每域一篇(套 `reference/templates/knowledge-doc.template.md`)。
- skills：按**高频开发动作**选题(不是按模块!多数任务跨模块):新增接口/数据访问/认证/数据库迁移/构建运行等。每个套 `reference/templates/SKILL.template.md`。
- `landmines.md`：坑/已知 bug/环境陷阱汇总，逐条核实代码、标 `文件:行号`。
- 建 `index.md`：landmines 必读 + skills 速查表。

### Phase 4 — (可选) GAP 配置
- 若想让漂移脚本也检测"哪个业务模块没文档覆盖"，在项目根建 `.claude/knowledge-drift.config`，每行一个业务模块 glob(如 `src/*`、`services/*`)。不建则只做 STALE 检测。

### Phase 5 — 验证 + 移交
- 确认每篇文档 frontmatter 有 `sources`(窄而准) + `verified_at`(当前 `git rev-parse --short HEAD`)。
- 漂移机制即刻生效(插件 Stop hook 会在会话结束自动检测)。
- 此后维护交给 `skill-maintenance` 技能。

## 锚定 frontmatter 规范

```yaml
---
name: <kebab-case>
description: <覆盖什么 / 何时读或触发>
sources:          # 只列推导来源的代码路径(相对仓库根),窄而准；不要列其它文档
  - path/to/domain/**
verified_at: <短 git SHA>
---
```

## 两条 sources 铁律（实战教训）
1. `sources` **只列代码，绝不列另一篇文档**(否则那篇一更新就连带误报)。
2. 慎列"热点宽文件"(被很多文档当示例的大类)——它一改会触发一批 STALE。

完整方法论见 `reference/playbook.md`。
