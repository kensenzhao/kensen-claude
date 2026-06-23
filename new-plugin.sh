#!/usr/bin/env bash
# new-plugin.sh — 一键给本市场起一个新插件骨架(按 CONTRIBUTING 规范预填)。
# 用法:
#   bash new-plugin.sh <插件名(kebab-case)> ["一句话描述"]
# 生成 plugins/<名>/{.claude-plugin/plugin.json, README.md, CHANGELOG.md, test.sh, release.sh}
# 并自动注册进 .claude-plugin/marketplace.json;最后打印待你手填的下一步。
set -euo pipefail

NAME="${1:-}"
DESC="${2:-一句话:这个插件解决什么}"
[ -n "$NAME" ] || { echo "用法: bash new-plugin.sh <插件名> [\"一句话描述\"]" >&2; exit 1; }
echo "$NAME" | grep -qE '^[a-z0-9][a-z0-9-]*$' || { echo "✗ 插件名要是 kebab-case(小写/数字/连字符): $NAME" >&2; exit 1; }

REPO="$(git rev-parse --show-toplevel)"
DIR="$REPO/plugins/$NAME"
[ -e "$DIR" ] && { echo "✗ 已存在: plugins/$NAME" >&2; exit 1; }
DONOR="$REPO/plugins/knowledge-keeper/release.sh"
[ -f "$DONOR" ] || { echo "✗ 找不到模板 release.sh(参考插件 knowledge-keeper)" >&2; exit 1; }

mkdir -p "$DIR/.claude-plugin"

# --- plugin.json ---
cat > "$DIR/.claude-plugin/plugin.json" <<JSON
{
  "name": "$NAME",
  "description": "$DESC",
  "version": "0.1.0",
  "author": { "name": "kensenzhao" },
  "keywords": []
}
JSON

# --- README.md(两层结构骨架,占位符待填) ---
cat > "$DIR/README.md" <<'MD'
# __NAME__

> 一句话:__DESC__

<sub>本插件随 [kensen-claude](../../README.md) 市场分发。开启自动更新等市场级说明见根 README。</sub>

## 它帮你做什么
- 📌 <好处一>
- 📌 <好处二>
- 📌 <好处三>

## 📥 安装(3 步,复制即用)
```
/plugin marketplace add kensenzhao/kensen-claude
/plugin install __NAME__@kensen-claude
/reload-plugins
```

## ✨ 第一次使用
<手把手:你对 AI 说什么 → 它做什么 → 产出什么>

## 📋 怎么用这个插件
> 安装见上方;更新见 [根 README](../../README.md)。下面只列本插件**自己**的能力。

### 🗣 技能(斜杠命令 / 自然语言 / 自动触发)
<!-- 技能 = 自动生成的斜杠命令 /__NAME__:<技能名>;斜杠和自然语言两种触发都写上。若本插件无技能,删掉本表。 -->
| 技能 | 斜杠命令 | 或自然语言这样说 | 作用 |
|---|---|---|---|
| <做什么> | `/__NAME__:<技能名>` | 「<怎么说>」 | <作用> |

> 输入 `/` 可在菜单看到这些命令。

### 💻 终端脚本(可选,若有)
<!-- 若本插件带可手动跑的脚本,在此列;没有就删掉本节。 -->
...

## ❓ 常见问题
**...?** ...

## 🔧 进阶(需要时再看)
<details>
<summary><b>...</b></summary>
...
</details>

## 👩‍🔧 给维护者
通用目录/文档/发布规范见 [CONTRIBUTING](../../CONTRIBUTING.md);版本史见 [CHANGELOG](CHANGELOG.md)。
MD

# --- CHANGELOG.md ---
cat > "$DIR/CHANGELOG.md" <<'MD'
# Changelog · __NAME__

遵循语义化版本。每次发布由 `release.sh` 校验后打 tag `__NAME__-vX.Y.Z`。

## [0.1.0] — 初版
- <第一版做了什么>
MD

# --- test.sh(最小但真实:让 release.sh 有东西可校验;行为用例自己加) ---
cat > "$DIR/test.sh" <<'SH'
#!/usr/bin/env bash
# __NAME__ 回归测试。改完跑一下,全绿才提交。用法: bash test.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PASS=0; FAIL=0
ok(){ echo "  ✓ $1"; PASS=$((PASS+1)); }
no(){ echo "  ✗ $1"; FAIL=$((FAIL+1)); }

echo "1) plugin.json 是合法 JSON"
python3 -c "import json; json.load(open('$HERE/.claude-plugin/plugin.json'))" 2>/dev/null \
  && ok "plugin.json valid" || no "plugin.json invalid"

echo "2) 必备文档存在"
[ -f "$HERE/README.md" ]    && ok "README.md"    || no "README.md missing"
[ -f "$HERE/CHANGELOG.md" ] && ok "CHANGELOG.md" || no "CHANGELOG.md missing"

# TODO: 加你插件自己的行为用例(可照 plugins/knowledge-keeper/test.sh 的 fixture 模式)

echo ""
echo "==== 结果: PASS=$PASS  FAIL=$FAIL ===="
[ $FAIL -eq 0 ] && { echo "全部通过 ✅"; exit 0; } || { echo "有失败 ❌"; exit 1; }
SH

# --- release.sh:直接复用通用模板(按目录名自动取插件名,无需改) ---
cp "$DONOR" "$DIR/release.sh"

chmod +x "$DIR/test.sh" "$DIR/release.sh"

# 占位符替换(plugin.json/release.sh 不含占位符,跳过)
for f in "$DIR/README.md" "$DIR/CHANGELOG.md" "$DIR/test.sh"; do
  sed -i.bak -e "s/__NAME__/$NAME/g" "$f" && rm -f "$f.bak"
done
# DESC 可能含特殊字符,用 python 安全替换
python3 - "$DIR/README.md" "$DESC" <<'PY'
import sys
p, desc = sys.argv[1], sys.argv[2]
s = open(p, encoding="utf-8").read().replace("__DESC__", desc)
open(p, "w", encoding="utf-8").write(s)
PY

# --- 自动注册进 marketplace.json ---
python3 - "$REPO/.claude-plugin/marketplace.json" "$NAME" "$DESC" <<'PY'
import json, sys
path, name, desc = sys.argv[1], sys.argv[2], sys.argv[3]
data = json.load(open(path, encoding="utf-8"))
plugins = data.setdefault("plugins", [])
if any(p.get("name") == name for p in plugins):
    print(f"  (marketplace.json 已有 {name},跳过注册)")
else:
    plugins.append({"name": name, "source": f"./plugins/{name}", "description": desc})
    json.dump(data, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    open(path, "a", encoding="utf-8").write("\n")
    print(f"  已注册到 marketplace.json")
PY

echo ""
echo "✅ 已生成 plugins/$NAME/  并注册到市场。"
echo ""
echo "下一步(手填):"
echo "  1. 在根 README.md「收录的插件」表加一行:"
echo "     | **$NAME** | $DESC | \`$NAME@kensen-claude\` | \`v0.1.0\` | [📖 README](plugins/$NAME/README.md) |"
echo "  2. 编辑 plugins/$NAME/README.md(填好处/用法/命令)与 CHANGELOG.md。"
echo "  3. 往 plugins/$NAME/ 加能力组件(skills/ commands/ hooks/ agents/ 按需)。"
echo "  4. 补 test.sh 行为用例 → bash plugins/$NAME/test.sh 全绿。"
echo "  5. 发布:bash plugins/$NAME/release.sh --dry-run 然后 bash plugins/$NAME/release.sh"
