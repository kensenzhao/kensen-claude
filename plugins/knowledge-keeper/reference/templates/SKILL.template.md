---
name: <kebab-case 技能名，如 add-endpoint>
description: <既说"做什么"又说"何时触发"，要略 pushy 以确保自动触发。按栈举例:
  · 后端——在本项目新增/修改 REST 接口时(新增 Controller 方法、新建 Service、加查询、定义请求/响应 VO)必须使用，给出本项目标准链路与约定。
  · 前端——在本项目新增页面/路由或对接后端接口时(在 API 客户端层加调用、补类型、接 store、处理 loading/错误)必须使用，给出本项目的请求封装与状态约定。>
sources:
  - <代表性真实示例文件，如 path/to/ExampleController.ext>
  - <相关基础设施目录/**>
verified_at: <短 git SHA>
---

# <技能名> — <做什么>

## 何时用
<触发场景；列举几个典型用户意图。>

## 本项目的标准做法
<不是通用教科书写法，而是本项目真实约定。> 配真实代码示例：

```<lang>
// 摘自 path/to/Example.ext:line
<真实片段>
```

## 关键约定清单
- <约定>（`path:line`）

## 常见坑
- <这类活最易踩的坑>（见 `.claude/knowledge/landmines.md` 或 `path:line`）

## 相关知识
- 背景/为什么：`.claude/knowledge/<相关域>.md`

<!-- 纪律：只写实际读到的代码；标 path:line；改完把 verified_at 推到 HEAD。正文 < 200 行。 -->
