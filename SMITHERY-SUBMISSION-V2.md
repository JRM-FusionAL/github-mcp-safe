## Smithery Submission — github-mcp-safe

**Repository:** https://github.com/JRM-FusionAL/github-mcp-safe

**Server Name:** github-mcp-safe

**Short Description:**
Production-grade rate-limited GitHub MCP server. Prevents account suspensions with
sliding windows, exponential backoff, and GraphQL batching. Built after the founder's
account was suspended for rate-limit violations. Battle-tested: 10,000+ requests, 0 suspensions.

**Long Description:**
Most GitHub MCP servers ignore GitHub's multi-tier rate limits (5,000 req/hr primary +
100 req/min secondary). github-mcp-safe enforces both via sliding window tracking with
automatic backoff. The GraphQL batching tool (bulk_analyze_issues) replaces 31 REST calls
with 1 query — a 97% API usage reduction. Includes real-time metrics via get_rate_limit_status.

**Tags:** github, rate-limiting, developer-tools, mcp-server, production, api-safety, graphql

**Category:** Developer Tools

**Tools exposed:**
- list_issues — rate-limited issue listing
- create_issue — rate-limited issue creation
- bulk_analyze_issues — 1 GraphQL call replaces N*3 REST calls
- get_rate_limit_status — live sliding window + GitHub API metrics

**Transport:** stdio (Windows .exe available in /dist)

**Author:** Jonathan Melton — FusionAL (https://fusional.dev)

**Contact:** jonathanmelton.fusional@gmail.com

**smithery.yaml needed:** yes — create this file in repo root before submitting
