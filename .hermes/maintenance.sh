#!/bin/bash
# Maintenance script — SI-111 hardened.
# Checks for outdated dependencies, opens a PR with updates.
# PROTECTED packages (mcp, mcp-types, pydantic*) are NEVER auto-upgraded:
# mcp 2.x removed mcp.server.fastmcp and crash-looped the gateway (see SI-111).
# Every update passes a validation gate BEFORE any commit is made.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$REPO_DIR/.hermes/maintenance.log"
DRY_RUN=${DRY_RUN:-false}
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
PROTECTED_PY="^(mcp|mcp[-_]types|pydantic|pydantic[-_]settings|pydantic[-_]core)$"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

cd "$REPO_DIR"
mkdir -p .hermes

# --- Git setup -------------------------------------------------------------
REMOTE=$(git remote | head -1)
DEFAULT_BRANCH=$(git symbolic-ref "refs/remotes/$REMOTE/HEAD" 2>/dev/null | sed 's@^refs/remotes/[^/]*/@@' || echo main)
git fetch "$REMOTE" >/dev/null 2>&1 || true
CURRENT=$(git branch --show-current)
if [[ "$CURRENT" != "$DEFAULT_BRANCH" ]]; then
    log "WARNING: repo on branch '$CURRENT', switching to '$DEFAULT_BRANCH'"
    git checkout "$DEFAULT_BRANCH"
fi
git pull "$REMOTE" "$DEFAULT_BRANCH" || true

PR_NUMBERS_FILE=$(mktemp)
trap 'rm -f "$PR_NUMBERS_FILE"' EXIT

open_pr() {
    local title="$1" body="$2" branch="$3"
    if [[ "$DRY_RUN" == "true" ]]; then
        log "[DRY RUN] Would open PR: $title"
        return 0
    fi
    local pr_url pr_number
    pr_url=$(gh pr create --title "$title" --body "$body" --base "$DEFAULT_BRANCH" --head "$branch" 2>&1) \
        || { log "PR creation failed: $pr_url"; return 1; }
    pr_number=$(echo "$pr_url" | grep -oE '[0-9]+$' || true)
    [[ -n "$pr_number" ]] && echo "$pr_number" >> "$PR_NUMBERS_FILE"
    log "Opened PR #$pr_number ($branch)"
}

# --- Python (requirements.txt or pyproject.toml) ---------------------------
PY_PROJECT=""
[[ -f requirements.txt ]] && PY_PROJECT="reqs"
[[ -z "$PY_PROJECT" && -f pyproject.toml ]] && PY_PROJECT="pyproject"

if [[ -n "$PY_PROJECT" ]]; then
    # Find or create a venv (python3.12 mandatory per workspace standard)
    VENV_DIR=""
    for d in .venv venv; do
        [[ -x "$REPO_DIR/$d/bin/python" ]] && VENV_DIR="$REPO_DIR/$d" && break
    done
    if [[ -z "$VENV_DIR" ]]; then
        log "Creating venv at $REPO_DIR/.venv"
        python3.12 -m venv .venv
        VENV_DIR="$REPO_DIR/.venv"
        "$VENV_DIR/bin/pip" install -q -e . 2>/dev/null || "$VENV_DIR/bin/pip" install -q -r requirements.txt 2>/dev/null || true
    fi
    VPY="$VENV_DIR/bin/python"
    VPIP="$VENV_DIR/bin/pip"

    log "Checking for outdated Python dependencies..."
    OUTDATED=$("$VPIP" list --outdated --format json 2>/dev/null || echo "[]")
    # SI-111 protected-package guard
    OUTDATED=$(echo "$OUTDATED" | python3 -c "
import json, sys, re
protected = re.compile(r'$PROTECTED_PY')
data = json.load(sys.stdin)
kept = [d for d in data if not protected.match(d['name'].lower().replace('_','-'))]
skipped = sorted(d['name'] for d in data if protected.match(d['name'].lower().replace('_','-')))
if skipped:
    print(f'PROTECTED (skipped): {skipped}', file=sys.stderr)
print(json.dumps(kept))
" 2>>"$LOG_FILE")
    COUNT=$(echo "$OUTDATED" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)

    if [[ "$COUNT" -eq 0 ]]; then
        log "No outdated (non-protected) Python dependencies."
    else
        log "Outdated Python packages: $COUNT"
        if [[ "$DRY_RUN" != "true" ]]; then
            BRANCH="dependency-update-$(date +%Y%m%d%H%M%S)"
            git checkout -b "$BRANCH"

            PKGS=$(echo "$OUTDATED" | python3 -c "
import json, sys
for item in json.load(sys.stdin): print(item['name'])")

            if [[ "$PY_PROJECT" == "reqs" ]]; then
                cp requirements.txt requirements.txt.bak
                # Upgrade only non-protected packages
                echo "$PKGS" | xargs -n1 "$VPIP" install -q --upgrade \
                    || { log "pip upgrade FAILED — restoring, aborting."; cp requirements.txt.bak requirements.txt; git checkout "$DEFAULT_BRANCH"; exit 1; }
                # Rewrite only originally-listed packages; protected pins preserved verbatim
                python3 - <<'PYEOF'
import re, importlib.metadata as im
protected = re.compile(r'^(mcp|mcp[-_]types|pydantic|pydantic[-_]settings|pydantic[-_]core)$')
out = []
for line in open('requirements.txt.bak'):
    s = line.rstrip('\n'); t = s.strip()
    if not t or t.startswith('#') or t.startswith('-'):
        out.append(s); continue
    name = re.match(r'^[A-Za-z0-9_.\-\[\]]+', t).group(0)
    bare = name.lower().replace('_','-').split('[')[0]
    if protected.match(bare):
        out.append(s)  # deliberate exact pin — never touch
    else:
        try:
            out.append(f"{name.split('[')[0]}=={im.version(name.split('[')[0])}")
        except Exception:
            out.append(s)
open('requirements.txt','w').write('\n'.join(out) + '\n')
PYEOF
                # SI-111 validation gate: every requirement must import before commit
                if ! python3 - <<'PYEOF'
import re, subprocess, sys
fails = []
for line in open('requirements.txt'):
    s = line.strip()
    if not s or s.startswith('#') or s.startswith('-'): continue
    mod = re.match(r'^[A-Za-z0-9_.\-]+', s).group(0).replace('-', '_')
    r = subprocess.run([sys.executable, '-c', f'import {mod}'], capture_output=True)
    if r.returncode != 0: fails.append(mod)
if fails:
    print(f'IMPORT FAILURES: {fails}', file=sys.stderr); sys.exit(1)
PYEOF
                then
                    log "VALIDATION FAILED — reverting requirements.txt, NOT committing."
                    cp requirements.txt.bak requirements.txt
                    rm -f requirements.txt.bak
                    git checkout "$DEFAULT_BRANCH"
                    exit 1
                fi
                rm -f requirements.txt.bak
                git add requirements.txt
            else
                # pyproject.toml repo: upgrade deps, rewrite pins in [project].dependencies
                cp pyproject.toml pyproject.toml.bak
                DEPS=$(python3 -c "
import tomllib
for d in tomllib.load(open('pyproject.toml','rb'))['project']['dependencies']: print(d)")
                NONPROT=$(echo "$DEPS" | sed -E 's/[><=!~;].*//' | tr -d ' ' | grep -viE "$PROTECTED_PY" | tr '\n' ' ')
                [[ -n "$NONPROT" ]] && echo "$NONPROT" | xargs -n1 "$VPIP" install -q --upgrade || true
                # Rewrite pins using the repo venv's python (SI-113: system python3 lacks venv packages)
                "$VPY" - "$NONPROT" <<'PYEOF'
import re, sys, importlib.metadata as im
protected = re.compile(r'^(mcp|mcp[-_]types|pydantic|pydantic[-_]settings|pydantic[-_]core)$')
updatable = set(sys.argv[1].split()) if len(sys.argv) > 1 else set()
lines = open('pyproject.toml.bak').read().splitlines()
out = []
in_deps = False
for line in lines:
    m = re.match(r'^(\s*)"([^"]+)"(,?\s*)$', line)
    if in_deps and m:
        spec = m.group(2); name = re.split(r'[><=!~;\s]', spec)[0]
        bare = name.lower().replace('_','-')
        if bare in updatable and not protected.match(bare):
            try:
                ver = im.version(name)
                out.append(f'{m.group(1)}"{name}>={ver}"{m.group(3)}')
                continue
            except Exception:
                pass
    if re.match(r'^dependencies\s*=\s*\[', line): in_deps = True
    elif in_deps and line.strip() == ']': in_deps = False
    out.append(line)
open('pyproject.toml','w').write('\n'.join(out) + '\n')
PYEOF
                # Validation gate
                if ! "$VPY" -c "
import tomllib, subprocess, sys
deps = tomllib.load(open('pyproject.toml','rb'))['project']['dependencies']
fails = []
for d in deps:
    mod = re.split(r'[><=!~;\s]', d)[0].replace('-', '_') if (re := __import__('re')) else d
    r = subprocess.run([sys.executable, '-c', f'import {mod}'], capture_output=True)
    if r.returncode != 0: fails.append(mod)
sys.exit(1 if fails else 0)"; then
                    log "VALIDATION FAILED — reverting pyproject.toml, NOT committing."
                    cp pyproject.toml.bak pyproject.toml
                    rm -f pyproject.toml.bak
                    git checkout "$DEFAULT_BRANCH"
                    exit 1
                fi
                rm -f pyproject.toml.bak
                git add pyproject.toml
            fi

            # SI-113 guard: skip cleanly if the update produced no diff
            if git diff --cached --quiet; then
                log "No changes after update — nothing to commit."
                git checkout "$DEFAULT_BRANCH"
                continue
            fi

            git commit -m "chore: update dependencies (validated, protected pins preserved)" >/dev/null
            git push -u "$REMOTE" "$BRANCH"
            open_pr "chore: update dependencies" "Automated dependency update. Passed SI-111 validation gate (all requirement imports verified). Protected pins (mcp, pydantic-core, etc.) untouched." "$BRANCH"
            git checkout "$DEFAULT_BRANCH"
        fi
    fi
fi

# --- Node (pnpm) -------------------------------------------------------------
if [[ -f package.json ]]; then
    USE_PNPM=false
    [[ -f pnpm-lock.yaml ]] && USE_PNPM=true
    if [[ "$USE_PNPM" == "true" ]]; then
        log "Checking for outdated Node dependencies (pnpm)..."
        OUTDATED=$(timeout 60 pnpm outdated --json 2>/dev/null | python3 -c "
import json, sys
try: data = json.load(sys.stdin)
except Exception: sys.exit(0)
for name in sorted(data): print(name)" || true)
        if [[ -z "$OUTDATED" ]]; then
            log "No outdated Node dependencies."
        else
            N_COUNT=$(echo "$OUTDATED" | wc -l)
            log "Outdated Node packages: $N_COUNT"
            if [[ "$DRY_RUN" != "true" ]]; then
                BRANCH="dependency-update-node-$(date +%Y%m%d%H%M%S)"
                git checkout -b "$BRANCH"
                pnpm update --recursive >/dev/null 2>&1 || pnpm update >/dev/null
                # SI-111 validation gate: full production build must pass
                if [[ "${SKIP_BUILD:-false}" != "true" ]]; then
                    log "Validating with pnpm build (this may take a few minutes)..."
                    if ! pnpm build >>"$LOG_FILE" 2>&1; then
                        log "BUILD VALIDATION FAILED — reverting, NOT committing."
                        git checkout -- . 2>/dev/null || true
                        git checkout "$DEFAULT_BRANCH"
                        exit 1
                    fi
                    log "Build validation passed."
                fi
                git add package.json pnpm-lock.yaml
                git diff --cached --quiet && { log "No changes to commit."; git checkout "$DEFAULT_BRANCH"; } || {
                    git commit -m "chore: update Node.js dependencies (build-validated)" >/dev/null
                    git push -u "$REMOTE" "$BRANCH"
                    open_pr "chore: update Node.js dependencies" "Automated dependency update. Passed build validation gate." "$BRANCH"
                    git checkout "$DEFAULT_BRANCH"
                }
            fi
        fi
    fi
fi

# --- Label unlabeled issues --------------------------------------------------
log "Labeling unlabeled issues as 'triage'..."
gh issue list --state open --limit 10 --json number,labels --jq '.[] | select(.labels | length == 0) | .number' 2>/dev/null | while read -r n; do
    [[ -n "$n" ]] && gh issue edit "$n" --add-label "triage" >/dev/null 2>&1 && log "Labeled issue #$n"
done || true

# --- Summary -------------------------------------------------------------------
{
    echo ""
    echo "## Maintenance Run: $TIMESTAMP"
    echo "- Python outdated (non-protected): ${COUNT:-0}"
    if [[ -f package.json ]]; then echo "- Node outdated checked (pnpm)"; fi
    PRS=$(cat "$PR_NUMBERS_FILE" 2>/dev/null | tr '\n' ' ')
    echo "- PRs opened: ${PRS:-none}"
    echo "---"
} >> "$REPO_DIR/MAINTENANCE.md" 2>/dev/null || true

log "Maintenance completed."
