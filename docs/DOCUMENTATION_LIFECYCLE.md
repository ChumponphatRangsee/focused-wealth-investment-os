# FWIOS Documentation Lifecycle

Status: **ACTIVE — docs-only governance** (introduced 2026-10-20). This is a process guide, not a trading, database, pricing or migration contract.

## One entrypoint, multiple source documents

- `docs/CURRENT_STATUS.md` is the **living navigation index** for new chats and workstreams. Keep it short, clearly dated and linked. Do not fill it with copied logs or current stock prices.
- `AGENTS.md` and `contracts/system-contract.yaml` are behavioral/system guardrails; neither a status index nor handover can override them.
- GitHub PRs/issues own review, task progress and acceptance. Feature specs in `docs/implementation/` own requirements and completion criteria; architecture and ADR documents retain consequential decisions; runbooks own procedures, verification and rollback.
- Current Supabase/Sheet/deployed state must be freshly verified for production-facing work. A dated document or merged PR cannot prove live production state.

## Document lifecycle

| Class | Rule |
| --- | --- |
| **Living index** | Update `CURRENT_STATUS.md` after material PR merge, environment cutover, owner-approved change of next task, or known blocker. Identify verification time and what was *not* checked. |
| **Active feature document** | Keep the approved scope, acceptance, known risks and links to active PRs. Avoid repeating the entire project history. |
| **Historical evidence / ADR / runbook** | Preserve release receipts, significant architectural decisions, rollback steps and accepted test results in durable locations; mark older decisions superseded rather than silently rewriting history. |
| **Chat handover** | Create a new dated handover **only** when a genuine context transfer requires information missing from living docs/PR/Issue. Prefer the living index for routine chat changes. |
| **Archived handover** | Preserve once complete/superseded. Add a prominent historical-only banner and index it; optionally retain a short pointer at the original path to preserve incoming links. |
| **Deletion** | Delete redundant files from `main` only after inspecting references, migrating any unique evidence/decisions, and checking recoverability in Git history. Never delete just because a document is old. |

## PR checklist for documentation changes

1. Re-read main HEAD and open PRs, especially PRs that may also edit `AGENTS.md` or docs.
2. Inventory impacted Markdown paths, internal relative links, and any named references in contracts/agent instructions.
3. Separate **verified present state** from **snapshot assertions** and proposed work; do not report a feature deployed solely from a plan.
4. Archive with a link index, preserve external/backward references with compatibility pointers where appropriate, and fix moved-file relative links.
5. Update `CURRENT_STATUS.md` and `README.md` navigation. Ensure old handover "next action" commands have no apparent current authority.
6. Confirm the PR diff contains **only Markdown/documentation files**; no database, Edge Function, cron, Sheets, trade or accounting changes.
7. Do not auto-merge; inspect CI, required reviews and merge conflicts first. Resolve conflicting AGENTS edits by reconciling the newer live contract rather than overwriting it.

## Scope of the 2026-10-20 cleanup

- Archived **six** completed/superseded chat handovers, with full historical text retained and minimal pointers at the old paths.
- Left two feature-level dated handovers in `docs/implementation/`, clearly directing readers to the living index.
- Added an archive index, current-status entrypoint, README navigation and a small `AGENTS.md` procedure.
- **No** changes to Business Logic, system-contract YAML, SQL, schemas, Edge Functions, schedules or external systems.

After merge, all claims in this file remain process guidance only; the status index must still be maintained as implementation progresses.
