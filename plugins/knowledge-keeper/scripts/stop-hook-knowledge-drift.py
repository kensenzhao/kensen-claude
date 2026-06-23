#!/usr/bin/env python3
"""
Stop hook：会话结束跑知识漂移检测，仅在出现"新"漂移时极简提醒一次。· knowledge-keeper 插件版

与项目内置版的区别：检测脚本在插件里，故通过 --check 参数传入其路径；检测针对**当前项目**
(CLAUDE_PROJECT_DIR)运行。其余减噪逻辑一致：
  - 指纹去重：同一组漂移只提醒一次(状态存项目 .claude/.drift-state)。
  - 极简一行输出；exit 2 回灌给模型由其按 skill-maintenance 自主判断是否同步。
  - 双重防循环：指纹去重 + stop_hook_active。
  - 检测脚本若判定本项目没用这套体系，会自己静默 exit 0，本 hook 随之静默。

hooks.json 里这样调用：
  python3 "${CLAUDE_PLUGIN_ROOT}/scripts/stop-hook-knowledge-drift.py" --check "${CLAUDE_PLUGIN_ROOT}/scripts/check-knowledge-drift.py"
"""
import hashlib
import json
import os
import re
import subprocess
import sys

STATE_FILE = ".claude/.drift-state"
MAINTENANCE_SKILL = "skill-maintenance"


def get_check_path():
    argv = sys.argv
    if "--check" in argv:
        i = argv.index("--check")
        if i + 1 < len(argv):
            return argv[i + 1]
    return None


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        data = {}

    if data.get("stop_hook_active"):
        sys.exit(0)

    check_script = get_check_path()
    if not check_script or not os.path.exists(check_script):
        sys.exit(0)

    base = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()

    # 状态文件放"git 仓库根"——避免 CLAUDE_PROJECT_DIR 缺失时写错位置/污染插件目录。
    rp = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=base, capture_output=True, text=True)
    project_root = rp.stdout.strip() if rp.returncode == 0 else base

    # 让位：若本项目自带漂移脚本(自包含,如把脚本焊进仓库的团队项目)，由它自己的 hook 管，
    # 插件不重复触发(否则双 hook + 共用 .drift-state 互相打架)。
    for marker in ("scripts/check-knowledge-drift.py", "scripts/stop-hook-knowledge-drift.py"):
        if os.path.exists(os.path.join(project_root, marker)):
            sys.exit(0)

    res = subprocess.run(["python3", check_script], capture_output=True, text=True, cwd=base)
    state_path = os.path.join(project_root, STATE_FILE)

    if res.returncode != 3:
        if os.path.exists(state_path):
            try:
                os.remove(state_path)
            except OSError:
                pass
        sys.exit(0)

    # 抓所有 "• <路径/模块>" 条目(STALE 文档 / GAP 目录 / ERR),不能只抓 .md
    # ——否则"只有 GAP"时指纹恒为空字符串 SHA，去重会把 GAP 永久静默。
    items = sorted(set(re.findall(r"^\s*•\s+(\S+)", res.stdout, re.MULTILINE)))
    signature = hashlib.sha1("\n".join(items).encode()).hexdigest()

    last = ""
    if os.path.exists(state_path):
        try:
            last = open(state_path, encoding="utf-8").read().strip()
        except OSError:
            last = ""

    if signature == last:
        sys.exit(0)

    try:
        os.makedirs(os.path.dirname(state_path), exist_ok=True)
        open(state_path, "w", encoding="utf-8").write(signature)
    except OSError:
        pass

    sys.stderr.write(
        f"【知识漂移】检测到 {len(items)} 处需同步(知识文档过时或业务模块未覆盖)。"
        f"如有需要用 {MAINTENANCE_SKILL} 技能同步（核实代码→更新→推进 verified_at）；"
        "详情可跑插件内 check-knowledge-drift.py。"
        "（同一组漂移只提醒一次；若本次改动不影响这些文档，忽略即可。）\n"
    )
    sys.exit(2)


if __name__ == "__main__":
    main()
