# kensen-claude

**[Claude Code](https://code.claude.com) 插件市场** —— 一组让 Claude 更懂你项目、把工程经验沉淀成可复用能力的工具。

添加本市场后即可一键安装下面的插件;依赖极简(仅 `python3` + `git`),无第三方包。

---

## 🚀 快速开始

在 Claude Code 里添加市场(仓库已公开,**无需鉴权**):

```
/plugin marketplace add kensenzhao/kensen-claude
```

然后安装需要的插件,例如:

```
/plugin install knowledge-keeper@kensen-claude
/reload-plugins
```

> 想日后自动拿到新版(推荐):`/plugin` → **Marketplaces** → 选中 `kensen-claude` → **Enable auto-update**。开启后每次启动 Claude Code 自动更新。

---

## 📦 收录的插件

| 插件 | 安装名 | 最新版 | 一句话 |
|------|--------|--------|--------|
| [**knowledge-keeper**](plugins/knowledge-keeper/) | `knowledge-keeper@kensen-claude` | `v0.4.0` | 给项目自举一套 AI 知识体系并随代码**自动保鲜**:确定性漂移检测 + 安静 Stop hook + 维护技能 + 一键 bootstrap |

### knowledge-keeper

让 Claude **一上手就精通你的项目**,并且这套"项目知识"会随代码自动保鲜、不会悄悄烂掉。后端 / 前端 / 前后端混合(monorepo)通用。

- **knowledge**(参考文档,按需读)+ **skills**(操作手册,自动触发),每条断言带 `文件:行号`。
- 代码一改,确定性脚本算出哪篇文档因哪个文件过时,会话结束**极简提醒一次**——不靠人记得更新,几乎零 token。
- 与 `CLAUDE.md` / wiki 的关键差异:别的文档会**悄悄烂掉**,它能**确定性检测**文档与代码的漂移。

详细用法、工作原理、FAQ → **[插件 README](plugins/knowledge-keeper/README.md)**。

---

## 🔄 保持更新

插件装的是缓存副本(`~/.claude/plugins/cache/`)。开启自动更新(见上)后启动即更;或手动:

```
/plugin marketplace update kensen-claude          # 刷新市场清单
/plugin update <插件>@kensen-claude               # 更新插件
/reload-plugins                                    # 生效
```

每个插件版本对应一个 git tag,形如 `knowledge-keeper-vX.Y.Z`。

---

## 🛠 给贡献者 / 维护者

```
kensen-claude/
├── .claude-plugin/marketplace.json   # 市场清单(列出所有插件及其 source)
└── plugins/
    └── knowledge-keeper/             # 各插件自包含:含自己的 README/CHANGELOG/test/release
```

- 每个插件自带回归套件 `test.sh` 与发布护栏 `release.sh`(回归绿 + 版本已升 + CHANGELOG 有条目 + 工作树干净,四校验任一不过即拒绝发布)。
- 迭代与发布流程见各插件的 `ITERATING.md`。

---

## 📄 许可

如未另行声明,本仓库内容供学习与内部使用。
