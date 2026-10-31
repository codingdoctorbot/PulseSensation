#!/usr/bin/env python3
"""
Generates and validates translated_koKR_batch1a.json for PulseHaptics Korean localization.
Strictly adheres to WoW Classic Korean terminology and GLOSSARY.md.
"""

import json
import os
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "tools"))
from validate_catalog import extract_signature, check_color_balance

TRANSLATIONS_KO = {
    # 0..17
    " (page off)|r": " (페이지 비활성)|r",
    " (reported as \"": " (인식된 이름: \"",
    " Rules and management are on the Profiles page.": " 규칙 및 관리는 프로필 페이지에서 설정할 수 있습니다.",
    " as a whole — both its pulses and the gaps between them, so a multi-hit mode keeps its rhythm instead of the hits stretching into their own gaps. 1.0 is the authored default.": " 전체를 조절합니다 — 펄스와 펄스 간격 모두에 적용되므로 다중 타격 모드가 간격 속으로 늘어지는 대신 고유한 리듬을 유지합니다. 기본값은 1.0입니다.",
    " right now with whatever's currently set on its sliders above.": " 위의 슬라이더에 현재 설정된 값으로 지금 바로 테스트합니다.",
    "\" is recommended — pick a different one to change how just this cue feels, without affecting anything else that also uses \"": "\" 모드를 권장합니다 — 동일한 모드를 사용하는 다른 신호에 영향을 주지 않고 이 신호의 느낌만 변경하려면 다른 항목을 선택하세요: \"",
    "\" — try one of: ": "\" — 다음 중 하나를 사용해 보세요: ",
    "%d of %d cues on": "%d / %d개 신호 활성",
    "%d of %d on": "%d / %d개 활성",
    "%s (%d)": "%s (%d)",
    "%s Activate   •   %s Try Texture   •   %s Categories": "%s 활성화   •   %s 진동 질감 테스트   •   %s 범주",
    "%s Adjust Intensity   •   %s Quick Step   •   |cff38BDF8◀/▶|r Controls   •   %s Try Texture   •   %s Categories": "%s 강도 조절   •   %s 빠른 단계   •   |cff38BDF8◀/▶|r 컨트롤   •   %s 진동 질감 테스트   •   %s 범주",
    "%s Browse Modes   •   %s Select   •   %s Cancel": "%s 모드 탐색   •   %s 선택   •   %s 취소",
    "%s Select Mode   •   |cff38BDF8◀/▶|r Controls   •   %s Try Texture   •   %s Categories": "%s 모드 선택   •   |cff38BDF8◀/▶|r 컨트롤   •   %s 진동 질감 테스트   •   %s 범주",
    "%s Switch Category   •   %s Navigate   •   %s Select   •   %s Close": "%s 범주 전환   •   %s 탐색   •   %s 선택   •   %s 닫기",
    "%s Toggle   •   |cff38BDF8▶|r Next Control   •   %s Try Texture   •   %s Categories": "%s 전환   •   |cff38BDF8▶|r 다음 컨트롤   •   %s 진동 질감 테스트   •   %s 범주",
    "%s is felt as %s struck about %.1f times a second, over the bed.": "%s은(는) 바탕 진동 위에서 %s 감각이 초당 약 %.1f회 울리는 느낌으로 전달됩니다.",
    "%s/%s Try Texture   •   |cff38BDF8◀|r Controls   •   %s Categories": "%s/%s 진동 질감 테스트   •   |cff38BDF8◀|r 컨트롤   •   %s 범주",

    # 18..39
    "(Toggles all continuous sensations)": "(모든 지속 감각 전환)",
    ", heartbeat, warningbeat": ", heartbeat, warningbeat",
    ", not ": ", 제외: ",
    ", so there is nothing to test.": ", 따라서 테스트할 항목이 없습니다.",
    "0 = one soft pulse. 1 = a sharp lub, then a clearly separate softer dub. Derives the knock timing and intensity split automatically — see lowHealthTexture if you want those set by hand instead.": "0 = 부드러운 펄스 1회. 1 = 날카로운 쿵(lub) 이후 명확히 구분되는 부드러운 쾅(dub). 노크 타이밍과 강도 분할을 자동으로 계산합니다. 직접 수동으로 설정하려면 lowHealthTexture를 확인하세요.",
    "1 = every scripted event, 3 = only the most severe. Higher means rarer, more significant warnings.": "1 = 모든 스크립트 이벤트, 3 = 가장 심각한 이벤트만. 수치가 높을수록 더 드물고 중요한 경고만 울립니다.",
    "3. World": "3. 세계",
    "4. Interface": "4. 인터페이스",
    "5. Immersion": "5. 몰입감",
    "6. Finish": "6. 완료",
    "< Back": "< 뒤로",
    "A bright tick when you learn a new ability.": "새로운 능력을 배울 때 울리는 선명한 틱 진동입니다.",
    "A crisp mechanical snap on the high motor.": "고주파 모터에서 발생하는 산뜻한 기계식 스냅입니다.",
    "A dense 3-pulse tactical flurry.": "조밀한 3회 펄스의 전술적 연속 진동입니다.",
    "A dry click when you use an ability that has no cast time.": "시전 시간이 없는 능력을 사용할 때 울리는 건조한 클릭 진동입니다.",
    "A heavy, decisive impact when your current target dies.": "현재 대상이 사망할 때 울리는 묵직하고 결정적인 충격입니다.",
    "A light click when a major UI panel is dismissed.": "주요 UI 창이 닫힐 때 울리는 가벼운 클릭 진동입니다.",
    "A light click when the last confirmation dialog closes.": "마지막 확인 대화 상자가 닫힐 때 울리는 가벼운 클릭 진동입니다.",
    "A light tick when you step away from an NPC or close its window.": "NPC에게서 멀어지거나 NPC 창을 닫을 때 울리는 가벼운 틱 진동입니다.",
    "A ringing anvil strike when repairing armor and weapons at a vendor.": "상인에게 방어구 및 무기를 수리할 때 울리는 모루 타격 진동입니다.",
    "A rising celebratory surge when you gain a level.": "레벨이 상승할 때 울리는 축하 상승 파동입니다.",
    "A sharp alert pulse when your hostile target or focus turns to target you.": "적대적 대상이나 주시 대상이 나를 목표로 잡을 때 울리는 날카로운 경고 펄스입니다.",

    # 40..69
    "A sharp deflection tick when a cast of yours is rejected outright — out of range, not facing the target, still on cooldown.": "시전이 즉시 거부되었을 때(사정거리 벗어남, 대상을 향하지 않음, 재사용 대기 중) 울리는 날카로운 튕김 틱 진동입니다.",
    "A sharp deflection tick when the game refuses an action — out of range, facing the wrong way, not enough resource, still on cooldown.": "게임에서 행동이 거부되었을 때(사정거리 벗어남, 방향 잘못됨, 자원 부족, 재사용 대기 중) 울리는 날카로운 튕김 틱 진동입니다.",
    "A sharp snap when a harmful effect lands on you.": "자신에게 해로운 효과가 적용될 때 울리는 날카로운 스냅입니다.",
    "A sharp snap with a short tail.": "여운이 짧은 날카로운 스냅입니다.",
    "A short warning before a significant scripted boss ability, using Blizzard's own built-in Boss Warnings timeline.": "블리자드 기본 내장 우두머리 경고 타임라인을 사용하여 중요한 스크립트 우두머리 능력이 발동하기 전에 전달되는 짧은 경고입니다.",
    "A short, sharp tick instead of the normal one when the segment you land on can't be used.": "선택한 구획을 사용할 수 없을 때 일반 진동 대신 울리는 짧고 날카로운 틱 진동입니다.",
    "A single dry click, lighter than a tick.": "틱보다 가벼운 단일 건조 클릭 진동입니다.",
    "A single very short, very hard hit.": "매우 짧고 매우 강한 단일 타격입니다.",
    "A slow low/high oscillation — the caller supplies the phase.": "느린 저주파/고주파 진동입니다 — 호출 측에서 위상을 제공합니다.",
    "A soft tick followed by a brighter one.": "부드러운 틱 이후 더 선명한 틱이 이어지는 진동입니다.",
    "A soft tick when releasing the group targeting modifier back to normal navigation.": "파티원 지정 보조 키를 떼고 일반 탐색으로 돌아갈 때 울리는 부드러운 틱 진동입니다.",
    "A soft tick when you cancel a radial selection instead of committing to it.": "원형 메뉴 선택을 확정하지 않고 취소할 때 울리는 부드러운 틱 진동입니다.",
    "A soft tick when you start auto-attacking with a ranged weapon (Auto Shot, Shoot, wands).": "원거리 무기(자동 사격, 사격, 마법봉)로 자동 공격을 시작할 때 울리는 부드러운 틱 진동입니다.",
    "A soft tick when you start meleeing.": "근접 공격을 시작할 때 울리는 부드러운 틱 진동입니다.",
    "A soft tick when you start resting in an inn or major city.": "여관이나 대도시에서 휴식을 시작할 때 울리는 부드러운 틱 진동입니다.",
    "A soft tick when your melee auto-attack stops — catches walking out of range or a target dying without noticing.": "근접 자동 공격이 중단될 때(사정거리 벗어남 또는 대상의 사망 미감지 방지) 울리는 부드러운 틱 진동입니다.",
    "A soft, quick tick.": "부드럽고 빠른 틱 진동입니다.",
    "A steady, low ambient texture.": "안정적이고 은은한 저주파 배경 질감 진동입니다.",
    "A steady, stronger texture — meant to be scaled by the caller (e.g. speed).": "호출 측에서 조절하도록 고안된(예: 속도) 안정적이고 강한 질감 진동입니다.",
    "A tactile micro-tick each time the stack splitter quantity slider changes.": "아이템 겹침 분할 수량 슬라이더가 변경될 때마다 느껴지는 촉각 미세 틱입니다.",
    "A tactile recoil kick on every Auto Shot arrow, timed to the real shot, not estimated.": "추정치가 아닌 실제 발사에 맞춰 모든 자동 사격 화살마다 울리는 촉각적 반동 킥입니다.",
    "A tap when a confirmation dialog opens.": "확인 대화 상자가 열릴 때 울리는 탭 진동입니다.",
    "A tap when an NPC or world object opens a window nothing else here covers.": "NPC나 환경 오브젝트가 여기에 포함되지 않은 창을 열 때 울리는 탭 진동입니다.",
    "A texture that builds as your gliding speed climbs toward a boost.": "활공 속도가 증가하여 가속에 가까워질수록 점점 고조되는 질감 진동입니다.",
    "A tick when a book, plaque, gravestone or signpost opens to be read.": "책, 명판, 비석 또는 표지판을 읽기 위해 열 때 울리는 틱 진동입니다.",
    "A tick when a piece of your gear's durability drops into the low or broken range.": "장비의 내구도가 낮음 또는 파손 상태로 떨어질 때 울리는 틱 진동입니다.",
    "A tiny blip when you gain experience.": "경험치를 획득할 때 울리는 미세한 블립 신호입니다.",
    "A tiny low blip, for things that happen often.": "자주 발생하는 상황을 위한 미세한 저주파 블립 신호입니다.",
    "A triumphant dual-tone chime when you earn an achievement.": "업적을 달성할 때 울리는 당당한 2음조 차임입니다.",
    "A very light micro-pulse.": "매우 가벼운 마이크로 펄스입니다.",

    # 70..99
    "A very light tick per combo point, building toward a full resource.": "연계 점수가 쌓여 최대 자원에 도달할 때까지 점수마다 울리는 매우 가벼운 틱 진동입니다.",
    "A very light tick when your equipped gear changes.": "착용한 장비가 변경될 때 울리는 매우 가벼운 틱 진동입니다.",
    "A very short, sharp tick when you avoid an incoming attack.": "받는 공격을 회피하거나 빗겨냈을 때 울리는 매우 짧고 날카로운 틱 진동입니다.",
    "AFK or DND toggled": "자리 비움 또는 다른 용무 중 전환",
    "Ability pulse": "능력 펄스",
    "Achievement earned": "업적 달성",
    "Action bar page changed": "행동 단축바 페이지 변경됨",
    "Action bars": "행동 단축바",
    "Action failed": "행동 실패",
    "Action feedback": "행동 피드백",
    "Activate": "활성화",
    "Active Profile: |cffffd100%s|r": "활성 프로필: |cffffd100%s|r",
    "Active profile": "활성 프로필",
    "Actuator profile: %s\n%s": "액추에이터 프로필: %s\n%s",
    "Addon language": "애드온 언어",
    "Adjust your global master vibration strength. Individual cues can always be fine-tuned in settings.": "전역 마스터 진동 강도를 조절합니다. 개별 신호는 언제든지 설정에서 미세 조정할 수 있습니다.",
    "Advanced Settings": "고급 설정",
    "Also fires when you cancel a cast yourself, or move out of range — it means \"your cast did not finish\", not specifically \"you were kicked\".": "스스로 시전을 취소하거나 사정거리를 벗어날 때도 발동합니다. 구체적으로 \"차단당함\"이 아니라 \"시전이 완료되지 않음\"을 의미합니다.",
    "Also fires when you switch to a target that is already mid-cast.": "이미 시전 중인 대상으로 전환할 때도 발동합니다.",
    "Alternates between the motors — an unsteady, rolling feel.": "모터 간을 교대로 진동하여 흔들리며 구르는 듯한 느낌을 줍니다.",
    "Alternating low thud and high snap across motors.": "모터 간에 저주파 쿵 충격과 고주파 스냅이 교대로 발생합니다.",
    "Any other window": "기타 모든 창",
    "Anything else": "기타 모든 항목",
    "Applies only while this character is in this specialization. Switching specialization switches profile with it, with no further action from you.": "이 캐릭터가 해당 전문화 상태일 때만 적용됩니다. 전문화를 전환하면 추가 조작 없이 프로필도 함께 전환됩니다.",
    "Applies to this character whatever specialization it is in. This is the rule the profile picker on the Pulse page has always written to.": "캐릭터의 전문화와 무관하게 이 캐릭터에 항상 적용됩니다. 이는 Pulse 페이지의 프로필 선택기에서 항상 설정해 온 규칙입니다.",
    "Attack time (s)": "어택 시간 (s)",
    "Attentive triage. Emergency low health warnings, dispel/CC alerts, kick warnings, and heal completion confirmation with subdued personal damage.": "세심한 치유 우선순위 관리. 긴급 생명력 위험 경고, 해제/군중 제어(CC) 알림, 차단 경고 및 치유 완료 확인을 제공하며 받는 피해 진동은 절제됩니다.",
    "Auto Shot fired": "자동 사격 발사됨",
    "Auto-switch in %s": "%s에서 자동 전환",
    "Automatic — game language": "자동 — 게임 언어",

    # 100..129
    "Automatically switch to %s whenever this character is in this specialization.": "이 캐릭터가 해당 전문화 상태일 때마다 %s(으)로 자동 전환합니다.",
    "Battleground queue ready": "전장 대기열 준비됨",
    "Bed strength": "바탕 진동 강도",
    "Bends the relationship between what a cue asks for and what the motor is told. Below 1.0 makes quiet cues louder; above 1.0 makes them quieter and reserves more of the range for strong ones. 1.0 is the unbent default.": "신호가 요청하는 출력과 모터에 전달되는 출력 간의 관계 곡선을 조절합니다. 1.0 미만은 미세한 신호를 더 강하게 만들고, 1.0 초과는 신호를 더 조용하게 만들어 강한 신호에 더 넓은 범위를 할당합니다. 기본 곡선값은 1.0입니다.",
    "Boss ability warning": "우두머리 능력 경고",
    "Boss chat warning": "우두머리 대화 경고",
    "Boss encounter ended": "우두머리 전투 종료됨",
    "Boss encounter started": "우두머리 전투 시작됨",
    "Breakaway floor": "시동 임계값",
    "Builds from a low hum into a high pulse.": "낮은 웅 소리에서 높은 펄스로 점점 고조됩니다.",
    "CLICK %s:LeftButton": "CLICK %s:LeftButton",
    "Cancel": "취소",
    "Cast outcomes": "시전 결과",
    "Cast presence (low)": "시전 지속감 (저주파)",
    "Cast sent": "시전 전송됨",
    "Cast swell peak (high)": "시전 고조 정점 (고주파)",
    "Cast texture, cast finish confirmation, lockout/pushback warnings, proc glows, kick alerts": "시전 질감, 시전 완료 확인, 시전 방해/밀림 경고, 발동 효과 강조, 차단 알림",
    "Casting": "주문 시전",
    "Casting texture": "시전 질감",
    "Change threshold": "변경 임계값",
    "Character & Status": "캐릭터 및 상태",
    "Character state": "캐릭터 상태",
    "Checked via C_UnitAuras.AuraIsBigDefensive. Occurrence only.": "C_UnitAuras.AuraIsBigDefensive를 통해 확인합니다. 발생 시에만 1회 출력됩니다.",
    "Choose the addon display language. Automatic follows the game client. Missing translations use English. Changes apply after /reload.": "애드온 표시 언어를 선택합니다. 자동 설정 시 게임 클라이언트 언어를 따릅니다. 번역이 없는 항목은 영어를 사용합니다. 변경 사항은 /reload 후 적용됩니다.",
    "Click to open settings": "클릭하여 설정 열기",
    "Climbs this motor slowly from silence to %d%% power over %d seconds, ": "정지 상태에서 %d%% 출력까지 %d초에 걸쳐 이 모터의 출력을 서서히 상승시키며, ",
    "Close": "닫기",
    "Combo point gained": "연계 점수 획득",
    "Companion tools": "동반 도구",
    "Competitive & Baseline": "경쟁 및 기본 설정",

    # 130..159
    "Configure tactile rewards for exploring Azeroth and sensory spatial awareness for targeting.": "아제로스 탐험을 위한 촉각적 보상과 대상 지정을 위한 감각적 공간 인식을 설정합니다.",
    "Confirmation popup appeared": "확인 팝업창 나타남",
    "Confirmation popup closed": "확인 팝업창 닫힘",
    "Confused or possessed": "혼란 또는 지배됨",
    "Conversation & reading": "대화 및 읽기",
    "Copy": "복사",
    "Copy \"%s\" to a new custom profile named:": "\"%s\"을(를) 다음 이름의 새 사용자 지정 프로필로 복사:",
    "Copy \"%s\" to a new profile named:": "\"%s\"을(를) 다음 이름의 새 프로필로 복사:",
    "Copy this profile": "이 프로필 복사",
    "Copy...": "복사...",
    "Create": "생성",
    "Create a new editable custom profile that starts as an exact copy of %s.": "%s의 사본으로 시작하는 편집 가능한 새 사용자 지정 프로필을 생성합니다.",
    "Create a new profile from Registry.lua's stock defaults and switch to it.": "Registry.lua의 기본 설정을 바탕으로 새 프로필을 생성하고 해당 프로필로 전환합니다.",
    "Create a new profile that starts as an exact copy of the one in use, and switch to it. The two are independent from the first edit.": "현재 사용 중인 프로필의 사본으로 새 프로필을 생성하고 해당 프로필로 전환합니다. 첫 편집 시점부터 두 프로필은 독립적으로 동작합니다.",
    "Create editable copy": "편집 가능한 사본 생성",
    "Create...": "생성...",
    "Crest froth & spray": "파도 거품 및 물보라",
    "Cue index": "신호 색인",
    "Danger start threshold": "위험 시작 임계값",
    "Death Knight": "죽음의 기사",
    "Debuff received": "약화 효과 받음",
    "Debug logging": "디버그 로깅",
    "Default": "기본값",
    "Default (Balanced Baseline)": "기본값 (균형 잡힌 표준)",
    "Default profiles": "기본 프로필",
    "Defensive": "방어 생존기",
    "Delete": "삭제",
    "Delete profile \"%s\"? This can't be undone.": "\"%s\" 프로필을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.",
    "Delete this profile": "이 프로필 삭제",
    "Delete...": "삭제...",

    # 160..189
    "Device": "장치",
    "Disable All": "모두 비활성화",
    "Disable all cues": "모든 신호 비활성화",
    "Disable all cues in profile": "프로필 내 모든 신호 비활성화",
    "Disable every vibration cue in the active profile in one sweep for quiet testing or building a profile from scratch.": "조용한 환경에서 테스트하거나 프로필을 처음부터 새로 구성하기 위해 활성 프로필의 모든 진동 신호를 한 번에 비활성화합니다.",
    "Disarmed": "무장 해제됨",
    "Displays a shortcut button on the edge of your minimap for quick access to settings and toggling vibration.": "미니맵 가장자리에 바로가기 버튼을 표시하여 설정에 빠르게 접근하고 진동을 켜고 끌 수 있도록 합니다.",
    "Distinctiveness": "구분감",
    "Distinguished from cancelling by Blizzard's own `isCancelled` flag, which it sets before ending the selection — so a cancel never counts as a choice.": "선택을 종료하기 전에 블리자드의 자체 `isCancelled` 플래그를 통해 취소 여부를 구분하므로 취소한 동작이 선택으로 간주되지 않습니다.",
    "Doubles as the catch-all: a loss-of-control type this addon does not recognise — a new one added by a patch — fires this generic cue instead of being silently dropped.": "포괄적 대체 기능도 겸합니다. 패치로 추가되는 등 애드온이 인식하지 못하는 제어 불가 유형이 발생하면 무시되지 않고 이 일반 신호가 대신 출력됩니다.",
    "Druid": "드루이드",
    "Dual asymmetrical ERM motors, balanced 75ms spin-up": "듀얼 비대칭 ERM 모터, 균형 잡힌 75ms 회전 도달 시간",
    "Dual-motor rumble & vibration schemas": "듀얼 모터 진동 스키마",
    "Duel request": "결투 신청",
    "Dungeon queue popped": "던전 입장 알림 (큐 열림)",
    "Dungeon: Caster": "던전: 시전자",
    "Dungeon: Caster DPS": "던전: 원거리 공격 담당",
    "Dungeon: Healer": "던전: 치유 담당",
    "Dungeon: Hunter": "던전: 사냥꾼",
    "Dungeon: Melee": "던전: 근접",
    "Dungeon: Melee DPS": "던전: 근접 공격 담당",
    "Dungeon: Tank": "던전: 방어 담당",
    "Effort peak": "추진력 정점 강도",
    "Empowered cast stage": "강화 주문 단계",
    "Enable All": "모두 활성화",
    "Enable Cue": "신호 활성화",
    "Enable Pulse": "Pulse 활성화",
    "Enable all cues": "모든 신호 활성화",
    "Enable all cues in profile": "프로필 내 모든 신호 활성화",
    "Enable every vibration cue in the active profile in one sweep for testing and debugging.": "테스트 및 디버깅을 위해 활성 프로필의 모든 진동 신호를 한 번에 활성화합니다.",

    # 190..219
    "Encounter": "우두머리 전투",
    "Entered a vehicle": "차량/탈것 탑승함",
    "Entered melee range": "근접 사정거리 진입",
    "Environment": "환경",
    "Equipment": "장비",
    "Every character": "모든 캐릭터",
    "Evoker-only in practice. It stays registered for every class and simply never fires for the others.": "실제로는 기원사 전용입니다. 모든 직업에 등록된 상태로 유지되지만 다른 직업에서는 발동하지 않습니다.",
    "Experience gained": "경험치 획득",
    "Experimental": "실험실 기능",
    "Fast attack time constant used specifically for discrete impacts, clicks, and strikes. Gives snappy transients without making sustained immersion textures harsh.": "개별 충격, 클릭, 타격에 특별히 사용되는 빠른 어택 시상수입니다. 지속적인 몰입 질감을 거칠게 만들지 않으면서도 산뜻한 순간 반응을 제공합니다.",
    "Feared or charmed": "공포 또는 매혹됨",
    "Feel ": "느껴보기: ",
    "Feel Strength": "진동 체감 강도",
    "Feel this texture": "이 진동 질감 느껴보기",
    "Feels like": "체감 느낌",
    "Feels like: ": "체감 느낌: ",
    "Find breakaway floor": "시동 임계값 찾기",
    "Fires as an empowered cast of yours begins and ends.": "자신의 강화 주문 시전이 시작되고 끝날 때 발동합니다.",
    "Fires at most ": "최대 ",
    "Fires for any summon confirmation dialog, not only a player summoning you.": "플레이어가 소환하는 경우뿐만 아니라 모든 소환 확인 대화 상자에서 발동합니다.",
    "Fires on PLAYER_TARGET_DIED.": "PLAYER_TARGET_DIED 이벤트 발생 시 발동합니다.",
    "Fires on input, so it also fires for casts that then fail. That is intentional: this is an input-acknowledgement cue, not a success cue.": "입력 즉시 발동하므로 이후 실패하는 시전에도 발동합니다. 이는 의도된 동작으로, 시전 성공 신호가 아니라 입력 확인 신호입니다.",
    "Fires on the change itself, not on every flag update.": "모든 플래그 업데이트마다가 아니라 실제 변경 시에만 발동합니다.",
    "Fires on the crossing into low, not repeatedly while low.": "낮은 상태가 지속되는 동안 반복되지 않고, 낮음 상태로 전환되는 순간에만 발동합니다.",
    "Fires on the yellow informational messages the game shows in the top centre of the screen.": "게임 화면 상단 중앙에 표시되는 노란색 안내 메시지 출력 시 발동합니다.",
    "Fires only when a queue enters the ready-to-enter state, not on every status update.": "모든 상태 업데이트마다가 아니라 대기열이 입장 가능 상태가 되었을 때만 발동합니다.",
    "Fires the instant you press a cast, before the server has confirmed it.": "서버가 확인하기 전, 시전 키를 누르는 즉시 발동합니다.",
    "Fires upon arrival at destination when player control is restored.": "목적지에 도착하여 플레이어 제어권이 복원될 때 발동합니다.",
    "Fires when a battleground or arena queue is ready to enter.": "전장 또는 투기장 대기열의 입장이 준비되었을 때 발동합니다.",
    "Fires when a boss encounter begins.": "우두머리 전투가 시작될 때 발동합니다.",

    # 220..249
    "Fires when a boss encounter ends, in victory or in a wipe.": "승리 또는 전멸로 우두머리 전투가 끝날 때 발동합니다.",
    "Fires when a flight master's map opens.": "비행 조련사의 지도가 열릴 때 발동합니다.",
    "Fires when a loading screen ends and the world is back.": "로딩 화면이 끝나고 게임 세계로 돌아왔을 때 발동합니다.",
    "Fires when a quest is handed in and its reward is taken.": "퀘스트를 완료하고 보상을 수령할 때 발동합니다.",
    "Fires when a quest's completion page opens, ready to hand in.": "완료 가능한 퀘스트 완료 창이 열릴 때 발동합니다.",
    "Fires when a quest's detail page opens, ready to accept.": "수락 가능한 퀘스트 세부 창이 열릴 때 발동합니다.",
    "Fires when a ready check completes or times out.": "전투 준비 확인이 완료되거나 시간 초과되었을 때 발동합니다.",
    "Fires when a ready check starts.": "전투 준비 확인이 시작될 때 발동합니다.",
    "Fires when a role check starts.": "역할 확인이 시작될 때 발동합니다.",
    "Fires when a trade window opens.": "거래 창이 열릴 때 발동합니다.",
    "Fires when a vendor window opens.": "상인 창이 열릴 때 발동합니다.",
    "Fires when an innkeeper asks to make this your home.": "여관주인이 귀환 지점으로 지정할 것인지 물어볼 때 발동합니다.",
    "Fires when gaining money with an open vendor window.": "상인 창이 열린 상태에서 돈을 획득할 때 발동합니다.",
    "Fires when group leadership changes hands.": "파티장/공격대장이 변경될 때 발동합니다.",
    "Fires when one of your own casts begins.": "자신의 주문 시전이 시작될 때 발동합니다.",
    "Fires when one of your own casts completes successfully — distinct from a cast simply ending.": "단순한 시전 종료와 달리, 자신의 주문 시전이 성공적으로 완료될 때 발동합니다.",
    "Fires when one of your own casts ends, whether or not it completed.": "완료 여부와 상관없이 자신의 주문 시전이 끝날 때 발동합니다.",
    "Fires when someone challenges you to a duel.": "누군가 결투를 신청할 때 발동합니다.",
    "Fires when someone invites you to a group.": "누군가 파티에 초대할 때 발동합니다.",
    "Fires when someone joins or leaves your group.": "누군가 파티에 참가하거나 탈퇴할 때 발동합니다.",
    "Fires when someone offers you a resurrection and the accept dialog appears.": "누군가 부활을 제안하여 수락 대화 상자가 표시될 때 발동합니다.",
    "Fires when someone summons you and the accept dialog appears.": "누군가 소환을 시도하여 수락 대화 상자가 표시될 때 발동합니다.",
    "Fires when spending money with an open vendor window.": "상인 창이 열린 상태에서 돈을 지출할 때 발동합니다.",
    "Fires when the stable master's window opens.": "야수 관리인 창이 열릴 때 발동합니다.",
    "Fires when you accept a quest.": "퀘스트를 수락할 때 발동합니다.",
    "Fires when you are confused or possessed (CONFUSE, POSSESS).": "혼란 또는 지배 상태가 되었을 때 발동합니다(CONFUSE, POSSESS).",
    "Fires when you are disarmed (DISARM).": "무장 해제 상태가 되었을 때 발동합니다(DISARM).",
    "Fires when you are feared or charmed (FEAR, FEAR_MECHANIC, CHARM).": "공포 또는 매혹 상태가 되었을 때 발동합니다(FEAR, FEAR_MECHANIC, CHARM).",
    "Fires when you are resurrected or leave ghost form.": "부활하거나 유령 상태에서 벗어날 때 발동합니다.",
    "Fires when you are rooted in place (ROOT). You can still act, so this is a rung below the cues that stop you entirely.": "이동 불가(ROOT) 상태가 되었을 때 발동합니다. 여전히 행동할 수는 있으므로 완전히 무력화하는 신호보다는 한 단계 낮은 강도입니다.",

    # 250..279
    "Fires when you are silenced (SILENCE).": "침묵 상태가 되었을 때 발동합니다(SILENCE).",
    "Fires when you are stunned (STUN, STUN_MECHANIC).": "기절 상태가 되었을 때 발동합니다(STUN, STUN_MECHANIC).",
    "Fires when you change target, including when you clear it.": "대상을 취소하는 경우를 포함하여 대상을 변경할 때 발동합니다.",
    "Fires when you die.": "사망했을 때 발동합니다.",
    "Fires when you enter a new zone.": "새로운 지역에 진입할 때 발동합니다.",
    "Fires when you enter a vehicle and your action bar is replaced.": "차량/탈것에 탑승하여 행동 단축바가 교체될 때 발동합니다.",
    "Fires when you leave a vehicle and your own action bar returns.": "차량/탈것에서 내려 기존 행동 단축바로 복귀할 때 발동합니다.",
    "Fires when you set or clear your focus target.": "주시 대상을 설정하거나 해제할 때 발동합니다.",
    "Fires when your class's secondary resource fills up — combo points, holy power, soul shards, chi, arcane charges, essence or runes, whichever your specialisation uses.": "직업의 보조 자원이 가득 찼을 때 발동합니다(전문화에 따른 연계 점수, 신성한 힘, 영혼의 조각, 기, 비전 충전물, 정수 또는 룬).",
    "Fires when your focus target begins casting.": "주시 대상이 주문 시전을 시작할 때 발동합니다.",
    "Fires when your own away or do-not-disturb flag actually changes.": "자리 비움 또는 다른 용무 중 상태가 실제로 변경될 때 발동합니다.",
    "Flight map opened": "비행 지도 열림",
    "Focus": "주시 대상",
    "Focus changed": "주시 대상 변경됨",
    "Focus started casting": "주시 대상 시전 시작함",
    "Focused element became unavailable": "포커스된 요소를 사용할 수 없게 됨",
    "Four rapid, sharp ticks.": "빠르고 날카로운 4회 틱 진동입니다.",
    "Gait strength": "걸음걸이 진동 강도",
    "Gasp peak": "숨가쁨 정점 강도",
    "Gear needs repair": "장비 수리 필요",
    "Generic / Unknown": "일반 / 알 수 없음",
    "Generic / unknown": "일반 / 알 수 없음",
    "Gentle steady engine-like cruise vibration while riding flight master gryphons, bats, or wyverns.": "비행 조련사의 그리핀, 박쥐, 와이번 탑승 시 부드럽고 안정적으로 유지되는 순항 진동입니다.",
    "Group changes": "파티 변경",
    "Group readiness": "파티 준비 상태",
    "Group roster changed": "파티/공격대원 목록 변경됨",
    "Group targeting active": "파티원 대상 지정 활성",
    "Group targeting released": "파티원 대상 지정 해제",
    "Hardware & Presets": "하드웨어 및 프리셋",
    "Harvest complete": "채집 완료",

    # 280..309
    "Heal casts and low-health triage": "치유 시전 및 생명력 위급 상황 관리",
    "Healing received": "치유 받음",
    "Health & survival": "생명력 및 생존",
    "Heart rate (BPM)": "심박수 (BPM)",
    "Heart rate (calm), BPM": "심박수 (안정 시), BPM",
    "Heavy Impacts": "묵직한 충격",
    "Heavy left counterweight (85ms), light right counterweight (45ms)": "무거운 좌측 편심 모터(85ms), 가벼운 우측 편심 모터(45ms)",
    "High Motor Only": "고주파 모터 전용",
    "High motor": "고주파 모터",
    "Hooks StackSplitFrame:UpdateStackText.": "StackSplitFrame:UpdateStackText를 후킹합니다.",
    "How far the hum swells either side of its baseline. 0 is a flat hold.": "기준선 대비 웅 소리가 양쪽으로 얼마나 부풀어 오르는지 조절합니다. 0은 변동 없는 지속입니다.",
    "How fast the wingbeat-style undulation cycles.": "날갯짓 형태의 파동이 얼마나 빠르게 반복되는지 조절합니다.",
    "How many seconds before the scripted moment this fires.": "스크립트 이벤트 발생 몇 초 전에 이 신호가 울릴지 설정합니다.",
    "How pronounced each stroke is against its own baseline. Higher values (0.80-1.0) allow the counterweight to physically spin down during the glide phase between strokes. 0 is a flat drag with no rhythm at all.": "각 스트로크가 기준 진동 대비 얼마나 뚜렷하게 강조되는지 조절합니다. 높은 값(0.80-1.0)은 스트로크 사이의 활공 단계에서 편심 모터가 물리적으로 감속할 수 있도록 합니다. 0은 리듬이 전혀 없는 단조로운 저항감입니다.",
    "How steady the low motor stays regardless of speed. Only audible while actually gliding.": "속도와 관계없이 저주파 모터가 얼마나 안정적으로 유지되는지 조절합니다. 실제로 활공 중일 때만 체감할 수 있습니다.",
    "How strong the hum gets by the moment a regular cast completes. Only audible if \"Casting texture\" is also enabled on its own tab.": "일반 주문 시전이 완료되는 순간 웅 소리가 얼마나 강해지는지 조절합니다. 해당 탭에서 \"시전 질감\"이 활성화되어 있어야만 체감할 수 있습니다.",
    "Hunter": "사냥꾼",
    "If nothing is happening": "아무런 상황도 발생하지 않을 때",
    "Immediately switch to %s for the current character.": "현재 캐릭터의 설정을 즉시 %s(으)로 전환합니다.",
    "Immersion: Caster": "몰입: 시전자",
    "Immersion: Melee": "몰입: 근접",
    "Immersion: Ranged": "몰입: 원거리",
    "Impact attack (s)": "충격 어택 시간 (s)",
    "Initial software voltage boost applied during transient onset to accelerate the motor rapidly to target speed. 1.0 is disabled.": "모터를 목표 속도까지 빠르게 가속하기 위해 과도 응답 시작 시 적용되는 소프트웨어 초기 전압 부스트입니다. 1.0은 비활성화 상태입니다.",
    "Innkeeper hearth prompt": "여관주인 귀환지 지정 확인",
    "Input device changed": "입력 장치 변경됨",
    "Input mode": "입력 모드",
    "Instant ability used": "즉시 시전 능력 사용됨",
    "Intensity": "강도",
    "Intensity Slider": "강도 슬라이더",

    # 310..329
    "Interface": "인터페이스",
    "Interface & Accessibility": "인터페이스 및 접근성",
    "Interface message": "인터페이스 메시지",
    "Interface tab changed": "인터페이스 탭 변경됨",
    "Inventory full warning": "소지품 가득 참 경고",
    "Invites & requests": "초대 및 요청",
    "Jarring physical weapon clatter": "날카롭고 덜컥거리는 무기 부딪힘",
    "LRA (Classic ERM Emulation)": "LRA (클래식 ERM 에뮬레이션)",
    "Landed": "착지함",
    "Leave this scope with no opinion and let the next one decide.": "이 범위에서는 설정을 지정하지 않고 다음 우선순위에서 결정하도록 합니다.",
    "Left a vehicle": "차량/탈것에서 내림",
    "Left melee range": "근접 사정거리 벗어남",
    "Level up": "레벨 상승",
    "Lifecycle (advanced)": "수명 주기 (고급)",
    "Load its starting values": "초기값 불러오기",
    "Loading screen finished": "로딩 화면 완료됨",
    "Loss of control": "제어 불가",
    "Loss of control cues": "제어 불가 신호",
    "Low Health Heartbeat": "생명력 위험 심장 박동",
    "Low Motor Only": "저주파 모터 전용",
}

def main():
    batch_path = "/home/deck/developer/wow/PulseSensation/localization/batches/batch1a_ui_navigation.json"
    with open(batch_path, "r", encoding="utf-8") as f:
        batch_data = json.load(f)

    items = batch_data.get("items", [])
    print(f"Total source items to process: {len(items)}")

    errors = 0
    translated_items = []

    for idx, item in enumerate(items):
        src = item["source"]
        if src not in TRANSLATIONS_KO:
            print(f"ERROR: Missing translation for item [{idx}]: {repr(src)}")
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

    out_path = "/home/deck/developer/wow/PulseSensation/localization/batches/translated_koKR_batch1a.json"
    out_data = {
        "items": translated_items
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out_data, f, indent=2, ensure_ascii=False)

    print(f"SUCCESS: Wrote {len(translated_items)} validated translations to {out_path}")

if __name__ == "__main__":
    main()
