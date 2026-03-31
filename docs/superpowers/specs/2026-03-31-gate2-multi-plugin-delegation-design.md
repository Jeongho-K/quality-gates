# Quality Gates Multi-Plugin Delegation Upgrade

## Context

현재 quality-gates의 Gate 1(plan-verifier)과 Gate 2(pr-reviewer)는 각각 자체 로직과 `pr-review-toolkit`에만 의존한다. 또한 리뷰 결과를 `.claude/quality-gates-reports/`에 MD 파일로 저장하는데, 수동 정리가 번거롭다.

이 업그레이드는:
1. `feature-dev`와 `superpowers` 플러그인의 에이전트들도 위임 대상에 추가
2. 파일 기반 리포트를 Agent 반환값 체인 기반 보고로 전환
3. 서브에이전트에서 사용 불가한 `Skill()` 호출을 pipeline 스킬(메인 대화)로 이동

---

## 변경 대상 파일

1. `plugins/quality-gates/agents/plan-verifier.md` — code-explorer 위임 추가, 파일 저장 제거
2. `plugins/quality-gates/agents/pr-reviewer.md` — 새 에이전트 위임 추가, 파일 저장 제거
3. `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — 의존성 체크 확장, available_plugins 전달
4. `plugins/quality-gates/.claude-plugin/plugin.json` — 버전 범프, 설명 업데이트
5. `plugins/quality-gates/README.md` — 문서 업데이트

---

## 리포트 방식 변경: 파일 → Stop Hook

### 현재 (문제)
```
pr-reviewer → toolkit 에이전트 dispatch
           → Write(".claude/quality-gates-reports/code-reviewer-iter1.md")
           → Write(".claude/quality-gates-reports/silent-failure-hunter-iter1.md")
           → ... (수동 정리 필요)
```

### 변경 후
```
pr-reviewer → toolkit 에이전트 dispatch
           → Agent 도구 반환값으로 결과 수신 (이미 동작)
           → 최종 리포트를 구조화된 출력으로 반환
           → Stop hook이 gate 에이전트 완료 시 최종 보고 캡처
```

### 리포트 전달 경로

```
toolkit 에이전트 → Agent 반환값 → gate 에이전트(pr-reviewer) → Agent 반환값 → quality-pipeline 스킬 → 사용자에게 직접 출력
```

quality-pipeline 스킬은 메인 대화 컨텍스트에 있으므로, 출력이 사용자에게 직접 보인다. 별도의 hook이나 파일 저장 없이, 기존 Agent 반환값 체인으로 충분하다.

### 실시간 Gate별 출력

quality-pipeline 스킬이 **각 Gate 완료 후 즉시** 결과를 사용자에게 출력한다:

```
Gate 1 dispatch → 결과 수신 → Gate 1 결과 즉시 출력 → Gate 2 진행
Gate 2 dispatch → 결과 수신 → Gate 2 결과 즉시 출력 → Gate 3 진행
Gate 3 dispatch → 결과 수신 → Gate 3 결과 즉시 출력
최종 요약 출력
```

각 Gate 완료 시 출력 포맷:
```
## Gate N: [Name] — [PASS/FAIL/SKIP/NEEDS_RESTART]
[verdict 설명]
[주요 findings 요약]
```

이렇게 하면 사용자가 파이프라인 진행 상황을 실시간으로 확인할 수 있다.

### 제거 항목
- `mkdir -p .claude/quality-gates-reports` (pr-reviewer에서 제거)
- 모든 `Write(".claude/quality-gates-reports/...")` 지시 (pr-reviewer, plan-verifier에서 제거)
- `.claude/quality-gates-reports/` 디렉터리 참조 (quality-pipeline SKILL.md에서 제거)
- "Report Directory Setup" 섹션 (pr-reviewer에서 제거)
- "Save Phase N Reports" 섹션들 (pr-reviewer에서 제거)
- 최종 요약의 "Detailed Agent Reports" 파일 목록 (quality-pipeline에서 제거)

---

## Gate 1: plan-verifier 확장

### 추가: feature-dev:code-explorer 위임

plan-verifier의 Step 4(Cross-Reference with Git) **이후**, Step 4.5 추가:

**Step 4.5: Implementation Trace (conditional)**

- **조건**: `available_plugins`에 `feature-dev` 포함 + blocking 미완료 항목이 "possibly implemented" 상태
- **목적**: 파일 수정은 확인되었지만 체크박스 미체크 항목에 대해, 실행 경로 추적으로 실제 구현 검증
- **dispatch**:
  ```
  Agent(subagent_type="feature-dev:code-explorer", model="opus",
    prompt="The implementation plan is at {plan_path}. Read it first to understand
      the full scope of planned features.
      Then trace the implementation of the following items that appear to have
      been partially implemented (files exist in git diff but checkboxes unchecked):
      {list of 'possibly implemented' items with file paths}
      For each, verify it is properly wired up and functional.
      Report which features are fully connected and which have gaps.")
  ```
  - `model="opus"` 오버라이드: feature-dev 에이전트의 기본 모델(sonnet)을 opus로 오버라이드. 플러그인 업데이트에 영향받지 않음.
  - 플랜 파일 경로를 전달하여 code-explorer가 전체 계획을 이해한 뒤 구현 추적을 수행
- **결과 통합**: "fully connected" → "likely implemented"로 상태 업그레이드
- **읽기 전용**: Gate 1 원칙 유지, 코드 수정 없음

### Step 5.5: Evidence-Based Verification (moved to pipeline skill)

- **조건**: `available_plugins`에 `superpowers` 포함 + blocking 항목이 "likely implemented" 또는 "possibly implemented" 상태
- **목적**: 단순 파일 존재가 아닌, 실행/테스트 증거로 구현 완료를 검증
- **실행 위치**: ~~plan-verifier 에이전트 내~~ → **quality-pipeline 스킬(메인 대화)**에서 Gate 1 결과 수신 후 호출
- **이유**: 서브에이전트에서는 `Skill()` 도구 사용 불가. pipeline 스킬은 메인 대화 컨텍스트에서 실행되므로 `Skill("superpowers:verification-before-completion")` 호출 가능
- **결과 통합**: 증거가 확인된 항목은 verdict에 반영
- **읽기 전용 예외**: 이 스킬은 테스트/빌드 명령을 실행하지만 코드를 수정하지 않음

### plan-verifier 리포트 포맷 확장

```
### Implementation Trace (code-explorer)
- [item]: fully connected ✓
- [item]: gap found — [description]
```

Note: Evidence-Based Verification 결과는 plan-verifier 리포트에 포함되지 않는다. pipeline 스킬이 Gate 1 결과 수신 후 별도로 실행하고 Gate 1 출력에 통합한다.

---

## Gate 2: pr-reviewer 확장

### Phase 구조 (확장)

```
Phase 1 (Critical, always run, parallel — 3 agents):
  ├── pr-review-toolkit:code-reviewer        → 버그, 보안, 로직 에러 (Opus)
  ├── pr-review-toolkit:silent-failure-hunter → 에러 핸들링 (Opus)
  └── feature-dev:code-reviewer              → 컨벤션, 가이드라인 (Sonnet) [NEW]

Phase 2 (Conditional — up to 5 agents):
  ├── pr-review-toolkit:type-design-analyzer  → 새 타입 추가 시
  ├── pr-review-toolkit:pr-test-analyzer      → 테스트 파일 변경 시
  ├── pr-review-toolkit:comment-analyzer      → 주석/문서 추가 시
  ├── superpowers:code-reviewer               → 플랜 파일 존재 시 [NEW]
  └── feature-dev:code-architect              → 구조적 변경 시 [NEW]

Phase 3 (Polish, non-blocking — 1 agent):
  └── pr-review-toolkit:code-simplifier       → 단순화 제안
```

### 새 에이전트 상세

#### feature-dev:code-reviewer (Phase 1)
- **항상 실행**, 기존 2개와 **병렬**
- **모델 오버라이드**: `model="opus"` (feature-dev 기본 sonnet → opus로 오버라이드)
- **역할 분담**: `pr-review-toolkit:code-reviewer`는 버그/보안/로직, `feature-dev:code-reviewer`는 컨벤션/가이드라인
- **프롬프트**: "Review the unstaged changes in git diff for project convention and guideline compliance. Focus on CLAUDE.md adherence, import patterns, naming conventions, and framework-specific patterns. Do NOT focus on bugs or security — another reviewer handles those. Report only issues with confidence >= 80."

#### superpowers:code-reviewer (Phase 2, conditional)
- **조건**: 플랜 파일 존재 시
- **모델**: inherit (→ pr-reviewer의 opus 상속)
- **역할**: 플랜 alignment 검증, SOLID 원칙, 관심사 분리
- **프롬프트**: "Review the unstaged changes against the implementation plan at {plan_path}. Check for plan alignment, architectural deviations, SOLID principles, and separation of concerns. Categorize issues as Critical, Important, or Suggestions."

#### feature-dev:code-architect (Phase 2, conditional)
- **조건**: 구조적/아키텍처 변경 감지 시 (새 파일, 설정 파일, 타입/스키마 변경)
- **모델 오버라이드**: `model="opus"` (feature-dev 기본 sonnet → opus로 오버라이드)
- **역할**: 아키텍처 일관성, 패턴 준수, 모듈 경계 검증
- **프롬프트**: "Analyze the architectural impact of the current git diff changes. Validate that new files follow existing codebase patterns, module boundaries are respected, and architecture remains consistent. Focus on pattern validation, not bugs or style."

#### 제외 항목
- **feature-dev:code-explorer**: Gate 2에서 제외 (리뷰 도구가 아닌 분석 도구, Gate 1에서만 사용)

### Fix-and-Review 도메인 매핑

```
Agent                                   Domain
pr-review-toolkit:code-reviewer         bugs, security, logic
pr-review-toolkit:silent-failure-hunter  error-handling
feature-dev:code-reviewer               conventions, guidelines
pr-review-toolkit:type-design-analyzer  type-design
pr-review-toolkit:pr-test-analyzer      testing
pr-review-toolkit:comment-analyzer      comments
superpowers:code-reviewer               plan-alignment
feature-dev:code-architect              architecture
pr-review-toolkit:code-simplifier       simplification (never re-run)
```

---

## 공통: 의존성 관리

### 의존성 분류

| 플러그인 | 유형 | 사용처 | 없을 때 |
|---------|------|--------|---------|
| pr-review-toolkit | 필수 | Gate 2 core (Phase 1/2/3) | Gate 2 SKIP |
| feature-dev | 선택 | Gate 1 trace, Gate 2 conventions/architecture | 해당 에이전트만 skip |
| superpowers | 선택 | Gate 1 verification, Gate 2 plan-alignment | 해당 스킬/에이전트만 skip |
| browser automation | 선택 | Gate 3 | fallback |

### quality-pipeline SKILL.md 의존성 체크 확장

```
1. pr-review-toolkit (필수): 없으면 Gate 2 SKIP 여부 사용자 확인
2. feature-dev (선택): 없으면 info 로그, 자동 진행
3. superpowers (선택): 없으면 info 로그, 자동 진행
4. browser automation (선택): Gate 3 fallback 있음
```

`available_plugins`를 Gate 1(plan-verifier)과 Gate 2(pr-reviewer) 프롬프트에 전달.

### Graceful Degradation

**Gate 1:**
| 상황 | 동작 |
|------|------|
| feature-dev 있음 | Step 4.5 실행 (code-explorer 구현 추적) |
| feature-dev 없음 | Step 4.5 건너뜀, 기존 동작 유지 |
| superpowers 있음 | Gate 1.5 실행 (evidence-based verification, pipeline 스킬에서 호출) |
| superpowers 없음 | Gate 1.5 건너뜀 |

**Gate 2:**
| 상황 | Phase 1 | Phase 2 | Phase 3 |
|------|---------|---------|---------|
| 모든 플러그인 있음 | 3 agents | up to 5 | 1 |
| feature-dev 없음 | 2 agents (현재와 동일) | up to 3 | 1 |
| superpowers 없음 | 3 agents | up to 4 | 1 |
| 둘 다 없음 | 2 agents (현재와 동일) | up to 3 (현재와 동일) | 1 |

---

## Verification

1. `/qg gate1` 실행 — code-explorer trace 동작 확인
2. `/qg gate2` 실행 — 확장된 에이전트 dispatch 확인
3. 파일 미생성 확인 — `.claude/quality-gates-reports/` 생성 안 됨
4. quality-pipeline 출력 확인 — gate 결과가 대화에 직접 표시되는지 확인
5. feature-dev 미설치 상태에서 graceful skip 확인
