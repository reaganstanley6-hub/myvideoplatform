<#
This script attempts to create a branch and commit when Git is available.
Usage:
  powershell -ExecutionPolicy Bypass -File scripts\git_commit_when_available.ps1
#>

$branch = "feat/transcode-worker-ci"
$message = "feat: add transcoding worker, HLS, BullMQ, Docker Compose, and CI workflows"
try {
  & git --version >$null 2>&1
} catch {
  Write-Host "Git not found in PATH. Install Git and re-run this script."; exit 1
}

try {
  & git checkout -b $branch
  & git add -A
  & git commit -m $message
  Write-Host "Committed on branch $branch"
} catch {
  Write-Host "Git operation failed. Resolve manually."; exit 1
}
