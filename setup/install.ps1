# TIL 기록 환경을 이 컴퓨터의 ~/.claude에 설치한다.
#   - 전역 CLAUDE.md의 TIL-SETUP 블록 (세션 이름·사이드바 그룹·공부 세션 설명 방식)
#   - /til 스킬 (+ 이 레포 경로)
#   - 요청마다 세션 이름을 점검하게 하는 UserPromptSubmit 훅
# 설치:  powershell -ExecutionPolicy Bypass -File setup\install.ps1
# 점검:  powershell -ExecutionPolicy Bypass -File setup\install.ps1 -Check   (아무것도 바꾸지 않는다)
# 여러 번 실행해도 된다. CLAUDE.md는 TIL-SETUP 블록만 바꾸고, 훅은 중복으로 추가하지 않는다.

param(
    [string]$ClaudeDir = (Join-Path $HOME '.claude'),
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$setup = $PSScriptRoot
$repo = Split-Path $setup -Parent
$claude = $ClaudeDir
$utf8 = New-Object System.Text.UTF8Encoding $false
$begin = '<!-- TIL-SETUP:BEGIN -->'
$end = '<!-- TIL-SETUP:END -->'
$marker = '[세션 이름 점검]'

function Read-Text([string]$path) {
    if (Test-Path $path) { return ([IO.File]::ReadAllText($path)) -replace "`r`n", "`n" }
    return $null
}

$block = (Read-Text (Join-Path $setup 'CLAUDE.md')).Trim()
$command = (Read-Text (Join-Path $setup 'session-name-hook.txt')).Trim()
$mdPath = Join-Path $claude 'CLAUDE.md'
$skillDst = Join-Path $claude 'skills\til'
$settingsPath = Join-Path $claude 'settings.json'
$blockPattern = [regex]::Escape($begin) + '(?s)(.*?)' + [regex]::Escape($end)

# --- 현재 상태 ---
$md = Read-Text $mdPath
$mdState = '없음'
if ($null -ne $md) {
    $m = [regex]::Match($md, $blockPattern)
    if (-not $m.Success) { $mdState = '없음(다른 전역 규칙만 있음)' }
    elseif ($m.Groups[1].Value.Trim() -eq $block) { $mdState = '최신' }
    else { $mdState = '옛 버전' }
}

$skillState = '없음'
if (Test-Path (Join-Path $skillDst 'SKILL.md')) {
    $sameSkill = (Read-Text (Join-Path $skillDst 'SKILL.md')) -eq (Read-Text (Join-Path $setup 'skills\til\SKILL.md'))
    $samePath = (Read-Text (Join-Path $skillDst 'repo_path.txt')) -eq $repo
    if ($sameSkill -and $samePath) { $skillState = '최신' } else { $skillState = '옛 버전' }
}

$settings = $null
if (Test-Path $settingsPath) {
    $raw = [IO.File]::ReadAllText($settingsPath)
    if ($raw.Trim()) { $settings = $raw | ConvertFrom-Json }
}
$hookState = '없음'
if ($settings -and $settings.PSObject.Properties['hooks'] -and $settings.hooks.PSObject.Properties['UserPromptSubmit']) {
    foreach ($group in @($settings.hooks.UserPromptSubmit)) {
        foreach ($h in @($group.hooks)) {
            if ($h.command -and $h.command.Contains($marker)) {
                if ($h.command -eq $command) { $hookState = '최신' } else { $hookState = '옛 버전' }
            }
        }
    }
}

Write-Host "전역 규칙(CLAUDE.md 블록): $mdState"
Write-Host "/til 스킬: $skillState"
Write-Host "세션 이름 훅: $hookState"

if ($Check) { return }
Write-Host ''

New-Item -ItemType Directory -Force $claude | Out-Null

# 1. 전역 CLAUDE.md: TIL-SETUP 블록만 넣거나 바꾼다. 블록 밖의 내용은 그대로 둔다
if ($mdState -ne '최신') {
    $newBlock = "$begin`n$block`n$end"
    if ($null -eq $md) {
        $out = "$newBlock`n"
    } else {
        Copy-Item $mdPath "$mdPath.bak" -Force
        if ($mdState -eq '옛 버전') {
            $out = [regex]::Replace($md, $blockPattern, [Text.RegularExpressions.MatchEvaluator] { param($x) $newBlock })
        } else {
            $out = $md.TrimEnd() + "`n`n" + $newBlock + "`n"
        }
    }
    [IO.File]::WriteAllText($mdPath, $out, $utf8)
    Write-Host "CLAUDE.md 블록 설치: $mdPath"
}

# 2. /til 스킬과 이 레포 경로
New-Item -ItemType Directory -Force $skillDst | Out-Null
Copy-Item (Join-Path $setup 'skills\til\*') $skillDst -Recurse -Force
[IO.File]::WriteAllText((Join-Path $skillDst 'repo_path.txt'), $repo, $utf8)
Write-Host "/til 스킬 설치: $skillDst (레포: $repo)"

# 3. 세션 이름 리마인더 훅을 settings.json에 병합한다. 다른 설정과 훅은 그대로 둔다
if ($hookState -ne '최신') {
    if ($null -eq $settings) { $settings = [pscustomobject]@{} }
    if (-not $settings.PSObject.Properties['hooks']) {
        $settings | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{})
    }
    if (-not $settings.hooks.PSObject.Properties['UserPromptSubmit']) {
        $settings.hooks | Add-Member -NotePropertyName UserPromptSubmit -NotePropertyValue @()
    }
    $found = $false
    foreach ($group in @($settings.hooks.UserPromptSubmit)) {
        foreach ($h in @($group.hooks)) {
            if ($h.command -and $h.command.Contains($marker)) { $h.command = $command; $found = $true }
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
    Write-Host "훅 설치: $settingsPath"
}

Write-Host ''
Write-Host '완료. 열려 있는 Claude 세션은 새로 시작해야 설정이 적용된다.'
