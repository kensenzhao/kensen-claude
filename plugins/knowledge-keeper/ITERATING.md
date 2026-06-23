# 迭代 knowledge-keeper（怎么改、怎么知道好不好、怎么反哺）

## 1. 改动循环（改 → 测 → 升版 → 推 → 用上）

```bash
# 1. 改源码(就在本仓库)
# 2. 跑回归,全绿才继续
bash plugins/knowledge-keeper/test.sh
# 3. 升版本号(plugins/knowledge-keeper/.claude-plugin/plugin.json 的 version)
# 4. 提交并推送
git commit -am "..." && git push
# 5. 让已安装的副本拉到新版(装的是缓存副本,不 update 不生效!)
#    在 Claude Code 里:
/plugin marketplace update kensen-claude
/reload-plugins
```

**没有第 2 步就别改**——回归套件是你敢动手的底气。

### 加回归用例
每修一个 bug / 加一个行为，去 `test.sh` 加一段：建临时 git fixture → 跑脚本 → 断言退出码/输出 → `ok`/`no`。套件用 `mkrepo`/`anchor` 两个辅助函数造 fixture，照抄现有用例即可。**修过的 bug 必须留一条用例**，防回归。

## 2. 怎么判断"在某个项目里效果好不好"

### 自动:健康报告(任意项目根跑)
```bash
python3 <插件>/scripts/check-knowledge-drift.py --report
```
看小结：
- **STALE > 0 且长期不降** → 文档在烂、没人同步（维护没跟上）。
- **GAP > 0**（需先配 `.claude/knowledge-drift.config` 列业务模块 glob）→ 有模块没文档覆盖，AI 对那片还是瞎。
- **未验证合计高** → 当初抽取时没核实清楚，可信度打折。
- **滞后大但 STALE=0** → 正常（近期提交没碰被记录的代码）。

> 报告量的是**新鲜度+覆盖度(知识健不健康)**，不是"AI 真变聪明没"。

### 人工:真效用信号(别被全绿骗了)
- 你还需不需要反复跟 AI 解释这个项目？不用了=有用。
- 你纠正 AI 的频率。每次"代码其实是 X"=一处文档质量缺口。
- bootstrap 出的文档读着像不像内行写的。

## 3. 怎么把各项目的反馈反哺回插件（关键判据）

先分清两类问题：

| 现象 | 属于 | 改哪 |
|---|---|---|
| 某项目某篇文档内容错/过时 | **项目内容问题** | 在那个项目用 skill-maintenance 改，不动插件 |
| 漂移老误报某类目录、bootstrap 总漏某层、skill 该触发没触发 | **插件机制问题** | 改本插件、升版本、推送 |

**一句话判据：同一类毛病在多个项目反复出现 → 是插件的问题，该反哺。** 单项目独有的，本地修掉即可。

例子：
- 多个项目都"对 `generated/` 误报漂移" → 给检测脚本加默认忽略 → 全项目受益。
- 多个 Java 项目 bootstrap 都漏"定时任务/MQ 消费者" → 在 knowledge-bootstrap 的 Phase 1 清单补"找 @Scheduled / MQ listener"。

### 反馈不丢:一个跨项目收集口
dogfood 时随手记到 `~/.claude/kk-feedback.md`（跨所有项目共用），每条记：
```
- [项目] 现象 | 我判断: 插件问题 / 内容问题
```
**定期翻一遍**，把"多项目复现"的挑出来，变成本插件下一版的改进项（或开成 GitHub issue）。这样分散在各项目的痛点就汇成了插件路线图。

## 4. 进阶:让插件吃自己的狗粮(可选)
给本插件自己的代码(`scripts/`、`skills/`)也建一两篇锚定文档。改插件代码时它自己的机制就提醒你更新自身文档——最能逼出"好不好用"。
