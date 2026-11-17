---
name: codex-review
description: Run an OpenAI Codex code review (gpt-6-astra, high reasoning, fast tier) on uncommitted changes, a commit, or a branch diff. Use when the user asks for a codex review or a second-opinion review.
---

Run `codex review` with the model pinned so it does not depend on the user's
`~/.codex/config.toml`. `codex review` rejects a custom prompt combined with
`--uncommitted`/`--base`/`--commit`, so describe the target in the prompt:

```bash
codex review \
  -c model="gpt-6-astra" \
  -c model_reasoning_effort="high" \
  -c service_tier="fast" \
  "<TARGET SENTENCE> <FOCUS> <optional user instructions>"
```

`<TARGET SENTENCE>`, picked from the arguments or context:

- no argument / "uncommitted" → "Review the uncommitted changes: staged,
  unstaged and untracked files (`git status`, `git diff HEAD`)."
- a commit SHA → "Review the changes introduced by commit <SHA>
  (`git show <SHA>`)."
- a branch name → "Review the changes on this branch against <BRANCH>
  (`git diff <BRANCH>...HEAD`)."
- default when the working tree is clean → the branch form with `main`

`<FOCUS>`, always included:

> Report only real bugs and problems: incorrect behavior, crashes, data loss
> or corruption, races, resource leaks, security issues, broken API
> contracts. Skip style, naming, formatting, documentation, refactoring
> suggestions, and speculative issues that need unrealistic inputs or
> conditions to trigger. If nothing qualifies, say so.

Any remaining argument text is appended as extra instructions.

Run it with the Bash tool using `run_in_background: true`; reviews take a
while.

Codex output is a set of claims, not ground truth. Evaluate every finding
before reporting it:

1. Read the cited code and enough surrounding context to judge it.
2. Check the claim: does the described failure actually happen? Trace the
   inputs, or write a quick test when that is cheap.
3. Drop nitpicks and rare edge cases that slipped through the focus
   instructions; don't report them.
4. Classify each remaining finding as:
   - **Valid**: confirmed, with the evidence that confirms it
   - **Invalid**: wrong, with the reason (misread code, impossible input,
     already handled elsewhere)
   - **Uncertain**: can't be settled without more information; say what
     is missing

Report your verdicts, not Codex's raw output. Rank valid findings by
severity. Mention invalid ones briefly so the user knows they were checked.
Do not apply fixes unless the user asks.
