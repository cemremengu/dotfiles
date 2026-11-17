---
name: implement-plan
description: Implement an approved plan by splitting it into tasks and delegating each to `builder` subagents, then reviewing and verifying their work. Use when the user asks to implement, execute or build a plan (a plan file, pasted plan, or the plan just approved in plan mode) with builders or subagents.
---

You are the orchestrator. Builders write the code; you split the work, brief
them, review what they produce and own the final result. Do not write the
feature code yourself except for small fixes after review.

## 1. Load the plan

The plan is, in order of preference: a path or text in the arguments, the
plan approved earlier in this conversation, or a plan file the user names.
If there is none, ask for it. Do not invent one.

Read the plan and the code it touches until you can answer:

- What does "done" look like? Turn each plan item into a checkable outcome.
- Which files does each item create or change?
- What is ambiguous or contradicts the code? Ask the user before spawning
  anything; a builder that guesses wrong costs a full round trip.

## 2. Split into tasks

Each task is one coherent change a builder can finish and verify alone,
usually one layer or feature slice (proto + Rust handler, a React screen,
a migration). Prefer fewer, larger tasks over many small ones: every builder
starts cold and re-reads context.

For each task note its files and its dependencies on other tasks. Order:

- Shared contracts first (protos, types, schemas, API shapes). Run
  `npm --prefix web-local run generate` after proto changes so later tasks
  see the generated code.
- Tasks run in parallel only when their file sets do not overlap and
  neither needs the other's output. Otherwise run them in sequence.
- One task in flight is fine. Parallelism is an optimisation, not a goal.

Show the user the task list (one line each, with order) before spawning,
unless they said to go ahead without asking.

## 3. Brief each builder

Spawn with `subagent_type: "builder"`. The builder sees none of this
conversation, so the prompt must stand alone:

```
Goal: <one sentence: what this task delivers and why>

Plan excerpt:
<the relevant part of the plan, verbatim>

Context:
- <decisions already made, existing code to reuse, pitfalls you found>
- Files to change/create: <list>
- Do not touch: <files owned by other in-flight tasks, unrelated areas>

Done when:
- <checkable outcome>
- <verification commands that must pass>

Rules: follow AGENTS.md. Do not commit. Do not expand scope; if the plan
is wrong or blocked, stop and report instead of improvising.

Report: files changed, how each "done when" item was verified (with
command output), and any deviation from the plan or open question.
```

Verification commands by area:

- Rust: `cargo test -p <crate>`, `cargo clippy -p <crate>`
- UI: `npx tsc -p tsconfig.app.json --noEmit`, `npm test`,
  `npm run lint` (all in `web-local`; `npm run typecheck` is a no-op)
- Protos: `buf lint`, then `npm --prefix web-local run generate`

Builders run in the background. Wait for their completion notifications;
never assume or predict a result. Spawn independent tasks in one message.

## 4. Review each result

When a builder finishes, check its work before starting dependent tasks:

1. Read the diff (`git diff`, `git status` for new files). Compare it to the
   plan excerpt and the "done when" list, not to the builder's report.
2. Re-run the verification commands yourself.
3. Look for scope creep, narrative comments, needless abstractions and
   edits outside the task's files; AGENTS.md forbids all of them.

If something is wrong, send the findings to the same builder with
`SendMessage` (it keeps its context) rather than spawning a new one. Fix
trivial issues (a typo, a missing import) yourself. If a builder fails the
same way twice, stop and tell the user what is blocking.

## 5. Finish

After the last task:

1. Run the full checks: `mise run test` and `mise run lint`, plus the UI
   typecheck above if UI files changed.
2. For UI changes, check the change in the running app when feasible (the
   `run` skill).
3. Report to the user: what was built per plan item, verification results
   (say plainly if anything fails), deviations from the plan and why, and
   anything left open. Do not commit unless asked.
