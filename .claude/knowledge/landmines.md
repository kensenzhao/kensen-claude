# Landmines — kensen-claude / knowledge-keeper 的坑

> 跨域的坑、反直觉点、环境陷阱。无 frontmatter 锚定(不参与漂移检测),靠人工维护。

## 1. 已装副本是缓存,版本会滞后(最常踩)
插件安装后是缓存副本(`~/.claude/plugins/cache/kensen-claude/knowledge-keeper/<版本>/…`)。
**改了本仓库源码不会自动生效**——实测会从旧版本(如 0.1.0)缓存载入技能。
→ 改完必须:`/plugin marketplace update kensen-claude` 然后 `/reload-plugins`。验证生效看缓存目录里的版本号。

## 2. sources 必须是仓库根相对路径
检测脚本用 `git rev-parse --show-toplevel` 定位仓库根(`plugins/knowledge-keeper/scripts/stop-hook-knowledge-drift.py:51`),
sources 都按仓库根解析。写成"插件目录相对"或绝对路径会漏匹配 → 漂移检测对该文档失效。

## 3. Stop hook exit 2 是有意的,不是 bug
exit 2 会阻止本次会话停止并把提醒回灌给模型(`plugins/knowledge-keeper/scripts/stop-hook-knowledge-drift.py:98`)。
这是"会话结束安全网"设计;指纹去重保证同一组漂移只打扰一次。别当成卡死去"修"。

## 4. glob 收口语义(改 glob_to_regex 必读)
`plugins/knowledge-keeper/scripts/check-knowledge-drift.py:65` 的收口规则:
- 非通配结尾(`src`)按目录边界收口,**不**匹配 `srcfoo`(防裸前缀误报)。
- 尾部单 `*`(`lib/*`)不跨目录;`**` 含零层(`a/**/b` 匹配 `a/b`)。
改这里极易引入过匹配(噪音)或漏匹配(漏报),**必须**在 `test.sh` 加边界用例(现有用例 10-12 守着)。

## 5. verified_at 与浅克隆
verified_at 要指向真实 commit。浅克隆(`git clone --depth 1`)里历史 SHA 缺失会被**静默**跳过
(`plugins/knowledge-keeper/scripts/check-knowledge-drift.py:222`),不报锚点异常——这是有意降噪,别误以为检测坏了。

## 6. 改脚本不跑 test.sh 不准提交
`bash plugins/knowledge-keeper/test.sh` 全绿是提交红线(`ITERATING.md`)。修过的 bug 必须留一条回归用例。

## 7. GAP 是粗粒度
模块内任一文件被锚到即算"已覆盖"(`plugins/knowledge-keeper/scripts/check-knowledge-drift.py:131`)。
GAP=0 不等于"全覆盖",别据此误判文档完整。
