# Deployment Model: Where Agents Actually Run

The other documents in this repository describe what each agent does. This one describes what an "agent" physically is, where it runs, and how one agent actually hands off to another — none of which is obvious just from reading instruction templates.

## Agents are configured, not custom-built

An agent in this architecture is not a standalone application you write from scratch. It's a configuration — a model, a set of instructions (the templates in [`/agents`](../agents)), and a bound set of tools — hosted and executed by an **agent orchestration platform**. The platform handles running the model, managing conversation state, and invoking tools on the agent's behalf. This reference implementation was built on Microsoft Foundry, but the pattern itself isn't tied to any single vendor — any platform that supports tool-calling and agent-to-agent handoff can implement it.

## Tools are exposed through small, independently deployed services

An agent doesn't have direct access to your project-tracking system, your code repository, or your cloud provider's APIs. It has access to *tools* — and those tools are implemented by small backend services the agent calls out to, using the **Model Context Protocol (MCP)**: an open standard for exposing a specific, narrow set of capabilities to an AI agent in a structured way.

In this architecture, each functional area gets its own dedicated MCP service rather than one large service exposing everything:

```
Agent Orchestration Platform
        │
        ├── Enrichment Agent ──────┐
        ├── Authoring Agent ───────┼──► MCP: Project-Tracking Tools (read/write work items)
        ├── Independent Audit Agent┤    MCP: Repository Tools (read files, create branches, open PRs)
        └── Drift Detection Agent ─┘    MCP: Schema Discovery Tools (resource types, API versions)
                                        MCP: Cloud Posture Tools (read compliance findings)
```

This separation is what makes the independent audit agent's read-only status a real, physical fact rather than an instruction. Its tool bindings are drawn from a service that simply does not implement a write-capable tool — there is nothing in its available action space that could commit code, even if a prompt somehow convinced it to try. **Enforce this at the tool-service level, not just in the agent's instructions.** An instruction saying "never write anything" is a policy that can be misread or worked around; a tool service with no write endpoint is a physical constraint that can't.

## Each tool service is independently authenticated

Every MCP service in this architecture requires its own explicit authorization — see [`08-security-design.md`](08-security-design.md) for the platform-enforced pattern. A credential that lets an agent call the project-tracking tools does not automatically let it call the repository tools; each is its own access grant, scoped narrowly to what that specific agent role actually needs.

## Handoff between agents is a platform-native call, not custom glue code

When the enrichment agent finishes and hands off to the authoring agent, that's not a webhook, a queue, or anything you build yourself — it's the orchestration platform's native agent-invocation capability. One agent's tool set includes the ability to invoke another specific, named agent, passing along a structured payload as the handoff contract described in each agent's instruction template. The platform manages the underlying session and conversation state; you don't have to.

This matters for reliability in a specific way: because the handoff is a first-class platform feature rather than custom integration code, retries, timeouts, and conversation continuity are handled by infrastructure that's already been built and tested — not something this pattern has to reinvent.

## Putting it together

For one request moving through the pre-deployment pipeline:

1. The trigger service (Stage 1) calls the orchestration platform's API to start a run, targeting a specific top-level agent.
2. That agent (enrichment) uses its bound MCP tools to read and investigate the request.
3. It hands off to the authoring agent via a platform-native agent-invocation call — not a separate HTTP request you write yourself.
4. The authoring agent uses its own, differently-scoped MCP tools to write code and open a pull request.
5. It hands off to the independent audit agent the same way — which has an entirely different, read-only set of tool bindings, drawn from a service that was never given a write capability in the first place.

Every stage in this chain is a configuration choice — which agent, which tools, which model — rather than custom application code. That's a meaningful part of why the pattern is reproducible: someone implementing this on a different platform is largely making the same configuration choices, not rebuilding infrastructure.
