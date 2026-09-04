# Stage 5: Human-Gated Merge

Everything upstream of this stage — enrichment, authoring, independent audit — exists to make this final gate fast and low-friction for the human reviewing it. Nothing upstream exists to replace the human.

## No agent can merge

Every validated change becomes a pull request, automatically linked to its originating request. The agents in this pipeline have no tooling that can approve or merge a pull request — that capability, like the audit agent's write access, simply isn't part of any agent's available toolset.

```
required before merge:
  - automated validation check: passed
  - at least one human reviewer approval
  - no merge conflicts
```

## Structured, predictable PR descriptions

Every PR follows the same description format — what changed, why, and what was validated — regardless of which agent or which request produced it:

```markdown
## Description
<what this change does and why>

## Changes
- <file>: <what changed>

## Validation
- Resource schema reviewed for <type>@<version>
- <validation tool> passed with no blocking diagnostics
- <any other checks relevant to this specific change>

Related work item: <id>
```

A human reviewer who's seen one of these PRs already knows how to read the next one. That consistency is worth deliberately enforcing — it's a small thing that measurably speeds up review.

## Feedback loops back to the same agents

If a human reviewer leaves comments on the PR, those comments are treated as mandatory input on the next automated pass — not optional context. Every unresolved comment must be addressed in code, replied to, and explicitly marked resolved before the next validation pass is considered complete:

```
for each unresolved review comment:
    apply the requested change
    reply confirming what changed
    mark the comment thread resolved
```

A fix commit alone, without replying to and closing the review thread, is treated as an incomplete pass — this keeps the review history genuinely useful to whoever looks at it later, rather than a set of comments nobody can tell were ever addressed.

Next: [Stage 6 — the drift detection agent](07-drift-detection-agent.md)
