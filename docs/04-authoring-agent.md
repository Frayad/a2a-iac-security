# Stage 3: The Authoring Agent

Once a request is complete enough to act on, the authoring agent drafts the actual infrastructure code. Its job is narrower than it might sound: follow the organization's established patterns exactly, validate everything it writes, and never touch the production branch directly.

## Work on an isolated branch, always

```
read from:  main/master (never write here)
write to:   a dedicated feature branch, created fresh for this request
```

This is enforced structurally, not left to the agent's discretion — the tooling available to this agent simply does not include a "commit to main" capability.

## Follow a canonical template, don't improvise structure

Rather than letting the model decide how a module should be structured each time, the agent is pointed at a single canonical reference implementation and required to follow it exactly — for identity configuration, network isolation, naming conventions, and output structure. This is what makes output from many separate runs consistent with each other, rather than each one being a slightly different interpretation of "good infrastructure code."

## Keep deployment wrappers thin; put shared logic in versioned modules

Infrastructure code in this pattern is split into two layers: **reusable modules** that hold the real logic, and thin **deployment wrappers** that call a pinned module version with environment-specific parameters. The authoring agent is expected to respect that split.

A real example shows why. One request asked for automatic access assignment on a new database: based on which business unit owns the resource and which environment tier it belongs to (production versus non-production), the correct pre-approved security group had to be selected and given either full management or read-only access. The first revisions built that conditional logic inside the wrapper. The final revision moved it into the shared module and changed the wrapper to consume the new module version, so every future resource of that type gets the same logic without duplicating it:

```
revision 1-2:  add owner/tier detection and group-to-role assignment in the wrapper
revision 3:    move that logic into the shared module; wrapper consumes the new module version
```

The diff for the final revision shows the logic being *removed* from the wrapper. That is the intended outcome, not a regression.

## Modify narrowly, never regenerate wholesale

For a modification request, the agent patches only the specific lines required — it does not regenerate the whole file from scratch, even if that would be simpler. Two mechanical checks help catch accidental damage from this kind of narrow edit:

```
- Count structured documentation comments (e.g. @description(...)) before and after;
  a drop means something was accidentally deleted — stop and fix before proceeding.
- Every existing comment outside the lines being intentionally changed must survive
  byte-for-byte. Never "clean up" or paraphrase code you weren't asked to touch.
```

## Validate every draft before proposing it

```
1. Run the draft through inline validation (schema + syntax)
2. If errors: revise and re-validate
3. Repeat up to a fixed retry limit (e.g. 3 attempts)
4. If still failing after the limit: stop and escalate — don't keep guessing
```

A validation tool that requires files to exist on a local filesystem doesn't work well for an agent operating entirely against a remote repository — make sure your validation step accepts file *content* directly, not just file paths, or this stage will quietly fail in ways that are hard to diagnose.

## Announce the plan before writing code

Before authoring begins, the agent posts one comment stating its intent — resource type, mode, target location, and any structurally significant flags (e.g. whether this is a breaking change):

```
"[AGENT-PLAN] Resource: <type>, Mode: <NEW|MODIFY>, Target: <path>, Breaking: <yes|no>"
```

This single comment is often the fastest way for a human reviewer to sanity-check an agent's understanding of the request before investing time reading the actual diff.

Next: [Stage 4 — the independent audit agent](05-independent-audit-agent.md)
