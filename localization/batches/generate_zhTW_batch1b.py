#!/usr/bin/env python3
"""
Generates and validates translated_zhTW_batch1b.json for PulseHaptics Traditional Chinese (Taiwan zhTW) localization.
"""

import json
import os
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "tools"))
from validate_catalog import extract_signature, check_color_balance

TRANSLATIONS_ZH_TW = {
    # 0..49
    "Low health": "低生命值",
    "Low health texture": "低生命值震感",
    "Low motor": "重震馬達",
    "Low motor holds a steady presence, floored so it's never silent while gliding; high motor eases in from near-silent toward thrillPeak as speed climbs, shaped by thrillCurve.": "重震馬達保持持續存在感，設有起轉門檻使其在滑翔時永不沉寂；輕震馬達則隨著速度提升從近乎無聲平穩過渡至 thrillPeak，受 thrillCurve 曲線調節。",
    "Mage": "法師",
    "Manage": "管理",
    "Master Vibration Strength": "主震動強度",
    "Master switch for every loss-of-control cue below. With this off, none of them fire and no loss-of-control events are registered at all.": "下方所有失去控制提示的總開關。關閉後，所有提示均不會觸發，且完全不會註冊任何失去控制事件。",
    "Master switch. With this off, nothing registers and nothing costs anything.": "總開關。關閉後，不註冊任何事件且無任何效能開銷。",
    "Melee auto-attack started": "近戰自動攻擊開始",
    "Melee auto-attack stopped": "近戰自動攻擊停止",
    "Menus & tabs": "選單與分頁",
    "Messages": "訊息",
    "Minimum severity": "最低嚴重度",
    "Mode to test": "待測試模式",
    "Most specific wins. A scope set to |cffffd100No rule|r has no opinion and lets the one below it decide; with none of them set, Pulse uses Default.": "最特定的規則優先。若範圍設為|cffffd100無規則|r，則不作設定並由其下層規則決定；若均未設定，Pulse 將使用預設設定檔。",
    "Movement": "移動",
    "Movement & Travel": "移動與旅行",
    "Multiplies every trigger's intensity. Part of the current profile, not global.": "按倍率縮放每個觸發器的強度。屬於目前設定檔，非全域設定。",
    "Name the new profile:": "為新設定檔命名：",
    "Navigation": "導覽",
    "New profile": "新增設定檔",
    "Next >": "下一步 >",
    "No rule": "無規則",
    "None (full sensory richness)": "無（完全感官豐富度）",
    "None (stock defaults)": "無（初始預設值）",
    "ON — option changes and cue firings will print here.": "開啟——選項變更與提示觸發將在此處輸出。",
    "Ocean Waves & Swell": "海浪與海湧",
    "Ocean waves & swell": "海浪與海湧",
    "Ocean zones only (guessed from zone name)": "僅限海洋區域（根據區域名稱推測）",
    "Off by default and deliberately the faintest cue in the addon: this fires for EVERY NPC you talk to, which in a city is constantly. Try it before leaving it on. Untested.": "預設關閉，且刻意設計為本插件中最微弱的提示：與任何 NPC 對話時都會觸發，而在城市中對話極其頻繁。建議在保持開啟前先體驗測試。未經測試。",
    "Offensive": "進攻",
    "One cue for both directions, same reasoning as the navigation edge cue — a motor can't tell you which way you went.": "雙向共用一個提示，原因與導覽邊緣提示相同——馬達無法傳達你移動的具體方向。",
    "One full-bodied hit on both motors.": "雙馬達上產生一次飽滿有力的敲擊。",
    "One long, sombre pulse when a spirit healer's window opens.": "靈魂醫者視窗開啟時，產生一次漫長而沉鬱的脈衝。",
    "One sharp, heavy impact — fast attack, fast decay.": "一次清脆沉重的撞擊——快速起振，快速消退。",
    "One strong, sustained pulse.": "一次強烈而持續的脈衝。",
    "One sustained pulse.": "一次持續脈衝。",
    "Open Pulse settings": "開啟 Pulse 設定",
    "Other": "其他",
    "Overall heave amplitude of the oceanic swell. Sets the physical displacement intensity of the slow motor.": "海浪起伏的整體振幅。設定重震馬達的物理位移強度。",
    "Overall intensity": "整體強度",
    "Overall strength. Meant to sit at the edge of perception — if you notice it as a vibration rather than as being submerged, it is too high. Inherits the old idleFloatAmplitude, which was live-tuned to 0.04.": "整體強度。旨在維持在感官察覺的邊緣——若你感覺它是一陣震動而非置身水下，代表強度偏高。繼承了舊版 idleFloatAmplitude，實機調校設定為 0.04。",
    "Overdrive kick": "超驅衝量",
    "Overdrive time (s)": "超驅時間 (秒)",
    "Own motor": "獨立馬達",
    "PLAYER_ALIVE also fires when you release to a graveyard, so this can fire while you are still a ghost.": "釋放靈魂到墓地時也會觸發 PLAYER_ALIVE，因此當你仍處於鬼魂狀態時可能觸發此提示。",
    "PLAYER_SOFT_FRIEND_CHANGED, occurrence-only, no payload. Worth pairing with the hostile cue above only if you can tell two TICKs apart — if not, give one of them a different shape with its own \"Feels like\" dropdown.": "PLAYER_SOFT_FRIEND_CHANGED，僅事件觸發，無額外資料。只有當你能分辨兩種不同的「TICK」提示震動時，才建議與上方的敵對提示搭配使用——若無法分辨，請在各自的「體感觸感」下拉選單中為其指定不同的震動形態。",
    "PULSE QUICK SETUP": "PULSE 快速設定",
    "Pacified or school-locked": "處於被安撫或法術系別封鎖狀態",

    # 50..99
    "Page switches": "頁面總開關",
    "Paladin": "聖騎士",
    "Passively polled by observing IsEnabled() on the currently focused element. Fires if the element becomes disabled while focused.": "透過監測目前焦點元素的 IsEnabled() 進行被動輪詢。若焦點元素在處於焦點狀態時變為停用則觸發。",
    "Passively polled via GetUIPanel every 0.05s to eliminate UIParentPanelManager execution taint on protected frames.": "每 0.05 秒透過 GetUIPanel 被動輪詢，避免受保護框架產生 UIParentPanelManager 執行污染。",
    "Passively polled via GetUIPanel every 0.05s. Detects when major UI panels are dismissed without callback taint.": "每 0.05 秒透過 GetUIPanel 被動輪詢。在不產生回呼污染的前提下偵測主要介面面板的關閉。",
    "Passively polled via GroupTargeting.isTargetingActive. Fires when the group targeting modifier is released.": "透過 GroupTargeting.isTargetingActive 被動輪詢。在放開隊伍目標組合鍵時觸發。",
    "Physical tool strikes: anvil hammer strokes, mining pickaxe impacts, tailoring stitches.": "物理工具敲擊：鐵砧錘擊、採礦鎬擊打、裁縫縫紉針線。",
    "Pick a mode to test below.": "在下方選擇要測試的模式。",
    "Play": "播放",
    "Play ": "播放 ",
    "Play a few seconds of this texture at its current intensity. Module-driven preview reproducing authentic physical dynamics and configured intensity.": "以目前強度播放數秒該震感。模組驅動的預覽能夠真實還原物理動態與配置強度。",
    "Presence floor (low)": "最低存在感底限（重震）",
    "Priest": "牧師",
    "Prints every option you change and every cue that actually fires to chat, in real time. Same as /pulse debug — off by default, and resets to off on /reload since it's a testing aid, not a saved preference.": "在對話框中即時輸出你變更的每個選項以及實際觸發的每個提示。等同於 /pulse debug——預設關閉，且在 /reload 後重設為關閉，因為此項僅為測試輔助工具，而非儲存的偏好設定。",
    "Profile": "設定檔",
    "Profiles": "設定檔",
    "Profiles and automatic rules": "設定檔與自動規則",
    "Progression": "角色成長",
    "Progressive low build leading to a sharp high break.": "重震漸強積聚，隨後爆發清脆的輕震碎裂。",
    "Pull / glide balance": "拉力 / 滑翔平衡",
    "Pulse": "Pulse",
    "Pulse is using |cffffd100%s|r, because a rule is set for %s.": "Pulse 正在使用|cffffd100%s|r，因為已為 %s 設定了規則。",
    "Pulse tunes motor spin-up attack, coast-down release, and breakaway friction to match your physical hardware actuators.": "Pulse 調校馬達的起轉加速、減速釋放與起轉摩擦力，以精確符合你的實體硬體震動致動器。",
    "Pulse: (Engine recorded %d errors. Last error: %s)": "Pulse: (引擎記錄了 %d 個錯誤。最後錯誤：%s)",
    "Pulse: /pulse test <mode>|heartbeat|warningbeat — try one of: ": "Pulse: /pulse test <mode>|heartbeat|warningbeat —— 推薦嘗試：",
    "Pulse: activated profile \"%s\"": "Pulse: 已啟用設定檔「%s」",
    "Pulse: active profile is \"%s\" (%s)": "Pulse: 目前使用中設定檔為「%s」(%s)",
    "Pulse: bound profile \"%s\" to specialization %s": "Pulse: 已將設定檔「%s」綁定至專精 %s",
    "Pulse: could not build settings row %q (%s)": "Pulse: 無法建構設定列 %q (%s)",
    "Pulse: could not build the settings window (": "Pulse: 無法建構設定視窗 (",
    "Pulse: debug ": "Pulse: 偵錯 ",
    "Pulse: disabled all %d cues in active profile.": "Pulse: 已停用目前設定檔中的全部 %d 個提示。",
    "Pulse: disabled all %d cues in profile \"%s\".": "Pulse: 已停用全部 %d 個提示（設定檔「%s」）。",
    "Pulse: disabled all %d cues in profile %s.": "Pulse: 已停用全部 %d 個提示（設定檔 %s）。",
    "Pulse: enabled all %d cues in active profile.": "Pulse: 已啟用目前設定檔中的全部 %d 個提示。",
    "Pulse: enabled all %d cues in profile \"%s\".": "Pulse: 已啟用全部 %d 個提示（設定檔「%s」）。",
    "Pulse: enabled all %d cues in profile %s.": "Pulse: 已啟用全部 %d 個提示（設定檔 %s）。",
    "Pulse: live oscilloscope is provided by the companion addon PulseDebug (/pdebug scope).": "Pulse: 即時示波器由隨附插件 PulseDebug (/pdebug scope) 提供。",
    "Pulse: minimap icon %s": "Pulse: 小地圖圖示 %s",
    "Pulse: no profile matching \"%s\". Available: %s": "Pulse: 找不到相符「%s」的設定檔。可用設定檔：%s",
    "Pulse: switched to profile \"%s\"": "Pulse: 已切換至設定檔「%s」",
    "Pulse: that preview is unavailable.": "Pulse: 該預覽無法使用。",
    "Pulse: this looks like a %s%s. Pick it above, then press Apply.": "Pulse: 偵測到目前裝置疑似為 %s%s。請在上方選取它，然後按一下套用。",
    "Pure flavour — nothing depends on it. Untested.": "僅用於增添氛圍——無任何邏輯依賴它。未經測試。",
    "Pure novelty. Off by default forever, basically — nobody asked for this one.": "純屬新奇體驗。基本上永遠預設關閉——畢竟從未有人要求過這項功能。",
    "Put every motor's strength, floor, timing and curve back to the engine defaults. Doesn't touch cues, per-cue intensity, mode tuning or your schema.": "將每個馬達的強度、起轉門檻、時序與曲線恢復為引擎預設值。不會影響提示、個別提示強度、模式調校或你的震動架構方案。",
    "Put the profile in use back to its stock defaults — works on built-ins too, restoring their curated content rather than blank Registry.lua defaults.": "將使用中的設定檔恢復為初始預設值——對內建設定檔同樣有效，恢復其精心策劃的內容而非空白的 Registry.lua 預設值。",
    "PvP (Tactical Radar)": "PvP（戰術雷達）",
    "Quest accepted": "接受任務",
    "Quest offered": "提供任務",

    # 100..149
    "Quest ready to hand in": "任務可回報",
    "Quest turned in": "回報任務",
    "Questing": "任務",
    "Questing & Exploration": "任務與探索",
    "Quests": "任務",
    "Quick Setup": "快速設定",
    "Quick Setup Wizard": "快速設定精靈",
    "Radial menu": "環形選單",
    "Radial menu closed": "環形選單已關閉",
    "Radial menu opened": "環形選單已開啟",
    "Radial page changed": "環形選單切換分頁",
    "Radial segment changed": "環形扇區切換",
    "Radial segment chosen": "環形扇區已選取",
    "Radial segment unavailable": "環形扇區無法使用",
    "Radial selection cancelled": "環形選取已取消",
    "Ranged auto-repeat started": "遠程自動射擊開始",
    "Ranged auto-repeat stopped": "遠程自動射擊停止",
    "Rapid staccato triple-click on the high motor.": "輕震馬達上快速斷奏的三連擊。",
    "Reading something": "正在閱讀",
    "Reads the segment's own IsEnabled() — the same value Blizzard reads to grey the highlight out, so this matches what you see on screen. Fires in place of \"Radial segment changed\", not alongside it.": "讀取該扇區自身的 IsEnabled()——與 Blizzard 用於將高亮變灰的值完全相同，因此與你在螢幕上看到的完全一致。此提示會替代「環形扇區切換」觸發，而非並列觸發。",
    "Ready check": "就位確認",
    "Ready check finished": "就位確認結束",
    "Release time (s)": "釋放時間 (秒)",
    "Reload UI": "重載介面",
    "Reload UI to apply the language change.": "重載介面以套用語言變更。",
    "Reload the interface to apply your selected addon language.": "重載介面以套用你所選取的插件語言。",
    "Rename": "重新命名",
    "Rename \"%s\" to:": "將「%s」重新命名為：",
    "Rename the profile in use. Every rule pointing at it follows the rename. Built-in profiles can't be renamed.": "重新命名使用中的設定檔。指向該設定檔的所有規則都將同步更新名稱。內建設定檔無法重新命名。",
    "Rename this profile": "重新命名此設定檔",
    "Rename...": "重新命名...",
    "Repaired equipment": "已修復裝備",
    "Reset": "重設",
    "Reset every motor's strength, floor, timing and curve back to the engine defaults? This can't be undone.": "是否將每個馬達的強度、起轉門檻、時序與曲線重設為引擎預設值？此操作無法復原。",
    "Reset profile \"%s\" to defaults? Every cue, intensity and mode override in it goes back to stock values. This can't be undone.": "是否將設定檔「%s」重設為預設值？其中的所有提示、強度以及模式覆寫都將恢復為初始值。此操作無法復原。",
    "Reset this profile": "重設此設定檔",
    "Reset...": "重設...",
    "Resources": "資源",
    "Response curve": "反應曲線",
    "Resting": "休息狀態",
    "Resurrection offered": "受到復活邀請",
    "Rewards": "獎勵",
    "Rogue": "盜賊",
    "Role poll": "職責確認",
    "Rooted": "被定身",
    "Routing & Schema": "路由與架構方案",
    "Rules": "規則",
    "Run Wizard": "執行精靈",
    "Run cadence (steps/s)": "奔跑踏步節奏 (步/秒)",
    "Same polled mechanism as \"Confirmation popup appeared\". Untested.": "與「確認彈出視窗出現」相同的輪詢機制。未經測試。",

    # 150..199
    "Save & Start Playing": "儲存並開始遊戲",
    "Scales both the bed and the strikes for %s, before the two shared strengths above.": "在上方的兩個共用強度之前，按比例縮放 %s 的持續底震與敲擊震動。",
    "Scales this cue on top of the overall intensity on the Pulse page.": "在 Pulse 主頁面的整體強度之上，按比例縮放此提示。",
    "School lockouts are frequent in melee-heavy content. Off by default because a cue every kick you eat can crowd out the ones that mean you cannot act at all.": "在近戰密集的戰鬥中法系封鎖相當頻繁。預設關閉，因為每次被斷法都產生震動提示可能會掩蓋那些導致你完全無法行動的關鍵提示。",
    "Search %d cues...": "搜尋 %d 個提示...",
    "Secondary resource full": "次要資源已滿",
    "Set Floor": "設定起轉門檻",
    "Set but not in force: |cffffd100%s|r. A more specific rule above is winning — clear it to let these take over.": "已設定但未生效：|cffffd100%s|r。上方更特定的規則優先——清除該規則即可讓此項生效。",
    "Set for Spec": "為專精設定",
    "Setup Summary": "設定摘要",
    "Shaman": "薩滿",
    "Shares its pulse pattern with the target cue. If your focus is also your target, you get one cue rather than two.": "與目標提示共用相同的脈衝模式。若專注目標同時也是你的當前目標，你只會感受到一次提示而非兩次。",
    "Sharp high kick layered with heavy low kick and rumble decay.": "清脆的輕震衝量疊加沉重的重震衝量，並伴隨漸弱餘震。",
    "Show a Play button on every cue": "在每個提示旁顯示播放按鈕",
    "Show minimap icon": "顯示小地圖圖示",
    "Show per-cue detail controls": "顯示個別提示的詳細控制項",
    "Shows only the page switches and this page. Every cue keeps its own settings; turn this off to get every page back exactly as it was.": "僅顯示頁面總開關以及本頁面。每個提示都會保留其各自的設定；關閉此項即可完全恢復所有頁面的原貌。",
    "Silenced": "被沉默",
    "Simple view": "簡潔檢視",
    "Slow, harmonic oceanic gravity swells and coastal tides while submerged in deep oceans.": "潛入深海時，產生緩慢而和諧的海洋重力海湧與海岸潮汐感。",
    "Snappy & Taps": "清脆敲擊",
    "Social & Group": "社交與隊伍",
    "Social & Group Communication": "社交與隊伍溝通",
    "Soft target interact": "互動軟目標",
    "Special casting": "特殊施法",
    "Speeds up or slows down ": "加快或減慢 ",
    "Spirit healer": "靈魂醫者",
    "Split left and right": "左右聲道分離",
    "Square / X: open settings": "Square / X: 開啟設定",
    "Stable opened": "獸欄已開啟",
    "Stack split ratchet": "拆分堆疊棘輪感",
    "Standard Rumble": "標準震動",
    "Standard balance across all categories": "所有分類的均衡標準配置",
    "Status: %s": "狀態：%s",
    "Step 4: Interface & Social Alerts": "第 4 步：介面與社交警報",
    "Step 6: Master Strength & Completion": "第 6 步：主強度與完成",
    "Steps per second at full running speed. Scaled by how fast you are actually moving.": "全速奔跑時每秒的踏步次數。根據你實際移動的速度進行動態縮放。",
    "Steps per second at normal walking speed.": "正常步行時每秒的踏步次數。",
    "Strength": "強度",
    "Strike strength": "敲擊強度",
    "Stroke depth": "划水深度",
    "Stroke rate, fast (Hz)": "划水頻率，快速 (Hz)",
    "Stroke rate, slow (Hz)": "划水頻率，慢速 (Hz)",
    "Strokes per second at barely-moving speed.": "在極慢微動速度下每秒的划水次數。",
    "Stunned": "被昏迷",
    "Summon offered": "受到召喚",
    "Swapped / Inverted Rumble": "對調 / 反轉震動",
    "Swell depth": "海湧深度",
    "Swell rate (Hz)": "海湧頻率 (Hz)",
    "Swell strength": "海湧強度",

    # 200..249
    "Switch to this profile": "切換至此設定檔",
    "Switches every cue on the Casting page on or off at once. Each cue keeps its own setting underneath.": "一鍵開啟或關閉「施法」頁面上的所有提示。每個提示仍會保留其各自的底層設定。",
    "Switches every cue on the Character & Status page on or off at once. Each cue keeps its own setting underneath.": "一鍵開啟或關閉「角色與狀態」頁面上的所有提示。每個提示仍會保留其各自的底層設定。",
    "Switches every cue on the Interface & Accessibility page on or off at once. Each cue keeps its own setting underneath.": "一鍵開啟或關閉「介面與無障礙」頁面上的所有提示。每個提示仍會保留其各自的底層設定。",
    "Switches every cue on the Movement & Travel page on or off at once. Each cue keeps its own setting underneath.": "一鍵開啟或關閉「移動與旅行」頁面上的所有提示。每個提示仍會保留其各自的底層設定。",
    "Switches every cue on the Social & Group page on or off at once. Each cue keeps its own setting underneath.": "一鍵開啟或關閉「社交與隊伍」頁面上的所有提示。每個提示仍會保留其各自的底層設定。",
    "Switches every cue on the Target & Focus page on or off at once. Each cue keeps its own setting underneath.": "一鍵開啟或關閉「目標與專注目標」頁面上的所有提示。每個提示仍會保留其各自的底層設定。",
    "Switches every cue on the World & Environment page on or off at once. Each cue keeps its own setting underneath.": "一鍵開啟或關閉「世界與環境」頁面上的所有提示。每個提示仍會保留其各自的底層設定。",
    "Talking to someone": "與某人交談",
    "Target": "目標",
    "Target & Crosshair Feedback": "目標與準星反饋",
    "Target & Focus": "目標與專注目標",
    "Target changed": "目標已切換",
    "Target died": "目標死亡",
    "Target started casting": "目標開始施法",
    "Target used major defensive": "目標使用了主要防禦技能",
    "Target's cast stopped": "目標的施法已停止",
    "Targeted by enemy": "被敵人選為目標",
    "Targeting": "目標鎖定",
    "Test Alert": "測試警報",
    "Test Impact": "測試撞擊",
    "Test Lock": "測試鎖定",
    "Test Reward": "測試獎勵",
    "Test Rumble": "測試震動",
    "Test Strike": "測試敲擊",
    "Test UI": "測試介面",
    "Test the selected mode": "測試所選模式",
    "Textures & Patterns": "質感與模式",
    "The Accessibility section": "「無障礙」分類",
    "The Cue Index directory": "提示索引目錄",
    "The _QUIET variant covers failures the game prints no error for, so this can fire with nothing visible on screen.": "_QUIET 變體涵蓋了遊戲未輸出錯誤訊息的失敗情況，因此在螢幕上沒有任何可見提示時也可能觸發。",
    "The experimental section": "實驗性分類",
    "The lightest possible tick when a conversation window opens with any NPC.": "與任何 NPC 開啟對話視窗時，產生最為輕微的提示震動。",
    "The master switch for this page. Also on the Casting page, where the cue lives alongside the other casting cues.": "本頁面的總開關。同時也存在於「施法」頁面中，與該頁面中的其他施法提示並列。",
    "This character": "目前角色",
    "This character reports no specialization, so there is no per-specialization rule to set. The row appears by itself on a character that has one.": "目前角色無專精資訊，因此無可設定的個別專精規則。當角色擁有專精時該列將自動顯示。",
    "This specialization": "目前專精",
    "This specialization (": "目前專精 (",
    "Three rhythmic thuds.": "三次有節奏的沉重撞擊。",
    "Three-stage rising tension building on the low motor.": "重震馬達上呈現三段漸強的緊張感積蓄。",
    "Thrill curve (high)": "俯衝快感曲線（輕震）",
    "Thrill peak (high)": "俯衝快感峰值（輕震）",
    "Time in seconds for a complete wave cycle. Real oceanic swells roll every 8 to 12 seconds (~0.10 Hz). Shorter periods feel like choppy coastal chop; longer periods feel like open-ocean rollers.": "一個完整海浪週期的秒數。現實中的大洋湧浪每 8 到 12 秒湧動一次 (~0.10 Hz)。週期較短感覺像近岸碎浪；週期較長感覺像遠洋起伏巨浪。",
    "Tracked cooldown ready": "追蹤的冷卻已就緒",
    "Trade opened": "交易視窗已開啟",
    "Triggers, modes, and motor tuning": "觸發器、模式與馬達調校",
    "Try Texture": "測試震感",
    "Tuned for HD Rumble voice-coil actuators": "專為 HD 震動音圈致動器調校",
    "Turn off every cue in the active profile in one sweep (useful for quiet debugging).": "一鍵關閉使用中設定檔中的所有提示（對靜音偵錯非常實用）。",
    "Turn on every cue in the active profile in one sweep (useful for testing/debugging).": "一鍵開啟使用中設定檔中的所有提示（對測試/偵錯非常實用）。",

    # 250..299
    "Turn whole pages of cues on or off. Each cue keeps its own setting underneath: switching a page back on restores exactly what was there.": "整頁開啟或關閉提示。每個提示在底層均會保留各自的設定：重新開啟頁面將完全恢復先前的狀態。",
    "Two crisp ticks when a cooldown the built-in Cooldown Manager is tracking comes off cooldown.": "內建冷卻管理器追蹤的技能結束冷卻時，產生兩次清脆的提示震動。",
    "Two heavier hits with a gap between them.": "兩次較重的敲擊，中間帶有明顯間隔。",
    "Two kinds of trigger: pulses and textures": "兩類觸發器：脈衝與持續質感",
    "Two rhythmic thuds.": "兩次有節奏的沉重撞擊。",
    "Two soft ticks when the action bar pages to a different set of abilities.": "快捷列翻頁至另一組技能時，產生兩次柔和的提示震動。",
    "Two soft ticks when you page the radial left or right with the shoulder buttons.": "使用肩鍵向左或向右翻動環形選單時，產生兩次柔和的提示震動。",
    "UI focus moved": "介面焦點移動",
    "UI navigation hit an edge": "介面導覽觸碰邊緣",
    "UI panel closed": "介面面板已關閉",
    "UI panel opened": "介面面板已開啟",
    "Untested whether this also fires on every instant-cast press rather than only real cast-bar completions — if so, it'll feel far too frequent to read as \"that landed\" specifically. Check before relying on it.": "未經測試每次按下瞬發技能是否也會觸發，而非僅在實際施法條讀條完成時觸發——若是前者，震動將過於頻繁而無法準確傳達「技能命中」的感受。依賴此項前請先進行驗證。",
    "Untested.": "未經測試。",
    "Use the old estimator": "使用舊版估算演算法",
    "Using \"%s\" — set for %s.": "正在使用「%s」——已為 %s 設定。",
    "Vendor window opened": "商人視窗已開啟",
    "Vibration Mode": "震動模式",
    "Vibration Schema: |cffffd100%s|r": "震動架構方案：|cffffd100%s|r",
    "Vibration schema": "震動架構方案",
    "Voice-coil actuators (LRA), ultra-low 0.025 floor, instant response": "線性音圈致動器 (LRA)，0.025 超低起轉門檻，瞬時響應",
    "Walk cadence (steps/s)": "步行踏步節奏 (步/秒)",
    "Warlock": "術士",
    "Warning lead time": "警報前置時間",
    "Warrior": "戰士",
    "Watches UNIT_TARGET and target swaps for hostile units whose target is the player. Uses UnitIsUnit('targettarget', 'player') with defensive secrecy guards.": "監測 UNIT_TARGET 以及目標切換，追蹤以玩家為目標的敵對單位。使用 UnitIsUnit('targettarget', 'player') 並帶有防禦性私密保護。",
    "Wave cycle (seconds)": "海浪週期 (秒)",
    "Wave period (sec)": "海浪週期 (秒)",
    "Wave steepness": "海浪陡度",
    "Weapon or gear swapped": "更換武器或裝備",
    "What this does": "功能說明",
    "When mobs are pulled socially — aggroing because a neighbour was pulled — the game often reports status 0 even though you have aggro.": "當怪物被連帶引怪拉到時（因鄰近的怪物被引而產生仇恨），遊戲往往回報仇恨狀態為 0，即便你實際上持有仇恨。",
    "Which of the preset shapes this specific cue plays when it fires. \"": "此提示觸發時播放哪種預設震動形態。「",
    "Which physical motors each cue drives. Start with Standard Rumble, then calibrate the motors below.": "每個提示驅動哪些實體馬達。建議從「標準震動」開始，然後在下方校準馬達。",
    "Which physical motors each trigger drives. Try one, test a mode below, keep the one you can feel.": "每個觸發器驅動哪些實體馬達。嘗試一種並測試下方的模式，保留你能清晰感知的設定。",
    "Which profile to use right now. This writes to whichever rule is currently in force, so picking here always changes what you are actually using rather than editing a rule something more specific is overriding.": "目前使用的設定檔。這會直接寫入目前生效的規則，因此在此選擇始終會改變你實際使用的設定，而不會編輯被更高優先級規則覆寫的內容。",
    "Wind amplitude": "風力振幅",
    "Wind resistance & thrust surge while flying. Scales dynamically with your flight speed.": "飛行時的風阻與推力湧動。根據飛行速度動態縮放。",
    "Windows": "視窗",
    "World": "世界",
    "World & Environment": "世界與環境",
    "World Immersion": "世界沉浸",
    "You are alive again": "你復活了",
    "You died": "你死亡了",
    "You have aggro": "你獲得了仇恨",
    "Your cast ended": "你的施法結束",
    "Your cast failed": "你的施法失敗",
    "Your cast started": "你的施法開始",
    "Your cast succeeded": "你的施法成功",
    "Zone changed": "區域已變更",
    "an impact": "一次撞擊",

    # 300..330
    "could not apply that preset": "無法套用該預設",
    "could not run that": "無法執行該項",
    "could not set that rule": "無法設定該規則",
    "detection unavailable": "偵測無法使用",
    "in force": "生效中",
    "no role chosen": "未選擇職責",
    "once a minute": "每分鐘一次",
    "once every ": "每隔 ",
    "once every %.1f seconds": "每 %.1f 秒一次",
    "|cff00ff00Left-Click:|r Open Settings": "|cff00ff00左鍵點擊：|r開啟設定",
    "|cff00ff00Right-Click:|r Toggle Master On/Off": "|cff00ff00右鍵點擊：|r切換主開關開啟/關閉",
    "|cff00ff00[Adjusting %d%%]|r Use |cffffffff[← / →]|r to Change, |cff38BDF8[A]|r Confirm & Feel": "|cff00ff00[正在調整 %d%%]|r 使用 |cffffffff[← / →]|r 調整，|cff38BDF8[A]|r 確認並感受",
    "|cff38BDF8[L1 / LB]|r": "|cff38BDF8[L1 / LB]|r",
    "|cff38BDF8[L1/R1]|r Tabs  •  |cff38BDF8[A]|r Toggle Slider / Select": "|cff38BDF8[L1/R1]|r 分頁  •  |cff38BDF8[A]|r 切換滑桿 / 選取",
    "|cff38BDF8[R1 / RB]|r": "|cff38BDF8[R1 / RB]|r",
    "|cff444444[L1 / LB]|r": "|cff444444[L1 / LB]|r",
    "|cff444444[R1 / RB]|r": "|cff444444[R1 / RB]|r",
    "|cff4cb8ffPulse:|r Quick setup complete! Type |cffffffff/pulse|r anytime to fine-tune settings.": "|cff4cb8ffPulse:|r 快速設定完成！隨時輸入 |cffffffff/pulse|r 即可微調各項設定。",
    "|cff4db8ff✔ |r": "|cff4db8ff✔ |r",
    "|cff888888Drag:|r Move Icon": "|cff888888拖曳：|r移動圖示",
    "|cff888888Loss of control cues are governed by the master switch on the main Pulse page.|r": "|cff888888失去控制提示受 Pulse 主頁面上的總開關統一控制。|r",
    "|cff888888Recommended intensity:|r %d%%": "|cff888888推薦強度：|r%d%%",
    "|cffffcc00◀/▶ Adjust Intensity|r   •   %s/%s Lock Value   •   %s Try Texture": "|cffffcc00◀/▶ 調整強度|r   •   %s/%s 鎖定數值   •   %s 測試震感",
    "|cffffd100%s|r  |cff00ff00[ACTIVE]|r": "|cffffd100%s|r  |cff00ff00[已啟用]|r",
    "|cffffd100/pulseui|r opens it too. |cffffd100/pulse setup|r re-opens Quick Setup, |cffffd100/pulse test <mode>|r plays a shape.": "|cffffd100/pulseui|r 亦可將其開啟。|cffffd100/pulse setup|r 重新開啟快速設定，|cffffd100/pulse test <mode>|r 試聽播放震動形態。",
    "|r, |cffffd100": "|r, |cffffd100",
    "• |r": "• |r",
    "⚔️ Melee DPS": "⚔️ 近戰輸出",
    "🏹 Ranged DPS": "🏹 遠程輸出",
    "💚 Healer": "💚 治療",
    "🛡️ Tank": "🛡️ 坦克",
}

def main():
    batch_path = os.path.join(os.path.dirname(__file__), "batch1b_ui_navigation.json")
    with open(batch_path, "r", encoding="utf-8") as f:
        batch_data = json.load(f)

    items = batch_data.get("items", [])
    print(f"Loaded {len(items)} items from {batch_path}")

    translated_items = []
    errors = 0

    for idx, item in enumerate(items):
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

    out_path = os.path.join(os.path.dirname(__file__), "translated_zhTW_batch1b.json")
    out_data = {
        "items": translated_items
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out_data, f, indent=2, ensure_ascii=False)

    print(f"SUCCESS: Wrote {len(translated_items)} validated translations to {out_path}")

if __name__ == "__main__":
    main()
