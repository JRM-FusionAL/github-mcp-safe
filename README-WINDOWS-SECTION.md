## Installation

### Windows Users (Recommended - Zero Dependencies)

**Download the standalone executable** - no Python installation required:

1. Go to [Releases](https://github.com/JonathanMelton-FusionAL/github-mcp-safe/releases)
2. Download `github-mcp-safe-windows.exe`
3. Move to your preferred location (e.g., `C:\Program Files\github-mcp-safe\`)
4. Done! Run it from command line or PowerShell

```powershell
# Test the executable
.\github-mcp-safe-windows.exe --version

# Add to Claude Desktop config
notepad $env:APPDATA\Claude\claude_desktop_config.json
```

Add this to your Claude Desktop config:
```json
{
  "mcpServers": {
    "github-safe": {
      "command": "C:\\Program Files\\github-mcp-safe\\github-mcp-safe-windows.exe",
      "env": {
        "GITHUB_TOKEN": "ghp_your_token_here"
      }
    }
  }
}
```

**Benefits**:
- ✅ No Python installation needed
- ✅ No UV package manager required
- ✅ No dependency conflicts
- ✅ Enterprise IT-approved (standalone executable)
- ✅ Works on locked-down corporate machines

**File size**: ~45MB (includes all dependencies)

---

### Python Users (All Platforms)

```bash
# Using UV (recommended)
uv pip install github-mcp-safe

# Using pip
pip install github-mcp-safe
```

Then add to Claude Desktop config:
```json
{
  "mcpServers": {
    "github-safe": {
      "command": "uv",
      "args": ["run", "github-mcp-safe"],
      "env": {
        "GITHUB_TOKEN": "ghp_your_token_here"
      }
    }
  }
}
```

---

### From Source (Developers)

```bash
git clone https://github.com/JonathanMelton-FusionAL/github-mcp-safe.git
cd github-mcp-safe
uv sync
uv run github-mcp-safe
```
