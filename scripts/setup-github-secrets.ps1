# ============================================================
#  Chess4U – GitHub Secrets Setup Script (Windows PowerShell)
#  Run this once to push all signing secrets to your repo.
#  Requires: GitHub CLI (gh) – https://cli.github.com/
# ============================================================

param(
    [string]$Repo = "premjiitian/Chess4U"
)

# ── Helper ────────────────────────────────────────────────────────────────────
function Prompt-File($label, $filter) {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title  = "Select $label"
    $dialog.Filter = $filter
    if ($dialog.ShowDialog() -eq "OK") { return $dialog.FileName }
    Write-Error "No file selected for $label. Aborting."
    exit 1
}

function To-Base64($path) {
    return [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
}

function Set-GHSecret($name, $value) {
    Write-Host "  Setting $name ..." -NoNewline
    $value | gh secret set $name --repo $Repo
    Write-Host " OK"
}

# ── Pre-flight ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Chess4U – GitHub Secrets Setup" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI (gh) is not installed. Download from https://cli.github.com/ then re-run."
    exit 1
}

$authCheck = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "You are not logged in to GitHub CLI. Running 'gh auth login'..." -ForegroundColor Yellow
    gh auth login
}

# ── Collect files ─────────────────────────────────────────────────────────────
Write-Host "Step 1/4 – Distribution Certificate (.p12)" -ForegroundColor Green
$p12Path = Prompt-File "Distribution Certificate" "P12 Files (*.p12)|*.p12"
$p12Password = Read-Host "  Enter the .p12 export password" -AsSecureString
$p12PasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($p12Password))

Write-Host ""
Write-Host "Step 2/4 – Provisioning Profile (.mobileprovision)" -ForegroundColor Green
$profilePath = Prompt-File "App Store Provisioning Profile" "Provisioning Profiles (*.mobileprovision)|*.mobileprovision"

Write-Host ""
Write-Host "Step 3/4 – App Store Connect API Key (.p8)" -ForegroundColor Green
$p8Path = Prompt-File "App Store Connect API Key" "API Key Files (*.p8)|*.p8"

Write-Host ""
Write-Host "Step 4/4 – Manual values" -ForegroundColor Green
$teamID      = Read-Host "  Apple Team ID (10 chars, e.g. AB12CD34EF)"
$apiKeyID    = Read-Host "  App Store Connect API Key ID (e.g. ABCD123456)"
$issuerID    = Read-Host "  App Store Connect Issuer ID (UUID format)"
$keychainPwd = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object { [char]$_ })
Write-Host "  KEYCHAIN_PASSWORD auto-generated: $keychainPwd"

# ── Push secrets ──────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Pushing secrets to $Repo ..." -ForegroundColor Cyan

Set-GHSecret "BUILD_CERTIFICATE_BASE64"          (To-Base64 $p12Path)
Set-GHSecret "P12_PASSWORD"                       $p12PasswordPlain
Set-GHSecret "BUILD_PROVISION_PROFILE_BASE64"    (To-Base64 $profilePath)
Set-GHSecret "KEYCHAIN_PASSWORD"                  $keychainPwd
Set-GHSecret "DEVELOPMENT_TEAM"                   $teamID
Set-GHSecret "APP_STORE_CONNECT_API_KEY_ID"       $apiKeyID
Set-GHSecret "APP_STORE_CONNECT_ISSUER_ID"        $issuerID
Set-GHSecret "APP_STORE_CONNECT_API_KEY_BASE64"  (To-Base64 $p8Path)

Write-Host ""
Write-Host "All secrets set successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "To trigger your first TestFlight build, run:" -ForegroundColor Yellow
Write-Host "  git tag v1.0.0 && git push origin v1.0.0" -ForegroundColor White
Write-Host ""
