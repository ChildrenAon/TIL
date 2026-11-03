# TIL 레포 작업 지침

## 이 컴퓨터에 기록 환경이 있는지 먼저 확인한다

이 레포를 처음 받아 왔거나 이 레포에서 세션을 시작하면, 첫 응답 전에 아래 점검을 한 번 돌린다. 아무것도 바꾸지 않는다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File setup\install.ps1 -Check
```

- 네 줄이 모두 `최신`이면 따로 말하지 않는다.
- `없음`이나 `옛 버전`이 하나라도 있으면 **설치하지 말고 먼저 묻는다.** [setup/README.md](setup/README.md)의 "설치하면 바뀌는 것"을 바탕으로 무엇이 있고 이 컴퓨터에서 무엇이 바뀌는지 짧게 정리한 뒤 "이 컴퓨터에도 적용할까요?"라고 묻는다. 항목별로 골라 적용하고 싶어 하면 그 항목만 손으로 넣는다.
- 사용자가 동의하면 `setup\install.ps1`(점검 옵션 없이)을 실행하고 결과를 알린다. 열려 있는 세션은 새로 시작해야 적용된다는 점도 알린다.
- 4번 "새벽 모아 보기 예약"은 설치 스크립트가 만들지 않는다. 동의를 받으면 예약 작업 도구(`create_scheduled_task`, `옛 버전`이면 `update_scheduled_task`)로 taskId `til-collect`, 제목 `TIL 모아 보기 (매일 새벽 5시)`, cron `0 5 * * *`, 완료 알림 끄기, 프롬프트는 [setup/til-collect-task.md](setup/til-collect-task.md) 전문 그대로 만든다. `node --version`으로 Node가 있는지도 본다. 앱이 열려 있을 때만 돌고, 꺼져 있었으면 다음에 켤 때 돈다는 점을 알린다.
- push에는 `gh`가 ChildrenAon 계정으로 로그인돼 있어야 한다(`gh auth status`). 로그인이 안 돼 있으면 사용자가 `gh auth login`을 직접 하도록 안내한다.

다른 폴더의 세션에서 이 레포를 받아 온 경우에도 같은 점검과 질문을 한다.

## 기록 형식

기록은 [setup/skills/til/SKILL.md](setup/skills/til/SKILL.md)의 형식과 [setup/til-style.md](setup/til-style.md)의 스타일 규칙(이쪽이 우선)을 따르고, 올리기 전에 초안을 보여 주고 확인받는다. `/til` 없이 손으로 고칠 때도 같다: `YYYY/Month/MM-DD.md` 하루 파일 하나, 항목 제목 앞 `[프로젝트]`/`[개념]`/`[코테]` 꼬리표, README 목차, `glossary.md`. 공개 레포라 학교 답변 원문·운영 값·키·개인정보·팀원 실명은 넣지 않는다.

## 설정을 고칠 때

`~/.claude`의 파일이 아니라 이 레포의 `setup/`을 고친다. 고친 뒤 이 컴퓨터에 `setup\install.ps1`을 실행하고, 커밋·push한다. 다른 컴퓨터는 `git pull` 뒤 같은 점검으로 `옛 버전`이 보이면 다시 적용할지 묻는다.
