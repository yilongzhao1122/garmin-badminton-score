# Run from an extracted source package after signing in with GitHub CLI.
# Creates a NEW public repository. Never overwrites an existing repository.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$Repo = 'yilongzhao1122/garmin-badminton-score'
foreach ($Tool in @('gh', 'git')) {
    if (-not (Get-Command $Tool -ErrorAction SilentlyContinue)) {
        throw "Install $Tool before publishing. See docs/PUBLISH_CN.md."
    }
}
$LoginName = (& gh api user --jq .login)
if ($LASTEXITCODE -ne 0) { throw 'Sign in first: gh auth login --hostname github.com --git-protocol https --web --scopes repo,workflow' }
if ($LoginName.Trim() -ne 'yilongzhao1122') { throw 'The active GitHub account must be yilongzhao1122.' }
if (Test-Path '.git') { throw 'Use a freshly extracted source package, without an existing .git directory.' }
$PreviousErrorPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& gh repo view $Repo --json name 2>$null | Out-Null
$RepositoryProbeExit = $LASTEXITCODE
$ErrorActionPreference = $PreviousErrorPreference
if ($RepositoryProbeExit -eq 0) { throw 'Repository already exists. Nothing was overwritten. Ask the agent to continue using the existing repository.' }
& git init --initial-branch=main
if ($LASTEXITCODE -ne 0) { throw 'git init failed.' }
& git config user.name 'yilongzhao1122'
& git config user.email '132163382+yilongzhao1122@users.noreply.github.com'
& git add -- .
if ($LASTEXITCODE -ne 0) { throw 'git add failed.' }
& git commit -m 'Release Garmin Badminton Score v0.11.0'
if ($LASTEXITCODE -ne 0) { throw 'git commit failed.' }
& gh repo create $Repo --public --source . --remote origin --description 'Chinese badminton scoring and service court guidance for Garmin Fenix 6X Pro / Solar, with ordinary FIT activity recording.' --push
if ($LASTEXITCODE -ne 0) { throw 'GitHub publication failed. Local files are retained; do not rerun blindly.' }
Write-Host 'Repository created. GitHub Actions will validate and publish the source release.'
Write-Host "https://github.com/$Repo/actions"
Write-Host "https://github.com/$Repo/releases/latest"
