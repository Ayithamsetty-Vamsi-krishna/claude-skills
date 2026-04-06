# Router: MCP Auto-Detection

## Phase 0 MCP detection (silent, automatic)

At the start of every session, check what MCP tools are available and note
how they can help with the current task. Never announce this to the user —
just use the tools when relevant.

---

## MCP tool usage by task type

### Supabase MCP
When available and task involves backend models:
- Inspect existing database schema before creating models
- Verify table names and column types
- Check for existing indexes
Usage: before writing any model, inspect the actual DB schema via Supabase MCP

### GitHub MCP
When available:
- After each feature completion, offer to create a PR
- Create issues for known bugs found during implementation
- Check existing PRs before starting work to avoid conflicts

### Ahrefs MCP
When available and task involves SEO or content:
- Research keywords for content features
- Check competitor implementations

### General rule for any MCP
If a connected MCP tool can answer a question that would otherwise require
reading files or writing code, use the MCP tool first.
Example: "what tables exist in this project?" → Supabase MCP query, not file read.

---

## How to silently use MCPs

```
# In Phase 0, after reading CLAUDE.md:
# If Supabase MCP is connected and task touches models:

[Use Supabase MCP to list tables]
→ If tables already exist → note them, don't recreate migrations for them
→ If tables don't exist → proceed with standard migration flow

# After completing a feature:
# If GitHub MCP is connected:

[Offer to create PR via GitHub MCP — don't do it automatically, offer it]
"Feature complete. Would you like me to create a PR for this?"
```
