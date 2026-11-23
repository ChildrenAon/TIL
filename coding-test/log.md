# 코테 기록

프로그래머스(JavaScript)로 푼 문제를 문제마다 세 줄로 남긴다. "코테 공부하려고"라고 하면 Claude가 이 기록과 단계 규칙([setup/skills/coding-test](../setup/skills/coding-test/SKILL.md))을 보고 오늘 문제를 골라 즐겨찾기해 두고, "코테 기록"이라고 하면 여기에 추가한다. 정답 코드와 문제 본문은 남기지 않는다.

## 현재 단계

- 단계 A (Lv0) — 코딩테스트 입문 Lv0 하루 4문제
- 다음 단계 기준: 최근 Lv0 5문제를 모두 풀이 없이 10분 안에

## 다시 풀 문제

- 2026-11-26 [문자 리스트를 문자열로 변환하기](https://school.programmers.co.kr/learn/courses/30/lessons/181941)

## 기록

### 2026-11-23

- [문자 리스트를 문자열로 변환하기](https://school.programmers.co.kr/learn/courses/30/lessons/181941) · Lv0 · 문자열 · 10분 · 풀이 봄
  - 핵심: 배열 → 문자열은 `join('')`, 반복문이면 `answer += arr[i]`
  - 틀린 이유: 반복 시작을 `i = arr.length`로 써서 한 번도 돌지 않음 (손풀이를 건너뜀)
