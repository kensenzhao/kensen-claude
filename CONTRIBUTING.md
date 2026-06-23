# 贡献指南 · kensen-claude 市场

本仓库是一个 **Claude Code 插件市场**,会持续收录多个插件。这份文档定一套**所有插件通用**的约定:目录怎么放、文档怎么写、版本怎么发。新增插件照着做,根 README 只需多一行,**加插件零返工**。

> 用户怎么安装/使用看 [根 README](README.md) 与各插件自己的 README;这份文档是给**维护者/贡献者**的。

---

## 1. 目录约定

> **起新插件最快方式**:`bash new-plugin.sh <name> "一句话描述"` —— 自动生成下面整套骨架(plugin.json/README/CHANGELOG/test.sh/release.sh,按本规范预填)并注册进 `marketplace.json`,你只需填空。手动建也行,照下面结构来。

每个插件**自包含**在 `plugins/<name>/` 下:

```
plugins/<name>/
├── .claude-plugin/plugin.json   # 必需:name / version / description / keywords
├── commands/ agents/ skills/ hooks/   # 按需:插件的能力组件
├── README.md                    # 必需:该插件的用户文档(结构见 §2)
├── CHANGELOG.md                 # 必需:该插件的版本史(SemVer)
├── test.sh                      # 推荐:回归套件(自带 fixture,不依赖外部)
└── release.sh                   # 推荐:发布护栏(见 §4)
```

注册到市场:在根 `.claude-plugin/marketplace.json` 的 `plugins[]` 加一条
`{ "name": "<name>", "source": "./plugins/<name>", "description": "<一句话>" }`,
并在 [根 README](README.md) 的"收录的插件"表加一行(指向 `plugins/<name>/`)。

> `source` 的相对路径从**仓库根**解析,不是从 `.claude-plugin/`。

---

## 2. 文档规范(治"啰嗦 vs 粗糙"的关键:分层,最多 2 层)

文档遵循**渐进式披露**——根是第 1 层、插件 README 是第 2 层,**不再往下套第 3 层**(NN/g:超过 2 层可用性骤降)。各层职责严格切分,**靠链接而非复制**(单一真相源):

| 内容 | 只写在 | 不写在 |
|---|---|---|
| 市场是什么、`marketplace add`、开启自动更新、缓存机制(**所有插件共用**) | 根 README | 插件 README(顶部一句话链回即可) |
| 插件目录表(名/一句话/版本/链接) | 根 README | —— |
| 某插件干什么、用法、命令清单、FAQ、配置 | 插件 README | 根 README(只放一句话 teaser + 链接) |
| 某插件版本史 | 插件 `CHANGELOG.md` | —— |
| 通用发布/贡献流程 | 本文件 | 各插件(引用本文件即可) |

**唯一允许的重复**:插件 README 的安装小节可重列 `add/install/reload` 三行——因为有人会从市场列表**直达** `plugins/<name>/`,该页要能自给自足。别为 DRY 洁癖牺牲落地可用性。

**每个插件 README 的推荐骨架**(由浅入深,新手停在顶部、老手钻折叠区):
```
# <插件名>
> 一句话:它解决什么(给谁、什么场景)
## 它帮你做什么        — 3 条好处,大白话
## 安装(3 步)         — add / install / reload,复制即用
## 第一次使用          — 手把手:你说什么 → AI 做什么 → 产出什么
## 命令与用法清单       — 斜杠命令 / 技能话术 / 终端脚本,可查全
## 常见问题            — 新手真正担心的(没反应?会变慢/花钱?)
## 进阶(<details> 折叠) — 原理、边界、手动用法
## 给维护者            — 一句话 + 链到 ITERATING / playbook
```

---

## 3. 版本与 CHANGELOG

- **语义化版本** `MAJOR.MINOR.PATCH`:破坏性改动升 MAJOR、加功能升 MINOR、修 bug 升 PATCH。
- 版本号写在该插件 `.claude-plugin/plugin.json` 的 `version`。**光 push commit 不升 version,用户收不到更新**。
- **每插件一份 `CHANGELOG.md`**,放插件目录,新版本条目加在顶部。
- 每次发布打一个 **按插件命名空间** 的 git tag:`<name>-vX.Y.Z`(如 `knowledge-keeper-v0.4.0`),避免多插件 tag 撞车。

---

## 4. 通用发布流程

每个插件自带 `test.sh`(回归)与 `release.sh`(发布护栏)。标准闭环:

```bash
# 1. 改代码;2. 跑回归,全绿才继续
bash plugins/<name>/test.sh
# 3. 升 plugin.json 的 version;4. CHANGELOG.md 顶部加该版本条目
# 5. 提交(工作树要干净)
git commit -am "..."
# 6. 发布护栏:回归绿 + 版本未发布(tag 不存在) + CHANGELOG 有条目 + 工作树干净,
#    四校验任一不过即拒绝;先 --dry-run 再真发
bash plugins/<name>/release.sh --dry-run
bash plugins/<name>/release.sh
```

发布后同事侧让新版生效:`/plugin marketplace update kensen-claude` → `/plugin update <name>@kensen-claude` → `/reload-plugins`(或开了自动更新则启动时自动更)。

> **质量红线**:任何改动都要有对应回归用例;`release.sh` 是发布闸门,不绿不发。各插件更细的迭代/反哺方法见其 `ITERATING.md`。
