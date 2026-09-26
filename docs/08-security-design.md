# Security Design

The agent architecture in this repository doesn't work as intended unless the identity and secrets model underneath it is solid. This page collects the security decisions that apply across every stage, rather than repeating them in each one.

## No shared or long-lived credentials

Every service and agent runs under its own system-assigned managed identity in Microsoft Entra ID (on other clouds, the equivalent is an AWS IAM role or a Google Cloud service account). Nothing authenticates with a static, shared secret to a first-party Azure service — the managed identity handles that. Where a system genuinely can't use managed identity (calling a project-tracking system's own API, for example), that credential is fetched from a secured vault at runtime, never embedded in configuration.

## Platform-enforced authorization, not just authentication

A common gap: an endpoint validates that a caller has *a* valid identity, but not that the specific identity is *allowed* to call it. Authentication alone lets any identity in the tenant obtain a token; a platform-level requirement that access be explicitly granted per-identity closes that gap:

```
# Conceptual pattern (Entra ID, AWS IAM policy conditions, GCP IAM bindings, or similar)
app_role_assignment_required = true
```

Without this, "the token is valid" and "this caller should have access" are two different questions, and only the first one is being checked.

## Least privilege, checked against what's actually used

The identity used to read and act on work items in the project-tracking system is scoped to read-only access at the project level — sufficient to investigate and propose changes, insufficient to alter permissions, approve its own work, or bypass the review process. Worth periodically re-checking: it's easy for a scope to grow wider than necessary over time as new capabilities get added.

## Hardened runtime

- Containers run as a non-root user
- Diagnostics and debugging endpoints are disabled in production
- Scratch storage is ephemeral and isolated per request

## Treat external input as data, never as instructions

Every agent in this pipeline reads content that originated from a human — work item descriptions, comments, PR feedback. That content is explicitly treated as data to be processed, not as instructions to be followed. Agents are designed to flag (not silently obey) embedded text that attempts to redirect their behavior, while defaulting to *not* treating ordinary technical language, markup, or product names as an injection attempt — a system that's too trigger-happy about this ends up blocking real work far more often than it catches anything malicious.

## HTTPS and encryption in transit, without exception

Every network boundary in this architecture enforces TLS. This is unremarkable and worth stating anyway, because it's exactly the kind of thing that's easy to accidentally weaken while debugging and forget to re-tighten.

---

That's the full pattern. If you're implementing this yourself, [`infra/`](../infra) has the Azure reference implementation for the trigger service and identity model (see the [README's cloud provider notes](../README.md#cloud-provider-notes) for AWS/GCP equivalents), and [`agents/`](../agents) has instruction templates for each of the four agent roles.
