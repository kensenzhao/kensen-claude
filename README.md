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

| 插件 | 一句话 | 安装名 | 版本 | 文档 |
|------|--------|--------|------|------|
| **knowledge-keeper** | 给项目自举 AI 知识体系并随代码**自动保鲜**(漂移检测 + 维护技能 + 一键 bootstrap);前 / 后 / 混合栈通用 | `knowledge-keeper@kensen-claude` | `v0.4.0` | [📖 README](plugins/knowledge-keeper/README.md) |

> 安装某个插件:`/plugin install <安装名>` 然后 `/reload-plugins`;点「📖 README」看该插件的完整用法与命令。
> **以后每多一个插件,这张表多一行就行**,根 README 其余部分不动。

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
├── CONTRIBUTING.md                   # 通用约定:目录/文档规范 + 发布流程
└── plugins/
    └── <插件>/                       # 各插件自包含:README / CHANGELOG / test.sh / release.sh
```

想加新插件或发布新版?**目录约定、文档规范、版本与发布流程见 [`CONTRIBUTING.md`](CONTRIBUTING.md)。** 各插件更细的迭代方法见其 `ITERATING.md`。

---

## 📄 许可

如未另行声明,本仓库内容供学习与内部使用。
