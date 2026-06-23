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

echo "10) glob 收口: 裸前缀 source='src' 不应误报兄弟目录 srcfoo (回归 B1)"
r=$(mkrepo); mkdir -p "$r/src" "$r/srcfoo"; echo a > "$r/src/A.txt"; echo a > "$r/srcfoo/B.txt"
( cd "$r" && git add -A && git "${GU[@]}" commit -q -m c1 )
anchor "$r" doc "src" "$(git -C "$r" rev-parse --short HEAD)"   # 裸前缀(无 /** )
echo b >> "$r/srcfoo/B.txt"; ( cd "$r" && git add -A && git "${GU[@]}" commit -q -m c2 )  # 只改兄弟目录
( cd "$r" && python3 "$CHK" ); [ $? -eq 0 ] && ok "裸前缀不过匹配(srcfoo 改动不触发)" || no "B1 过匹配仍在"
echo c >> "$r/src/A.txt"; ( cd "$r" && git add -A && git "${GU[@]}" commit -q -m c3 )     # 改本目录
out=$( cd "$r" && python3 "$CHK" ); { [ $? -eq 3 ] && echo "$out" | grep -q "doc.md"; } && ok "裸前缀仍能正常检出本目录" || no "B1 漏报本目录"
rm -rf "$r"

echo "11) glob **: 'a/**/b' 含零层目录 a/b (回归 B2)"
r=$(mkrepo); mkdir -p "$r/a"; echo x > "$r/a/b"
( cd "$r" && git add -A && git "${GU[@]}" commit -q -m c1 )
anchor "$r" doc "a/**/b" "$(git -C "$r" rev-parse --short HEAD)"
echo y >> "$r/a/b"; ( cd "$r" && git add -A && git "${GU[@]}" commit -q -m c2 )
out=$( cd "$r" && python3 "$CHK" ); { [ $? -eq 3 ] && echo "$out" | grep -q "doc.md"; } && ok "** 匹配零层 a/b" || no "B2 零层漏匹配"
rm -rf "$r"

echo "12) glob 尾部单 *: 'lib/*' 不跨目录(lib/sub/deep 改动不触发)"
r=$(mkrepo); mkdir -p "$r/lib/sub"; echo a > "$r/lib/A.txt"; echo a > "$r/lib/sub/deep.txt"
( cd "$r" && git add -A && git "${GU[@]}" commit -q -m c1 )
anchor "$r" doc "lib/*" "$(git -C "$r" rev-parse --short HEAD)"
echo b >> "$r/lib/sub/deep.txt"; ( cd "$r" && git add -A && git "${GU[@]}" commit -q -m c2 )
( cd "$r" && python3 "$CHK" ); [ $? -eq 0 ] && ok "尾部单 * 不越目录" || no "lib/* 越目录误报"
rm -rf "$r"

echo "13) 浅克隆: verified_at 不在本地时静默(不报锚点异常)"
r=$(mkrepo); mkdir -p "$r/lib"; echo a > "$r/lib/A.txt"
( cd "$r" && git add -A && git "${GU[@]}" commit -q -m c1 )
anchor "$r" doc "lib/**" "deadbeef"   # 不存在的 SHA
# 真实浅克隆:克隆深度 1
shallow=$(mktemp -d); rm -rf "$shallow"
git clone -q --depth 1 "file://$r" "$shallow" 2>/dev/null
mkdir -p "$shallow/.claude/knowledge"
printf -- '---\nname: doc\ndescription: t\nsources:\n  - lib/**\nverified_at: deadbeef\n---\n# body\n' > "$shallow/.claude/knowledge/doc.md"
out=$( cd "$shallow" && python3 "$CHK" ); code=$?
{ [ $code -eq 0 ] && ! echo "$out" | grep -q "不存在"; } && ok "浅克隆静默(code=$code)" || no "浅克隆仍报异常(code=$code)"
# 对照:非浅克隆同样缺失 SHA 应报锚点异常 exit3
out2=$( cd "$r" && python3 "$CHK" ); { [ $? -eq 3 ] && echo "$out2" | grep -q "不存在"; } && ok "非浅克隆缺失 SHA 仍报异常" || no "非浅克隆漏报异常"
rm -rf "$r" "$shallow"

echo "14) --report GAP 措辞: 已配置且零缺口 不应显示'未配'"
r=$(mkrepo); mkdir -p "$r/lib"; echo a > "$r/lib/A.txt"
( cd "$r" && git add -A && git "${GU[@]}" commit -q -m c1 )
anchor "$r" doc "lib/**" "$(git -C "$r" rev-parse --short HEAD)"
printf 'lib\n' > "$r/.claude/knowledge-drift.config"   # 配了,且 lib 已被覆盖 -> GAP 0
out=$( cd "$r" && python3 "$CHK" --report )
{ echo "$out" | grep -q "已配" && ! echo "$out" | grep -q "GAP): 0（未配"; } && ok "GAP 措辞区分已配/未配" || no "GAP 措辞仍误导"
# 对照:未配置时应显示'未配/跳过'
r2=$(mkrepo); mkdir -p "$r2/lib"; echo a > "$r2/lib/A.txt"
( cd "$r2" && git add -A && git "${GU[@]}" commit -q -m c1 )
anchor "$r2" doc "lib/**" "$(git -C "$r2" rev-parse --short HEAD)"
out2=$( cd "$r2" && python3 "$CHK" --report )
echo "$out2" | grep -q "未配" && ok "未配置时提示未配" || no "未配置措辞缺失"
rm -rf "$r" "$r2"

echo ""
echo "==== 结果: PASS=$PASS  FAIL=$FAIL ===="
[ $FAIL -eq 0 ] && { echo "全部通过 ✅"; exit 0; } || { echo "有失败 ❌"; exit 1; }
