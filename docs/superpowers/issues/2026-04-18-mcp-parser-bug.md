# [bug] Notion MCP `notion-update-page` `replace_content`: child page URLs sharing 8-char prefix get deduplicated

## Summary

When using `replace_content` on `mcp__claude_ai_Notion__notion-update-page`, if `new_str` contains multiple `<page url="...">` tags whose URLs share the **first 8 characters**, only one is recognized. The other(s) trigger a "would delete" error, even though the intent is to preserve all of them.

## Steps to reproduce

1. Set up a parent Notion page with two child pages whose URLs start with the same 8-char prefix.
   - Example: child A `3387f080962181b3...`, child B `3387f0809621810d...` (both share prefix `3387f080`)
2. Call `notion-update-page` with `command: replace_content` and `new_str` containing both `<page url="...">` tags to preserve both children.
3. Observe: only one child is preserved. The other triggers a "would delete" warning/error.

## Expected behavior

Both child pages should be preserved when both `<page url="...">` tags are present in `new_str`, regardless of URL prefix similarity.

## Actual behavior

One child page is silently dropped. The error message implies the tool is about to delete it (`would delete <page url=...>`). The dedup appears to use the first 8 characters of the URL/ID as a key.

## Variations attempted (all failed identically)

- Undashed UUID format
- Dashed UUID format
- URL with slug appended (e.g., `agent-md-3387f080...`)
- Tag order reversed in `new_str`

## Environment

- Tool: `mcp__claude_ai_Notion__notion-update-page` (Anthropic-hosted Notion connector via Claude.ai)
- Discovered via Claude Code (CLI), 2026-04-12
- OS: macOS Darwin 24.6.0

## Workaround (confirmed working)

Use `update_content` instead of `replace_content`. Child pages live in blocks outside the body content (the part `update_content` modifies), so they are preserved automatically. No retry needed.

## Related

- Bug 2 (similar pattern, relation field validation): see separate issue
- Internal manual: `docs/rules/notion-mcp-bugs.md` (Korean)