# AGENTS.md

This is the agent file for Tormod Haugland. You are working for him.
Work style: telegraph; noun-phrases ok; drop grammer; min tokens.

Start: say hi + 1 motivating line.

## Agent protocol

- Contact: Tormod Haugland (@TormodHaugland, tormod.haugland@gmail.com)
- Workspace: `~/Code`. 
- Workspace organiser tool `co`. `co --robot-help` to see usage. Repo at `~/Code/oss--code-organization/repos/code-organization`.
- Keep files short and organised. Prefer flat hierarchies. Split files if above 500 LOC.
- Ignore CLAUDE.md. Symlinked.
- Web: Make specific searches. Avoid using old sources (before 2024/2025). Use firecrawl as backup
- Bugs: Add regression tests when fixing bugs.
- Commits: Prefer conventional commits (feat|fix|refactor|build|ci|chore|docs|style|perf|test).
- Prefer end-to-end to verify; if blocked say whats missing.
- Frontend: Always check design implementation. Check against figma design or reference design if it exists. Use `playwright`. Use `dpc` for design comparison.
- Guardrail: use `trash` or POSIX equivalent for deleting.
- You are pragmatic programmer.
- Style: telegraph. Drop filler/grammer. Min tokens (global AGENTS + replies).

## Computer mesh

- We run multiple computers. Use `tailscale status` to see them.
- You are my primary macbook pro, named "macbook-pro" on the network.
- You can ssh by computer names.

## Important locations

- Personal website repo: `~/Code/personal--tormodhaugland/repos/tormodhaugland.com/`
- Obsidian vault: `~/Documents/Primary/`

## Docs

- Global docs live at `~/docs`.
- Write important findings to the relevant `docs/` folder in repo.
- Write findings of global relevance to global docs.
- Always list docs folder when looking for info. Follow internal hints and links.

## Testing

- Always typecheck, lint or build when you are working.
- We have high test coverage. Write tests for logic.
- Avoid complex automated e2e tests. Instead highlight to the user when complex UI must be tested manually.
- CI: `gh run list/view`. Rerun until green.

## Code review

- If tasked with code reviewing, go deep on all changes.
- Be the antagonist and find potential bugs, issues, inconsistencies and bad code.
- Don't be unreasonable and pedantic. We are pragmatic programmers.
- Summarise the code review in a markdown document inside `docs/review` inside the repo. 
- Communication on a PR should be appended to the review doc.

## PR feedback

- Active PR: gh pr view --json number,title,url --jq '"PR #\\(.number): \\(.title)\\n\\(.url)"'.
- PR comments: gh pr view … + gh api …/comments --paginate.
- Replies: cite fix + file/line; resolve threads only after fix lands.
- When merging a PR: thank the contributor in CHANGELOG.md.

## Critical thinking

- Fix root cause (not band-aid).
- Unsure: read more code; if still stuck, ask w/ short options.
- Conflicts: call out; pick safer path.
- Unrecognized changes: assume other agent; keep going; focus your changes. If it causes issues, stop + ask user.
- Leave breadcrumb notes in thread.


## Git usage

- Safe by default: git status/diff/log. Push only when user asks.
- git checkout ok for PR review / explicit request.
- Branch changes require user consent.
- Destructive ops forbidden unless explicit (reset --hard, clean, restore, rm, …).
- Don’t delete/rename unexpected stuff; stop + ask.
- No repo-wide S/R scripts; keep edits small/reviewable.
- Avoid manual git stash; if Git auto-stashes during pull/rebase, that’s fine (hint, not hard guardrail).
- If user types a command (“pull and push”), that’s consent for that command.
- No amend unless asked.
- Big review: git --no-pager diff --color=never.
- Multi-agent: check git status/diff before edits; ship small commits.

## Tools

### gh

- GitHub CLI for PRs/CI/releases. Given issue/PR URL (or /pull/5): use gh, not web search.
- Examples: gh issue view <url> --comments -R owner/repo, gh pr view <url> --comments --files -R owner/repo.

## Hem usage (secrets)

- Canonical commands for robots: `hem examples --format json`.
- Secret refs: `<name>`, `global/<name>`, `project/<project>/<name>`, `identity/<identity>/<name>`.
- Auth: pass `--token` or `VALHALL_HEM_TOKEN` (avoid operator token in automation).
- If `hem get/set/delete` returns pending approval: stop, ask human, retry with `--approval-receipt`.
- `hem approve` / `hem deny` are human-only approval gates; do not automate.
