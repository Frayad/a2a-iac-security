# Overview

This walkthrough follows one infrastructure change request from the moment it's submitted to the moment it either merges or gets flagged back to a human — and then follows the same infrastructure after deployment, as it's continuously checked for drift.

Read the stages in order; each one assumes the previous stage's output.

| Stage | What it does | Doc |
|---|---|---|
| 1 | Authenticated trigger — what actually starts the pipeline | [02-trigger-mechanism.md](02-trigger-mechanism.md) |
| 2 | Enrichment agent — fills gaps in an incomplete request | [03-enrichment-agent.md](03-enrichment-agent.md) |
| 3 | Authoring agent — drafts the infrastructure code | [04-authoring-agent.md](04-authoring-agent.md) |
| 4 | Independent audit agent — reviews the change, read-only | [05-independent-audit-agent.md](05-independent-audit-agent.md) |
| 5 | Human-gated merge — the only path to production | [06-human-gated-merge.md](06-human-gated-merge.md) |
| 6 | Drift detection agent — post-deployment monitoring | [07-drift-detection-agent.md](07-drift-detection-agent.md) |
| 7 | Security design — identity, secrets, least privilege | [08-security-design.md](08-security-design.md) |
| 8 | Deployment model — where an agent actually runs, and how handoff works | [09-deployment-model.md](09-deployment-model.md) |
| 9 | Platform map — the Azure services behind each stage, and their AWS and Google Cloud equivalents | [10-azure-platform-and-cloud-equivalents.md](10-azure-platform-and-cloud-equivalents.md) |

## A note on what's real and what's a placeholder

Every code sample in this repository is a working pattern — the logic, the control flow, and the security model are all real and have been run in production. What's replaced are the specifics that would identify any particular organization: names, identifiers, URLs, and policy values are all placeholders (`<your-org>`, `<your-project>`, and similar) for you to supply.

## Prerequisites

- A cloud account. The implementation in [`infra/`](../infra) is built for Microsoft Azure; see [10-azure-platform-and-cloud-equivalents.md](10-azure-platform-and-cloud-equivalents.md) for the matching AWS and Google Cloud services
- A project-tracking system with webhook/service-hook support (Azure DevOps, GitHub, GitLab, Jira, and similar all work)
- An agent orchestration platform that supports tool-calling and agent-to-agent handoff. This pattern was built on Microsoft Foundry, using the **Model Context Protocol (MCP)** — an open standard for exposing tools to an AI agent — and the **Agent-to-Agent (A2A) protocol** for handoff between agents. The architecture itself doesn't depend on any single vendor; see [09-deployment-model.md](09-deployment-model.md) for how the pieces fit together.
