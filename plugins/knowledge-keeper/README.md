# knowledge-keeper

> 让 Claude 真正"懂"你的项目,而且这份理解会随代码自动更新、不会过时。
> 后端、前端、前后端混合项目都能用,装好基本不用管。

<sub>本插件随 [kensen-claude](../../README.md) 市场分发。开启自动更新等市场级说明见根 README。</sub>

## 它帮你做什么

不用每次重新跟 AI 解释项目;AI 按你项目的**真实写法**干活;代码一改,自动提醒你哪份说明书过时了——而且全程本地脚本,**不花 token**。

- 📖 **给 AI 一本项目说明书** —— 项目是什么、怎么写、有哪些坑,每条都标了出自**哪个文件第几行**,可核对、不瞎编。
- 🛠 **干活自动照你项目的规矩来** —— 比如"新增接口""加页面",用你项目的真实套路,不是教科书写法。
- 🔄 **代码变了自动盯说明书** —— 提交后算出哪页可能过时,对话结束**轻提醒一次**,不用你记着更新。

> 和 `CLAUDE.md` / wiki 最大的不同:那些**烂了你不知道**;它会**自动发现并告诉你**哪里该更新。

---

## 📥 安装(3 步,复制即用)

> 需要本机有 `python3` 和 `git`(基本都有)。仓库公开,不用登录。

```
/plugin marketplace add kensenzhao/kensen-claude
/plugin install knowledge-keeper@kensen-claude
/reload-plugins
```

💡 想让插件以后自动更新?设置方法见根 README 的「🔄 保持更新」([../../README.md](../../README.md))。

---

## ✨ 第一次使用

在你的项目里打开 Claude Code,对它说:

> 按 knowledge-bootstrap 给本项目建知识体系

它会自动:摸清项目结构 → 给你一张"功能 → 代码"表让你**确认范围** → 读真实代码写说明书(还会派"找茬分身"核对防写错)→ 生成到 `.claude/` 文件夹:

- `.claude/knowledge/` —— 项目说明书(是什么 / 为什么 / 坑)
- `.claude/skills/` —— 操作指南(某类活怎么干,AI 自动用)

最后把这些文件**提交进你的项目仓库**就好。之后自动生效,你正常写代码即可。

> 📌 不用装脚本、不用改配置,检测和提醒的"机器"都在插件里了。

---

## 🔄 之后基本全自动

| 什么时候 | 它做什么 | 你做什么 |
|---|---|---|
| 你提交代码后 | 自动更新受影响的说明书 | 一般不用管 |
| 对话快结束 | 发现可能过时就**提醒一句** | 看一眼,需要就让它改,不相关就忽略 |
| 你纠正 AI | 把纠正记进说明书,下次不再错 | 直接说「不对,我们其实是 X」 |

> 提醒只在 `git commit` 之后出现,同一问题**只提醒一次**。

---

## 📋 怎么用这个插件

> 安装见上方「📥 安装」;更新插件见 根 README 的「🔄 保持更新」一节(见 [../../README.md](../../README.md))。
> 下面是 knowledge-keeper **自己**的用法——主要靠"跟 AI 说话",脚本是可选的。

### 🗣 跟 AI 说的话(主要用法,你 90% 的时间就用这三句)
| 你说什么 | AI 会做什么 |
|---|---|
| `按 knowledge-bootstrap 给本项目建知识体系` | 读真实代码,生成项目说明书 + 操作指南到 `.claude/knowledge` 和 `.claude/skills` |
| `用 skill-maintenance 同步` | 核对代码、更新过时的说明书,并标记为"已核对到最新" |
| `不对,本项目其实是 …`(随口纠正) | 把你的纠正记进对应说明书,下次不再错 |

> 这两个是**技能**,自然语言触发——直接把上面的话说给 AI 即可,**不是斜杠命令**。

### 💻 在终端跑的脚本(可选,想手动检查时才用)
插件装在 `~/.claude/plugins/cache/kensen-claude/knowledge-keeper/<版本>/scripts/`(`<版本>` 形如 `0.4.0`)。在**你的项目根目录**跑:

| 命令 | 作用 |
|---|---|
| `python3 <上面路径>/check-knowledge-drift.py` | 立刻检测有没有说明书过时(退出码 `0`=没事 / `3`=有) |
| `python3 <上面路径>/check-knowledge-drift.py --report` | 打印**健康报告**:几篇可能过时、哪些模块还没文档覆盖 |

### ⚙️ 配置文件(可选)
在项目根建 `.claude/knowledge-drift.config`,每行写一个模块路径(如 `src/*`、`apps/*`),即可额外检查"哪个模块还没有任何说明书覆盖"。

---

## ❓ 常见问题

**装了没反应?** 正常——要么这项目还没建过说明书,要么你的改动**还没提交**(它只看已提交的)。

**提醒老不消失?** 说明书改完没标记"已核对到最新"。让 AI「用 skill-maintenance 同步」会自动处理好。

**会拖慢我 / 偷偷花钱吗?** 不会。没漂移时完全安静、零 token(纯本地 `git` + `python3`)。

**作者发了新版没生效?** 开了自动更新就会启动时自动更;没开就手动更新——见 根 README 的「🔄 保持更新」一节(见 [../../README.md](../../README.md))。

---

## 🔧 进阶(需要时再看)

<details>
<summary><b>它怎么发现"说明书过时"的?(一分钟看懂)</b></summary>

每篇说明书记了"根据哪些源码写的"和"上次核对时的代码版本"。对话结束时用 `git` 比一下这些源码改了没:改了→提醒,没改→安静。全程不调 AI,所以又快又免费。**检测**(自动)和**修改**(AI 核对后才动手)分开,不会乱改。
</details>

<details>
<summary><b>团队项目已自带同款脚本,会冲突吗?</b></summary>

不会。项目里若已有 `scripts/check-knowledge-drift.py` 这类脚本,插件会**自动让位**,不重复提醒。可放心全局启用。
</details>

<details>
<summary><b>不想装插件?手动用(等价)</b></summary>

把本插件 `scripts/` 两个脚本拷进项目 `scripts/`,在项目 `.claude/settings.json` 注册 Stop hook:
```json
{ "hooks": { "Stop": [ { "hooks": [
  { "type": "command", "command": "python3 \"$CLAUDE_PROJECT_DIR/scripts/stop-hook-knowledge-drift.py\" --check \"$CLAUDE_PROJECT_DIR/scripts/check-knowledge-drift.py\"" }
] } ] } }
```
再把 `.claude/.drift-state` 加进 `.gitignore`。技能与模板从 `skills/`、`reference/templates/` 拷过去。
</details>

---

## 👩‍🔧 给维护者

独立 git 仓库,只依赖 `python3` + `git`。完整改动/测试/发布流程见 **[`ITERATING.md`](ITERATING.md)**:改完先 `bash test.sh`(全绿才提交),发布走 `bash release.sh`(自动四校验)。设计方法论见 [`reference/playbook.md`](reference/playbook.md),版本历史见 [`CHANGELOG.md`](CHANGELOG.md)。
