"""
github-mcp-safe: Production-grade rate limiting for GitHub MCP servers.

Author: Jonathan Melton (@TangMan69)
License: MIT
"""

from .rate_limiter import (
    GitHubRateLimiter,
    RateLimitConfig,
    RateLimitMetrics,
    RateLimitExceeded,
    get_limiter
)

from .github_client import SafeGitHubClient

__version__ = "1.0.0"
__author__ = "Jonathan Melton (@TangMan69)"
__all__ = [
    "GitHubRateLimiter",
    "RateLimitConfig",
    "RateLimitMetrics",
    "RateLimitExceeded",
    "SafeGitHubClient",
    "get_limiter"
]
