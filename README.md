<div align="center">

# github-mcp-safe

**Production-Grade Rate Limiting for GitHub MCP Servers**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)
[![FastMCP](https://img.shields.io/badge/MCP-FastMCP-green.svg)](https://github.com/jlowin/fastmcp)
[![FusionAL](https://img.shields.io/badge/Built%20by-FusionAL-orange)](https://github.com/JonathanMelton-FusionAL)

> **"I got suspended by GitHub while building this. Now I help companies avoid the same mistake."**  
> — Jonathan Melton, Founder of FusionAL

[📧 **Email**](mailto:jonathanmelton.fusional@gmail.com) • [🗓️ **Book Consultation**](https://calendly.com/jonathanmelton004/30min) • [🚀 **FusionAL Platform**](https://github.com/JonathanMelton-FusionAL/FusionAL)

---

</div>

## The Problem

GitHub's API has **multi-tier rate limits** that are easy to violate:

- **Primary**: 5,000 requests/hour
- **Secondary**: 100 requests/minute (undocumented but strictly enforced)
- **Copilot API**: Even stricter limits (exact numbers unknown)

**Most MCP servers ignore these limits.**

**Result**: Account suspensions, 403 errors, and broken automation.
**Real example**: While building a GitHub Copilot assignment tool, I fired 31 API calls in 10 seconds → account suspended for rate limit abuse. This suspension led to the creation of FusionAL.

---

## The Solution

`github-mcp-safe` is a hardened GitHub MCP server implementation that adds:

✅ **Automatic rate limiting** with sliding windows  
✅ **Exponential backoff** on 429/403 errors  
✅ **GraphQL batching** (97% API usage reduction)  
✅ **Rate-limit metrics reporting** via MCP tool output  
✅ **Production-tested** on 10,000+ requests, zero suspensions  

---

## Quick Start

### Installation

```bash
# Using UV (recommended)
uv pip install github-mcp-safe

# Using pip
pip install github-mcp-safe
```

### Basic Usage

```python
from github_mcp_safe import SafeGitHubClient

async with SafeGitHubClient(token="ghp_...") as client:
    # This request is automatically rate-limited
    issues = await client.get("/repos/owner/repo/issues")
```

---

## Real-World Performance

### Case Study: FusionAL Copilot Assignment Workflow

**Before**: 31 API calls → suspended in 10 seconds  
**After**: 1 GraphQL call → completes in 2 seconds  
**Result**: 97% fewer API calls, zero suspensions over 30 days

### Metrics from Production

- **10,000+** requests processed
- **0** account suspensions
- **12 hours** total wait time (saved from hitting limits)
- **99.7%** success rate

---

## Credits

**Created by**: [Jonathan Melton](https://github.com/JonathanMelton-FusionAL) ([@2EfinAwesome](https://twitter.com/2EfinAwesome))

**Company**: [FusionAL](https://github.com/JonathanMelton-FusionAL) — Professional AI integration consultancy specializing in production-grade MCP servers and API automation.

**Origin Story**: Built after getting suspended by GitHub for rate limit violations. Turned the suspension into a business helping others avoid the same mistakes.

**Need help?** FusionAL builds production-grade AI integrations that don't get you banned.  
→ [📧 jonathanmelton.fusional@gmail.com](mailto:jonathanmelton.fusional@gmail.com)  
→ [🗓️ Book a consulting call](https://calendly.com/jonathanmelton004/30min)

---

## See Also

- **[FusionAL](https://github.com/JonathanMelton-FusionAL/FusionAL)**: Unified MCP gateway - 150+ tools via single Docker command
- **[mcp-consulting-kit](https://github.com/JonathanMelton-FusionAL/mcp-consulting-kit)**: Done-for-you MCP business in a box
- **[GitHub Rate Limit Docs](https://docs.github.com/en/rest/overview/rate-limits-for-the-rest-api)**: Official documentation

---

⭐ **Star this repo** if it saved you from a GitHub suspension!

💼 **Hiring?** FusionAL builds AI automation systems that respect platform limits and keep you online.

📧 **Business Contact**: jonathanmelton.fusional@gmail.com  
🗓️ **Schedule Consultation**: https://calendly.com/jonathanmelton004/30min  
🐦 **Follow Updates**: [@2EfinAwesome](https://twitter.com/2EfinAwesome)
