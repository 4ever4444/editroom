# The one line a user pastes in PowerShell (stage 13.3, D8): irm <address>/install.ps1 | iex
# It makes C:\EditRoom, brings uv (checked against its published SHA-256) and the system's code, and hands over to
# install/setup.py, which shows the approval and the progress on a page in the browser. Nothing needs admin rights.
# For a test, before iex: $EditRoomSource = '<a local release .zip>'; $EditRoomRoot = 'C:\EditRoomTest'
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Root = if ($EditRoomRoot) { $EditRoomRoot } else { 'C:\EditRoom' }
$Release = 'https://raw.githubusercontent.com/4ever4444/editroom/main'   # D9: the public repo of releases only
$Uv = @{ Url = 'https://github.com/astral-sh/uv/releases/download/0.13.9/uv-x86_64-pc-windows-msvc.zip';
         Sha = 'edd61f7f5728a56cc62455386661860bdfc7bab65872f39b0c25bdcc1d8e1beb' }

function Get-Checked($url, $sha, $dest) {
    if ((Test-Path $dest) -and ((Get-FileHash $dest -Algorithm SHA256).Hash -eq $sha)) { return }
    Invoke-WebRequest -UseBasicParsing $url -OutFile "$dest.part"
    if ((Get-FileHash "$dest.part" -Algorithm SHA256).Hash -ne $sha) {
        Remove-Item "$dest.part"; throw "Downloaded file does not match its published SHA-256: $url"
    }
    Move-Item -Force "$dest.part" $dest
}

if ($Root -match '[^\x20-\x7E]' -or $Root -match ' ') { throw "The install folder must be an English name with no spaces: $Root" }
$cache = Join-Path $Root 'runtime\.cache'
New-Item -ItemType Directory -Force $cache | Out-Null

# uv: the one tool that brings Python 3.12 (python-build-standalone), into the root, not the user's profile
Get-Checked $Uv.Url $Uv.Sha (Join-Path $cache 'uv.zip')
Expand-Archive -Force (Join-Path $cache 'uv.zip') (Join-Path $Root 'runtime\uv')

# the system's code: a release .zip, checked against the SHA-256 in its version.json
$app = Join-Path $Root 'app'
if (-not (Test-Path (Join-Path $app 'install\setup.py'))) {
    $zip = Join-Path $cache 'editroom.zip'
    if ($EditRoomSource) { Copy-Item -Force $EditRoomSource $zip }
    else {
        $v = Invoke-RestMethod "$Release/version.json"
        Get-Checked "$Release/$($v.file)" $v.sha256 $zip
    }
    Remove-Item -Recurse -Force "$app.new" -ErrorAction SilentlyContinue
    Expand-Archive -Force $zip "$app.new"
    if ($v) { $v | ConvertTo-Json | Set-Content -Encoding UTF8 "$app.new\version.json" }   # which version this is (updates)
    Move-Item "$app.new" $app
}

$env:UV_PYTHON_INSTALL_DIR = Join-Path $Root 'runtime\python'
$env:UV_CACHE_DIR = Join-Path $cache 'uv'
$env:TEMP = $env:TMP = (New-Item -ItemType Directory -Force (Join-Path $Root 'runtime\tmp')).FullName
& (Join-Path $Root 'runtime\uv\uv.exe') run --no-project --python 3.12 (Join-Path $app 'install\setup.py') --root $Root --app $app --ui
