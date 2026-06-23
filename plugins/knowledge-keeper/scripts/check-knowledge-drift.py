#!/usr/bin/env python3
"""
check-knowledge-drift.py — 知识漂移检测（确定性、零 LLM 成本）· knowledge-keeper 插件版

与项目内置版的区别：**零配置即可用**，便于插件在任意项目通用。
  - STALE 检测：只读各文档 frontmatter 的 sources/verified_at，完全项目无关，无需配置。
  - GAP 检测：可选。若项目根存在 .claude/knowledge-drift.config(每行一个业务模块 glob,# 注释)，
              才做覆盖缺口检查；否则跳过 GAP。
  - 惰性/无感：项目里若没有任何带 sources+verified_at 的锚定文档，直接静默 exit 0
              —— 这样在没用这套体系的项目里，插件 hook 完全无感。

退出码：0=无漂移(静默)  3=发现 STALE/GAP(stdout 输出详情)
依赖：python3 标准库 + git。在哪个项目跑就检测哪个项目(靠 git rev-parse 定位仓库根)。
"""
import glob as _glob
import os
import re
import subprocess
import sys
from pathlib import Path

DOC_DIRS = [".claude/knowledge", ".claude/skills"]
CONFIG_FILE = ".claude/knowledge-drift.config"   # 可选：每行一个业务模块 glob
IGNORE_DIRS = {"target", "build", "dist", "node_modules", ".git", "out", "bin"}


def repo_root():
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(0)  # 非 git 仓库：静默
    return Path(out.stdout.strip())


def parse_frontmatter(text):
    if not text.startswith("---"):
        return None, None
    body = text[3:]
    # 结束围栏必须是一整行 ---(允许尾随空白)，而非正文里任意 "---" 前缀
    m = re.search(r"(?m)^---[ \t]*$", body)
    if not m:
        return None, None
    fm = body[:m.start()]
    verified_at, sources, in_sources = None, [], False
    for raw in fm.splitlines():
        line = raw.rstrip()
        if not line:
            continue
        m = re.match(r"^verified_at:\s*(.+)$", line)
        if m:
            verified_at = m.group(1).strip().strip("'\"")
            in_sources = False
            continue
        if re.match(r"^sources:\s*$", line):
            in_sources = True
            continue
        if in_sources:
            item = re.match(r"^\s*-\s*(.+)$", line)
            if item:
                sources.append(item.group(1).strip().strip("'\""))
            elif re.match(r"^\S", line):
                in_sources = False
    return (sources or None), verified_at


def glob_to_regex(g):
    """gitignore 风格的 glob→正则。三条关键语义(均有回归用例)：
      - `**` 跨目录且含零层：`a/**/b` 匹配 `a/b` 与 `a/x/b`。
      - 尾部单 `*` 收到段末：`lib/*` 只匹配直接子项,不越过 `/`。
      - 非通配结尾按"精确或目录前缀"收口：`src` 匹配 `src`、`src/x`,但**不**匹配 `srcfoo`
        (修复裸前缀过匹配导致的 STALE 误报)。
    """
    out, i, n = [], 0, len(g)
    while i < n:
        c = g[i]
        if c == "*":
            if g[i:i + 2] == "**":
                j = i + 2
                if j < n and g[j] == "/":
                    out.append("(?:.*/)?"); i = j + 1; continue  # `**/` 含零层目录
                out.append(".*"); i = j; continue                # 尾部/裸 `**`:开放
            out.append("[^/]*"); i += 1; continue                # 段内单 `*`
        if c in ".+()[]{}^$|\\":
            out.append("\\" + c)
        else:
            out.append(c)
        i += 1
    pat = "".join(out)
    if g.endswith("**"):
        return re.compile("^" + pat)              # 递归:开放结尾
    if g.endswith("*"):
        return re.compile("^" + pat + "$")        # 尾部单 *:收到段末,不越目录
    return re.compile("^" + pat + "(?:/|$)")       # 精确路径/目录前缀,收口防裸前缀误匹配


def git_commit_exists(sha, cwd):
    return subprocess.run(["git", "cat-file", "-e", sha], cwd=cwd, capture_output=True).returncode == 0


def is_shallow_repo(cwd):
    # 浅克隆(git clone --depth N)里历史 SHA 多半不在本地,据此让"锚点异常"静默,
    # 避免团队成员浅克隆后首个会话被刷一屏假异常。
    out = subprocess.run(["git", "rev-parse", "--is-shallow-repository"], cwd=cwd, capture_output=True, text=True)
    return out.stdout.strip() == "true"


def changed_since(sha, cwd):
    out = subprocess.run(["git", "diff", "--name-only", f"{sha}..HEAD"], cwd=cwd, capture_output=True, text=True)
    return [l for l in out.stdout.splitlines() if l.strip()]


def commits_behind(sha, cwd):
    out = subprocess.run(["git", "rev-list", "--count", f"{sha}..HEAD"], cwd=cwd, capture_output=True, text=True)
    try:
        return int(out.stdout.strip())
    except ValueError:
        return None


def load_module_globs(root):
    cfg = root / CONFIG_FILE
    if not cfg.exists():
        return None
    globs = []
    for line in cfg.read_text(encoding="utf-8", errors="replace").splitlines():
        s = line.strip()
        if s and not s.startswith("#"):
            globs.append(s)
    return globs or None


def gap_check(rootstr, all_sources):
    """返回未被任何 doc 的 sources 覆盖的业务模块目录(需项目提供 module glob 配置)。"""
    gap = []
    module_globs = load_module_globs(Path(rootstr))
    if module_globs:
        norm = [s.split("*")[0].rstrip("/") for s in all_sources]
        for mg in module_globs:
            for mod_abs in _glob.glob(os.path.join(rootstr, mg)):
                if not os.path.isdir(mod_abs) or os.path.basename(mod_abs) in IGNORE_DIRS:
                    continue
                mod = os.path.relpath(mod_abs, rootstr)
                if not any(s == mod or s.startswith(mod + "/") for s in norm):
                    gap.append(mod)
    return sorted(set(gap))


def print_report(rootstr, anchored, rows, gaps, broken):
    """知识健康报告(--report)：新鲜度+覆盖度,判断这个项目里知识体系用得好不好。"""
    head = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=rootstr,
                          capture_output=True, text=True).stdout.strip() or "?"
    print(f"知识健康报告 · {os.path.basename(rootstr)} @ {head}")
    if anchored == 0:
        print("  本项目没有任何带 sources+verified_at 的锚定文档（未启用本知识体系）。")
        return
    print(f"  锚定文档: {anchored}")

    def short(rel):  # 去掉 .claude/ 前缀并截断,保证列对齐
        s = rel[len(".claude/"):] if rel.startswith(".claude/") else rel
        return s if len(s) <= 38 else "…" + s[-37:]

    print(f"  {'文档':<40}{'verified_at':<12}{'滞后':>5}{'STALE':>6}{'未验证':>6}{'src':>5}")
    for rel, va, lag, is_stale, unv, nsrc, ok in rows:
        lag_s = "?" if (lag is None) else str(lag)
        print(f"  {short(rel):<40}{va:<12}{lag_s:>5}{('是' if is_stale else '否'):>6}{unv:>6}{nsrc:>5}")
    n_stale = sum(1 for r in rows if r[3])
    max_lag = max([r[2] for r in rows if r[2] is not None] or [0])
    tot_unv = sum(r[4] for r in rows)
    if gaps:
        print(f"  覆盖缺口(GAP): {len(gaps)}  → " + ", ".join(gaps))
    elif load_module_globs(Path(rootstr)) is not None:
        print("  覆盖缺口(GAP): 0（已配 .claude/knowledge-drift.config,无缺口）")
    else:
        print("  覆盖缺口(GAP): 0（未配 .claude/knowledge-drift.config,跳过 GAP 检测）")
    if broken:
        print(f"  锚点异常: {len(broken)}  → " + "; ".join(broken))
    print(f"  小结: STALE {n_stale} · GAP {len(gaps)} · 未验证合计 {tot_unv} · 最大滞后 {max_lag} commit(仅供参考)")
    # 健康判据：STALE/GAP/锚点异常 才是真问题；滞后大但 STALE=0 说明那些提交没碰被记录的代码,不算问题
    if n_stale == 0 and not gaps and not broken:
        print(f"  评估: 健康" + ("（滞后偏大但无 STALE,即近期提交未触及已记录代码,正常）" if max_lag > 10 else ""))
    else:
        print(f"  评估: 需关注 —— " + "；".join(filter(None, [
            f"{n_stale} 篇 STALE 待同步" if n_stale else "",
            f"{len(gaps)} 个模块无覆盖" if gaps else "",
            f"{len(broken)} 处锚点异常" if broken else "",
        ])))


def main():
    report = "--report" in sys.argv
    root = repo_root()
    rootstr = str(root)

    docs = []
    for base in DOC_DIRS:
        p = root / base
        if p.exists():
            docs.extend(sorted(p.rglob("*.md")))

    shallow = is_shallow_repo(rootstr)
    # 按 verified_at 分组缓存:刚 bootstrap 时多篇文档同一 SHA,从 N 次 git diff 降到 1 次。
    diff_cache, exists_cache = {}, {}

    def commit_ok_cached(sha):
        if sha not in exists_cache:
            exists_cache[sha] = git_commit_exists(sha, rootstr)
        return exists_cache[sha]

    def changed_cached(sha):
        if sha not in diff_cache:
            diff_cache[sha] = changed_since(sha, rootstr)
        return diff_cache[sha]

    anchored = 0
    stale, broken, all_sources, rows = [], [], [], []
    for doc in docs:
        rel = str(doc.relative_to(root))
        # 只读前 64KB 解析 frontmatter，防超大/恶意文件吃内存
        with doc.open(encoding="utf-8", errors="replace") as f:
            head = f.read(65536)
        sources, verified_at = parse_frontmatter(head)
        if not sources or not verified_at:
            continue
        anchored += 1
        all_sources.extend(sources)
        commit_ok = commit_ok_cached(verified_at)
        # 浅克隆里 SHA 缺失多为历史被截断而非真异常 -> 静默,不报"锚点异常"也不误判 STALE
        if not commit_ok and not shallow:
            broken.append(f"{rel}: verified_at={verified_at} 不存在")
        hits = []
        if commit_ok:
            changed = changed_cached(verified_at)
            if changed:
                regexes = [glob_to_regex(g) for g in sources]
                hits = [f for f in changed if any(rx.match(f) for rx in regexes)]
        if hits:
            stale.append((rel, verified_at, len(hits), hits[:8],
                          "" if len(hits) <= 8 else f" …(+{len(hits) - 8})"))
        if report:
            lag = commits_behind(verified_at, rootstr) if commit_ok else None
            unv = doc.read_text(encoding="utf-8", errors="replace").count("⚠️未验证")
            rows.append((rel, verified_at, lag, bool(hits), unv, len(sources), commit_ok))

    # 报告模式：打印健康度，恒 exit 0
    if report:
        gaps = gap_check(rootstr, all_sources)
        print_report(rootstr, anchored, rows, gaps, broken)
        sys.exit(0)

    # 无锚定文档 -> 本项目没用这套体系，静默退出（插件无感）
    if anchored == 0:
        sys.exit(0)

    gap_notes = gap_check(rootstr, all_sources)

    if not (stale or gap_notes or broken):
        sys.exit(0)

    print("⚠️  知识漂移检测：发现需同步的文档")
    if stale:
        print("\n[STALE] 源码已变更，以下文档可能过时（同步后把 verified_at 推到 HEAD）：")
        for rel, va, n, shown, more in stale:
            print(f"  • {rel}  (verified_at={va}, {n} 个相关文件变更{more})")
            for f in shown:
                print(f"      - {f}")
    if gap_notes:
        print("\n[GAP] 以下业务模块似乎没有任何知识文档覆盖：")
        for m in sorted(set(gap_notes)):
            print(f"  • {m}")
    if broken:
        print("\n[ERR] frontmatter 锚点异常：")
        for b in broken:
            print(f"  • {b}")
    sys.exit(3)


if __name__ == "__main__":
    main()
