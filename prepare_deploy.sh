#!/usr/bin/env bash
set -euo pipefail

# Override this if needed. When left unchanged, the script uses its own location.
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "$0")" && pwd)}"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "ERROR: PROJECT_DIR does not exist: $PROJECT_DIR" >&2
  exit 1
fi

if [[ ! -f "$PROJECT_DIR/monitor.py" ]]; then
  echo "ERROR: monitor.py not found under PROJECT_DIR: $PROJECT_DIR" >&2
  exit 1
fi

export PROJECT_DIR

python3 - <<'PY'
import os
import re
from pathlib import Path

project_dir = Path(os.environ["PROJECT_DIR"]).resolve()
project_dir_str = str(project_dir)


def replace_regex(path: Path, pattern: str, repl: str, *, count: int = 0) -> None:
    text = path.read_text(encoding="utf-8")
    new_text, n = re.subn(pattern, repl, text, count=count, flags=re.MULTILINE)
    if n == 0:
        raise SystemExit(f"ERROR: pattern not found in {path}")
    path.write_text(new_text, encoding="utf-8")


def replace_literal(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if old not in text:
        return
    path.write_text(text.replace(old, new), encoding="utf-8")


root = project_dir

# monitor.py: required
replace_regex(
    root / "monitor.py",
    r'^BASE_DIR = Path\(".*?"\)$',
    f'BASE_DIR = Path("{project_dir_str}")',
    count=1,
)

# cronjob_prompt.txt: required
cron_prompt = root / "cronjob_prompt.txt"
cron_text = cron_prompt.read_text(encoding="utf-8")
cron_text = re.sub(
    r"^【重要】.*(?:\r?\n)?",
    "",
    cron_text,
    count=1,
    flags=re.MULTILINE,
)
cron_text = cron_text.replace("/path/to/hermes-arxiv-agent", project_dir_str)
cron_prompt.write_text(cron_text, encoding="utf-8")

# Helper scripts: recommended
for helper in ("extract_pdf_info.py", "extract_affiliation.py"):
    helper_path = root / helper
    text = helper_path.read_text(encoding="utf-8")
    new_text = re.sub(
        r'Path\("/home/[^"]+/papers"\)',
        f'Path("{project_dir_str}/papers")',
        text,
        count=1,
    )
    if new_text != text:
        helper_path.write_text(new_text, encoding="utf-8")

# Viewer examples: optional normalization
for rel in ("viewer/README.md", "viewer/build_data.py", "viewer/run_viewer.py"):
    replace_literal(root / rel, "/home/wsg/.hermes/hermes-agent/venv/bin/python", "python3")

print(f"Patched repository for PROJECT_DIR={project_dir_str}")
print("Updated files:")
print("- monitor.py")
print("- cronjob_prompt.txt")
print("- extract_pdf_info.py")
print("- extract_affiliation.py")
print("- viewer/README.md")
print("- viewer/build_data.py")
print("- viewer/run_viewer.py")
print("")
print("Next step inside Hermes chat:")
print("1. Read the full current contents of cronjob_prompt.txt")
print("2. Send a Hermes slash command: /cron add <prompt>")
print("3. Do not try to run /cron add in bash or a system shell")
PY
