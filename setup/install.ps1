# TIL 기록 환경을 이 컴퓨터의 ~/.claude에 설치한다.
#   - 전역 CLAUDE.md (세션 이름·사이드바 그룹 규칙)
#   - /til 스킬 (+ 이 레포 경로)
#   - 요청마다 세션 이름을 점검하게 하는 UserPromptSubmit 훅
# 실행: powershell -ExecutionPolicy Bypass -File setup\install.ps1
# 여러 번 실행해도 된다. 훅은 중복으로 추가하지 않고 문구만 최신으로 맞춘다.

param([string]$ClaudeDir = (Join-Path $HOME '.claude'))

$ErrorActionPreference = 'Stop'
$setup = $PSScriptRoot
$repo = Split-Path $setup -Parent
$claude = $ClaudeDir
$utf8 = New-Object System.Text.UTF8Encoding $false
New-Item -ItemType Directory -Force $claude | Out-Null

# 1. 전역 CLAUDE.md: 내용이 다르면 백업한 뒤 덮어쓴다
$src = Join-Path $setup 'CLAUDE.md'
$dst = Join-Path $claude 'CLAUDE.md'
if ((Test-Path $dst) -and ((Get-FileHash $dst).Hash -ne (Get-FileHash $src).Hash)) {
    $bak = "$dst.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item $dst $bak
    Write-Host "기존 CLAUDE.md 백업: $bak"
}
Copy-Item $src $dst -Force
Write-Host "CLAUDE.md 설치: $dst"

# 2. /til 스킬과 이 레포 경로
$skillDst = Join-Path $claude 'skills\til'
New-Item -ItemType Directory -Force $skillDst | Out-Null
Copy-Item (Join-Path $setup 'skills\til\*') $skillDst -Recurse -Force
[IO.File]::WriteAllText((Join-Path $skillDst 'repo_path.txt'), $repo, $utf8)
Write-Host "/til 스킬 설치: $skillDst (레포: $repo)"

# 3. 세션 이름 리마인더 훅을 settings.json에 병합한다
$marker = '[세션 이름 점검]'
$command = (Get-Content (Join-Path $setup 'session-name-hook.txt') -Raw -Encoding UTF8).Trim()
$settingsPath = Join-Path $claude 'settings.json'
$raw = '{}'
if (Test-Path $settingsPath) { $raw = [IO.File]::ReadAllText($settingsPath) }
if (-not $raw.Trim()) { $raw = '{}' }
$settings = $raw | ConvertFrom-Json

if (-not $settings.PSObject.Properties['hooks']) {
    $settings | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{})
}
if (-not $settings.hooks.PSObject.Properties['UserPromptSubmit']) {
    $settings.hooks | Add-Member -NotePropertyName UserPromptSubmit -NotePropertyValue @()
}

$found = $false
foreach ($group in @($settings.hooks.UserPromptSubmit)) {
    foreach ($h in @($group.hooks)) {
        if ($h.command -and $h.command.Contains($marker)) {
            $h.command = $command
            $found = $true
        }
    }
}
if (-not $found) {
    $entry = [pscustomobject]@{
        hooks = @([pscustomobject]@{ type = 'command'; command = $command; timeout = 5 })
    }
    $settings.hooks.UserPromptSubmit = @($settings.hooks.UserPromptSubmit) + $entry
}

if (Test-Path $settingsPath) { Copy-Item $settingsPath "$settingsPath.bak" -Force }
[IO.File]::WriteAllText($settingsPath, ($settings | ConvertTo-Json -Depth 32), $utf8)
if ($found) { Write-Host "훅 문구 갱신: $settingsPath" } else { Write-Host "훅 추가: $settingsPath" }

Write-Host ''
Write-Host '완료. 열려 있는 Claude 세션은 새로 시작해야 설정이 적용된다.'
