"""
Safe GitHub API client with built-in rate limiting.

Author: Jonathan Melton (@JonathanMelton-FusionAL)
License: MIT
"""

import os
import httpx
from typing import Optional, Any, Dict, List
import logging

from .rate_limiter import GitHubRateLimiter, get_limiter

logger = logging.getLogger(__name__)


class SafeGitHubClient:
    """GitHub API client with production-grade safety features."""
    
    def __init__(
        self,
        token: Optional[str] = None,
        limiter: Optional[GitHubRateLimiter] = None,
        user_agent: str = "github-mcp-safe/1.0",
        base_url: str = "https://api.github.com"
    ):
        self.token = token or os.getenv("GITHUB_TOKEN")
        if not self.token:
            raise ValueError("GitHub token required (set GITHUB_TOKEN env var)")
        
        self.limiter = limiter or get_limiter()
        self.user_agent = user_agent
        self.base_url = base_url.rstrip("/")
        self._client: Optional[httpx.AsyncClient] = None
    
    async def __aenter__(self):
        self._client = httpx.AsyncClient(
            timeout=30.0,
            limits=httpx.Limits(max_connections=100, max_keepalive_connections=20)
        )
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self._client:
            await self._client.aclose()
    
    def _get_headers(self) -> Dict[str, str]:
        return {
            "Authorization": f"Bearer {self.token}",
            "User-Agent": self.user_agent,
            "X-GitHub-Api-Version": "2022-11-28",
            "Accept": "application/vnd.github+json"
        }
    
    async def get(self, path: str, params: Optional[Dict[str, Any]] = None, **kwargs) -> Any:
        """Safe GET request with rate limiting."""
        url = f"{self.base_url}{path}" if path.startswith("/") else path
        
        async def _request():
            if not self._client:
                raise RuntimeError("Client not initialized. Use 'async with SafeGitHubClient()'")
            
            resp = await self._client.get(url, params=params, headers=self._get_headers(), **kwargs)
            resp.raise_for_status()
            self.limiter.update_from_headers(dict(resp.headers))
            return resp.json()
        
        return await self.limiter.execute(_request)
    
    async def post(self, path: str, json: Optional[Dict[str, Any]] = None, **kwargs) -> Any:
        """Safe POST request with rate limiting."""
        url = f"{self.base_url}{path}" if path.startswith("/") else path
        
        async def _request():
            if not self._client:
                raise RuntimeError("Client not initialized")
            
            resp = await self._client.post(url, json=json, headers=self._get_headers(), **kwargs)
            resp.raise_for_status()
            self.limiter.update_from_headers(dict(resp.headers))
            return resp.json()
        
        return await self.limiter.execute(_request)
    
    async def graphql(self, query: str, variables: Optional[Dict[str, Any]] = None) -> Any:
        """Execute GraphQL query with rate limiting."""
        async def _request():
            if not self._client:
                raise RuntimeError("Client not initialized")
            
            resp = await self._client.post(
                f"{self.base_url}/graphql",
                json={"query": query, "variables": variables or {}},
                headers=self._get_headers()
            )
            resp.raise_for_status()
            self.limiter.update_from_headers(dict(resp.headers))
            
            data = resp.json()
            if "errors" in data:
                raise Exception(f"GraphQL errors: {data['errors']}")
            
            return data.get("data", {})
        
        return await self.limiter.execute(_request)
