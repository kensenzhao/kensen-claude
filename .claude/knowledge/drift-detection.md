---
name: drift-detection
description: 漂移检测引擎(check-knowledge-drift.py)是什么/怎么算出 STALE 与 GAP/退出码语义。改检测逻辑或排查"为什么报/不报漂移"时读。
sources:
  - plugins/knowledge-keeper/scripts/check-knowledge-drift.py
verified_at: 9ff3184
---

# 漂移检测引擎 (check-knowledge-drift.py)

> 确定性、零 LLM 成本。在哪个 git 仓库跑就检测哪个;无锚定文档则静默退出(插件无感)。
> 相邻:`stop-hook`(会话结束的包装/减噪) 调用本脚本。

## 模块架构 / 数据流
```
扫描 .claude/knowledge + .claude/skills 下所有 *.md  (DOC_DIRS, check:22)
  → 解析每篇 frontmatter 取 sources + verified_at      (parse_frontmatter, check:34)
  → 仅"同时有 sources 且 verified_at"的文档参与检测     (check:216 附近 continue)
  → STALE: git diff <verified_at>..HEAD ∩ sources globs (changed_since check:106)
  → GAP : 配置的业务模块 glob 里,没被任何 doc 覆盖的     (gap_check check:131,需配置)
  → 无漂移 exit 0;有 STALE/GAP/锚点异常 exit 3
```

## 关键实体 / 数据模型 / 组件
| 概念 | 说明 | 来源 |
|------|------|------|
| `DOC_DIRS` | 只扫 `.claude/knowledge`、`.claude/skills` | `check:22` |
| `CONFIG_FILE` | 可选 GAP 配置 `.claude/knowledge-drift.config` | `check:23` |
| `IGNORE_DIRS` | GAP 扫描时跳过的构建产物目录(target/build/dist/node_modules…) | `check:24` |
| frontmatter 结束围栏 | 必须是一整行 `---`(`^---[ \t]*$`),正文里的 `---` 不破坏解析 | `check:39` |
| 64KB 上限 | 每篇只读前 64KB 解析 frontmatter,防超大文件吃内存 | `check:214` |

## 核心流程
### glob → 正则收口(三条语义,B1/B2 修复后)
`glob_to_regex` 把 sources 的 glob 编成正则,结尾收口规则决定匹不匹得准(`check:65`、`check:88-93`):
- `**` **跨目录且含零层**:`a/**/b` 匹配 `a/b` 与 `a/x/b`(`**/` → `(?:.*/)?`)。
- 尾部单 `*` **收到段末**(`$`):`lib/*` 只匹配直接子项,不越 `/`。
- 非通配结尾按"精确或目录前缀"收口(`(?:/|$)`):`src` 匹配 `src`、`src/x`,**不**匹配 `srcfoo`。
  ⚠️ 这条收口正是修复"裸前缀过匹配致 STALE 误报"的关键。

### STALE 判定
对每篇锚定文档,跑 `git diff --name-only <verified_at>..HEAD`(`changed_since` `check:106`),
与该文档 sources 的正则求交;有交集即 STALE。按 `verified_at` 分组缓存,多篇同 SHA 只 diff 一次。

### 锚点健壮性
- `git_commit_exists` 验 verified_at 是否在本地(`check:95`)。
- 浅克隆(`is_shallow_repo` `check:99`)里 SHA 缺失多为历史被截断 → **静默**,不报"锚点异常"也不误判 STALE(`check:222` `if not commit_ok and not shallow`)。
- 非浅克隆里 SHA 真缺失 → 报"锚点异常",计入 exit 3。

### GAP(可选,粗粒度)
仅当存在 `.claude/knowledge-drift.config`(每行一个业务模块 glob)才做(`gap_check` `check:131`)。
⚠️ **粗粒度**:模块内只要有任一文件被某文档锚到,整模块即算已覆盖——发现不了"只记了一半"。

## 业务规则与边界
- **退出码**:`0`=无漂移/无锚定文档/report 模式;`3`=有 STALE 或 GAP 或锚点异常(`check:268`)。
- **无锚定文档 → 静默 exit 0**(`check:245-246`):没用这套体系的项目里插件完全无感。
- `--report` 模式(`check:184`):打印健康报告(新鲜度+覆盖度),**恒 exit 0**,不参与 hook 触发。
- 只看**已提交**改动(`git diff verified_at..HEAD`),工作区未提交改动不触发。

## 已知坑（若有）
- sources 必须是**仓库根相对路径**(脚本靠 `git rev-parse --show-toplevel` 定位);写成插件目录相对会漏匹配。详见 `.claude/knowledge/landmines.md`。

## 相关接口 / 入口
| 入口 | 说明 | 来源 |
|------|------|------|
| `python3 check-knowledge-drift.py` | 检测,exit 0/3 | `check:183` |
| `python3 check-knowledge-drift.py --report` | 健康报告,恒 exit 0 | `check:184` |

<!-- 纪律:只写实际读到的代码;标 path:line;改完把 verified_at 推到 HEAD。 -->
