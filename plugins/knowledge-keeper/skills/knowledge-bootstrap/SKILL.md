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
- **先判栈**:读根 manifest(`package.json`/`pom.xml`/`go.mod`/`Cargo.toml`/`requirements.txt`…)与目录形态,判定本仓是**后端 / 前端 / 前后端混合(monorepo)**,据此选下面对应清单。混合仓三套都走,并**额外建接缝域**(见 Phase 3)。
- 复用已有的 README/ADR/`.claude`，别推倒。
- **产出一张"域→源码路径"映射表 → 给用户确认范围后再继续。**

**找分层入口(按栈)**:
- **后端**:controller/handler/route、service、数据访问(repository/mapper/dao)、entity/model、定时任务(`@Scheduled`/cron)、MQ 消费者/生产者、中间件/拦截器、配置与启动入口。
- **前端**:路由表(router/pages/app 目录)、页面与核心组件、状态管理(store:Redux/Pinia/Vuex/Zustand/signals)、**API 客户端层**(请求封装/拦截器/SDK)、共享类型(`types.ts`/DTO)、设计系统(组件库/theme/design tokens)、hooks/composables、表单与校验、国际化、构建与环境配置(vite/webpack/next/`.env`)。
- **前后端接缝(混合仓必做)**:契约定义处——OpenAPI/Swagger、GraphQL schema、protobuf/IDL、共享 DTO 包;鉴权链路(token 怎么发怎么带);错误码/统一响应包络;分页与时间/金额等跨端约定。**这是混合仓最高价值、最易漂的知识,务必单列。**

### Phase 2 — 多 agent 并行抽取 + 对抗式审查（质量关键）
- **抽取**：每个域派一个子 agent 读真实代码，写成代码级文档(带锚定 frontmatter + `文件:行号` + `⚠️未验证`)，各写各文件。
- **对抗式审查**：每篇再派一个"怀疑论者"子 agent 抽查带行号的断言、核对源码、`sources` 是否覆盖正文；核不实即标 issue 并修。
- 顺带挖出的真实代码 bug：**只记进 landmines，不在建库流程里改代码**，单独汇报用户定夺。

### Phase 3 — 组织成两层 + landmines
- knowledge：每域一篇(套 `reference/templates/knowledge-doc.template.md`)。**混合仓额外建一篇接缝文档** `api-contract.md`(前后端契约/鉴权/错误码/分页约定),sources 同时锚后端契约定义处与前端 API 客户端层——它是前后端的"翻译官",最值得维护。
- skills：按**高频开发动作**选题(不是按模块!多数任务跨模块)。按栈选(只建本仓真实存在的链路):
  - **后端**:新增接口、新增数据访问/查询、认证鉴权、数据库迁移、定时任务/MQ 消费、构建与本地运行。
  - **前端**:新增页面/路由、新增组件、**对接后端接口**(在 API 客户端层加调用 + 类型 + 错误处理)、状态管理改动、表单与校验、国际化、构建与本地运行。
  - **混合**:端到端加一个功能(后端加接口 → 前端接调 → 打通类型/错误码)——这条贯穿接缝的 skill 对混合仓价值最高。
  每个套 `reference/templates/SKILL.template.md`。
- `landmines.md`：坑/已知 bug/环境陷阱汇总，逐条核实代码、标 `文件:行号`(前端常见坑:SSR/水合、跨域、环境变量注入、打包体积、状态竞态)。
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
2. **别把同一个热点文件塞进很多篇文档的 sources**——它一改会连带触发一批 STALE。
   注意:这针对的是"被多篇当**示例**引用的文件",不是"不许给共享文件建文档"。前端的 `api/client.ts`、`types.ts`、`theme.ts`/design tokens 恰恰是高价值知识源,**应当**由一篇专属文档(如接缝文档/设计系统文档)owns 它并锚定;只要别让它再出现在其它文档的 sources 里即可。

完整方法论见 `reference/playbook.md`。
