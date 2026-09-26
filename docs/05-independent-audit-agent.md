# Stage 4: The Independent Audit Agent

This is the stage the rest of the architecture exists to support. Every other design decision in this repository is in service of one property: **the agent that proposes a change is never the same agent that approves it.**

## Why this needs to be architectural, not procedural

It's easy to build a "review" step that's really just the same model asked to double-check its own work with a different prompt. That's not independent review — it's the same reasoning process, run twice, with the same blind spots both times. It also means a confident-but-wrong claim in the authoring agent's own notes ("PE config already resolved") can pass straight through unchallenged, because nothing is actually re-deriving the answer.

The fix implemented here: the audit agent is a **separate agent, with separate tooling**, and its tooling set contains no write capability at all. It is not possible for this agent to modify a file — not "instructed not to," but structurally incapable of it, because the capability was never given to it. This is the single most important design decision in this repository.

## Read from the source, not from the claim

The audit agent never accepts a description of what changed — it reads the actual file content directly from the branch, every time, including on re-runs:

```
input:  branch name + list of changed files
        (never accept inline file content from the caller)
process: for each file, read_content(branch, file) → run diagnostics
output: structured findings, referencing only what was actually read
```

This is what catches the failure mode described above — a submission's own notes claiming something was resolved gets checked against the actual code, not taken at face value.

## A fixed, versioned checklist — not vibes

The audit isn't "does this look reasonable" — it's a specific, numbered checklist covering structural completeness, code quality, network/security configuration, version and parameter consistency, and validation results. Each check is independently pass/fail/skipped, and every check is classified in advance as blocking or advisory:

```
Blocking:   must pass before the change can proceed
Advisory:   reported, but does not block merge
```

Separating these matters for the same reason a human code review benefits from separating "this will break in production" from "I'd phrase this differently." Treating every finding as equally severe either makes the gate too strict to be usable, or trains people to ignore it.

## Deterministic, structured output

```json
{
  "qualityGateStatus": "PASSED | FAILED_BLOCKER | FAILED_NON_BLOCKER_ONLY",
  "blockerCount": 0,
  "checklist": [
    { "checkId": "...", "result": "FAIL", "evidence": "...", "remediation": "..." }
  ],
  "nextStep": "..."
}
```

Every failing check comes with a specific, file-level `remediation` instruction — concrete enough that the authoring agent (or a human) can act on it directly, not a vague "please review."

## Re-run fresh, every time

When a fix cycle happens and the audit is re-invoked, it re-reads every file from the branch again — it never reuses a cached result from the previous pass. A stale "this already passed" is worse than no result at all.

## What this actually catches

In a real run of this pattern, a submission's own change notes claimed a network security setting had already been correctly configured. The independent audit didn't accept that claim — it read the branch directly and found the setting was in fact missing, along with two unrelated structural issues in the same change. The change was held until all three were fixed and re-verified. The finding looked like this (illustrative pattern based on the audit's reported findings, not a verbatim excerpt):

```bicep
// As submitted: the notes said private networking was already configured
privateEndpointConfigs: [ { enabled: true } ]   // wrong shape, required fields missing
// no entry for this resource type in the shared private DNS zone map

// Required by the audit
privateEndpointConfig: { subnetId: <required>, privateDnsZoneId: <required> }
// matching entry added to the shared private DNS zone map
```

The complete result of that review recorded several blocking issues and one advisory finding, each with a file-level remediation instruction. The authoring agent applied the instructions and the audit re-read the branch from scratch before the change could move on.

That's the pattern working as intended: not catching an adversarial submission, just catching an honest mistake that a same-agent self-review would very plausibly have missed.

Next: [Stage 5 — human-gated merge](06-human-gated-merge.md)
