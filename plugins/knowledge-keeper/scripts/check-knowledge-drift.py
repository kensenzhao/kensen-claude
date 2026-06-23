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
    out, i = [], 0
    while i < len(g):
        c = g[i]
        if c == "*":
            if g[i:i + 2] == "**":
                out.append(".*"); i += 2; continue
            out.append("[^/]*")
        elif c in ".+()[]{}^$|\\":
            out.append("\\" + c)
        else:
            out.append(c)
        i += 1
    return re.compile("^" + "".join(out))


def git_commit_exists(sha, cwd):
    return subprocess.run(["git", "cat-file", "-e", sha], cwd=cwd, capture_output=True).returncode == 0


def changed_since(sha, cwd):
    out = subprocess.run(["git", "diff", "--name-only", f"{sha}..HEAD"], cwd=cwd, capture_output=True, text=True)
    return [l for l in out.stdout.splitlines() if l.strip()]


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


def main():
    root = repo_root()
    rootstr = str(root)

    docs = []
    for base in DOC_DIRS:
        p = root / base
        if p.exists():
            docs.extend(sorted(p.rglob("*.md")))

    anchored = 0
    stale, broken, all_sources = [], [], []
    for doc in docs:
        rel = doc.relative_to(root)
        # 只读前 64KB 解析 frontmatter，防超大/恶意文件吃内存
        with doc.open(encoding="utf-8", errors="replace") as f:
            head = f.read(65536)
        sources, verified_at = parse_frontmatter(head)
        if not sources or not verified_at:
            continue
        anchored += 1
        all_sources.extend(sources)
        if not git_commit_exists(verified_at, rootstr):
            broken.append(f"{rel}: verified_at={verified_at} 在本仓库不存在")
            continue
        changed = changed_since(verified_at, rootstr)
        if not changed:
            continue
        regexes = [glob_to_regex(g) for g in sources]
        hits = [f for f in changed if any(rx.match(f) for rx in regexes)]
        if hits:
            stale.append((str(rel), verified_at, len(hits), hits[:8],
                          "" if len(hits) <= 8 else f" …(+{len(hits) - 8})"))

    # 无锚定文档 -> 本项目没用这套体系，静默退出（插件无感）
    if anchored == 0:
        sys.exit(0)

    # GAP：仅当项目提供了模块 glob 配置时才检查
    gap_notes = []
    module_globs = load_module_globs(root)
    if module_globs:
        norm_sources = [s.split("*")[0].rstrip("/") for s in all_sources]
        for mg in module_globs:
            # 用绝对 glob 再转回仓库根相对路径，避免依赖进程 cwd(已去掉 chdir)
            for mod_abs in _glob.glob(os.path.join(rootstr, mg)):
                if not os.path.isdir(mod_abs) or os.path.basename(mod_abs) in IGNORE_DIRS:
                    continue
                mod = os.path.relpath(mod_abs, rootstr)
                if not any(s == mod or s.startswith(mod + "/") for s in norm_sources):
                    gap_notes.append(mod)

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
