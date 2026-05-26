# Enma Helix support installer (Windows PowerShell)
$ErrorActionPreference = "Stop"

$HelixRuntime = "$env:APPDATA\helix\runtime"
$Config = "$env:APPDATA\helix"
$BinDir = "$env:LOCALAPPDATA\enma-lsp"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Installing Enma for Helix..."

# LSP binary
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
$lspFile = Join-Path $ScriptDir "enma-lsp.exe"
if (Test-Path $lspFile) {
    Copy-Item $lspFile -Destination $BinDir
    Write-Host "  enma-lsp.exe -> $BinDir\enma-lsp.exe"
}

# Add to user PATH
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$BinDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$BinDir", "User")
    Write-Host "  added $BinDir to user PATH"
}

# Tree-sitter grammar
$GrammarDir = "$HelixRuntime\grammars"
New-Item -ItemType Directory -Force -Path $GrammarDir | Out-Null
Get-ChildItem "$ScriptDir\runtime\grammars\enma.*" | ForEach-Object {
    Copy-Item $_.FullName -Destination $GrammarDir
    Write-Host "  grammar -> $GrammarDir\$($_.Name)"
}

# Queries
$QueriesDir = "$HelixRuntime\queries\enma"
Remove-Item -Recurse -Force $QueriesDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $QueriesDir | Out-Null
Copy-Item "$ScriptDir\runtime\queries\enma\*.scm" -Destination $QueriesDir
Write-Host "  queries -> $QueriesDir\"

# Language config
$LanguagesToml = "$Config\languages.toml"
New-Item -ItemType Directory -Force -Path $Config | Out-Null
$existing = if (Test-Path $LanguagesToml) { Get-Content $LanguagesToml -Raw } else { "" }
if ($existing -notmatch 'name = "enma"') {
    "`n" | Out-File -Append -FilePath $LanguagesToml -NoNewline
    Get-Content "$ScriptDir\languages.toml" | Out-File -Append -FilePath $LanguagesToml
    Write-Host "  config -> $LanguagesToml"
} else {
    Write-Host "  config already present (skipped)"
}

Write-Host ""
Write-Host "Done! Restart Helix and open any .em file — highlighting and LSP are active."
Write-Host "Verify with: hx --health enma"
