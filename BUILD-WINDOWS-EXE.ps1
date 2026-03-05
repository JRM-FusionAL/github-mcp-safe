# Build Windows Executable for github-mcp-safe
$ErrorActionPreference = "Stop"

Set-Location C:\Users\puddi\Projects\github-mcp-safe

Write-Host "`n=== Creating virtual environment ===" -ForegroundColor Cyan
if (Test-Path ".venv") { Remove-Item -Recurse -Force .venv }
uv venv .venv --python 3.11

Write-Host "`n=== Installing dependencies ===" -ForegroundColor Cyan
uv pip install --python .venv/Scripts/python.exe pyinstaller fastmcp httpx

Write-Host "`n=== Building Windows Executable ===" -ForegroundColor Cyan
$env:PYTHONPATH = "src"
.venv/Scripts/python.exe -m PyInstaller `
  --onefile `
  --name github-mcp-safe-windows `
  --paths src `
  --hidden-import github_mcp_safe `
  --hidden-import github_mcp_safe.rate_limiter `
  --hidden-import github_mcp_safe.github_client `
  --hidden-import github_mcp_safe.server `
  --hidden-import httpx `
  --hidden-import fastmcp `
  --console `
  --clean `
  main.py

if (Test-Path ".\dist\github-mcp-safe-windows.exe") {
    Write-Host "`n=== Testing Executable ===" -ForegroundColor Cyan
    .\dist\github-mcp-safe-windows.exe

    Write-Host "`n SUCCESS! Windows executable built" -ForegroundColor Green
    Write-Host "Location: $PWD\dist\github-mcp-safe-windows.exe" -ForegroundColor Cyan

    $size = (Get-Item .\dist\github-mcp-safe-windows.exe).Length / 1MB
    Write-Host ("Size: {0:N2} MB" -f $size) -ForegroundColor Yellow

    Write-Host "`n=== Next Steps ===" -ForegroundColor Yellow
    Write-Host "1. Test: .\dist\github-mcp-safe-windows.exe"
    Write-Host "2. Create release: gh release create v1.0.0 .\dist\github-mcp-safe-windows.exe"
    Write-Host "3. Update README with download link"
    Write-Host "4. Announce on Reddit/LinkedIn"
} else {
    Write-Host "`n Build failed - executable not found" -ForegroundColor Red
    Write-Host "Check build output above for errors" -ForegroundColor Yellow
}
