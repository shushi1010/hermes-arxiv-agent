---
name: hermes-arxiv-agent-deploy
description: Use this skill inside a Hermes conversation when a user wants Hermes to deploy genggng/hermes-arxiv-agent end to end, including cloning the GitHub repo, installing Python dependencies, checking Feishu readiness, running `prepare_deploy.sh` to patch hardcoded paths, and creating a daily cron job via `/cron add <prompt>` from the patched `cronjob_prompt.txt`.
---

# Hermes Arxiv Agent Deploy

This skill is for deployment and maintenance of the GitHub repository `genggng/hermes-arxiv-agent`.

This skill is only meant to be used inside Hermes. Do not add Hermes installation checks or Hermes bootstrap guidance here.

Use it when the user wants any of the following:

- install the project from GitHub
- set up or repair the daily arXiv monitoring cron job
- initialize a new machine for this project
- re-create the cron prompt with the correct local path

The repository defaults to monitoring quantization-related papers. If the user wants a different research topic, update `search_keywords.txt` during deployment.

Do not assume the current local folder name matches the remote repository name. Treat the GitHub repository name `hermes-arxiv-agent` as canonical for clone and deployment instructions.

## Deployment Goal

Bring the user to a working state where:

1. Feishu/Lark gateway is configured.
2. The repo `https://github.com/genggng/hermes-arxiv-agent.git` is cloned locally.
3. Python dependencies are installed.
4. Repository files that contain deployment-specific local paths are updated to the real local project directory.
5. A Hermes cron job exists and points to the real local project directory.

Because this skill runs inside Hermes, Hermes itself is already present by assumption.
If Feishu is not configured, that is a deploy-time prerequisite to surface, not a reason to discuss Hermes installation.

## Required Workflow

Follow this order unless the user explicitly asks for a partial action.

### 1. Verify prerequisites

Check:

- Python 3 is available
- `pip` or `pip3` is available

If Feishu/Lark is not configured, direct the user to run:

```bash
hermes gateway setup
```

### 2. Clone or locate the repository

Preferred default:

```bash
git clone https://github.com/genggng/hermes-arxiv-agent.git
cd hermes-arxiv-agent
```

If the repository already exists locally, reuse it instead of recloning.

The effective project directory must be captured as an absolute path and reused in later steps. Refer to it as `PROJECT_DIR`.

### 3. Install runtime dependencies

Run inside `PROJECT_DIR`:

```bash
pip install openpyxl requests pdfplumber
```

If the environment uses `pip3`, use that instead.

Also note the repository default search scope:

- the default query in `search_keywords.txt` targets quantization-related LLM papers
- if the user wants another topic, edit `search_keywords.txt` before the first scheduled run

### 4. Run the deployment patch script

Run this script inside the checked-out repository:

```bash
bash prepare_deploy.sh
```

The script uses one deployment variable:

- `PROJECT_DIR`

If `PROJECT_DIR` is not supplied, the script uses its own directory as the project root. That is the preferred path, because it avoids manual mistakes after clone.

The script is responsible for:

- patching `monitor.py` so `BASE_DIR` matches the real local checkout
- patching `cronjob_prompt.txt` so placeholder paths are replaced
- removing the human-only path reminder from `cronjob_prompt.txt`
- normalizing helper-script fallback paths in `extract_pdf_info.py` and `extract_affiliation.py`
- replacing machine-specific Python executable examples in `viewer/` with `python3`

If the user wants manual override, run:

```bash
PROJECT_DIR=/absolute/path/to/hermes-arxiv-agent bash prepare_deploy.sh
```

### 5. Understand the current path constraint

Current versions of `monitor.py` use a hardcoded project base directory. Because of that, both code and cron prompt must be patched to the real absolute path of the deployed checkout.

This means:

- do not use the original repository checkout without patching hardcoded paths
- do not leave placeholder paths such as `/path/to/hermes-arxiv-agent`
- do not leave `monitor.py` pointing at the author's local machine
- always finish path patching before creating the cron job

### 6. Use the patched `cronjob_prompt.txt` as the cron payload

After step 4, `cronjob_prompt.txt` should already contain the correct project path and should no longer contain the human-only path-replacement reminder.

Use the full current contents of the patched `cronjob_prompt.txt` as the exact `<prompt>` payload for:

```text
/cron add <prompt>
```

Do not rewrite the prompt from memory. Read it from the patched file and use it directly.
This is a Hermes chat slash command, not a bash command.
Do not try to execute `/cron add` through `bash`, `sh`, or `subprocess`.

Verify the patched file now references paths under `PROJECT_DIR`, for example:

- `PROJECT_DIR/new_papers.json`
- `PROJECT_DIR/papers_record.xlsx`
- `PROJECT_DIR/monitor.py`

### 7. Create the cron job

Create the job inside the Hermes conversation using the standard slash-command form with the exact current contents of `cronjob_prompt.txt`.

After creation, confirm:

- prompt contains the real absolute path
- the job is listed in `/cron list`
- the business instructions from `cronjob_prompt.txt` were preserved exactly

### 8. Smoke test

Prefer one of these:

- run `python3 monitor.py` manually once inside `PROJECT_DIR`
- or use `/cron run <job_id>` after the cron is created

Check whether:

- `new_papers.json` is produced
- `papers_record.xlsx` exists or is updated
- `papers/` receives downloaded PDFs when new papers are found

## Agent Behavior Rules

- Prefer automation over asking the user to hand-edit prompt text.
- Do not ask the user to rename their local directory.
- Keep the repository name `hermes-arxiv-agent` in clone instructions and user-facing descriptions.
- If local folder names differ, adapt by substituting the actual absolute path rather than forcing a rename.
- When reconfiguring cron, patch the repository files first and then reuse the patched `cronjob_prompt.txt`.
- Prefer `prepare_deploy.sh` over ad hoc manual edits, because it centralizes all known path fixes behind one variable.
- Do not paraphrase or simplify the substantive task instructions from `cronjob_prompt.txt`.
- Treat the patched `cronjob_prompt.txt` file as the source of truth for cron behavior.
- Treat `/cron add` and `/cron list` as Hermes chat commands, not shell commands.
- Treat `monitor.py` as a required deployment patch target when it contains the author's local absolute path.
- Also correct any remaining repository-local hardcoded paths you discover during deployment.

## Path Handling Guidance

The current implementation is deployment-fragile because both code and cron prompt depend on an absolute path.

Under the current no-code-change constraint, the correct approach is:

1. Determine `PROJECT_DIR` after clone or discovery.
2. Run `prepare_deploy.sh`.
3. Confirm that `monitor.py` and `cronjob_prompt.txt` now reference the correct absolute project path.
4. Use the patched `cronjob_prompt.txt` file content directly when creating or updating cron.

If future code changes are allowed, recommend this improvement:

- make `monitor.py` derive its base directory from `__file__`
- use paths relative to the repository root
- remove all absolute project-root assumptions from helper scripts too

That is the long-term fix. Until then, path substitution is mandatory.

## Expected User-Facing Outcome

After successful use of this skill, the user should only need Hermes for normal operations:

- view cron jobs
- rerun the job manually
- update keywords
- inspect generated Excel and viewer output

The user should not need to manually edit repository paths in prompt text.
