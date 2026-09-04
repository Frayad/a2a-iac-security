# Stage 2: The Enrichment Agent

Most incoming requests are incomplete in some specific, predictable way: a resource type without a confirmed API version, a modification request without a description of current behavior, a request with no file paths attached. The enrichment agent's job is to close those gaps *before* anything gets built — investigating rather than assuming, and recording what it found in a way a human can verify later.

## Completeness scoring, not a single pass/fail

Rather than a binary "is this ready," the agent scores completeness across independent dimensions, each worth one point:

```
- Resource type specified and valid
- Expected behavior clearly stated
- Current behavior documented (only required for modification requests)
- API version known and confirmed
- Affected files identified
```

Scoring this way makes the gap visible and specific — "3/5, missing API version and affected files" is something a human or a downstream agent can act on directly. A bare "incomplete" is not.

## Investigate before asking

When something is missing, the agent doesn't guess and doesn't immediately escalate to a human — it investigates using the same tools a careful engineer would:

```
1. Search the code repository for related existing infrastructure
2. Query the platform's own schema/API discovery service for the resource type
   (never rely on a model's memorized knowledge of API versions — they go stale)
3. Read linked items and prior comments for context
```

Only if investigation genuinely can't resolve a required field does the agent escalate — and even then, it escalates with a specific, named reason, not a generic "needs more info."

## Recording what was found

Whatever the agent resolves gets written back to the request as a durable, auditable comment — never silently held only in the handoff to the next agent:

```
"[AGENT] Enriched: resourceType=<value>, apiVersion=<value>,
 operationMode=<value>, affectedFiles=<value>"
```

Two details worth calling out:

- **Never place a placeholder value** (`?`, `N/A`, `unknown`) in this comment. If a field genuinely couldn't be resolved, omit it from the comment rather than writing something misleading.
- **Never edit the original request's description.** Enrichment is additive, recorded as a comment — the original request stays intact as a record of what was actually asked for.

## Handoff contract

The enrichment agent's output to the next stage is a structured object, not free text — this is what makes the handoff between agents reliable rather than another opportunity for misinterpretation:

```json
{
  "workItemId": "...",
  "resourceType": "...",
  "apiVersion": "...",
  "operationMode": "NEW | MODIFY",
  "affectedFiles": ["..."],
  "completenessScore": "X/5",
  "proceed": "YES | NO"
}
```

`proceed = NO` is a deliberate, valid outcome — not a failure state. It means a required field genuinely could not be resolved, and a human needs to look at it.

Next: [Stage 3 — the authoring agent](04-authoring-agent.md)
