# Stage 6: The Drift Detection Agent

Everything above this line prevents a *new* misconfiguration from being deployed. It does nothing about infrastructure that was compliant when it was deployed and has since drifted — through a manual emergency change, an expired exception, or a policy that changed after the fact. That's a separate, ongoing problem, and it needs a separate, continuously-running agent.

## Continuous evaluation, not a point-in-time audit

The drift detection agent evaluates deployed resources against your cloud provider's security and compliance benchmarks on an ongoing basis (this reference implementation targets Microsoft Defender for Cloud, but the pattern applies to any provider's posture-management service). The goal is a standing, current picture of compliance — not a quarterly snapshot that's stale by the time anyone reads it.

## Classify before creating anything

Not every finding can be fixed by changing code — some require a manual configuration change outside the infrastructure-as-code definition entirely. The agent classifies each finding before acting on it:

```
for each finding:
    if the affected resource is tracked in an IaC repository:
        classify as code-fixable
    else:
        classify as manual-only
```

This distinction is what a careful human reviewer would make instinctively — the agent just applies it consistently, every time, without getting tired of the hundredth finding of the day.

## Structured, evidence-backed work items — not just an alert

For each code-fixable finding, the agent creates a work item with the same level of structure the rest of this pipeline expects:

```markdown
**Non-compliance finding:** <the specific benchmark violated>
**Severity:** <as reported by the source scan>
**Affected resource:** <full resource identifier>
**What's wrong:** <the specific gap>
**Remediation guidance:** <from the source platform, if available>
**Likely infrastructure-as-code fix:**
  File: <path>
  Property: <the specific property to change>
  Suggestion: <what to change it to>
```

That last section — a specific, named property and a concrete suggestion, not just "this needs fixing" — is what turns a generic security alert into something an engineer (or the pipeline in Stages 2–5) can act on directly.

## A dedicated, separately secured tool server

The drift detection agent's tools run on their own MCP server, deployed separately from the pre-deployment tools and protected by the same authorization pattern: a caller must be explicitly granted a role before it can obtain a token for that server. On Azure, that is an Entra ID app registration with a required app role, and findings come from Microsoft Defender for Cloud. On AWS the findings source is AWS Security Hub; on Google Cloud, Security Command Center.

## Closing the loop

In this implementation, drift work items are created in a dedicated project, separate from the pre-deployment project, so they do not start the pre-deployment pipeline on their own. A person reviews each finding and decides whether to route it. Once routed, a code-fixable finding's work item can flow into the exact same pre-deployment pipeline described in Stages 1–5 — the same trigger, the same enrichment, authoring, and independent audit. Post-deployment monitoring and pre-deployment validation don't need to be two differently-governed systems; the second one can simply feed the first.

Next: [Security design](08-security-design.md)
