# knowledge-keeper（Claude Code 插件）

**让 Claude 一上手就精通你的项目，并且这套"项目知识"会随代码自动保鲜、不会悄悄烂掉。**

适用于**后端 / 前端 / 前后端混合(monorepo)**任意项目。

---

## 它解决什么

没有它:每开一个会话，Claude 都要重读代码、还常凭记忆猜你项目的约定，猜错了你得反复纠正；团队 wiki 写完就开始烂，没人知道哪篇过时了。

有了它:
- **knowledge**（参考文档，AI 按需读）——本项目"是什么 / 为什么 / 有哪些坑"，每条断言带 `文件:行号`。
- **skills**（操作手册，AI 自动触发）——本项目"某类活怎么干"（新增接口、对接 API、加页面…）。
- **自动保鲜**——代码一改，确定性脚本算出哪篇文档因哪个文件过时，会话结束**极简提醒一次**。不靠任何人"记得更新"，几乎零 token。

> 关键差异:`CLAUDE.md`、wiki、普通 `.claude/docs` 都能存文档，但它们会**悄悄烂掉**。这个插件唯一不可替代的，是用脚本**确定性地检测文档与代码的漂移**——文档烂了你会立刻知道。

---

## 前置要求
- Claude Code。
- 本机有 `python3` 和 `git`（插件不依赖任何第三方包）。
- 能访问 `kensenzhao/kensen-claude` 仓库（私有仓需先 `gh auth login` 或设 `GH_TOKEN`）。

## 安装（一次性）
在 Claude Code 里：
```
/plugin marketplace add kensenzhao/kensen-claude
/plugin install knowledge-keeper@kensen-claude
/reload-plugins
```
装好后会出现在 `enabledPlugins`，形如 `"knowledge-keeper@kensen-claude": true`。

> 想对所有项目生效 → 在**用户级**启用；只想某项目生效 → 在该项目 `.claude/settings.local.json` 启用。

## 你的前 5 分钟（quickstart）
1. 在目标项目里开一个 Claude Code 会话。
2. 说：**「按 knowledge-bootstrap 给本项目建知识体系」**。
3. Claude 会:测绘项目 → 让你确认"域→源码路径"范围 → 多 agent 读真实代码抽取 + 对抗式审查 → 产出 `.claude/knowledge` + `.claude/skills`（带源码锚定）。
4. 把产出的 `.claude/knowledge`、`.claude/skills` 提交进你的项目仓库（知识内容归项目所有，跟着仓库走）。
5. 之后正常开发即可——保鲜机制已自动生效。

> 机制（检测脚本 + Stop hook）都在插件里，**不用往项目拷任何脚本、不用改 settings**。

## 日常怎么用
- **改完代码并提交后**:Claude 会按 `skill-maintenance` 自主核对、同步受影响的文档（只改必要部分，不逐条问你）。
- **会话结束**:若有未同步的漂移，插件 Stop hook **极简提醒一次**（同一组漂移不重复刷屏）。
- **你纠正 AI 时**（"不对，本项目其实是 X"）:这是最高优先的同步时机，Claude 会把它固化进文档。
- **(可选) 覆盖缺口检测**:在项目根建 `.claude/knowledge-drift.config`，每行一个业务模块 glob（如 `src/*`、`apps/*`），即可额外检测"哪个模块还没文档覆盖"。

---

## FAQ / 排错
**Q: 装了但完全没反应？**
A: 多半是两种正常情况——① 项目里还没有锚定文档（没跑过 bootstrap）→ 插件设计为此时完全静默；② 你的改动还没 `git commit`。检测只看**已提交**改动（`git diff <verified_at>..HEAD`），编辑当下不触发。

**Q: 同一条漂移提醒老不消失？**
A: 同步文档后**必须**把该文档 frontmatter 的 `verified_at` 推到当前 HEAD（`git rev-parse --short HEAD`），否则脚本会一直报它。`skill-maintenance` 会自动做这步。

**Q: 改了插件 / 装了新版却没生效？**
A: 安装的是**缓存副本**。要 `/plugin marketplace update kensen-claude` + `/reload-plugins` 才会拉到新版。

**Q: 我们项目把脚本焊进了自己仓库，会和插件打架吗？**
A: 不会。见下方"与项目自带副本共存"——插件会自动退让。

**Q: 怎么知道某项目的知识库是健不健康？**
A: 跑健康报告（见下方"进阶"）。

---

## 进阶

<details>
<summary><b>判断某项目用得好不好（健康报告）</b></summary>

```bash
python3 <插件路径>/scripts/check-knowledge-drift.py --report
```
输出该项目知识库的 STALE / GAP / 未验证 / 滞后，一眼看出在这个项目里是被维护着还是在烂尾。
注意 GAP 是**粗粒度**:模块内只要有任一文件被锚到即算覆盖，GAP=0 ≠ 全覆盖。
</details>

<details>
<summary><b>与"项目自带副本"共存</b></summary>

若某项目把漂移脚本焊进了自己仓库（存在 `scripts/check-knowledge-drift.py` 或 `scripts/stop-hook-knowledge-drift.py`，常见于团队为了"别人不装插件也能用"），插件的全局 Stop hook 会**自动退让**(exit 0)，交给该项目自己的 hook，避免双触发 + 抢同一个 `.drift-state`。所以可放心在用户级全局启用，不打扰这类自包含项目。
</details>

<details>
<summary><b>不想用插件？手动装(等价)</b></summary>

把 `scripts/` 两个脚本拷进目标项目 `scripts/`，在项目 `.claude/settings.json` 注册 Stop hook：
```json
{ "hooks": { "Stop": [ { "hooks": [
  { "type": "command", "command": "python3 \"$CLAUDE_PROJECT_DIR/scripts/stop-hook-knowledge-drift.py\" --check \"$CLAUDE_PROJECT_DIR/scripts/check-knowledge-drift.py\"" }
] } ] } }
```
再 `echo ".claude/.drift-state" >> .gitignore`。维护技能与模板从本插件 `skills/`、`reference/templates/` 拷过去。
</details>

<details>
<summary><b>验证机制可用</b></summary>

在任意启用了本插件的项目根：
```bash
echo '{}' | CLAUDE_PROJECT_DIR="$PWD" python3 <插件路径>/scripts/stop-hook-knowledge-drift.py --check <插件路径>/scripts/check-knowledge-drift.py; echo "exit=$?"
```
没用这套体系的项目 → 静默 exit 0；有未同步漂移 → exit 2 + 一行提醒。
</details>

<details>
<summary><b>装了什么 / 目录结构</b></summary>

```
knowledge-keeper/
├── .claude-plugin/plugin.json   # 插件清单(name/version/description)
├── hooks/hooks.json             # Stop hook: 会话结束检测知识漂移
├── scripts/
│   ├── check-knowledge-drift.py     # 确定性漂移检测(零配置;STALE 自动,GAP 可选)
│   └── stop-hook-knowledge-drift.py # hook 包装(去重/极简/防循环/让位)
├── skills/
│   ├── knowledge-bootstrap/     # 一键:给当前项目建知识体系
│   └── skill-maintenance/       # 代码变了同步知识文档
├── reference/{playbook.md, templates/}  # 方法论 + 文档模板
├── test.sh / release.sh         # 回归套件 / 发布护栏
└── CHANGELOG.md / ITERATING.md  # 版本记录 / 维护指南
```
> 市场清单 `marketplace.json` 在**仓库根** `.claude-plugin/`（指向 `./plugins/knowledge-keeper`），不在插件目录内。
</details>

---

## 维护本插件（给维护者）
独立 git 仓库，依赖仅 `python3` + `git`。改动循环、回归测试、发布护栏、效果判断、跨项目反哺——见 **[`ITERATING.md`](ITERATING.md)**。
红线:改完先 `bash test.sh` 全绿；发布走 `bash release.sh`（自动校验回归/版本/CHANGELOG/工作树）。
设计依据与"为什么这么设计"见 `reference/playbook.md`，两条 sources 铁律：①只锚代码不锚文档；②同一热点文件别塞进多篇 sources。
