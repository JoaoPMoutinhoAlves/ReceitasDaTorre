# Run this script once from PowerShell to copy the project into your git repo
# and make the initial commit.
#
# Usage (from PowerShell as normal user):
#   cd C:\Users\joaop\Claude\Projects\ReceitasDaTorre
#   .\init-repo.ps1

$source = "C:\Users\joaop\Claude\Projects\ReceitasDaTorre"
$dest   = "C:\repos\ReceitasDaTorre"

Write-Host "Copying project files to $dest ..."
# robocopy handles missing dest dir automatically; /XD excludes dirs
robocopy $source $dest /E /XD ".git" "__pycache__" "build" ".dart_tool" /XF "*.pyc" /NFL /NDL /NJH /NJS | Out-Null
Write-Host "Copy done."

Set-Location $dest

# Init only if not already a git repo
if (-not (Test-Path ".git")) {
    git init -b main
    Write-Host "Git repo initialised."
}

git add -A
git commit -m "feat: initial Recipe Manager app

- FastAPI + PostgreSQL backend (Docker, Raspberry Pi)
- Claude API recipe parser: transforms Instagram/TikTok captions into structured recipes
- Flutter app (Android + Web) with share-intent support
- Home screen: search + category filter
- Recipe detail screen with ingredients and steps
- Settings screen to configure server URL"

Write-Host ""
Write-Host "Done! Repo is ready at $dest"
