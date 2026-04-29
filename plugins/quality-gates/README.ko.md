# Quality Gates 플러그인

Claude Code용 3-게이트 품질 검증 파이프라인. 멀티 플러그인 리뷰 위임 구조.

## 인스턴스화한 원칙

이 플러그인은 다음 devbrew 법칙 / 원칙을 인스턴스화합니다
(자세한 내용은 [`docs/philosophy/devbrew-harness-philosophy.md`](../../docs/philosophy/devbrew-harness-philosophy.md) 참고 — 해당 문서가 `main`에 머지된 후):

- **Law 1 (코드 작성 전 명확성)** — Gate 1 plan-verifier 가 FAIL 시 `gate1_summary` YAML 핸드오프를 통해 Gate 2 진입을 차단.
- **Law 2 (작성자 ≠ 리뷰어)** — 모든 리뷰어 agent 가 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 선언.
- **Law 3 (복리)** — scout 의 `rationale` 필드를 매 반복마다 state 파일에 로깅; reviewer-persona 편집이 학습된 교훈을 인코딩하는 방식.
- **AP3 (Trivia 의식) 회피** — `check-trivia.sh` 가 단일 파일·≤3 줄 whitespace/rename 변경을 파이프라인 전체 스킵.
- **AP9 (서브에이전트 난사) 하드 게이트** — Phase 1 + Phase 2 dispatch 수가 ≥4 일 때 AskUserQuestion 발동.
- **AP15 (무제한 자율) 회피** — Gate 2 내부 루프가 `max_gate2_iterations=5` + 반복 감지(no-progress check) + 킬 스위치로 묶임.
- **P21 (JSON 이 아닌 Markdown 상태)** — `.claude/quality-gates*.local.md` 파일 (`*.local.md` gitignore 패턴으로 자동 제외).

## 구조

```
quality-gates/
├── .claude-plugin/         # 플러그인 메타데이터
│   └── plugin.json
├── agents/                 # Gate agent (leaf agent; 파이프라인이 dispatch)
│   ├── plan-verifier.md    # Gate 1
│   ├── runtime-verifier.md # Gate 3 (Gate 2 는 SKILL.md 가 직접 orchestrate)
│   ├── scout.md            # Gate 2 의 Phase 0 — 모델 기반 dispatch planner
│   ├── adversarial.md      # Gate 2 의 Phase 1.5 — false positive 사냥꾼
│   └── synthesizer.md      # Gate 2 의 Phase 1.6 — finding dedupe/rank
├── commands/
│   ├── qg.md               # /qg 슬래시 커맨드 (--reset, --paths, branch flag 포함)
│   └── cancel-qg.md        # /cancel-qg 커맨드
├── hooks/
│   ├── hooks.json                            # Hook 설정
│   ├── stop-hook.py                          # 파이프라인 진행 (state machine)
│   ├── post-tool-use-session-tracker.py      # 세션 동안 편집한 파일 추적
│   ├── session-start-advisor.py              # in-flight 파이프라인 read-only advisor
│   └── post-tool-use.py                      # (비활성; 롤백용 보존)
├── scripts/
│   ├── setup-qg.sh                           # 파이프라인 초기화
│   ├── pre-pipeline-check.sh                 # in-skill 세션 라이프사이클 체크
│   ├── check-trivia.sh                       # Trivia escape 감지기
│   └── filter-docs.sh                        # 코드 리뷰어용 docs path 필터
└── skills/
    └── quality-pipeline/
        ├── SKILL.md         # 단일 게이트 실행기
        └── references/
            ├── dependency-check.md   # 사전 의존성 체크
            └── state-file-format.md  # 파이프라인 state 파일 포맷
```

## 설치된 Hook

| Hook | 이벤트 | 변경? | 왜 hook 인가 (skill 이 아니라)? |
|---|---|---|---|
| `stop-hook.py` | Stop | 예 (state 파일) | 매 어시스턴트 turn 이후 파이프라인 진행이 필요. |
| `post-tool-use-session-tracker.py` | PostToolUse(Edit/Write/MultiEdit) | 예 (세션 파일) | 모든 파일 변경을 결정적으로 관찰해야 함; hook 만 가능. |
| `session-start-advisor.py` | SessionStart | **아니오 — read-only advisor** | 변경 없이 in-flight 파이프라인을 알림 (CLAUDE.md hook coexistence 룰). |

모든 hook 은 `DEVBREW_DISABLE_QUALITY_GATES=1` (전역) 와 hook 단위 override `DEVBREW_SKIP_HOOKS=quality-gates:<hook-name>` 을 따릅니다.

## Cost Class

`quality-pipeline` skill 은 `cost_class: variable` 입니다. 자동 감지된 depth 에 따라 비용이 달라집니다:

| Depth | 기존 default-Opus 베이스라인 대비 비용 |
|---|---|
| Trivia | ~0% (즉시 스킵) |
| Quick | ~25–35% |
| Standard | ~30–45% |
| Deep | ~55–75% (AskUserQuestion 게이트 발동) |

트리거 조건과 override flag 는 [`commands/qg.md`](commands/qg.md) 참고.

## 게이트

| Gate | 주체 | 목적 | 위임 대상 |
|------|-----|------|---------|
| 1 | plan-verifier agent | plan 의 checkbox 와 git diff 를 교차 확인; `gate1_summary` YAML 을 Gate 2 로 핸드오프 | feature-dev:code-explorer (구현 추적), superpowers:verification-before-completion (증거) |
| 2 | quality-pipeline skill (inline) | scout 주도 오케스트레이션: depth-aware dispatch + Phase 1.5 adversarial + Phase 1.6 synthesizer | pr-review-toolkit, feature-dev, superpowers (리뷰 agent 들) |
| 3 | runtime-verifier agent | 앱 시작, 콘솔 에러 확인, 스크린샷 | chrome-devtools-mcp 또는 playwright |

**아키텍처 메모 — 왜 Gate 2 는 agent 가 없는가**: Claude Code 는 skill 만 (agent 가 아닌) `Agent()` 의 `subagent_type` 을 사용 가능. Gate 2 는 여러 단계로 리뷰 agent 를 dispatch 해야 하므로 orchestration 로직이 `skills/quality-pipeline/SKILL.md` 에 직접 있습니다. Gate 1 과 3 은 leaf agent (sub-agent dispatch 안 함) 그대로 사용.

## Gate 2 리뷰 단계 (v1.5.0 재설계)

```
Phase 0  Scout (항상, sonnet) — dispatch plan 산출: depth + agent subset
Phase 1  Critical analysis (depth-aware, 병렬)
  ├── pr-review-toolkit:code-reviewer        (항상; upstream Opus)
  ├── pr-review-toolkit:silent-failure-hunter (Standard/Deep; sonnet override)
  └── feature-dev:code-reviewer              (Deep 전용)
Phase 2  Conditional (scout 추천만)
  ├── pr-review-toolkit:type-design-analyzer  → 신규 타입
  ├── pr-review-toolkit:pr-test-analyzer      → 테스트 변경
  ├── pr-review-toolkit:comment-analyzer      → 문서
  ├── superpowers:code-reviewer               → 플랜 정합성
  └── feature-dev:code-architect              → 아키텍처
Phase 1.5  Adversarial (Standard/Deep, opus) — false positive 사냥
Phase 1.6  Synthesizer (Phase 1 실행 시 항상, sonnet) — dedupe/rank
Phase 3  Polish (one-shot, upstream Opus): pr-review-toolkit:code-simplifier
```

`len(phase1) + len(phase2) >= 4` 일 때 AskUserQuestion 발동 (philosophy AP9).

## 파이프라인 흐름 (forward-only state machine, v1.5.0)

```
/qg → setup-qg.sh → pre-pipeline-check → trivia escape?
   ├── yes → 즉시 PASS, 0 dispatch
   └── no → SKILL.md (Gate 1) → Stop hook → SKILL.md (Gate 2)
              → Stop hook → SKILL.md (Gate 3) → done
```

**v1.5.0 에서 cross-gate restart 제거**: Gate 2 / Gate 3 NEEDS_RESTART 결과가 이제 user-choice prompt ("변경을 적용하고 /qg 재실행") 로 종료. Gate 1 자동 재진입은 없습니다. Gate 2 내부 fix-loop (최대 5 회) 는 보존.

## 사용

```
/qg                            # 풀 파이프라인; 세션 단위 diff
/qg branch                     # 풀 파이프라인; main 대비 풀 브랜치 diff
/qg --paths <glob>...          # 풀 파이프라인; 명시 path 단위
/qg --reset                    # 모든 세션 state 파일 정리 후 종료
/qg gate1                      # plan 검증만
/qg gate2                      # PR 리뷰만
/qg gate3                      # 런타임 검증만
/qg --skip-runtime             # Gate 1 & 2 만
/qg --plan <path>              # 특정 plan 파일 사용
/qg --pr-url <url>             # PR URL 명시
/cancel-qg                     # 활성 파이프라인 취소
```

## 사전 요건

| 플러그인 | 필수 | 사용처 | 목적 |
|---------|------|-------|------|
| pr-review-toolkit | 예 | Gate 2 | 핵심 리뷰 agent |
| feature-dev | 아니오 | Gate 1, 2 | 컨벤션 리뷰, 아키텍처, 구현 추적 |
| superpowers | 아니오 | Gate 1, 2 | 플랜 정합성, 증거 검증 |
| chrome-devtools-mcp / playwright | 아니오 | Gate 3 | 브라우저 자동화 |

## 설정

- `MAX_GATE2_ITERATIONS`: 5 (Gate 2 내부 review-fix 사이클 수)
- `QG_STALE_HOURS`: 24 (pre-pipeline-check.sh 의 세션 파일 staleness 기준)

(`MAX_TOTAL_ITERATIONS` 와 cross-gate restart 루프는 v1.5.0 에서 제거됨.)

## State 파일

파이프라인 상태는 `.claude/` 에 추적됩니다:

| 파일 | 소유자 | 생성 | 삭제 |
|------|--------|------|------|
| `quality-gates.local.md` | stop-hook.py + setup-qg.sh | setup-qg.sh | stop-hook.py 가 완료 시 |
| `quality-gates-session.local.md` | post-tool-use-session-tracker.py | 세션 첫 Edit/Write | pre-pipeline-check.sh 가 branch mismatch / stale 때; `/qg --reset` |
| `quality-gates-branch.local.md` | pre-pipeline-check.sh | 브랜치별 첫 `/qg` 호출 | `/qg --reset` |

세 파일 모두 `*.local.md` gitignore 패턴에 매칭됩니다 (별도 `.gitignore` 변경 불필요).
