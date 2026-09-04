# Stage 1: The Trigger Mechanism

No agent in this pipeline decides on its own to start working. A request only enters the system through a single, authenticated entry point — and understanding that entry point matters, because it's where most of the pipeline's real-world reliability problems (and security requirements) actually live.

## What starts a run

A human applies a specific label (e.g. `ai-agent`) to a work item in the project-tracking system. That label is the *only* thing that triggers automation — a service-hook subscription is configured to fire on that specific event and filtered to that specific label, not on every change to every work item.

The work item itself can originate from anywhere, and the trigger doesn't distinguish between sources:

- A developer's own feature or change request
- A bug report
- A manually identified policy or compliance requirement — for example, a security or compliance reviewer deciding a new standard needs to be applied, with no automated finding behind it at all
- An automated finding created by the drift detection agent (Stage 6)

All of these become the same kind of object once written up: a work item, labeled for automation. The trigger has no concept of "where this came from" — it only cares whether the label and authentication check out. This is a deliberate simplification: it means the pipeline doesn't need a special case for "this request came from a human's own judgment" versus "this request came from a scan" — it's the same five stages either way.

```
Trigger event:  Work item created / updated
Filter:         Tag = "<your-automation-label>"
Filter:         Area/Project = "<your-project>"
```

Filtering this precisely at the source, rather than filtering later in code, means the vast majority of noise never reaches the pipeline at all.

## Authentication before anything else

The webhook target validates a shared secret on every incoming request, before any business logic runs:

```
1. Receive HTTP request
2. Fetch expected secret from a secured vault (via managed identity — never hardcoded)
3. Compare against the request's secret header
4. If mismatched → reject (401), stop
5. If matched → send an immediate acknowledgment, then continue asynchronously
```

The immediate acknowledgment matters in practice: most project-tracking systems enforce a short timeout on webhook responses, and agent orchestration can take minutes. Acknowledging immediately and continuing the real work asynchronously avoids the webhook provider treating a slow-but-successful run as a failure.

## Preventing the system from triggering on itself

This is the detail that's easy to skip and expensive to skip. If the pipeline's own agents write comments or change tags on the same work items they're processing, and the trigger isn't careful, the system will re-trigger itself indefinitely.

The fix is a simple, consistently-applied check, run before anything else:

```
if event.author == "<automation-service-account>": skip
if event.comment starts_with "[AGENT": skip
```

This check needs to exist in *every* code path that could re-fire the trigger — not just the primary one. It's worth auditing this specifically if you build your own version: a single missed path is a real production incident, not a theoretical one.

## Independent completion verification

Each agent in this pipeline is responsible for updating its own status when it finishes (e.g. removing the triggering label). But relying solely on an agent's self-reported completion is fragile — if that specific call fails partway through, the label never gets removed, and the system fires again on the same request forever.

The fix: the trigger service *itself* independently verifies the label was actually removed after the downstream agents report completion, as a second, architecturally separate check:

```
after agent orchestration completes:
    re-fetch the work item's current tags
    if triggering label is still present:
        remove it directly
        re-verify
```

This is a small amount of extra code that has an outsized effect on reliability — it converts a class of silent, self-perpetuating failures into a non-issue.

## Routing by request type

Not every request needs the same downstream handling. A defect report and a new-infrastructure request are different problems; this pipeline classifies and routes them to separate downstream orchestrations rather than forcing one flow to handle both:

```
switch work_item.type:
    case "Bug":     invoke DiagnosticWorkflow
    default:        invoke InfrastructureWorkflow
```

## Bounded waiting, not indefinite polling

Downstream agent orchestration is invoked asynchronously and polled for completion on a fixed interval with a hard timeout — not awaited indefinitely:

```
invoke orchestration (async)
loop (max N iterations, e.g. 180):
    wait 20s
    check status
    if completed/failed/cancelled: break
```

A hard ceiling here is a deliberate choice: a stuck downstream process should surface as a visible failure, not silently consume resources forever.

## Reference implementation

See [`infra/modules/trigger-service.bicep`](../infra/modules/trigger-service.bicep) for a generic Logic App implementation of this pattern.

Next: [Stage 2 — the enrichment agent](03-enrichment-agent.md)
