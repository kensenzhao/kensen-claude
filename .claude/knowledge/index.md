# kensen-claude 知识体系 · 索引

> 本仓库是 Claude Code 插件市场,核心是 `knowledge-keeper` 插件(给任意项目自举 AI 知识体系并随代码保鲜)。
> 本知识库是 knowledge-keeper **吃自己狗粮**的产物——它的机制看守着它自己的代码。

## ⚠️ 先读 landmines
`.claude/knowledge/landmines.md` —— 缓存滞后、sources 相对路径、exit2 语义、glob 收口等必踩坑。

## skills 速查(怎么做)
| 技能 | 何时触发 |
|------|---------|
| `iterate-plugin` | 改插件代码(scripts/test.sh/hooks/模板/技能):改→回归→升版→推→reload 的闭环 |

> 另外两个面向**其它项目**的技能由插件提供:`knowledge-bootstrap`(建库)、`skill-maintenance`(同步)。

## knowledge 速查(是什么/为什么)
| 文档 | 覆盖 |
|------|------|
| `drift-detection.md` | 检测引擎:frontmatter 解析、glob 收口、STALE/GAP、退出码 |
| `stop-hook.md` | 会话结束包装:去重、让位护栏、防循环、exit2 安全网 |
| `landmines.md` | 跨域坑汇总 |

## 维护
代码一变,插件自己的漂移检测会在会话结束提醒(吃狗粮)。同步用 `skill-maintenance`:
核实代码 → 更新文档 → 把 `verified_at` 推到当前 HEAD。完整方法论见 `plugins/knowledge-keeper/reference/playbook.md`。
