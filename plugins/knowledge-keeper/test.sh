#!/usr/bin/env bash
# knowledge-keeper 回归测试套件。改完脚本跑一下,全绿才提交/升版本。
# 自带临时 git fixture,不依赖任何外部项目。用法: bash test.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
CHK="$HERE/scripts/check-knowledge-drift.py"
HOOK="$HERE/scripts/stop-hook-knowledge-drift.py"
PASS=0; FAIL=0
ok(){ echo "  ✓ $1"; PASS=$((PASS+1)); }
no(){ echo "  ✗ $1"; FAIL=$((FAIL+1)); }

GU=(-c user.name=t -c user.email=t@t)
mkrepo(){ d=$(mktemp -d); git -C "$d" init -q; echo "$d"; }
anchor(){ # $1=repo $2=docname $3=sources-glob $4=verified_at
  mkdir -p "$1/.claude/knowledge"
  printf -- '---\nname: %s\ndescription: t\nsources:\n  - %s\nverified_at: %s\n---\n# body\n' \
    "$2" "$3" "$4" > "$1/.claude/knowledge/$2.md"; }

echo "0) 语法"
python3 -m py_compile "$CHK" "$HOOK" && ok "py_compile" || no "py_compile"

echo "1) 无锚定文档 -> 静默 exit0"
r=$(mkrepo); ( cd "$r" && git "${GU[@]}" commit -q --allow-empty -m i )
( cd "$r" && python3 "$CHK" ); [ $? -eq 0 ] && ok "inert exit0" || no "inert"
rm -rf "$r"

echo "2) 已同步(verified_at=HEAD,无变更) -> exit0"
r=$(mkrepo); mkdir -p "$r/lib"; echo a > "$r/lib/A.txt"
( cd "$r" && git add -A && git "${GU[@]}" commit -q -m c1 )
anchor "$r" doc "lib/**" "$(git -C "$r" rev-parse --short HEAD)"
( cd "$r" && python3 "$CHK" ); [ $? -eq 0 ] && ok "synced exit0" || no "synced"

echo "3) STALE(源码在 verified_at 之后被改) -> exit3 且报该文档"
echo b >> "$r/lib/A.txt"; ( cd "$r" && git add -A && git "${GU[@]}" commit -q -m c2 )
out=$( cd "$r" && python3 "$CHK" ); code=$?
{ [ $code -eq 3 ] && echo "$out" | grep -q "doc.md"; } && ok "STALE 检出" || no "STALE (code=$code)"

echo "4) hook 去重: 同一漂移第一次 exit2,第二次 exit0"
rm -f "$r/.claude/.drift-state"
c1=$(echo '{}' | CLAUDE_PROJECT_DIR="$r" python3 "$HOOK" --check "$CHK" >/dev/null 2>&1; echo $?)
c2=$(echo '{}' | CLAUDE_PROJECT_DIR="$r" python3 "$HOOK" --check "$CHK" >/dev/null 2>&1; echo $?)
{ [ "$c1" = 2 ] && [ "$c2" = 0 ]; } && ok "dedup (2 then 0)" || no "dedup (got $c1,$c2)"
echo "   状态文件写在项目根?"; [ -f "$r/.claude/.drift-state" ] && ok "state at project root" || no "state location"
rm -rf "$r"

echo "5) GAP(配了模块 glob,有模块没被覆盖) -> exit3 且报该模块"
r=$(mkrepo); mkdir -p "$r/lib" "$r/src"; echo a > "$r/lib/A.txt"
( cd "$r" && git add -A && git "${GU[@]}" commit -q -m c1 )
anchor "$r" doc "lib/**" "$(git -C "$r" rev-parse --short HEAD)"
printf 'lib\nsrc\n' > "$r/.claude/knowledge-drift.config"
out=$( cd "$r" && python3 "$CHK" ); code=$?
{ [ $code -eq 3 ] && echo "$out" | grep -q "src"; } && ok "GAP 检出" || no "GAP (code=$code)"

echo "6) GAP-only 也能去重(回归 I-4: 指纹覆盖 GAP 而非只 .md)"
rm -f "$r/.claude/.drift-state"
c1=$(echo '{}' | CLAUDE_PROJECT_DIR="$r" python3 "$HOOK" --check "$CHK" >/dev/null 2>&1; echo $?)
c2=$(echo '{}' | CLAUDE_PROJECT_DIR="$r" python3 "$HOOK" --check "$CHK" >/dev/null 2>&1; echo $?)
{ [ "$c1" = 2 ] && [ "$c2" = 0 ]; } && ok "GAP dedup" || no "GAP dedup (got $c1,$c2)"
rm -rf "$r"

echo "7) frontmatter 健壮性: 正文含整行 --- 不破坏解析"
r=$(mkrepo); mkdir -p "$r/lib" "$r/.claude/knowledge"; echo a > "$r/lib/A.txt"
( cd "$r" && git add -A && git "${GU[@]}" commit -q -m c1 )
sha=$(git -C "$r" rev-parse --short HEAD)
printf -- '---\nname: doc\ndescription: t\nsources:\n  - lib/**\nverified_at: %s\n---\n正文\n\n---\n分隔线后还有内容\n' "$sha" > "$r/.claude/knowledge/doc.md"
out=$( cd "$r" && python3 "$CHK" --report ); echo "$out" | grep -q "锚定文档: 1" && ok "frontmatter 仍解析(锚定计数=1)" || no "frontmatter 解析"
rm -rf "$r"

echo "8) --report 模式: 已同步项目应 exit0 且评估=健康"
r=$(mkrepo); mkdir -p "$r/lib"; echo a > "$r/lib/A.txt"
( cd "$r" && git add -A && git "${GU[@]}" commit -q -m c1 )
anchor "$r" doc "lib/**" "$(git -C "$r" rev-parse --short HEAD)"
out=$( cd "$r" && python3 "$CHK" --report ); code=$?
{ [ $code -eq 0 ] && echo "$out" | grep -q "评估: 健康"; } && ok "report 健康" || no "report (code=$code)"
rm -rf "$r"

echo "9) 让位: 项目自带 scripts/ 漂移脚本时,插件 hook 退让(exit0),否则正常 exit2"
r=$(mkrepo); mkdir -p "$r/lib"; echo a > "$r/lib/A.txt"
( cd "$r" && git add -A && git "${GU[@]}" commit -q -m c1 )
anchor "$r" doc "lib/**" "$(git -C "$r" rev-parse --short HEAD)"
echo b >> "$r/lib/A.txt"; ( cd "$r" && git add -A && git "${GU[@]}" commit -q -m c2 )   # 造 STALE
rm -f "$r/.claude/.drift-state"
cNo=$(echo '{}' | CLAUDE_PROJECT_DIR="$r" python3 "$HOOK" --check "$CHK" >/dev/null 2>&1; echo $?)
mkdir -p "$r/scripts"; echo '#' > "$r/scripts/check-knowledge-drift.py"   # 标记:本项目自带
rm -f "$r/.claude/.drift-state"
cYes=$(echo '{}' | CLAUDE_PROJECT_DIR="$r" python3 "$HOOK" --check "$CHK" >/dev/null 2>&1; echo $?)
{ [ "$cNo" = 2 ] && [ "$cYes" = 0 ]; } && ok "defer-to-local (无=2 有=0)" || no "defer (got 无=$cNo 有=$cYes)"
rm -rf "$r"

echo ""
echo "==== 结果: PASS=$PASS  FAIL=$FAIL ===="
[ $FAIL -eq 0 ] && { echo "全部通过 ✅"; exit 0; } || { echo "有失败 ❌"; exit 1; }
