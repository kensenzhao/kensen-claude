---
name: stop-hook
description: 会话结束的漂移提醒包装(stop-hook-knowledge-drift.py + hooks.json):减噪/去重/让位/防循环怎么实现。改 hook 行为或排查"为什么没提醒/重复提醒"时读。
sources:
  - plugins/knowledge-keeper/scripts/stop-hook-knowledge-drift.py
  - plugins/knowledge-keeper/hooks/hooks.json
verified_at: 9ff3184
---

# Stop hook 包装 (stop-hook-knowledge-drift.py)

> 会话结束跑 `drift-detection` 引擎,仅在出现**新**漂移时极简提醒一次。
> 相邻:调用 `.claude/knowledge/drift-detection.md` 所述的 check 脚本。

## 模块架构 / 数据流
```
hooks.json 注册 Stop hook(hooks.json:8-9):
  stop-hook-knowledge-drift.py --check <check 脚本>   (路径用 ${CLAUDE_PLUGIN_ROOT})
    → stop_hook_active? 是则退出(防循环)              (stop:41-42)
    → 本项目自带 scripts/ 漂移脚本? 是则让位 exit0     (stop:56-58)
    → 跑 check(cwd=CLAUDE_PROJECT_DIR)                 (stop:60)
    → check 非 3(无漂移): 删状态文件, exit0           (stop:63-69)
    → 提取 "• 路径" 条目算指纹, 与上次比               (stop:73-74,83)
    → 指纹相同: 静默 exit0; 不同: 写状态 + stderr提醒 + exit2 (stop:84-98)
```

## 关键实体 / 数据模型 / 组件
| 概念 | 说明 | 来源 |
|------|------|------|
| `STATE_FILE` | `.claude/.drift-state`,存上次漂移指纹 | `stop:22` |
| 状态文件位置 | 写在 **git 仓库根**,避免 CLAUDE_PROJECT_DIR 缺失时写错地方 | `stop:50-61` |
| 指纹 | 所有 `• <路径/模块>` 条目排序去重后 sha1 | `stop:73-74` |
| `--check` 参数 | check 脚本路径由 hooks.json 传入 | `stop:28-29`、`hooks.json:9` |
| `${CLAUDE_PLUGIN_ROOT}` | hooks.json 用它定位插件内脚本 | `hooks.json:9` |

## 核心流程
### 减噪:同一组漂移只提醒一次
指纹 = 排序去重的 `• 路径` 条目集合的 sha1(`stop:73-74`)。与状态文件比对(`stop:83`):
相同则静默 exit 0;不同则写新指纹并 exit 2 提醒。漂移消失时(check 非 3)删状态文件(`stop:64-68`),
下次同样漂移再现可重新提醒。
> ⚠️ 抓的是 `•` 开头的条目(STALE 文档 / GAP 目录 / ERR),**不能只抓 .md**——否则"只有 GAP"时指纹恒空,会被永久静默(回归用例 6 守这条)。

### 让位护栏(defer-to-local)
若被检项目自己仓库里有 `scripts/check-knowledge-drift.py` 或 `scripts/stop-hook-knowledge-drift.py`,
插件 hook **退让 exit 0**(`stop:56-58`),交给项目自带 hook,避免双触发 + 抢同一个 `.drift-state`。
→ 可放心在 user 级全局启用插件,不打扰这类自包含项目。

### 双重防循环
① `stop_hook_active` 兜底(`stop:41-42`);② 指纹去重。两者叠加防止 exit 2 反复拉起会话。

## 业务规则与边界
- **exit 2 是有意的安全网**:Stop hook exit 2 会阻止本次停止、把 stderr 回灌给模型,由模型按
  `skill-maintenance` 自主判断是否同步(`stop:98`)。不是 bug;提醒文案已注明"不影响就忽略"。
- 提醒只发一行到 stderr,不阻塞正常使用。

## 已知坑（若有）
- 见 `.claude/knowledge/landmines.md`(缓存滞后、exit2 语义等)。

## 相关接口 / 入口
| 入口 | 说明 | 来源 |
|------|------|------|
| Stop hook 命令 | `stop-hook…py --check <check…py>` | `hooks.json:8-9` |

<!-- 纪律:只写实际读到的代码;标 path:line;改完把 verified_at 推到 HEAD。 -->
