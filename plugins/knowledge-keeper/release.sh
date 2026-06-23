#!/usr/bin/env bash
# release.sh — 发布护栏。一条命令完成"回归→校验→打 tag→推送",任一不达标即拒绝发布。
# 用法:
#   bash release.sh --dry-run   # 只校验,不打 tag/不推送(建议先跑这个)
#   bash release.sh             # 校验通过后打 tag <插件名>-vX.Y.Z 并推送
# 校验项:① 回归全绿 ② plugin.json 版本未发布过(对应 tag 不存在)
#         ③ CHANGELOG.md 有该版本条目 ④ 工作树干净(全部已提交)
# 插件名自动取自所在目录名,故本脚本对所有插件通用,拷过去即用、无需改。
set -euo pipefail

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(git -C "$HERE" rev-parse --show-toplevel)"
NAME="$(basename "$HERE")"          # 插件名 = 目录名(如 knowledge-keeper)
PLUGIN_JSON="$HERE/.claude-plugin/plugin.json"
CHANGELOG="$HERE/CHANGELOG.md"

fail(){ echo "✗ $1" >&2; exit 1; }

# 1) 回归(不绿绝不发布)
echo "▶ 跑回归套件..."
bash "$HERE/test.sh" >/dev/null 2>&1 || fail "回归未通过,发布中止(先 bash test.sh 看详情)"
echo "✓ 回归全绿"

# 2) 读版本
VERSION="$(grep -E '"version"' "$PLUGIN_JSON" | head -1 | sed -E 's/.*"version"[^"]*"([^"]+)".*/\1/')"
[ -n "$VERSION" ] || fail "读不到 plugin.json 的 version"
TAG="$NAME-v$VERSION"
echo "  插件 $NAME · 版本 $VERSION → tag $TAG"

# 3) 版本必须比上次新:对应 tag 不能已存在
if git -C "$REPO" rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1; then
  fail "tag $TAG 已存在 —— 是不是忘了升 plugin.json 的 version?"
fi
echo "✓ 版本未发布过"

# 4) CHANGELOG 必须有该版本条目(点号转义,避免 . 通配误匹配)
VRE="${VERSION//./\\.}"
grep -qE "^#+ .*${VRE}" "$CHANGELOG" || fail "CHANGELOG.md 缺 $VERSION 的条目"
echo "✓ CHANGELOG 有 $VERSION 条目"

# 5) 工作树干净
[ -z "$(git -C "$REPO" status --porcelain)" ] || fail "有未提交改动,先提交再发布"
echo "✓ 工作树干净"

if [ "$DRY" = 1 ]; then
  echo "— dry-run:四项校验全过,未打 tag、未推送 —"
  exit 0
fi

# 6) 打 tag + 推送当前分支与 tag
git -C "$REPO" tag -a "$TAG" -m "$NAME $VERSION"
git -C "$REPO" push origin HEAD --follow-tags
echo "✅ 已发布 $TAG 并推送。"
echo "   同事侧让新版生效:/plugin marketplace update kensen-claude → /plugin update $NAME@kensen-claude → /reload-plugins"
