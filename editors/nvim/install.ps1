# Enma Neovim plugin installer (Windows PowerShell)
$ErrorActionPreference = "Stop"

$Data = "$env:LOCALAPPDATA\nvim-data"
$Config = "$env:LOCALAPPDATA\nvim"
$BinDir = "$env:LOCALAPPDATA\enma-lsp"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Installing Enma for Neovim..."

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

# Tree-sitter parser
$ParserDir = "$Data\site\parser"
New-Item -ItemType Directory -Force -Path $ParserDir | Out-Null
Get-ChildItem "$ScriptDir\parser\enma.*" | ForEach-Object {
    Copy-Item $_.FullName -Destination $ParserDir
    Write-Host "  parser -> $ParserDir\$($_.Name)"
}

# Queries
$QueriesDir = "$Data\site\queries\enma"
Remove-Item -Recurse -Force $QueriesDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $QueriesDir | Out-Null
Copy-Item "$ScriptDir\queries\enma\*.scm" -Destination $QueriesDir
Write-Host "  queries -> $QueriesDir\"

# Lua plugin files
$LuaDir = "$Config\lua\enma"
New-Item -ItemType Directory -Force -Path $LuaDir | Out-Null
Copy-Item "$ScriptDir\lua\enma\init.lua" -Destination $LuaDir
$PluginDir = "$Config\plugin"
New-Item -ItemType Directory -Force -Path $PluginDir | Out-Null
Copy-Item "$ScriptDir\plugin\enma.lua" -Destination $PluginDir
Write-Host "  plugin -> $PluginDir\enma.lua"

# LazyVim plugin spec
$LazyPlugins = "$Config\lua\plugins"
if (Test-Path $LazyPlugins) {
    Copy-Item "$ScriptDir\lua\plugins\enma.lazyvim.lua" -Destination "$LazyPlugins\enma.lua"
    Write-Host "  lazyvim spec -> $LazyPlugins\enma.lua"
}

Write-Host ""
Write-Host "Done! Restart Neovim and open any .em file."
Write-Host "If using LazyVim: run :Lazy sync after installing."
