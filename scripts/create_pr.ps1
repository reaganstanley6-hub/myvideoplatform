<#
PowerShell equivalent for create_pr.sh. Requires GITHUB_TOKEN and REPO (owner/repo) env vars.
Usage:
  powershell -ExecutionPolicy Bypass -File scripts\create_pr.ps1 -Branch feat/transcode-worker-ci -Base main
#>
param(
  [string]$Branch = "feat/transcode-worker-ci",
  [string]$Base = "main",
  [string]$Title = "feat: add transcoding worker, HLS, BullMQ, Docker Compose, and CI workflows",
  [string]$Body = "This PR adds FFmpeg-based transcoding, HLS multi-quality outputs, worker and queue scaffolding, Docker Compose for dev, and CI workflows for Playwright E2E tests."
)

if (-not $env:GITHUB_TOKEN) { Write-Host "GITHUB_TOKEN is required"; exit 1 }
if (-not $env:REPO) { Write-Host "REPO (owner/repo) is required"; exit 1 }

$api = "https://api.github.com/repos/$($env:REPO)/pulls"
$body = @{ title = $Title; head = $Branch; base = $Base; body = $Body; draft = $true } | ConvertTo-Json

Invoke-RestMethod -Uri $api -Method Post -Headers @{ Authorization = "token $($env:GITHUB_TOKEN)"; Accept = 'application/vnd.github+json' } -Body $body -ContentType 'application/json'
Write-Host "PR creation request sent."