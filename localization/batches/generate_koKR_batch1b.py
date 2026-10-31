#!/usr/bin/env python3
"""
Generates and validates translated_koKR_batch1b.json for PulseHaptics Korean (koKR) localization.
Strictly adheres to WoW Classic Korean terminology and GLOSSARY.md.
"""

import json
import os
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "tools"))
from validate_catalog import extract_signature, check_color_balance

BATCH1B_JSON = os.path.join(os.path.dirname(__file__), "batch1b_ui_navigation.json")
OUTPUT_JSON = os.path.join(os.path.dirname(__file__), "translated_koKR_batch1b.json")

TRANSLATIONS_KO = {
    # 000..049
    "Low health": "생명력 낮음",
    "Low health texture": "생명력 낮음 질감",
    "Low motor": "저주파 모터",
    "Low motor holds a steady presence, floored so it's never silent while gliding; high motor eases in from near-silent toward thrillPeak as speed climbs, shaped by thrillCurve.": "저주파 모터는 활공 중 결코 꺼지지 않도록 시동 임계값을 유지하며 안정적인 존재감을 제공합니다. 고주파 모터는 거의 무음에 가까운 상태에서 시작하여 속도가 증가함에 따라 thrillCurve에 맞춰 thrillPeak를 향해 서서히 상승합니다.",
    "Mage": "마법사",
    "Manage": "관리",
    "Master Vibration Strength": "마스터 진동 강도",
    "Master switch for every loss-of-control cue below. With this off, none of them fire and no loss-of-control events are registered at all.": "아래의 모든 제어 불가 신호를 제어하는 마스터 스위치입니다. 이 기능을 끄면 신호가 전혀 울리지 않으며 제어 불가 이벤트도 일체 등록되지 않습니다.",
    "Master switch. With this off, nothing registers and nothing costs anything.": "마스터 스위치입니다. 이 기능을 끄면 아무것도 등록되지 않으며 시스템 리소스도 전혀 소모하지 않습니다.",
    "Melee auto-attack started": "근접 자동 공격 시작",
    "Melee auto-attack stopped": "근접 자동 공격 중지",
    "Menus & tabs": "메뉴 및 탭",
    "Messages": "메시지",
    "Minimum severity": "최소 심각도",
    "Mode to test": "테스트할 모드",
    "Most specific wins. A scope set to |cffffd100No rule|r has no opinion and lets the one below it decide; with none of them set, Pulse uses Default.": "가장 구체적인 규칙이 우선 적용됩니다. 범위를 |cffffd100규칙 없음|r으로 설정하면 자체 규칙을 두지 않고 그 아래 단계의 규칙에 따르며, 아무것도 설정되지 않은 경우 Pulse는 기본값을 사용합니다.",
    "Movement": "이동",
    "Movement & Travel": "이동 및 여행",
    "Multiplies every trigger's intensity. Part of the current profile, not global.": "모든 트리거의 강도를 배가합니다. 전역 설정이 아닌 현재 프로필에만 적용됩니다.",
    "Name the new profile:": "새 프로필 이름:",
    "Navigation": "탐색",
    "New profile": "새 프로필",
    "Next >": "다음 >",
    "No rule": "규칙 없음",
    "None (full sensory richness)": "없음 (풍부한 모든 감각)",
    "None (stock defaults)": "없음 (초기 기본값)",
    "ON — option changes and cue firings will print here.": "켜짐 — 설정 변경 및 신호 발생 내역이 여기에 출력됩니다.",
    "Ocean Waves & Swell": "바다 물결 및 너울",
    "Ocean waves & swell": "바다 물결 및 너울",
    "Ocean zones only (guessed from zone name)": "해양 지역 전용 (지역 이름으로 추정)",
    "Off by default and deliberately the faintest cue in the addon: this fires for EVERY NPC you talk to, which in a city is constantly. Try it before leaving it on. Untested.": "기본적으로 비활성화되어 있으며 애드온에서 의도적으로 가장 미세하게 설정된 신호입니다. 대화하는 모든 NPC마다 작동하므로 도시에서는 끊임없이 발생합니다. 켜두기 전에 먼저 테스트해 보세요. 미검증 항목입니다.",
    "Offensive": "공격",
    "One cue for both directions, same reasoning as the navigation edge cue — a motor can't tell you which way you went.": "두 방향 모두에 적용되는 단일 신호입니다. 탐색 가장자리 신호와 마찬가지로 모터 진동만으로는 어느 방향으로 이동했는지 구별할 수 없기 때문입니다.",
    "One full-bodied hit on both motors.": "양쪽 모터에서 발생하는 묵직하고 풍부한 단일 타격 진동입니다.",
    "One long, sombre pulse when a spirit healer's window opens.": "영혼의 치유사 창이 열릴 때 발생하는 길고 엄숙한 펄스 진동입니다.",
    "One sharp, heavy impact — fast attack, fast decay.": "날카롭고 묵직한 단일 타격 진동 — 빠른 상승, 빠른 감쇄.",
    "One strong, sustained pulse.": "강하고 지속적인 단일 펄스 진동입니다.",
    "One sustained pulse.": "지속적인 단일 펄스 진동입니다.",
    "Open Pulse settings": "Pulse 설정 열기",
    "Other": "기타",
    "Overall heave amplitude of the oceanic swell. Sets the physical displacement intensity of the slow motor.": "바다 너울의 전체 승강 진폭입니다. 저속 모터의 물리적 변위 강도를 설정합니다.",
    "Overall intensity": "전체 강도",
    "Overall strength. Meant to sit at the edge of perception — if you notice it as a vibration rather than as being submerged, it is too high. Inherits the old idleFloatAmplitude, which was live-tuned to 0.04.": "전체 강도입니다. 지각의 경계선에 머물도록 설계되었습니다 — 물속에 잠겨 있는 느낌 대신 진동 그 자체로 느껴진다면 너무 강한 것입니다. 기존에 0.04로 실시간 보정되었던 idleFloatAmplitude 설정을 이어받습니다.",
    "Overdrive kick": "오버드라이브 킥",
    "Overdrive time (s)": "오버드라이브 시간 (초)",
    "Own motor": "자체 모터",
    "PLAYER_ALIVE also fires when you release to a graveyard, so this can fire while you are still a ghost.": "무덤으로 영혼을 해방할 때도 PLAYER_ALIVE 이벤트가 발생하므로, 아직 유령 상태일 때도 이 신호가 작동할 수 있습니다.",
    "PLAYER_SOFT_FRIEND_CHANGED, occurrence-only, no payload. Worth pairing with the hostile cue above only if you can tell two TICKs apart — if not, give one of them a different shape with its own \"Feels like\" dropdown.": "PLAYER_SOFT_FRIEND_CHANGED 이벤트로 데이터 페이로드 없이 발생 여부만 감지합니다. 두 틱(TICK) 진동을 명확히 구별할 수 있을 때만 위의 적대적 대상 신호와 함께 사용하는 것을 권장합니다. 구별이 어렵다면 '체감 형태' 드롭다운에서 서로 다른 형태를 지정하세요.",
    "PULSE QUICK SETUP": "PULSE 빠른 설정",
    "Pacified or school-locked": "평화주의 또는 주문 계열 차단",

    # 050..099
    "Page switches": "페이지 전환",
    "Paladin": "성기사",
    "Passively polled by observing IsEnabled() on the currently focused element. Fires if the element becomes disabled while focused.": "현재 포커스된 요소의 IsEnabled()를 수동적으로 확인(폴링)합니다. 포커스를 받은 상태에서 해당 요소가 비활성화되면 작동합니다.",
    "Passively polled via GetUIPanel every 0.05s to eliminate UIParentPanelManager execution taint on protected frames.": "보호된 프레임에서 UIParentPanelManager로 인한 실행 오염을 방지하기 위해 GetUIPanel을 0.05초마다 수동적으로 확인(폴링)합니다.",
    "Passively polled via GetUIPanel every 0.05s. Detects when major UI panels are dismissed without callback taint.": "GetUIPanel을 0.05초마다 수동적으로 확인(폴링)합니다. 콜백 오염 없이 주요 UI 창이 닫히는 것을 감지합니다.",
    "Passively polled via GroupTargeting.isTargetingActive. Fires when the group targeting modifier is released.": "GroupTargeting.isTargetingActive를 수동적으로 확인(폴링)합니다. 파티원 지정 보조 키를 뗄 때 작동합니다.",
    "Physical tool strikes: anvil hammer strokes, mining pickaxe impacts, tailoring stitches.": "물리적 도구 타격: 모루 망치질, 채광 곡괭이질, 재봉술 바느질 타격감.",
    "Pick a mode to test below.": "아래에서 테스트할 모드를 선택하세요.",
    "Play": "재생",
    "Play ": "재생 ",
    "Play a few seconds of this texture at its current intensity. Module-driven preview reproducing authentic physical dynamics and configured intensity.": "현재 설정된 강도로 이 질감을 몇 초 동안 재생합니다. 실제 물리적 역학 및 구성된 강도를 재현하는 모듈 구동 미리보기입니다.",
    "Presence floor (low)": "존재감 하한선 (저주파)",
    "Priest": "사제",
    "Prints every option you change and every cue that actually fires to chat, in real time. Same as /pulse debug — off by default, and resets to off on /reload since it's a testing aid, not a saved preference.": "변경된 모든 설정과 실제로 작동한 모든 신호를 실시간으로 채팅창에 출력합니다. /pulse debug와 동일하며, 저장되는 환경 설정이 아닌 테스트 보조 도구이므로 기본적으로 비활성화되어 있고 /reload 실행 시 꺼짐 상태로 초기화됩니다.",
    "Profile": "프로필",
    "Profiles": "프로필",
    "Profiles and automatic rules": "프로필 및 자동 규칙",
    "Progression": "진행 상황",
    "Progressive low build leading to a sharp high break.": "점진적인 저주파 상승 후 날카로운 고주파 파열로 이어집니다.",
    "Pull / glide balance": "추력 / 활공 균형",
    "Pulse": "Pulse",
    "Pulse is using |cffffd100%s|r, because a rule is set for %s.": "Pulse에서 |cffffd100%s|r 프로필을 사용하는 중입니다 (%s 규칙 적용).",
    "Pulse tunes motor spin-up attack, coast-down release, and breakaway friction to match your physical hardware actuators.": "Pulse는 실제 하드웨어 액추에이터에 맞게 모터의 회전 시작 도달 속도(어택), 감속 릴리스 및 정지 마찰력을 정밀하게 조율합니다.",
    "Pulse: (Engine recorded %d errors. Last error: %s)": "Pulse: (엔진에 %d개의 오류가 기록되었습니다. 마지막 오류: %s)",
    "Pulse: /pulse test <mode>|heartbeat|warningbeat — try one of: ": "Pulse: /pulse test <모드>|heartbeat|warningbeat — 다음 중 하나를 시도해 보세요: ",
    "Pulse: activated profile \"%s\"": "Pulse: \"%s\" 프로필이 활성화되었습니다",
    "Pulse: active profile is \"%s\" (%s)": "Pulse: 현재 활성 프로필은 \"%s\"(%s)입니다",
    "Pulse: bound profile \"%s\" to specialization %s": "Pulse: \"%s\" 프로필을 %s 전문화에 지정했습니다",
    "Pulse: could not build settings row %q (%s)": "Pulse: 설정 행 %q을(를) 구성할 수 없습니다 (%s)",
    "Pulse: could not build the settings window (": "Pulse: 설정 창을 구성할 수 없습니다 (",
    "Pulse: debug ": "Pulse: 디버그 ",
    "Pulse: disabled all %d cues in active profile.": "Pulse: 활성 프로필의 모든 신호 %d개를 비활성화했습니다.",
    "Pulse: disabled all %d cues in profile \"%s\".": "Pulse: %d개의 모든 신호를 비활성화했습니다 (프로필: \"%s\").",
    "Pulse: disabled all %d cues in profile %s.": "Pulse: %d개의 모든 신호를 비활성화했습니다 (프로필: %s).",
    "Pulse: enabled all %d cues in active profile.": "Pulse: 활성 프로필의 모든 신호 %d개를 활성화했습니다.",
    "Pulse: enabled all %d cues in profile \"%s\".": "Pulse: %d개의 모든 신호를 활성화했습니다 (프로필: \"%s\").",
    "Pulse: enabled all %d cues in profile %s.": "Pulse: %d개의 모든 신호를 활성화했습니다 (프로필: %s).",
    "Pulse: live oscilloscope is provided by the companion addon PulseDebug (/pdebug scope).": "Pulse: 실시간 오실로스코프는 보조 애드온인 PulseDebug(/pdebug scope)에서 제공됩니다.",
    "Pulse: minimap icon %s": "Pulse: 미니맵 아이콘 %s",
    "Pulse: no profile matching \"%s\". Available: %s": "Pulse: \"%s\"와(과) 일치하는 프로필이 없습니다. 사용 가능: %s",
    "Pulse: switched to profile \"%s\"": "Pulse: \"%s\" 프로필로 전환했습니다",
    "Pulse: that preview is unavailable.": "Pulse: 해당 미리보기를 사용할 수 없습니다.",
    "Pulse: this looks like a %s%s. Pick it above, then press Apply.": "Pulse: %s%s 기기로 감지됩니다. 위에서 선택한 후 적용을 누르세요.",
    "Pure flavour — nothing depends on it. Untested.": "단순한 분위기 연출용이며 다른 기능에 영향을 주지 않습니다. 미검증 항목입니다.",
    "Pure novelty. Off by default forever, basically — nobody asked for this one.": "단순한 흥미 위주의 기능입니다. 기본적으로 완전히 비활성화되어 있습니다.",
    "Put every motor's strength, floor, timing and curve back to the engine defaults. Doesn't touch cues, per-cue intensity, mode tuning or your schema.": "모든 모터의 강도, 시동 임계값, 타이밍 및 감응 곡선을 엔진 기본값으로 되돌립니다. 신호, 신호별 강도, 모드 미세 조정 또는 진동 스키마는 변경되지 않습니다.",
    "Put the profile in use back to its stock defaults — works on built-ins too, restoring their curated content rather than blank Registry.lua defaults.": "사용 중인 프로필을 초기 기본값으로 되돌립니다. 기본 제공 프로필에서도 작동하며, 빈 Registry.lua 기본값이 아닌 세심하게 제작된 초기 콘텐츠로 복원합니다.",
    "PvP (Tactical Radar)": "PvP (전술 레이더)",
    "Quest accepted": "퀘스트 수락",
    "Quest offered": "퀘스트 제안",

    # 100..149
    "Quest ready to hand in": "퀘스트 완료 가능",
    "Quest turned in": "퀘스트 완료 보고",
    "Questing": "퀘스트",
    "Questing & Exploration": "퀘스트 및 탐험",
    "Quests": "퀘스트",
    "Quick Setup": "빠른 설정",
    "Quick Setup Wizard": "빠른 설정 마법사",
    "Radial menu": "원형 메뉴",
    "Radial menu closed": "원형 메뉴 닫힘",
    "Radial menu opened": "원형 메뉴 열림",
    "Radial page changed": "원형 메뉴 페이지 변경됨",
    "Radial segment changed": "원형 메뉴 구획 변경됨",
    "Radial segment chosen": "원형 메뉴 구획 선택됨",
    "Radial segment unavailable": "원형 메뉴 구획 사용 불가",
    "Radial selection cancelled": "원형 메뉴 선택 취소됨",
    "Ranged auto-repeat started": "원거리 자동 사격 시작",
    "Ranged auto-repeat stopped": "원거리 자동 사격 중지",
    "Rapid staccato triple-click on the high motor.": "고주파 모터에서 발생하는 빠르고 스타카토 같은 3연타 클릭 진동입니다.",
    "Reading something": "문서 읽기",
    "Reads the segment's own IsEnabled() — the same value Blizzard reads to grey the highlight out, so this matches what you see on screen. Fires in place of \"Radial segment changed\", not alongside it.": "구획 자체의 IsEnabled()를 읽어옵니다. 이는 블리자드가 강조 표시를 비활성화(회색) 처리할 때 읽는 값과 동일하므로 화면에 표시되는 상태와 완벽히 일치합니다. \"원형 메뉴 구획 변경됨\"과 함께 울리지 않고 이를 대체하여 발생합니다.",
    "Ready check": "전투 준비 확인",
    "Ready check finished": "전투 준비 확인 완료",
    "Release time (s)": "감속 시간 (초)",
    "Reload UI": "UI 다시 불러오기",
    "Reload UI to apply the language change.": "언어 변경을 적용하려면 UI를 다시 불러오세요.",
    "Reload the interface to apply your selected addon language.": "선택한 애드온 언어를 적용하려면 인터페이스를 다시 불러오세요(/reload).",
    "Rename": "이름 변경",
    "Rename \"%s\" to:": "\"%s\"의 새 이름 입력:",
    "Rename the profile in use. Every rule pointing at it follows the rename. Built-in profiles can't be renamed.": "사용 중인 프로필의 이름을 변경합니다. 이 프로필을 가리키는 모든 규칙도 변경된 이름을 따릅니다. 기본 제공 프로필은 이름을 변경할 수 없습니다.",
    "Rename this profile": "이 프로필 이름 변경",
    "Rename...": "이름 변경...",
    "Repaired equipment": "장비 수리 완료",
    "Reset": "초기화",
    "Reset every motor's strength, floor, timing and curve back to the engine defaults? This can't be undone.": "모든 모터의 강도, 시동 임계값, 타이밍 및 감응 곡선을 엔진 기본값으로 초기화하시겠습니까? 이 작업은 되돌릴 수 없습니다.",
    "Reset profile \"%s\" to defaults? Every cue, intensity and mode override in it goes back to stock values. This can't be undone.": "\"%s\" 프로필을 기본값으로 초기화하시겠습니까? 프로필의 모든 신호, 강도 및 모드 재지정 값이 초기 상태로 되돌아갑니다. 이 작업은 되돌릴 수 없습니다.",
    "Reset this profile": "이 프로필 초기화",
    "Reset...": "초기화...",
    "Resources": "자원",
    "Response curve": "감응 곡선",
    "Resting": "휴식 중",
    "Resurrection offered": "부활 제안받음",
    "Rewards": "보상",
    "Rogue": "도적",
    "Role poll": "역할 확인",
    "Rooted": "이동 불가",
    "Routing & Schema": "라우팅 및 스키마",
    "Rules": "규칙",
    "Run Wizard": "마법사 실행",
    "Run cadence (steps/s)": "달리기 케이던스 (걸음/초)",
    "Same polled mechanism as \"Confirmation popup appeared\". Untested.": "\"확인 팝업 표시됨\"과 동일한 폴링 메커니즘을 사용합니다. 미검증 항목입니다.",

    # 150..199
    "Save & Start Playing": "저장 후 게임 시작",
    "Scales both the bed and the strikes for %s, before the two shared strengths above.": "위의 두 공통 강도를 적용하기 전에, %s의 바탕 진동과 타격 진동을 모두 조절합니다.",
    "Scales this cue on top of the overall intensity on the Pulse page.": "Pulse 페이지의 전체 강도 설정 위에 이 신호의 강도를 추가로 조절합니다.",
    "School lockouts are frequent in melee-heavy content. Off by default because a cue every kick you eat can crowd out the ones that mean you cannot act at all.": "근접 전투가 많은 콘텐츠에서는 주문 계열 차단이 자주 발생합니다. 차단 기술을 맞을 때마다 울리는 신호가 완전히 행동 불가 상태가 되었을 때의 신호를 묻히게 할 수 있으므로 기본적으로 꺼져 있습니다.",
    "Search %d cues...": "%d개 신호 검색...",
    "Secondary resource full": "보조 자원 가득 참",
    "Set Floor": "시동 임계값 지정",
    "Set but not in force: |cffffd100%s|r. A more specific rule above is winning — clear it to let these take over.": "설정되었으나 비활성 상태: |cffffd100%s|r. 상위의 더 구체적인 규칙이 우선 적용 중입니다 — 해당 규칙을 지우면 이 설정이 적용됩니다.",
    "Set for Spec": "전문화별 설정",
    "Setup Summary": "설정 요약",
    "Shaman": "주술사",
    "Shares its pulse pattern with the target cue. If your focus is also your target, you get one cue rather than two.": "대상 신호와 동일한 펄스 패턴을 공유합니다. 주시대상이 현재 대상과 같으면 두 번 울리지 않고 한 번만 작동합니다.",
    "Sharp high kick layered with heavy low kick and rumble decay.": "날카로운 고주파 킥에 묵직한 저주파 킥과 진동 감쇄가 겹쳐진 형태입니다.",
    "Show a Play button on every cue": "모든 신호에 재생 버튼 표시",
    "Show minimap icon": "미니맵 아이콘 표시",
    "Show per-cue detail controls": "신호별 세부 제어 표시",
    "Shows only the page switches and this page. Every cue keeps its own settings; turn this off to get every page back exactly as it was.": "페이지 전환 스위치와 이 페이지만 표시합니다. 모든 신호는 자체 설정을 유지하며, 이 옵션을 끄면 모든 페이지가 이전 상태 그대로 복원됩니다.",
    "Silenced": "침묵",
    "Simple view": "간단히 보기",
    "Slow, harmonic oceanic gravity swells and coastal tides while submerged in deep oceans.": "깊은 바닷속에 잠겨 있을 때 느껴지는 느리고 조화로운 해양 중력 너울 및 연안 조석 진동입니다.",
    "Snappy & Taps": "경쾌한 탭",
    "Social & Group": "소셜 및 파티",
    "Social & Group Communication": "소셜 및 파티 대화",
    "Soft target interact": "소프트 타겟 상호작용",
    "Special casting": "특수 시전",
    "Speeds up or slows down ": "속도를 빠르게 하거나 느리게 설정 ",
    "Spirit healer": "영혼의 치유사",
    "Split left and right": "좌우 분리",
    "Square / X: open settings": "Square / X: 설정 열기",
    "Stable opened": "야수 우리 열림",
    "Stack split ratchet": "묶음 분할 래싯",
    "Standard Rumble": "표준 진동",
    "Standard balance across all categories": "모든 범주에 걸친 표준 균형",
    "Status: %s": "상태: %s",
    "Step 4: Interface & Social Alerts": "4단계: 인터페이스 및 소셜 알림",
    "Step 6: Master Strength & Completion": "6단계: 마스터 강도 및 완료",
    "Steps per second at full running speed. Scaled by how fast you are actually moving.": "전력 질주 달리기 속도에서의 초당 걸음 수입니다. 실제 이동 속도에 비례하여 조정됩니다.",
    "Steps per second at normal walking speed.": "일반 걷기 속도에서의 초당 걸음 수입니다.",
    "Strength": "강도",
    "Strike strength": "타격 강도",
    "Stroke depth": "스트로크 깊이",
    "Stroke rate, fast (Hz)": "스트로크 빈도, 빠름 (Hz)",
    "Stroke rate, slow (Hz)": "스트로크 빈도, 느림 (Hz)",
    "Strokes per second at barely-moving speed.": "매우 느린 이동 속도에서의 초당 스트로크 횟수입니다.",
    "Stunned": "기절",
    "Summon offered": "소환 제안받음",
    "Swapped / Inverted Rumble": "반전 / 맞바꿈 진동",
    "Swell depth": "너울 깊이",
    "Swell rate (Hz)": "너울 주기 (Hz)",
    "Swell strength": "너울 강도",

    # 200..249
    "Switch to this profile": "이 프로필로 전환",
    "Switches every cue on the Casting page on or off at once. Each cue keeps its own setting underneath.": "시전 페이지의 모든 신호를 한 번에 켜거나 끕니다. 각 신호의 개별 설정은 그대로 유지됩니다.",
    "Switches every cue on the Character & Status page on or off at once. Each cue keeps its own setting underneath.": "캐릭터 및 상태 페이지의 모든 신호를 한 번에 켜거나 끕니다. 각 신호의 개별 설정은 그대로 유지됩니다.",
    "Switches every cue on the Interface & Accessibility page on or off at once. Each cue keeps its own setting underneath.": "인터페이스 및 접근성 페이지의 모든 신호를 한 번에 켜거나 끕니다. 각 신호의 개별 설정은 그대로 유지됩니다.",
    "Switches every cue on the Movement & Travel page on or off at once. Each cue keeps its own setting underneath.": "이동 및 여행 페이지의 모든 신호를 한 번에 켜거나 끕니다. 각 신호의 개별 설정은 그대로 유지됩니다.",
    "Switches every cue on the Social & Group page on or off at once. Each cue keeps its own setting underneath.": "소셜 및 파티 페이지의 모든 신호를 한 번에 켜거나 끕니다. 각 신호의 개별 설정은 그대로 유지됩니다.",
    "Switches every cue on the Target & Focus page on or off at once. Each cue keeps its own setting underneath.": "대상 및 주시대상 페이지의 모든 신호를 한 번에 켜거나 끕니다. 각 신호의 개별 설정은 그대로 유지됩니다.",
    "Switches every cue on the World & Environment page on or off at once. Each cue keeps its own setting underneath.": "환경 및 세계 페이지의 모든 신호를 한 번에 켜거나 끕니다. 각 신호의 개별 설정은 그대로 유지됩니다.",
    "Talking to someone": "대화 진행 중",
    "Target": "대상",
    "Target & Crosshair Feedback": "대상 및 조준선 피드백",
    "Target & Focus": "대상 및 주시대상",
    "Target changed": "대상 변경됨",
    "Target died": "대상 사망",
    "Target started casting": "대상이 시전 시작",
    "Target used major defensive": "대상이 주요 생존기 사용",
    "Target's cast stopped": "대상의 시전 중지됨",
    "Targeted by enemy": "적에게 지목됨",
    "Targeting": "대상 지정",
    "Test Alert": "경고 테스트",
    "Test Impact": "충격 진동 테스트",
    "Test Lock": "차단 테스트",
    "Test Reward": "보상 테스트",
    "Test Rumble": "진동 테스트",
    "Test Strike": "타격 테스트",
    "Test UI": "UI 테스트",
    "Test the selected mode": "선택한 모드 테스트",
    "Textures & Patterns": "질감 및 패턴",
    "The Accessibility section": "접근성 섹션",
    "The Cue Index directory": "신호 인덱스 목록",
    "The _QUIET variant covers failures the game prints no error for, so this can fire with nothing visible on screen.": "_QUIET 변형은 게임에서 오류 메시지를 출력하지 않는 실패를 감지하므로, 화면에 아무것도 표시되지 않아도 신호가 발생할 수 있습니다.",
    "The experimental section": "실험실 섹션",
    "The lightest possible tick when a conversation window opens with any NPC.": "NPC와의 대화 창이 열릴 때 발생하는 가장 가벼운 틱 진동입니다.",
    "The master switch for this page. Also on the Casting page, where the cue lives alongside the other casting cues.": "이 페이지의 마스터 스위치입니다. 해당 신호가 다른 시전 신호들과 함께 배치되어 있는 시전 페이지에도 존재합니다.",
    "This character": "현재 캐릭터",
    "This character reports no specialization, so there is no per-specialization rule to set. The row appears by itself on a character that has one.": "이 캐릭터는 전문화가 확인되지 않아 전문화별 규칙을 설정할 수 없습니다. 전문화가 있는 캐릭터에서는 해당 행이 자동으로 표시됩니다.",
    "This specialization": "현재 전문화",
    "This specialization (": "현재 전문화 (",
    "Three rhythmic thuds.": "리드미컬한 3회의 쿵 진동입니다.",
    "Three-stage rising tension building on the low motor.": "저주파 모터에서 고조되는 3단계 긴장감 상승 진동입니다.",
    "Thrill curve (high)": "스릴 감응 곡선 (고속)",
    "Thrill peak (high)": "스릴 정점 강도 (고속)",
    "Time in seconds for a complete wave cycle. Real oceanic swells roll every 8 to 12 seconds (~0.10 Hz). Shorter periods feel like choppy coastal chop; longer periods feel like open-ocean rollers.": "전체 파도 주기의 지속 시간(초)입니다. 실제 대양 너울은 8~12초(~0.10Hz)마다 밀려옵니다. 주기가 짧으면 거친 연안 잔물결처럼 느껴지고, 주기가 길면 탁 트인 대양의 큰 파도처럼 느껴집니다.",
    "Tracked cooldown ready": "추적 중인 재사용 대기시간 준비됨",
    "Trade opened": "거래창 열림",
    "Triggers, modes, and motor tuning": "트리거, 모드 및 모터 미세 조정",
    "Try Texture": "진동 질감 테스트",
    "Tuned for HD Rumble voice-coil actuators": "HD 진동 보이스 코일 액추에이터에 최적화",
    "Turn off every cue in the active profile in one sweep (useful for quiet debugging).": "활성 프로필의 모든 신호를 한 번에 끕니다 (조용한 디버깅 시 유용).",
    "Turn on every cue in the active profile in one sweep (useful for testing/debugging).": "활성 프로필의 모든 신호를 한 번에 켭니다 (테스트/디버깅 시 유용).",

    # 250..299
    "Turn whole pages of cues on or off. Each cue keeps its own setting underneath: switching a page back on restores exactly what was there.": "페이지 전체의 신호를 한 번에 켜거나 끕니다. 각 신호의 개별 설정은 그대로 유지되므로, 페이지를 다시 켜면 이전 상태가 그대로 복원됩니다.",
    "Two crisp ticks when a cooldown the built-in Cooldown Manager is tracking comes off cooldown.": "기본 제공되는 재사용 대기시간 관리자에서 추적 중인 기술의 재사용 대기시간이 만료될 때 울리는 선명한 2회의 틱 진동입니다.",
    "Two heavier hits with a gap between them.": "간격을 두고 발생하는 묵직한 2회의 타격 진동입니다.",
    "Two kinds of trigger: pulses and textures": "두 가지 종류의 트리거: 펄스 및 질감",
    "Two rhythmic thuds.": "리드미컬한 2회의 쿵 진동입니다.",
    "Two soft ticks when the action bar pages to a different set of abilities.": "동작 모음이 다른 기술 페이지로 전환될 때 울리는 부드러운 2회의 틱 진동입니다.",
    "Two soft ticks when you page the radial left or right with the shoulder buttons.": "범퍼(숄더) 버튼으로 원형 메뉴 페이지를 좌우로 전환할 때 울리는 부드러운 2회의 틱 진동입니다.",
    "UI focus moved": "UI 포커스 이동됨",
    "UI navigation hit an edge": "UI 탐색이 가장자리에 닿음",
    "UI panel closed": "UI 창 닫힘",
    "UI panel opened": "UI 창 열림",
    "Untested whether this also fires on every instant-cast press rather than only real cast-bar completions — if so, it'll feel far too frequent to read as \"that landed\" specifically. Check before relying on it.": "실제 시전 바 완료뿐만 아니라 모든 즉시 시전 기술 사용 시에도 발생하는지 여부는 미검증 상태입니다. 만약 그렇다면 너무 자주 발생하여 기술이 적중했다는 고유한 느낌을 받기 어렵습니다. 사용하기 전에 확인하세요.",
    "Untested.": "미검증 항목입니다.",
    "Use the old estimator": "기존 예측 계산기 사용",
    "Using \"%s\" — set for %s.": "\"%s\" 사용 중 — %s에 설정됨.",
    "Vendor window opened": "상인 창 열림",
    "Vibration Mode": "진동 모드",
    "Vibration Schema: |cffffd100%s|r": "진동 스키마: |cffffd100%s|r",
    "Vibration schema": "진동 스키마",
    "Voice-coil actuators (LRA), ultra-low 0.025 floor, instant response": "보이스 코일 액추에이터(LRA), 초저지연 0.025 시동 임계값, 즉각적인 응답",
    "Walk cadence (steps/s)": "걷기 케이던스 (걸음/초)",
    "Warlock": "흑마법사",
    "Warning lead time": "경고 선행 시간",
    "Warrior": "전사",
    "Watches UNIT_TARGET and target swaps for hostile units whose target is the player. Uses UnitIsUnit('targettarget', 'player') with defensive secrecy guards.": "플레이어를 대상으로 잡고 있는 적대적 유닛의 UNIT_TARGET 및 대상 전환을 감시합니다. 방어적 예외 처리가 포함된 UnitIsUnit('targettarget', 'player')를 사용합니다.",
    "Wave cycle (seconds)": "파도 주기 (초)",
    "Wave period (sec)": "파도 주기 (초)",
    "Wave steepness": "파도 경사도",
    "Weapon or gear swapped": "무기 또는 장비 교체됨",
    "What this does": "기능 설명",
    "When mobs are pulled socially — aggroing because a neighbour was pulled — the game often reports status 0 even though you have aggro.": "몬스터가 동료 인식으로 반응할 때(주변 몬스터 공격으로 인해 애드될 때), 실제로는 어그로를 획득했음에도 게임 시스템에서 상태를 0으로 보고하는 경우가 자주 있습니다.",
    "Which of the preset shapes this specific cue plays when it fires. \"": "이 신호가 작동할 때 사전 설정된 형태 중 어떤 것을 재생할지 결정합니다. \"",
    "Which physical motors each cue drives. Start with Standard Rumble, then calibrate the motors below.": "각 신호가 구동할 물리적 모터를 선택합니다. 표준 진동으로 시작한 후 아래에서 모터를 보정하세요.",
    "Which physical motors each trigger drives. Try one, test a mode below, keep the one you can feel.": "각 트리거가 구동할 물리적 모터를 선택합니다. 스키마를 선택하고 아래에서 모드를 테스트한 후 직접 체감되는 것을 유지하세요.",
    "Which profile to use right now. This writes to whichever rule is currently in force, so picking here always changes what you are actually using rather than editing a rule something more specific is overriding.": "현재 사용할 프로필을 선택합니다. 현재 적용 중인 규칙에 기록되므로, 상위의 더 구체적인 규칙에 덮어씌워지는 규칙을 편집하는 대신 현재 실제로 사용 중인 설정을 즉시 변경합니다.",
    "Wind amplitude": "바람 진폭",
    "Wind resistance & thrust surge while flying. Scales dynamically with your flight speed.": "비행 중의 공기 저항 및 추진력 급증 진동입니다. 비행 속도에 따라 동적으로 조절됩니다.",
    "Windows": "창",
    "World": "세계",
    "World & Environment": "환경 및 세계",
    "World Immersion": "세계 몰입감",
    "You are alive again": "다시 살아남",
    "You died": "사망함",
    "You have aggro": "위협 수준 획득 (어그로)",
    "Your cast ended": "시전 완료됨",
    "Your cast failed": "시전 실패함",
    "Your cast started": "시전 시작됨",
    "Your cast succeeded": "시전 성공함",
    "Zone changed": "지역 변경됨",
    "an impact": "타격 진동",

    # 300..330
    "could not apply that preset": "해당 사전 설정을 적용할 수 없습니다",
    "could not run that": "해당 작업을 실행할 수 없습니다",
    "could not set that rule": "해당 규칙을 설정할 수 없습니다",
    "detection unavailable": "감지 불가",
    "in force": "적용 중",
    "no role chosen": "역할 미선택",
    "once a minute": "1분에 1회",
    "once every ": "매 ",
    "once every %.1f seconds": "%.1f초마다 1회",
    "|cff00ff00Left-Click:|r Open Settings": "|cff00ff00좌클릭:|r 설정 열기",
    "|cff00ff00Right-Click:|r Toggle Master On/Off": "|cff00ff00우클릭:|r 마스터 켜기/끄기",
    "|cff00ff00[Adjusting %d%%]|r Use |cffffffff[← / →]|r to Change, |cff38BDF8[A]|r Confirm & Feel": "|cff00ff00[%d%% 조절 중]|r |cffffffff[← / →]|r 변경, |cff38BDF8[A]|r 확인 및 체감",
    "|cff38BDF8[L1 / LB]|r": "|cff38BDF8[L1 / LB]|r",
    "|cff38BDF8[L1/R1]|r Tabs  •  |cff38BDF8[A]|r Toggle Slider / Select": "|cff38BDF8[L1/R1]|r 탭  •  |cff38BDF8[A]|r 슬라이더 전환 / 선택",
    "|cff38BDF8[R1 / RB]|r": "|cff38BDF8[R1 / RB]|r",
    "|cff444444[L1 / LB]|r": "|cff444444[L1 / LB]|r",
    "|cff444444[R1 / RB]|r": "|cff444444[R1 / RB]|r",
    "|cff4cb8ffPulse:|r Quick setup complete! Type |cffffffff/pulse|r anytime to fine-tune settings.": "|cff4cb8ffPulse:|r 빠른 설정 완료! 설정을 미세 조정하려면 언제든지 |cffffffff/pulse|r 명령어를 입력하세요.",
    "|cff4db8ff✔ |r": "|cff4db8ff✔ |r",
    "|cff888888Drag:|r Move Icon": "|cff888888드래그:|r 아이콘 이동",
    "|cff888888Loss of control cues are governed by the master switch on the main Pulse page.|r": "|cff888888제어 불가 신호는 Pulse 메인 페이지의 마스터 스위치로 관리됩니다.|r",
    "|cff888888Recommended intensity:|r %d%%": "|cff888888권장 강도:|r %d%%",
    "|cffffcc00◀/▶ Adjust Intensity|r   •   %s/%s Lock Value   •   %s Try Texture": "|cffffcc00◀/▶ 강도 조절|r   •   %s/%s 값 잠금   •   %s 진동 질감 테스트",
    "|cffffd100%s|r  |cff00ff00[ACTIVE]|r": "|cffffd100%s|r  |cff00ff00[활성]|r",
    "|cffffd100/pulseui|r opens it too. |cffffd100/pulse setup|r re-opens Quick Setup, |cffffd100/pulse test <mode>|r plays a shape.": "|cffffd100/pulseui|r 명령어로도 열 수 있습니다. |cffffd100/pulse setup|r 명령어로 빠른 설정을 다시 열 수 있으며, |cffffd100/pulse test <모드>|r 명령어로 진동 형태를 재생할 수 있습니다.",
    "|r, |cffffd100": "|r, |cffffd100",
    "• |r": "• |r",
    "⚔️ Melee DPS": "⚔️ 근접 공격 담당",
    "🏹 Ranged DPS": "🏹 원거리 공격 담당",
    "💚 Healer": "💚 치유 담당",
    "🛡️ Tank": "🛡️ 방어 담당",
}

def main():
    with open(BATCH1B_JSON, "r", encoding="utf-8") as f:
        batch_data = json.load(f)

    items = batch_data.get("items", [])
    print(f"Total source items in batch1b: {len(items)}")

    errors = 0
    translated_items = []

    for idx, item in enumerate(items):
        src = item["source"]
        if src not in TRANSLATIONS_KO:
            print(f"ERROR: Missing translation for [{idx}]: {repr(src)}")
            errors += 1
            continue

        tgt = TRANSLATIONS_KO[src]

        # 1. Signature check
        sig_src = extract_signature(src)
        sig_tgt = extract_signature(tgt)
        if sig_src != sig_tgt:
            print(f"ERROR: Signature mismatch for [{idx}]:\n  SRC ({sig_src}): {repr(src)}\n  TGT ({sig_tgt}): {repr(tgt)}")
            errors += 1

        # 2. Color balance check
        if not check_color_balance(src, tgt):
            print(f"ERROR: Color code mismatch for [{idx}]:\n  SRC: {repr(src)}\n  TGT: {repr(tgt)}")
            errors += 1

        # 3. Empty target check
        if not tgt:
            print(f"ERROR: Empty target for [{idx}]: {repr(src)}")
            errors += 1

        translated_items.append({
            "source": src,
            "target": tgt
        })

    if errors > 0:
        print(f"\nFAILED with {errors} errors. Aborting.")
        sys.exit(1)

    out_data = {
        "items": translated_items
    }
    with open(OUTPUT_JSON, "w", encoding="utf-8") as f:
        json.dump(out_data, f, indent=2, ensure_ascii=False)

    print(f"SUCCESS: Wrote {len(translated_items)} validated translations to {OUTPUT_JSON}")

if __name__ == "__main__":
    main()
