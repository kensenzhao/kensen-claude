# kensen-claude

kensenzhao 的 **Claude Code 工具市场**（私有）。根部是一个 marketplace，下面挂各类插件/工具。

## 安装（在任意机器/项目）

```
/plugin marketplace add <你的GitHub用户名>/kensen-claude
/plugin install knowledge-keeper@kensen-claude
/reload-plugins
```

> 私有仓库需要 `gh auth login` 或设置 `GH_TOKEN`/`GITHUB_TOKEN` 以便 Claude Code 拉取与自动更新。

## 收录的插件

| 插件 | 安装名 | 作用 |
|------|--------|------|
| [knowledge-keeper](plugins/knowledge-keeper/) | `knowledge-keeper@kensen-claude` | 给项目自举 AI 知识体系(skills+knowledge)并随代码自动保鲜:确定性漂移检测 + 安静 Stop hook + 维护技能 + 一键 bootstrap |

## 维护
改了某插件后，在 Claude Code 里 `/plugin marketplace update kensen-claude` 再 `/reload-plugins` 使其生效（已安装的是缓存副本，改源后需更新）。各插件依赖仅 `python3` + `git`。
