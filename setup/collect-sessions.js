#!/usr/bin/env node
// 이 컴퓨터의 Claude Code 세션 기록(~/.claude/projects/*/*.jsonl)에서
// 지난번 모아 보기 이후의 대화만 뽑아 /til 모아 보기 모드가 읽을 텍스트로 만든다.
//
//   node collect-sessions.js [--since ISO] [--until ISO] [--out 파일]
//   node collect-sessions.js --mark ISO      # 여기까지 모았다고 기록
//
// - 기간: --since가 없으면 마지막으로 --mark한 시각, 그것도 없으면 24시간 전부터.
// - 세션에서 /til을 이미 했으면 그 뒤의 대화만 남긴다(그 앞은 그때 기록했다).
// - 모아 보기를 돌린 세션 자신(첫 요청에 [TIL 모아 보기]가 있는 세션)은 뺀다.
// - 날짜는 새벽 5시를 하루의 경계로 본다(새벽 2시 대화는 전날 공부).
// 아무것도 바꾸지 않는다. --mark만 상태 파일 하나를 쓴다.

const fs = require('fs');
const os = require('os');
const path = require('path');

const CLAUDE_DIR = path.join(os.homedir(), '.claude');
const PROJECTS = path.join(CLAUDE_DIR, 'projects');
const STATE = path.join(CLAUDE_DIR, 'til-collect-state.json');
const MARKER = '[TIL 모아 보기]';
const DAY_START_HOUR = 5;
const USER_MAX = 2000;
const ASSISTANT_MAX = 1200;

function arg(name) {
  const i = process.argv.indexOf(name);
  return i === -1 ? null : process.argv[i + 1];
}

function readState() {
  try { return JSON.parse(fs.readFileSync(STATE, 'utf8')); } catch { return {}; }
}

function studyDate(ts) {
  const d = new Date(new Date(ts).getTime() - DAY_START_HOUR * 3600 * 1000);
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

function localTime(ts) {
  const d = new Date(ts);
  const p = (n) => String(n).padStart(2, '0');
  return `${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
}

function clip(text, max) {
  const t = text.trim();
  return t.length > max ? `${t.slice(0, max)} …(생략)` : t;
}

// 사람이 직접 쓴 요청만 남긴다. 훅·시스템 알림·도구 결과·요약은 뺀다.
function userText(o) {
  if (o.isMeta || o.isCompactSummary || o.isSidechain) return null;
  const c = o.message && o.message.content;
  let text = null;
  if (typeof c === 'string') text = c;
  else if (Array.isArray(c)) {
    if (c.some((b) => b.type === 'tool_result')) return null;
    text = c.filter((b) => b.type === 'text').map((b) => b.text).join('\n');
  }
  if (!text) return null;
  text = text.replace(/<system-reminder>[\s\S]*?<\/system-reminder>/g, '').trim();
  if (!text || text.startsWith('<local-command') || text.startsWith('Caveat:')) return null;
  return text;
}

function isTilCall(o, text) {
  if (text && (/^\/til(\s|$)/.test(text) || text.includes('<command-name>/til</command-name>'))) return true;
  if (o.type !== 'assistant') return false;
  const c = (o.message && o.message.content) || [];
  return Array.isArray(c) && c.some((b) => b.type === 'tool_use' && (
    (b.name === 'Skill' && b.input && b.input.skill === 'til') ||
    (b.name === 'Bash' || b.name === 'PowerShell') && b.input && /git commit[^\n]*-m\s+["']?til: /.test(b.input.command || '')
  ));
}

function readSession(file, since, until) {
  let raw;
  try { raw = fs.readFileSync(file, 'utf8'); } catch { return null; }
  if (!raw.includes('"type":"user"')) return null;
  let title = null;
  let firstUser = null;
  let cwd = null;
  const turns = []; // { ts, user, assistant }
  let lastTil = -1;
  for (const line of raw.split('\n')) {
    if (!line) continue;
    let o;
    try { o = JSON.parse(line); } catch { continue; }
    if (o.type === 'custom-title' && o.customTitle) title = o.customTitle;
    if (o.type !== 'user' && o.type !== 'assistant') continue;
    if (o.isSidechain) continue;
    const text = o.type === 'user' ? userText(o) : null;
    if (o.type === 'user' && text && firstUser === null) firstUser = text;
    if (!o.timestamp) continue;
    const t = Date.parse(o.timestamp);
    if (t < since || t > until) continue;
    cwd = cwd || o.cwd;
    if (isTilCall(o, text)) { lastTil = turns.length; continue; }
    if (o.type === 'user' && text) {
      turns.push({ ts: o.timestamp, user: clip(text, USER_MAX), assistant: '' });
    } else if (o.type === 'assistant' && turns.length) {
      const c = (o.message && o.message.content) || [];
      const said = Array.isArray(c) ? c.filter((b) => b.type === 'text').map((b) => b.text).join('\n').trim() : '';
      if (said) turns[turns.length - 1].assistant = said; // 한 턴의 마지막 답만 남긴다
    }
  }
  if (firstUser && firstUser.includes(MARKER)) return null;
  const kept = turns.slice(lastTil + 1).filter((x) => x.user);
  if (!kept.length) return null;
  return { title, cwd, tilBefore: lastTil >= 0, turns: kept };
}

function listTranscripts() {
  if (!fs.existsSync(PROJECTS)) return [];
  const out = [];
  for (const dir of fs.readdirSync(PROJECTS)) {
    const full = path.join(PROJECTS, dir);
    let names;
    try { names = fs.readdirSync(full); } catch { continue; }
    for (const n of names) if (n.endsWith('.jsonl')) out.push(path.join(full, n));
  }
  return out;
}

function main() {
  const mark = arg('--mark');
  if (mark) {
    if (Number.isNaN(Date.parse(mark))) throw new Error(`--mark 시각이 잘못됨: ${mark}`);
    // 답이 늦게 온 옛 모아 보기가 더 앞선 시각을 적어도 뒤로 돌아가지 않는다.
    const prev = readState().lastCollectedUntil;
    if (prev && Date.parse(prev) >= Date.parse(mark)) {
      console.log(`그대로 둠: 이미 ${prev}까지 모았음`);
      return;
    }
    fs.writeFileSync(STATE, JSON.stringify({ lastCollectedUntil: mark }, null, 2));
    console.log(`기록함: ${mark}까지 모았음 (${STATE})`);
    return;
  }
  const until = arg('--until') ? Date.parse(arg('--until')) : Date.now();
  const state = readState();
  const since = arg('--since') ? Date.parse(arg('--since'))
    : state.lastCollectedUntil ? Date.parse(state.lastCollectedUntil)
    : until - 24 * 3600 * 1000;

  const sessions = [];
  for (const file of listTranscripts()) {
    // 기간보다 먼저 끝난 파일은 열지 않는다(수정 시각은 기간 안이어도 내용은 아닐 수 있어 아래서 다시 거른다).
    try { if (fs.statSync(file).mtimeMs < since) continue; } catch { continue; }
    const s = readSession(file, since, until);
    if (s) sessions.push({ id: path.basename(file, '.jsonl'), ...s });
  }
  sessions.sort((a, b) => a.turns[0].ts.localeCompare(b.turns[0].ts));
  // 이어 하기·포크한 세션은 앞 세션의 대화를 그대로 복사해 둔다. 같은 요청은 한 번만 싣는다.
  const seen = new Set();
  for (const s of sessions) {
    s.turns = s.turns.filter((t) => {
      const key = `${t.ts}|${t.user.slice(0, 200)}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }
  for (let i = sessions.length - 1; i >= 0; i--) if (!sessions[i].turns.length) sessions.splice(i, 1);

  const lines = [
    `# 세션 모아 보기 원본`,
    `기간: ${new Date(since).toISOString()} ~ ${new Date(until).toISOString()}`,
    `UNTIL=${new Date(until).toISOString()}`,
    `세션 ${sessions.length}개, 요청 ${sessions.reduce((n, s) => n + s.turns.length, 0)}개`,
    '',
  ];
  for (const s of sessions) {
    lines.push(`## ${s.title || '(제목 없음)'}`);
    lines.push(`- 세션: ${s.id}`, `- 폴더: ${s.cwd || '?'}`);
    if (s.tilBefore) lines.push('- 이 기간 안에 /til을 한 번 했음 → 그 뒤 대화만 실음');
    lines.push('');
    for (const t of s.turns) {
      lines.push(`### [${studyDate(t.ts)}] ${localTime(t.ts)} 사용자`);
      lines.push(t.user, '');
      if (t.assistant) lines.push('**Claude 마지막 답**', clip(t.assistant, ASSISTANT_MAX), '');
    }
  }
  const text = lines.join('\n');
  const out = arg('--out');
  if (out) {
    fs.writeFileSync(out, text);
    console.log(`${out} (${Math.round(text.length / 1024)}KB) — 세션 ${sessions.length}개`);
  } else {
    process.stdout.write(text);
  }
}

main();
