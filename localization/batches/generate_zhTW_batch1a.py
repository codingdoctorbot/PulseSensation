#!/usr/bin/env python3
"""
Generates and validates translated_zhTW_batch1a.json for PulseHaptics Traditional Chinese (Taiwan zhTW) localization.
"""

import json
import os
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "tools"))
from validate_catalog import extract_signature, check_color_balance

TRANSLATIONS_ZH_TW = {
    # 0..17
    " (page off)|r": " (頁面已關閉)|r",
    " (reported as \"": " (辨識為 \"",
    " Rules and management are on the Profiles page.": " 規則與管理請見設定檔頁面。",
    " as a whole — both its pulses and the gaps between them, so a multi-hit mode keeps its rhythm instead of the hits stretching into their own gaps. 1.0 is the authored default.": " 作為一個整體——包含其脈衝以及脈衝之間的間隔，使多重打擊模式保持其固有節奏，而不是讓打擊延伸進入其自身的間隔中。1.0 為預設設計值。",
    " right now with whatever's currently set on its sliders above.": " 立即以其上方滑桿的目前設定播放。",
    "\" is recommended — pick a different one to change how just this cue feels, without affecting anything else that also uses \"": "\" 為推薦設定——選擇其他模式可以僅改變此提示的震感，而不會影響其他同樣使用 \"",
    "\" — try one of: ": "\" —— 推薦嘗試：",
    "%d of %d cues on": "%d / %d 個提示已開啟",
    "%d of %d on": "%d / %d 個已開啟",
    "%s (%d)": "%s (%d)",
    "%s Activate   •   %s Try Texture   •   %s Categories": "%s 啟用   •   %s 測試震感   •   %s 分類",
    "%s Adjust Intensity   •   %s Quick Step   •   |cff38BDF8◀/▶|r Controls   •   %s Try Texture   •   %s Categories": "%s 調整強度   •   %s 快速步進   •   |cff38BDF8◀/▶|r 控制項   •   %s 測試震感   •   %s 分類",
    "%s Browse Modes   •   %s Select   •   %s Cancel": "%s 瀏覽模式   •   %s 選取   •   %s 取消",
    "%s Select Mode   •   |cff38BDF8◀/▶|r Controls   •   %s Try Texture   •   %s Categories": "%s 選取模式   •   |cff38BDF8◀/▶|r 控制項   •   %s 測試震感   •   %s 分類",
    "%s Switch Category   •   %s Navigate   •   %s Select   •   %s Close": "%s 切換分類   •   %s 導覽   •   %s 選取   •   %s 關閉",
    "%s Toggle   •   |cff38BDF8▶|r Next Control   •   %s Try Texture   •   %s Categories": "%s 切換   •   |cff38BDF8▶|r 下一個控制項   •   %s 測試震感   •   %s 分類",
    "%s is felt as %s struck about %.1f times a second, over the bed.": "%s 的震感如同 %s 在持續底震之上每秒敲擊約 %.1f 次。",
    "%s/%s Try Texture   •   |cff38BDF8◀|r Controls   •   %s Categories": "%s/%s 測試震感   •   |cff38BDF8◀|r 控制項   •   %s 分類",

    # 18..32
    "(Toggles all continuous sensations)": "(切換所有持續震感)",
    ", heartbeat, warningbeat": ", heartbeat, warningbeat",
    ", not ": ", 而非 ",
    ", so there is nothing to test.": ", 因此無可測試內容。",
    "0 = one soft pulse. 1 = a sharp lub, then a clearly separate softer dub. Derives the knock timing and intensity split automatically — see lowHealthTexture if you want those set by hand instead.": "0 = 單次柔和脈衝。1 = 清脆的 lub 音，接著明顯區分的柔和 dub 音。自動計算敲擊時間間隔與強度分配——若想手動設定，請參閱 lowHealthTexture。",
    "1 = every scripted event, 3 = only the most severe. Higher means rarer, more significant warnings.": "1 = 所有腳本事件，3 = 僅最嚴重的事件。數值越高表示警報越罕見且越關鍵。",
    "3. World": "3. 世界",
    "4. Interface": "4. 介面",
    "5. Immersion": "5. 沉浸",
    "6. Finish": "6. 完成",
    "< Back": "< 返回",
    "A bright tick when you learn a new ability.": "學會新技能時，產生清脆的提示震動。",
    "A crisp mechanical snap on the high motor.": "輕震馬達上清脆的機械敲擊震動。",
    "A dense 3-pulse tactical flurry.": "密集的三連發戰術疾風微震。",
    "A dry click when you use an ability that has no cast time.": "使用瞬發技能時，產生乾脆的輕按震動。",

    # 33..65
    "A heavy, decisive impact when your current target dies.": "目前目標死亡時，產生沉重且具果斷感的撞擊震動。",
    "A light click when a major UI panel is dismissed.": "關閉主要介面面板時，產生輕微的點擊震動。",
    "A light click when the last confirmation dialog closes.": "關閉最後一個確認對話框時，產生輕微的點擊震動。",
    "A light tick when you step away from an NPC or close its window.": "離開 NPC 或關閉其視窗時，產生輕微的提示震動。",
    "A ringing anvil strike when repairing armor and weapons at a vendor.": "在商人處修理護甲與武器時，產生鐵砧敲擊的清脆鳴響震動。",
    "A rising celebratory surge when you gain a level.": "提升等級時，產生逐漸增強的慶祝躍動震感。",
    "A sharp alert pulse when your hostile target or focus turns to target you.": "敵對目標或專注目標轉向以你為目標時，產生尖銳的警報脈衝。",
    "A sharp deflection tick when a cast of yours is rejected outright — out of range, not facing the target, still on cooldown.": "你的施法被直接拒絕時（超出範圍、未面對目標、仍在冷卻中），產生清脆的偏斜提示震動。",
    "A sharp deflection tick when the game refuses an action — out of range, facing the wrong way, not enough resource, still on cooldown.": "遊戲拒絕某個動作時（超出範圍、朝向錯誤、資源不足、仍在冷卻中），產生清脆的偏斜提示震動。",
    "A sharp snap when a harmful effect lands on you.": "受到有害效果影響時，產生清脆的抽擊震動。",
    "A sharp snap with a short tail.": "帶有短尾音的清脆抽擊震動。",
    "A short warning before a significant scripted boss ability, using Blizzard's own built-in Boss Warnings timeline.": "在重大首領腳本技能施放前發出簡短預警，使用暴雪原生的內建首領預警時間線。",
    "A short, sharp tick instead of the normal one when the segment you land on can't be used.": "當停頓的扇區無法使用時，以簡短俐落的提示震動取代一般震動。",
    "A single dry click, lighter than a tick.": "單次乾脆的點擊震動，比輕觸提示更微弱。",
    "A single very short, very hard hit.": "單次極短促、極其強烈的衝擊。",
    "A slow low/high oscillation — the caller supplies the phase.": "緩慢的重震／輕震交替振盪——由呼叫端提供相位。",
    "A soft tick followed by a brighter one.": "一次輕微的提示震動，隨後伴隨一次更清脆的提示震動。",
    "A soft tick when releasing the group targeting modifier back to normal navigation.": "放開隊伍目標組合鍵恢復正常導覽時，產生柔和的輕微提示震動。",
    "A soft tick when you cancel a radial selection instead of committing to it.": "取消環形選單選取而非確認時，產生柔和的輕微提示震動。",
    "A soft tick when you start auto-attacking with a ranged weapon (Auto Shot, Shoot, wands).": "使用遠程武器開始自動攻擊（自動射擊、射擊、魔杖）時，產生柔和的輕微提示震動。",
    "A soft tick when you start meleeing.": "開始近戰自動攻擊時，產生柔和的輕微提示震動。",
    "A soft tick when you start resting in an inn or major city.": "在旅店或主城進入休息狀態時，產生柔和的輕微提示震動。",
    "A soft tick when your melee auto-attack stops — catches walking out of range or a target dying without noticing.": "近戰自動攻擊停止時產生柔和的輕微提示震動——用於提示走出近戰範圍或未察覺的目標死亡。",
    "A soft, quick tick.": "柔和短促的輕微提示震動。",
    "A steady, low ambient texture.": "平穩的低頻環境氛圍震感。",
    "A steady, stronger texture — meant to be scaled by the caller (e.g. speed).": "平穩且更強烈的震感——供呼叫端縮放調節（例如根據速度）。",
    "A tactile micro-tick each time the stack splitter quantity slider changes.": "堆疊拆分數量滑桿每次變更時，產生細微的觸感提示震動。",
    "A tactile recoil kick on every Auto Shot arrow, timed to the real shot, not estimated.": "每次自動射擊箭矢射出時產生真實的後座力衝擊，精確同步於實際射擊時刻，而非估算。",
    "A tap when a confirmation dialog opens.": "確認對話框彈出時產生輕觸震動。",
    "A tap when an NPC or world object opens a window nothing else here covers.": "NPC 或世界物件開啟未被此處涵蓋的視窗時產生輕觸震動。",
    "A texture that builds as your gliding speed climbs toward a boost.": "隨著滑翔速度提升接近加速時逐漸增強的震感。",
    "A tick when a book, plaque, gravestone or signpost opens to be read.": "開啟書籍、牌匾、墓碑或路標閱讀時產生輕微提示震動。",
    "A tick when a piece of your gear's durability drops into the low or broken range.": "某件裝備的耐久度降至過低或損壞區間時產生輕微提示震動。",

    # 66..99
    "A tiny blip when you gain experience.": "獲得經驗值時產生微弱短促的提示震動。",
    "A tiny low blip, for things that happen often.": "適用於頻繁發生事件的微弱低頻輕顫。",
    "A triumphant dual-tone chime when you earn an achievement.": "獲得成就時產生凱旋的雙音調清鳴震動。",
    "A very light micro-pulse.": "極輕微的微脈衝震動。",
    "A very light tick per combo point, building toward a full resource.": "每個連擊點數產生極輕微的提示震動，向滿資源遞增。",
    "A very light tick when your equipped gear changes.": "已裝備的裝備發生變更時產生極輕微的提示震動。",
    "A very short, sharp tick when you avoid an incoming attack.": "避開敵人攻擊（閃躲／招架／未命中）時產生極短促清脆的提示震動。",
    "AFK or DND toggled": "暫離或請勿打擾狀態切換",
    "Ability pulse": "技能脈衝",
    "Achievement earned": "獲得成就",
    "Action bar page changed": "快捷列分頁已切換",
    "Action bars": "快捷列",
    "Action failed": "動作失敗",
    "Action feedback": "動作回饋",
    "Activate": "啟用",
    "Active Profile: |cffffd100%s|r": "使用中設定檔：|cffffd100%s|r",
    "Active profile": "使用中設定檔",
    "Actuator profile: %s\n%s": "致動器設定檔：%s\n%s",
    "Addon language": "插件語言",
    "Adjust your global master vibration strength. Individual cues can always be fine-tuned in settings.": "調節全域主震動強度。個別提示的強度隨時可以在設定中進行微調。",
    "Advanced Settings": "進階設定",
    "Also fires when you cancel a cast yourself, or move out of range — it means \"your cast did not finish\", not specifically \"you were kicked\".": "當你自行取消施法或移出範圍時也會觸發——它的意義是「你的施法未能完成」，而非特指「你被斷法」。",
    "Also fires when you switch to a target that is already mid-cast.": "切換至正在施法中的目標時也會觸發。",
    "Alternates between the motors — an unsteady, rolling feel.": "在不同馬達之間交替——營造不穩定、翻滾的體感。",
    "Alternating low thud and high snap across motors.": "在馬達間交替出現低頻重擊與高頻抽擊。",
    "Any other window": "任何其他視窗",
    "Anything else": "其他任何內容",
    "Applies only while this character is in this specialization. Switching specialization switches profile with it, with no further action from you.": "僅當此角色處於該專精時生效。切換專精將自動隨之切換設定檔，無需任何額外操作。",
    "Applies to this character whatever specialization it is in. This is the rule the profile picker on the Pulse page has always written to.": "無論該角色處於何種專精均生效。這是 Pulse 頁面上的設定檔選擇器一直以來寫入的規則。",
    "Attack time (s)": "起振時間 (秒)",
    "Attentive triage. Emergency low health warnings, dispel/CC alerts, kick warnings, and heal completion confirmation with subdued personal damage.": "專注救急支援。緊急低生命值預警、驅散／控場警報、斷法警報以及治療完成確認，同時降低自身承受傷害的提示干擾。",
    "Auto Shot fired": "自動射擊已發射",
    "Auto-switch in %s": "在 %s 中自動切換",
    "Automatic — game language": "自動 — 遊戲語言",

    # 100..132
    "Automatically switch to %s whenever this character is in this specialization.": "每當該角色處於此專精時，自動切換至 %s。",
    "Battleground queue ready": "戰場排隊就緒",
    "Bed strength": "底震強度",
    "Bends the relationship between what a cue asks for and what the motor is told. Below 1.0 makes quiet cues louder; above 1.0 makes them quieter and reserves more of the range for strong ones. 1.0 is the unbent default.": "調節提示請求強度與馬達實際輸出之間的反應曲線。低於 1.0 會放大微弱提示；高於 1.0 會削弱微弱提示並將更多動態範圍保留給強烈衝擊。1.0 為未經調節的預設值。",
    "Boss ability warning": "首領技能預警",
    "Boss chat warning": "首領喊話預警",
    "Boss encounter ended": "首領戰結束",
    "Boss encounter started": "首領戰開始",
    "Breakaway floor": "起轉門檻",
    "Builds from a low hum into a high pulse.": "從低頻嗡鳴逐漸增強為高頻脈衝。",
    "CLICK %s:LeftButton": "CLICK %s:LeftButton",
    "Cancel": "取消",
    "Cast outcomes": "施法結果",
    "Cast presence (low)": "施法常駐感 (低頻)",
    "Cast sent": "施法請求已發送",
    "Cast swell peak (high)": "施法漸強峰值 (高頻)",
    "Cast texture, cast finish confirmation, lockout/pushback warnings, proc glows, kick alerts": "施法質感、施法完成確認、反制／推遲施法預警、觸發發光、斷法警報",
    "Casting": "正在施法",
    "Casting texture": "施法質感",
    "Change threshold": "變更門檻",
    "Character & Status": "角色與狀態",
    "Character state": "角色狀態",
    "Checked via C_UnitAuras.AuraIsBigDefensive. Occurrence only.": "透過 C_UnitAuras.AuraIsBigDefensive 檢查。僅在發生時觸發。",
    "Choose the addon display language. Automatic follows the game client. Missing translations use English. Changes apply after /reload.": "選擇插件顯示語言。「自動」將跟隨遊戲客戶端語言。缺失的在地化文字將退回顯示為英文。變更在重載介面 (/reload) 後生效。",
    "Click to open settings": "點擊以開啟設定",
    "Climbs this motor slowly from silence to %d%% power over %d seconds, ": "使該馬達從靜音緩慢攀升至 %d%% 功率，歷時 %d 秒，",
    "Close": "關閉",
    "Combo point gained": "獲得連擊點數",
    "Companion tools": "配套工具",
    "Competitive & Baseline": "競技與基礎",
    "Configure tactile rewards for exploring Azeroth and sensory spatial awareness for targeting.": "設定探索艾澤拉斯的觸覺回饋，以及用於選取目標的空間感知震動。",
    "Confirmation popup appeared": "確認彈出視窗出現",
    "Confirmation popup closed": "確認彈出視窗關閉",

    # 133..165
    "Confused or possessed": "迷惑或被心控",
    "Conversation & reading": "對話與閱讀",
    "Copy": "複製",
    "Copy \"%s\" to a new custom profile named:": "將「%s」複製為新的自訂設定檔，命名為：",
    "Copy \"%s\" to a new profile named:": "將「%s」複製為新的設定檔，命名為：",
    "Copy this profile": "複製此設定檔",
    "Copy...": "複製...",
    "Create": "建立",
    "Create a new editable custom profile that starts as an exact copy of %s.": "建立一個新的可編輯自訂設定檔，初始內容為 %s 的完整複本。",
    "Create a new profile from Registry.lua's stock defaults and switch to it.": "根據 Registry.lua 的內建預設值建立新設定檔並切換至該設定檔。",
    "Create a new profile that starts as an exact copy of the one in use, and switch to it. The two are independent from the first edit.": "建立一個以目前使用設定為完整複本的新設定檔並切換至該設定檔。從初次編輯起兩者即完全獨立。",
    "Create editable copy": "建立可編輯複本",
    "Create...": "建立...",
    "Crest froth & spray": "浪頭泡沫與飛沫",
    "Cue index": "提示索引",
    "Danger start threshold": "危險起始門檻",
    "Death Knight": "死亡騎士",
    "Debuff received": "受到減益效果",
    "Debug logging": "偵錯記錄",
    "Default": "預設",
    "Default (Balanced Baseline)": "預設 (平衡基準)",
    "Default profiles": "預設設定檔",
    "Defensive": "防禦",
    "Delete": "刪除",
    "Delete profile \"%s\"? This can't be undone.": "確定刪除設定檔「%s」？此操作無法復原。",
    "Delete this profile": "刪除此設定檔",
    "Delete...": "刪除...",
    "Device": "裝置",
    "Disable All": "全部停用",
    "Disable all cues": "停用所有提示",
    "Disable all cues in profile": "停用設定檔中的所有提示",
    "Disable every vibration cue in the active profile in one sweep for quiet testing or building a profile from scratch.": "一鍵停用目前使用中設定檔的每個震動提示，用於靜音測試或從零開始建構設定檔。",
    "Disarmed": "被繳械",

    # 166..199
    "Displays a shortcut button on the edge of your minimap for quick access to settings and toggling vibration.": "在小地圖邊緣顯示捷徑按鈕，以便快速開啟設定與切換震動開關。",
    "Distinctiveness": "辨識度",
    "Distinguished from cancelling by Blizzard's own `isCancelled` flag, which it sets before ending the selection — so a cancel never counts as a choice.": "透過暴雪原生的 `isCancelled` 標記與取消操作區分開來，該標記在結束選取前設定——因此取消絕不會被計為確認選擇。",
    "Doubles as the catch-all: a loss-of-control type this addon does not recognise — a new one added by a patch — fires this generic cue instead of being silently dropped.": "兼作通用後備處理：若插件無法識別某種失去控制類型（例如更新檔新增的類型），將觸發此通用提示，而非被靜默忽略。",
    "Druid": "德魯伊",
    "Dual asymmetrical ERM motors, balanced 75ms spin-up": "雙非對稱 ERM 馬達，平衡 75 毫秒起轉",
    "Dual-motor rumble & vibration schemas": "雙馬達震動配置",
    "Duel request": "決鬥請求",
    "Dungeon queue popped": "地城排隊就緒",
    "Dungeon: Caster": "地城：法系",
    "Dungeon: Caster DPS": "地城：法系傷害輸出",
    "Dungeon: Healer": "地城：治療者",
    "Dungeon: Hunter": "地城：獵人",
    "Dungeon: Melee": "地城：近戰",
    "Dungeon: Melee DPS": "地城：近戰傷害輸出",
    "Dungeon: Tank": "地城：坦克",
    "Effort peak": "發力峰值",
    "Empowered cast stage": "蓄力施法階段",
    "Enable All": "全部啟用",
    "Enable Cue": "啟用提示",
    "Enable Pulse": "啟用 Pulse",
    "Enable all cues": "啟用所有提示",
    "Enable all cues in profile": "啟用設定檔中的所有提示",
    "Enable every vibration cue in the active profile in one sweep for testing and debugging.": "一鍵啟用目前使用中設定檔的每個震動提示，用於測試與偵錯。",
    "Encounter": "首領戰",
    "Entered a vehicle": "進入載具",
    "Entered melee range": "進入近戰範圍",
    "Environment": "環境",
    "Equipment": "裝備",
    "Every character": "所有角色",
    "Evoker-only in practice. It stays registered for every class and simply never fires for the others.": "實際上僅適用於喚魔師。它對所有職業保持註冊狀態，但對其他職業絕不觸發。",
    "Experience gained": "獲得經驗值",
    "Experimental": "實驗性",
    "Fast attack time constant used specifically for discrete impacts, clicks, and strikes. Gives snappy transients without making sustained immersion textures harsh.": "專用於獨立撞擊、點擊與打擊的快速起振時間常數。提供俐落乾脆的暫態響應，同時避免持續沉浸震感變得生硬刺手。",

    # 200..232
    "Feared or charmed": "恐懼或魅惑",
    "Feel ": "體驗 ",
    "Feel Strength": "體感強度",
    "Feel this texture": "體驗此震感",
    "Feels like": "體感觸感",
    "Feels like: ": "體感觸感：",
    "Find breakaway floor": "尋找起轉門檻",
    "Fires as an empowered cast of yours begins and ends.": "在你的蓄力施法開始與結束時觸發。",
    "Fires at most ": "最多觸發 ",
    "Fires for any summon confirmation dialog, not only a player summoning you.": "在出現任何召喚確認對話框時觸發，不僅限於其他玩家召喚你。",
    "Fires on PLAYER_TARGET_DIED.": "在收到 PLAYER_TARGET_DIED 事件時觸發。",
    "Fires on input, so it also fires for casts that then fail. That is intentional: this is an input-acknowledgement cue, not a success cue.": "在按鍵輸入時觸發，因此對於隨後失敗的施法也會觸發。這是有意設計的：本提示為輸入確認提示，而非成功提示。",
    "Fires on the change itself, not on every flag update.": "僅在狀態本身發生改變時觸發，而非在每次標記更新時觸發。",
    "Fires on the crossing into low, not repeatedly while low.": "僅在耐久度跌入過低區間時觸發一次，而非在低耐久狀態下重複觸發。",
    "Fires on the yellow informational messages the game shows in the top centre of the screen.": "在螢幕頂部中央顯示黃色遊戲提示訊息時觸發。",
    "Fires only when a queue enters the ready-to-enter state, not on every status update.": "僅在排隊進入「可進入」狀態時觸發，而非在每次狀態更新時觸發。",
    "Fires the instant you press a cast, before the server has confirmed it.": "在按下施法的瞬間觸發，無需等待伺服器確認。",
    "Fires upon arrival at destination when player control is restored.": "在抵達目的地且玩家角色控制權恢復時觸發。",
    "Fires when a battleground or arena queue is ready to enter.": "戰場或競技場排隊準備就緒可進入時觸發。",
    "Fires when a boss encounter begins.": "首領戰開始時觸發。",
    "Fires when a boss encounter ends, in victory or in a wipe.": "首領戰結束時觸發（無論是獲勝還是滅團）。",
    "Fires when a flight master's map opens.": "飛行管理員地圖開啟時觸發。",
    "Fires when a loading screen ends and the world is back.": "載入畫面結束且遊戲世界重新顯現時觸發。",
    "Fires when a quest is handed in and its reward is taken.": "回報任務並領取獎勵時觸發。",
    "Fires when a quest's completion page opens, ready to hand in.": "任務完成頁面開啟、準備回報任務時觸發。",
    "Fires when a quest's detail page opens, ready to accept.": "任務詳細資訊頁面開啟、準備接受任務時觸發。",
    "Fires when a ready check completes or times out.": "就位確認完成或逾時時觸發。",
    "Fires when a ready check starts.": "發起就位確認時觸發。",
    "Fires when a role check starts.": "發起職責確認時觸發。",
    "Fires when a trade window opens.": "交易視窗開啟時觸發。",
    "Fires when a vendor window opens.": "商人視窗開啟時觸發。",
    "Fires when an innkeeper asks to make this your home.": "旅店老闆詢問是否將此處設為家時觸發。",
    "Fires when gaining money with an open vendor window.": "商人視窗開啟狀態下獲得金錢時觸發。",

    # 233..265
    "Fires when group leadership changes hands.": "隊伍領袖變更時觸發。",
    "Fires when one of your own casts begins.": "你自身的施法開始時觸發。",
    "Fires when one of your own casts completes successfully — distinct from a cast simply ending.": "你自身的施法成功完成時觸發——與施法單純結束有所區別。",
    "Fires when one of your own casts ends, whether or not it completed.": "你自身的施法結束時觸發（無論是否成功完成）。",
    "Fires when someone challenges you to a duel.": "有人向你發起決鬥挑戰時觸發。",
    "Fires when someone invites you to a group.": "有人邀請你加入隊伍時觸發。",
    "Fires when someone joins or leaves your group.": "有人加入或離開你的隊伍時觸發。",
    "Fires when someone offers you a resurrection and the accept dialog appears.": "有人對你施放復活且彈出接受復活對話框時觸發。",
    "Fires when someone summons you and the accept dialog appears.": "有人召喚你且彈出接受召喚對話框時觸發。",
    "Fires when spending money with an open vendor window.": "商人視窗開啟狀態下花費金錢時觸發。",
    "Fires when the stable master's window opens.": "獸欄管理員視窗開啟時觸發。",
    "Fires when you accept a quest.": "接受任務時觸發。",
    "Fires when you are confused or possessed (CONFUSE, POSSESS).": "當你陷入迷惑或被心控（CONFUSE、POSSESS）時觸發。",
    "Fires when you are disarmed (DISARM).": "當你被繳械（DISARM）時觸發。",
    "Fires when you are feared or charmed (FEAR, FEAR_MECHANIC, CHARM).": "當你受到恐懼或魅惑（FEAR、FEAR_MECHANIC、CHARM）時觸發。",
    "Fires when you are resurrected or leave ghost form.": "當你復活或脫離靈魂形態時觸發。",
    "Fires when you are rooted in place (ROOT). You can still act, so this is a rung below the cues that stop you entirely.": "當你被定身（ROOT）時觸發。你仍可行動，因此其提示層級低於完全限制行動的失控效果。",
    "Fires when you are silenced (SILENCE).": "當你被沉默（SILENCE）時觸發。",
    "Fires when you are stunned (STUN, STUN_MECHANIC).": "當你被昏迷（STUN、STUN_MECHANIC）時觸發。",
    "Fires when you change target, including when you clear it.": "切換目標時觸發（包含清除目標）。",
    "Fires when you die.": "死亡時觸發。",
    "Fires when you enter a new zone.": "進入新區域時觸發。",
    "Fires when you enter a vehicle and your action bar is replaced.": "進入載具且快捷列被替換時觸發。",
    "Fires when you leave a vehicle and your own action bar returns.": "離開載具且原本的快捷列恢復時觸發。",
    "Fires when you set or clear your focus target.": "設定或清除專注目標時觸發。",
    "Fires when your class's secondary resource fills up — combo points, holy power, soul shards, chi, arcane charges, essence or runes, whichever your specialisation uses.": "當職業次要資源蓄滿時觸發——連擊點數、聖能、靈魂碎片、真氣、秘法充能、精華或符文，視當前專精所使用的資源而定。",
    "Fires when your focus target begins casting.": "專注目標開始施法時觸發。",
    "Fires when your own away or do-not-disturb flag actually changes.": "自身的暫離或請勿打擾狀態實際發生改變時觸發。",
    "Flight map opened": "飛行地圖已開啟",
    "Focus": "專注目標",
    "Focus changed": "專注目標已變更",
    "Focus started casting": "專注目標開始施法",
    "Focused element became unavailable": "焦點元素變為無法使用",

    # 266..299
    "Four rapid, sharp ticks.": "四次快速清脆的提示震動。",
    "Gait strength": "步伐強度",
    "Gasp peak": "喘息峰值",
    "Gear needs repair": "裝備需要修理",
    "Generic / Unknown": "通用／未知",
    "Generic / unknown": "通用／未知",
    "Gentle steady engine-like cruise vibration while riding flight master gryphons, bats, or wyverns.": "騎乘飛行管理員的獅鷲、蝙蝠或雙足飛龍時，產生類似引擎巡航般平穩平緩的震動。",
    "Group changes": "隊伍變動",
    "Group readiness": "隊伍就位確認",
    "Group roster changed": "隊伍名冊已變更",
    "Group targeting active": "隊伍目標選取已啟用",
    "Group targeting released": "隊伍目標選取已釋放",
    "Hardware & Presets": "硬體與預設",
    "Harvest complete": "採集完成",
    "Heal casts and low-health triage": "治療施法與低生命值救援",
    "Healing received": "受到治療",
    "Health & survival": "生命與生存",
    "Heart rate (BPM)": "心率 (BPM)",
    "Heart rate (calm), BPM": "心率 (平靜)，BPM",
    "Heavy Impacts": "沉重衝擊",
    "Heavy left counterweight (85ms), light right counterweight (45ms)": "左側重配重塊 (85毫秒)，右側輕配重塊 (45毫秒)",
    "High Motor Only": "僅輕震馬達",
    "High motor": "輕震馬達",
    "Hooks StackSplitFrame:UpdateStackText.": "攔截 StackSplitFrame:UpdateStackText。",
    "How far the hum swells either side of its baseline. 0 is a flat hold.": "嗡鳴聲圍繞基線起伏漸強的幅度。0 表示平穩維持。",
    "How fast the wingbeat-style undulation cycles.": "振翅式起伏波動的循環速率。",
    "How many seconds before the scripted moment this fires.": "在腳本時刻到來前多少秒觸發。",
    "How pronounced each stroke is against its own baseline. Higher values (0.80-1.0) allow the counterweight to physically spin down during the glide phase between strokes. 0 is a flat drag with no rhythm at all.": "每個划水動作相對於其基線的明顯程度。較高的數值（0.80-1.0）允許配重塊在兩次划水之間的滑行階段自然減速。0 為完全沒有節奏的單調拖曳。",
    "How steady the low motor stays regardless of speed. Only audible while actually gliding.": "無論速度如何，重震馬達保持平穩的程度。僅在實際滑翔時可被感知。",
    "How strong the hum gets by the moment a regular cast completes. Only audible if \"Casting texture\" is also enabled on its own tab.": "一般施法完成瞬間嗡鳴達到的強度。僅在所屬分頁中同時啟用「施法質感」時方可感知。",
    "Hunter": "獵人",
    "If nothing is happening": "如果沒有事件發生",
    "Immediately switch to %s for the current character.": "立即為目前角色切換至 %s。",
    "Immersion: Caster": "沉浸：法系",

    # 300..329
    "Immersion: Melee": "沉浸：近戰",
    "Immersion: Ranged": "沉浸：遠程",
    "Impact attack (s)": "撞擊起振 (秒)",
    "Initial software voltage boost applied during transient onset to accelerate the motor rapidly to target speed. 1.0 is disabled.": "在暫態開始時套用的初始軟體電壓增強，以使馬達迅速加速至目標轉速。1.0 為停用。",
    "Innkeeper hearth prompt": "旅店老闆爐石綁定提示",
    "Input device changed": "輸入裝置已變更",
    "Input mode": "輸入模式",
    "Instant ability used": "已使用瞬發技能",
    "Intensity": "強度",
    "Intensity Slider": "強度滑桿",
    "Interface": "介面",
    "Interface & Accessibility": "介面與無障礙",
    "Interface message": "介面訊息",
    "Interface tab changed": "介面分頁標籤已切換",
    "Inventory full warning": "背包已滿警告",
    "Invites & requests": "邀請與請求",
    "Jarring physical weapon clatter": "劇烈的實體武器碰撞聲",
    "LRA (Classic ERM Emulation)": "LRA (經典 ERM 模擬)",
    "Landed": "著陸",
    "Leave this scope with no opinion and let the next one decide.": "保持目前作用範圍未設定，交由下一個層級決定。",
    "Left a vehicle": "離開載具",
    "Left melee range": "離開近戰範圍",
    "Level up": "升級",
    "Lifecycle (advanced)": "生命週期 (進階)",
    "Load its starting values": "載入其初始預設值",
    "Loading screen finished": "載入畫面結束",
    "Loss of control": "失去控制",
    "Loss of control cues": "失去控制提示",
    "Low Health Heartbeat": "低生命值心跳",
    "Low Motor Only": "僅重震馬達",
}

def main():
    batch_path = "/home/deck/developer/wow/PulseSensation/localization/batches/batch1a_ui_navigation.json"
    with open(batch_path, "r", encoding="utf-8") as f:
        batch_data = json.load(f)

    batch_items = batch_data["items"]
    print(f"Batch 1a items count: {len(batch_items)}")

    errors = 0
    translated_items = []

    for idx, item in enumerate(batch_items):
        src = item["source"]
        if src not in TRANSLATIONS_ZH_TW:
            print(f"ERROR: Missing translation for item [{idx}] (ID {item.get('id')}): {repr(src)}")
            errors += 1
            continue

        tgt = TRANSLATIONS_ZH_TW[src]

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

    out_path = "/home/deck/developer/wow/PulseSensation/localization/batches/translated_zhTW_batch1a.json"
    out_data = {
        "items": translated_items
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out_data, f, indent=2, ensure_ascii=False)

    print(f"SUCCESS: Wrote {len(translated_items)} validated translations to {out_path}")

if __name__ == "__main__":
    main()
