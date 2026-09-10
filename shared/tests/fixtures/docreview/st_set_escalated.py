#!/usr/bin/env python3
"""state 파일의 st["escalated"] 에 지정 finding_id 예약 하나를 심는다(픽스처 전용).

Task 2 — 재상승의 st_set_reraise.py 와 같은 종류의 상태 강제 도구. `_auto_decides`
의 escalated 판정은 `st["findings"]` 에 없는 finding_id 를 `record_findings()` 가
등재만 하고 지우지는 않으므로 production 경로로는 만들 수 없다(도달 불가능한 방어,
check_wiring.py 의 `_DR_ESCALATED_TARGET_GONE` 참조) — st_set_reraise.py 가
reraise_unconsumed 계수 분기를 겨눌 때 쓴 것과 같은 수법으로 직접 심는다.

round 는 심을 시점의 현재 st["round"] 를 그대로 쓴다 — `_auto_decides` 의
`int(e["round"]) >= n` 판정이 "이번 라운드 이후에 생긴 예약"만 보류하므로, 호출자가
이 픽스처를 심은 뒤 next_round 를 한 번 거쳐야 그 예약이 "이번 finalize 의 대상"
(round < n)이 된다.

경로 계산은 st_set_reraise.py 와 같다: `parents[3]` 이 이미 `shared/` 이므로 "shared"
세그먼트를 다시 붙이지 않는다.
"""
import sys, pathlib
SCRIPTS_DIR = pathlib.Path(__file__).resolve().parents[3] / "docreview" / "scripts"
assert SCRIPTS_DIR.is_dir(), "resolved scripts dir missing: %s" % SCRIPTS_DIR
sys.path.insert(0, str(SCRIPTS_DIR))
from docreview_state import load_state, save_state  # noqa: E402
state_file, fid = sys.argv[1], sys.argv[2]
d = str(pathlib.Path(state_file).parent)
st = load_state(d)
n = int(st["round"])
st["escalated"] = [{"finding_id": fid, "reason": "픽스처가 심은 미소비 예약", "round": n}]
save_state(d, st, "fixture: seed unconsumed escalated (round %d)" % n)
