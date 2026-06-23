---
name: <kebab-case-域标识>
description: <一句话：本文档覆盖什么 / 涉及哪个域时来读>
sources:
  # 只列推导来源的代码路径(相对仓库根)。窄而准；别用 src/**；不要列其它文档。
  - <path/to/domain/service/**>
  - <path/to/domain/SomeKeyFile.ext>
verified_at: <短 git SHA，建文档时的 HEAD>
---

# <域名称>

> 一句话定位：这个域是干什么的，与哪些域相邻。

## 模块架构 / 数据流
<分层、调用链、关键组件。可用 ASCII 图。>

## 关键实体 / 数据模型 / 组件
<!-- 后端:实体/表/DTO 字段;前端:核心组件 props/state、store 形状、关键类型;接缝:契约字段。 -->
| 字段/概念 | 说明 | 来源 |
|------|------|------|
| ... | ... | `path:line` |

## 核心流程
### <流程名>
<步骤，关键步骤标 `path:line`。>

## 业务规则与边界
- <规则>（`path:line`）

## 已知坑（若有）
- <反直觉点 / bug / 陷阱>（`path:line`）。跨域的坑统一进 `landmines.md`。

## 相关接口 / 入口
| 入口 | 说明 | 来源 |
|------|------|------|
| ... | ... | `path:line` |

<!-- 纪律：只写实际读到的代码；标 path:line；拿不准标 ⚠️未验证；改完把 verified_at 推到 HEAD。 -->
