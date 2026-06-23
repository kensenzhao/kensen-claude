---
name: iterate-plugin
description: 在本仓库(kensen-claude)改 knowledge-keeper 插件代码时必须使用——给出"改→回归→升版→推→让已装副本生效"的标准闭环与回归用例写法。涉及改 scripts/*.py、test.sh、hooks.json、模板或技能时触发。
sources:
  - plugins/knowledge-keeper/test.sh
verified_at: 1cfcdd6
---

# iterate-plugin — 安全迭代 knowledge-keeper

## 何时用
- 改 `plugins/knowledge-keeper/scripts/*.py`(检测/hook 逻辑)。
- 改 `test.sh`、`hooks.json`、`reference/templates/`、`skills/`。
- 修了 bug 或加了行为,准备发版。

## 本项目的标准做法
**铁律:没跑过 `test.sh` 全绿,不提交。** 回归套件是敢动手的底气(`plugins/knowledge-keeper/test.sh:1` 注释)。

闭环(摘自 `ITERATING.md`):
```bash
# 1. 改源码(就在本仓库)
# 2. 跑回归,全绿才继续
bash plugins/knowledge-keeper/test.sh
# 3. 升版本号 plugins/knowledge-keeper/.claude-plugin/plugin.json 的 version
# 4. git commit && git push
# 5. 让已装副本拉新版(装的是缓存副本,不 update 不生效!)
#    在 Claude Code: /plugin marketplace update kensen-claude  然后 /reload-plugins
```

### 加回归用例(修过的 bug 必须留一条)
`test.sh` 用两个辅助函数造临时 git fixture,照抄现有用例即可:
- `mkrepo`：建临时 git 仓(`test.sh:13`)。
- `anchor <repo> <docname> <sources-glob> <verified_at>`：写一篇带锚定 frontmatter 的文档(`test.sh:14`)。
模式:建 fixture → 跑脚本 → 断言退出码/输出 grep → `ok`/`no`。例见 STALE 检出(`test.sh` 用例 3)、glob 收口(用例 10-12)、浅克隆(用例 13)。

## 关键约定清单
- 改脚本 ⇒ 同步加/改 `test.sh` 回归用例(`test.sh` 整体)。
- 升 `version` 后必须 `/plugin marketplace update` + `/reload-plugins`,否则改动不生效(见 landmines)。
- 依赖只允许 `python3` 标准库 + `git`,不引第三方包。

## 常见坑
- **已装副本是缓存,版本会滞后**——改完不 update 看不到效果。见 `.claude/knowledge/landmines.md`。
- glob 收口语义易踩,改 `glob_to_regex` 必加边界用例。见 `.claude/knowledge/drift-detection.md`。

## 相关知识
- 引擎原理:`.claude/knowledge/drift-detection.md`
- hook 减噪/让位:`.claude/knowledge/stop-hook.md`
- 完整迭代/反哺方法论:`plugins/knowledge-keeper/ITERATING.md`

<!-- 纪律:只写实际读到的代码;标 path:line;改完把 verified_at 推到 HEAD。正文 < 200 行。 -->
