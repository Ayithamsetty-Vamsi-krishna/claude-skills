# Integrations: MCP Tool Usage

## How skills use MCP tools (automatic, silent — Q5)

Phase 0 of every skill: detect available MCPs and use them to improve output.
Never announce MCP usage to the user — just use the tools and deliver better results.

---

## Supabase MCP — schema inspection

When Supabase MCP is connected and the task touches models or migrations:

```
# Before creating models, inspect the actual database:
[Supabase MCP] → list_tables()
→ If table exists → don't re-migrate, update the model to match
→ If table missing → proceed with standard migration flow

# Before creating a migration, check for conflicts:
[Supabase MCP] → describe_table('orders')
→ Verify column types match model field types
→ Check existing indexes before adding duplicates

# After migration, verify:
[Supabase MCP] → execute_sql('SELECT column_name, data_type FROM information_schema.columns WHERE table_name = "orders"')
→ Confirm migration applied correctly
```

**When this matters:**
- Existing project with DB but no migrations in repo
- Syncing model to an existing table
- Verifying migration correctness before running in production

---

## GitHub MCP — PR creation

When GitHub MCP is connected, after each feature completion:

```
# After completing a feature:
"Feature complete. Would you like me to create a PR for this?"
[If yes]
[GitHub MCP] → create_pull_request(
    title="feat: add invoice approval workflow",
    body="Implements cross-app invoice approval...\n\nChanges:\n- ...",
    head="feat/invoice-approval",
    base="main"
)
```

**When to offer (not auto-create):**
- After completing a full feature (backend + frontend)
- After fixing a bug
- Never auto-create without asking — the user may not want a PR yet

---

## General MCP usage principle

```python
# Decision rule for any MCP:
# "Can this MCP answer a question that would otherwise require
#  reading files, running commands, or writing code to verify?"
# YES → use the MCP tool first
# NO  → proceed without MCP

# Examples:
# "Does the orders table have an index on status?" → Supabase MCP query
# "What PRs are open on this repo?" → GitHub MCP
# "What's the Stripe API version in the docs?" → web_search (not MCP)
```

---

## Handling MCP tool failures

```
If an MCP tool call fails:
1. Log the failure silently
2. Fall back to standard approach (file reading, web search)
3. Never tell the user "the MCP failed" unless it's directly relevant
4. Continue with the task using the fallback approach
```
