# knowledge-keeper（Claude Code 插件）

给**任意项目**自举一套 AI 知识体系（`.claude/skills` + `.claude/knowledge`），并随代码自动保鲜——把"机制"(检测脚本 + Stop hook + 维护技能 + 一键 bootstrap)做成插件单独维护，**知识内容仍留在各自项目仓库**。

## 它装了什么

```
knowledge-keeper/
├── .claude-plugin/
│   ├── plugin.json            # 插件清单
│   └── marketplace.json       # 本地市场清单(source: "./")
├── hooks/hooks.json           # Stop hook: 会话结束检测知识漂移
├── scripts/
│   ├── check-knowledge-drift.py     # 确定性漂移检测(零配置;STALE 全自动,GAP 可选)
│   └── stop-hook-knowledge-drift.py # hook 包装(指纹去重/极简/防循环)
├── skills/
│   ├── knowledge-bootstrap/   # 一键:给当前项目建知识体系
│   └── skill-maintenance/     # 代码变了同步知识文档
└── reference/
    ├── playbook.md            # 完整方法论
    └── templates/             # knowledge / SKILL 文档模板
```

## 怎么启用（一次性）

本插件经 `kensen-claude` 市场分发。在 Claude Code 里：

```
# 远端(私有仓库,需 gh 登录或 GH_TOKEN)
/plugin marketplace add <你的GitHub用户名>/kensen-claude
# 或本地
/plugin marketplace add /Users/zhaozhe/AlwaysNew/kensen-claude
/plugin install knowledge-keeper@kensen-claude
/reload-plugins
```

启用后会出现在 `enabledPlugins`，形如 `"knowledge-keeper@kensen-claude": true`。

> 想全局对所有项目生效就在用户级启用；想只在某项目生效，在该项目 `.claude/settings.local.json` 启用即可。

## 怎么用

- **给新项目建库**：开会话说「按 knowledge-bootstrap 给本项目建知识体系」。AI 会测绘→多 agent 抽取→对抗式审查→产出 `.claude/knowledge` + `.claude/skills`(带源码锚定 frontmatter)。机制(hook/检测)插件已自带，无需往项目拷脚本。
- **日常维护**：你改完业务代码并提交后，AI 按 `skill-maintenance` 自主同步受影响文档；会话结束时插件 Stop hook 若发现漂移会**极简提醒一次**(同一组漂移不重复刷屏)。
- **(可选) GAP 检测**：在目标项目根建 `.claude/knowledge-drift.config`，每行一个业务模块 glob(如 `src/*`)，即可检测"哪个模块还没文档覆盖"。

## 不想用插件？手动装(等价)
把 `scripts/` 两个脚本拷进目标项目 `scripts/`，并在项目 `.claude/settings.json` 注册 Stop hook：
```json
{ "hooks": { "Stop": [ { "hooks": [
  { "type": "command", "command": "python3 \"$CLAUDE_PROJECT_DIR/scripts/stop-hook-knowledge-drift.py\" --check \"$CLAUDE_PROJECT_DIR/scripts/check-knowledge-drift.py\"" }
] } ] } }
```
再 `echo ".claude/.drift-state" >> .gitignore`。维护技能与模板可从本插件 `skills/`、`reference/templates/` 拷过去。

## 验证机制可用
在任意启用了本插件的项目根：
```bash
echo '{}' | CLAUDE_PROJECT_DIR="$PWD" python3 <插件路径>/scripts/stop-hook-knowledge-drift.py --check <插件路径>/scripts/check-knowledge-drift.py; echo "exit=$?"
```
没用这套体系的项目(无锚定文档)→ 静默 exit 0；有未同步漂移 → exit 2 + 一行提醒。

## 判断某项目用得好不好（健康报告）
```bash
python3 <插件>/scripts/check-knowledge-drift.py --report
```
输出该项目知识库的 STALE / GAP / 未验证 / 滞后，一眼看出在这个项目里是被维护着还是在烂尾。

## 维护本插件
独立 git 仓库。**改动循环、回归测试、怎么判断效果、怎么把各项目反馈反哺回来——见 [`ITERATING.md`](ITERATING.md)**。
关键：改完先 `bash test.sh`（回归套件，全绿才提交）；改了脚本/技能后已安装副本需 `/plugin marketplace update kensen-claude` + `/reload-plugins` 才生效。依赖仅 `python3` + `git`。

## 设计依据
完整方法论与"为什么这么设计"见 `reference/playbook.md`。两条 sources 铁律：①只锚代码不锚文档；②慎锚热点宽文件。
