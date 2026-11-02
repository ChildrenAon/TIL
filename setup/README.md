# setup — 기록 환경 설치

Claude Code에서 `/til`로 기록하려면 컴퓨터마다 한 번 설치한다. 설치하면 아래 세 가지가 `~/.claude`에 들어간다.

| 파일 | 하는 일 |
|---|---|
| `CLAUDE.md` | 전역 지침. 세션 이름을 `[분류] 주제 #PR`로 붙이고 사이드바 그룹에 넣는 규칙 |
| `skills/til/` | `/til` 스킬. 대화에서 새로 배운 것을 오늘 날짜 파일에 정리하고 push한다 |
| `session-name-hook.txt` | 요청마다 세션 이름을 점검하게 하는 훅 문구. `settings.json`에 병합된다 |

## 처음 설치 (Windows)

```powershell
gh repo clone ChildrenAon/TIL "$HOME\Desktop\project\TIL"
cd "$HOME\Desktop\project\TIL"
powershell -ExecutionPolicy Bypass -File setup\install.ps1
```

클론 위치는 아무 곳이나 괜찮다. 설치 스크립트가 이 레포 경로를 스킬에 기록한다. 설치한 뒤에는 Claude 세션을 새로 시작한다.

## 규칙을 고칠 때

`~/.claude`의 파일을 직접 고치지 말고 이 레포의 `setup/` 파일을 고친 뒤 push한다. 다른 컴퓨터에서는 아래 두 줄로 맞춘다.

```powershell
git pull
powershell -ExecutionPolicy Bypass -File setup\install.ps1
```

스크립트는 여러 번 실행해도 된다. 기존 `CLAUDE.md`가 다르면 `.bak-날짜`로 백업하고, `settings.json`은 `.bak`을 남긴 뒤 훅만 병합한다. 다른 설정은 건드리지 않는다.
