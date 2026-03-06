"""
GitHub MCP Server with production-grade rate limiting.

Drop-in replacement for any GitHub MCP server that adds automatic
rate limiting, exponential backoff, and suspension prevention.

Author: Jonathan Melton (@JonathanMelton-FusionAL)
License: MIT
"""

from mcp.server.fastmcp import FastMCP
from typing import Optional
import os

from .github_client import SafeGitHubClient
from .rate_limiter import get_limiter

mcp = FastMCP("github-safe")


@mcp.tool()
async def list_issues(
    repo: str,
    state: str = "open",
    labels: Optional[str] = None,
    per_page: int = 30
) -> dict:
    """
    List issues with safe rate limiting.

    Args:
        repo: Repository in "owner/name" format
        state: Issue state ("open", "closed", "all")
        labels: Comma-separated label names
        per_page: Items per page (max 100)
    """
    async with SafeGitHubClient() as client:
        params = {"state": state, "per_page": min(per_page, 100)}
        if labels:
            params["labels"] = labels

        issues = await client.get(f"/repos/{repo}/issues", params=params)
        return {"repo": repo, "count": len(issues), "issues": issues}


@mcp.tool()
async def create_issue(
    repo: str,
    title: str,
    body: Optional[str] = None,
    labels: Optional[list[str]] = None
) -> dict:
    """Create a new issue with rate limiting."""
    async with SafeGitHubClient() as client:
        payload = {"title": title}
        if body:
            payload["body"] = body
        if labels:
            payload["labels"] = labels

        issue = await client.post(f"/repos/{repo}/issues", json=payload)
        return {
            "number": issue["number"],
            "url": issue["html_url"],
            "title": issue["title"]
        }


@mcp.tool()
async def bulk_analyze_issues(repo: str, max_issues: int = 10) -> dict:
    """
    Analyze multiple issues in SINGLE GraphQL call (97% API reduction).

    Replaces:
    - list_issues() -> 1 call
    - For each: get_issue(), get_comments(), get_labels() -> N*3 calls
    TOTAL: 1 + N*3 = 31 calls for 10 issues

    With:
    - Single GraphQL query -> 1 call
    TOTAL: 1 call (97% reduction)
    """
    owner, repo_name = repo.split("/")

    query = """
    query($owner: String!, $repo: String!, $maxIssues: Int!) {
      repository(owner: $owner, name: $repo) {
        issues(first: $maxIssues, states: OPEN, orderBy: {field: CREATED_AT, direction: DESC}) {
          nodes {
            number
            title
            body
            labels(first: 10) {
              nodes {
                name
              }
            }
            comments(first: 5) {
              totalCount
            }
            assignees(first: 5) {
              nodes {
                login
              }
            }
          }
        }
      }
    }
    """

    variables = {"owner": owner, "repo": repo_name, "maxIssues": max_issues}

    async with SafeGitHubClient() as client:
        data = await client.graphql(query, variables)
        issues = data["repository"]["issues"]["nodes"]

        # Analyze suitability locally (no extra API calls)
        analyzed = []
        for issue in issues:
            body_length = len(issue.get("body") or "")
            has_description = body_length > 100
            is_labeled = len(issue["labels"]["nodes"]) > 0
            unassigned = len(issue["assignees"]["nodes"]) == 0
            low_activity = issue["comments"]["totalCount"] < 10

            analyzed.append({
                "number": issue["number"],
                "title": issue["title"],
                "suitable_for_ai": has_description and is_labeled and unassigned and low_activity,
                "labels": [l["name"] for l in issue["labels"]["nodes"]],
                "comments_count": issue["comments"]["totalCount"]
            })

        return {"repo": repo, "analyzed_count": len(analyzed), "issues": analyzed}


@mcp.tool()
async def get_rate_limit_status() -> dict:
    """Check current GitHub API rate limit status."""
    async with SafeGitHubClient() as client:
        data = await client.get("/rate_limit")
        limiter = get_limiter()
        metrics = limiter.get_metrics()

        return {
            "github_api": data["resources"],
            "local_metrics": {
                "total_requests": metrics.total_requests,
                "requests_last_minute": metrics.requests_last_minute,
                "requests_last_hour": metrics.requests_last_hour,
                "total_wait_time_seconds": round(metrics.total_wait_time, 2),
                "retries": metrics.retries,
                "rate_limit_hits": metrics.rate_limit_hits,
                "success_rate": round(metrics.success_rate(), 2)
            }
        }


def main():
    mcp.run()


if __name__ == "__main__":
    main()
