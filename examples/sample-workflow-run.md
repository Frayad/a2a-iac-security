# Worked Example (Fictional Data)

This walks through one request from trigger to merge, using a fictional resource
and organization name throughout. No values here correspond to any real
deployment.

## The request

A work item is opened: *"Add support for a new caching tier in the `WidgetCache`
module — Redis Premium SKU with zone redundancy."* A human reviews it, agrees
it's ready for automation, and applies the `ai-agent` label.

## Stage 1 — Trigger

The label addition fires a webhook to the trigger service. The shared secret
checks out. The service classifies the work item type (`Feature`, not `Bug`)
and routes it to the infrastructure workflow. A new agent conversation is created.

## Stage 2 — Enrichment

The enrichment agent reads the request. Completeness check:

```
resourceType:       missing  (0)
expectedBehavior:   present  (1)
currentBehavior:    n/a — new resource, not required
apiVersion:         missing  (0)
affectedFiles:       missing  (0)
```

It searches the repository, finds the existing `WidgetCache` module, confirms
via schema discovery that Redis Premium SKU support requires API version
`2024-11-01`, and determines the two files that will need changes. It posts:

> "[AGENT] Enriched: resourceType=Contoso.Cache/redis, apiVersion=2024-11-01,
> operationMode=MODIFY, affectedFiles=[modules/WidgetCache/deploy.bicep,
> modules/WidgetCache/parameters.bicep]"

Hands off with `proceed: YES`.

## Stage 3 — Authoring

The authoring agent creates branch `feat/AB1001`, reads the reference template,
and patches the two identified files — adding the zone-redundancy parameter and
updating the SKU enum, without touching anything else in either file. It
validates the draft (passes on the first attempt), opens two pull requests
(one per repository), and posts a plan comment before starting:

> "[AGENT-PLAN] Resource: Contoso.Cache/redis, Mode: MODIFY, Target:
> modules/WidgetCache, Breaking: no"

It removes the `ai-agent` label and immediately re-fetches the work item to
confirm the removal succeeded.

## Stage 4 — Independent audit

The audit agent reads both changed files fresh from the branch — not from the
authoring agent's PR description. It runs the full checklist. One blocking
issue: the zone-redundancy parameter was added to the deployment file but the
corresponding parameters file wasn't updated to expose it, so a consumer of the
module has no way to actually set it.

```json
{
  "qualityGateStatus": "FAILED_BLOCKER",
  "blockerCount": 1,
  "remediationPayload": {
    "fixes": [{
      "checkId": "9",
      "severity": "blocker",
      "filePath": "modules/WidgetCache/parameters.bicep",
      "issue": "New zoneRedundant parameter not exposed in the wrapper.",
      "requiredChange": "Add a zoneRedundant bool parameter and pass it through to the module call.",
      "acceptanceCriteria": "Parameter is declared, typed, and threaded through to the module."
    }]
  }
}
```

## Back to authoring — fix cycle

The authoring agent applies the specific fix described, re-validates, and
requests a fresh audit.

## Stage 4, again

The audit agent re-reads both files from scratch (not a cached result) and
confirms the fix. `qualityGateStatus: PASSED`.

## Stage 5 — Human-gated merge

The pull request now shows a passing automated check and awaits a human
reviewer's approval. A person on the team reviews the diff, approves, and
merges. No agent touched the merge button at any point in this process.

## Six weeks later — drift detection

A routine scan flags that the deployed `WidgetCache` Redis instance doesn't
have diagnostic logging enabled — a setting that was compliant at deploy time
but has since become a required baseline. The drift detection agent classifies
it as code-fixable (the resource is tracked in the same repository), creates a
work item with a specific suggested fix, and tags it consistently with every
other finding it's filed. That work item can now go through the exact same
five stages above.
