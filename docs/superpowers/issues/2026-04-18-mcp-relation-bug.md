# [bug] Notion MCP `notion-update-page` `update_properties`: relation property rejects valid single-page URL with "Invalid page URL"

## Summary

When using `update_properties` on `mcp__claude_ai_Notion__notion-update-page` to set a **relation property** to a **single page URL**, the call fails with `Invalid page URL`. The URL is valid (verified by directly fetching that page).

## Steps to reproduce

1. Find a Notion DB row with a relation property currently linking 2+ pages.
2. Try to reduce the relation to a single page by calling:
   ```
   notion-update-page
     command: update_properties
     payload: { "<relation_property>": "https://www.notion.so/<valid-page-url>" }
   ```
3. Observe: `Invalid page URL` validation error, despite the URL being well-formed and pointing to an existing page.

## Expected behavior

Relation property is updated to contain only the specified single page.

## Actual behavior

`Invalid page URL` error. The MCP server appears to incorrectly validate single-value relation updates.

## Environment

- Tool: `mcp__claude_ai_Notion__notion-update-page` (Anthropic-hosted Notion connector via Claude.ai)
- Discovered via Claude Code (CLI), 2026-04-14
- Specific case: tenant master DB cleanup, reducing relation from 2 → 1
- OS: macOS Darwin 24.6.0

## Workaround (confirmed working)

Two-step:

1. Set relation to empty array first: `{ "<relation_property>": [] }`
2. Then set to desired single value: `{ "<relation_property>": [{ "id": "<page-id>" }] }`

Both steps succeed. The intermediate empty state is brief but should be performed atomically when possible to avoid data inconsistency.

## Related

- Bug 1 (replace_content prefix collision): see separate issue
- Internal manual: `docs/rules/notion-mcp-bugs.md` (Korean)
