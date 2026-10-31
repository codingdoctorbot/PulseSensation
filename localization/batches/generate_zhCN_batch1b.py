#!/usr/bin/env python3
"""
Generates and validates translated_zhCN_batch1b.json for PulseHaptics Simplified Chinese localization.
"""

import json
import os
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "tools"))
from validate_catalog import extract_signature, check_color_balance

TRANSLATIONS_ZH = {
    # 0..49
    "Low health": "低生命值",
    "Low health texture": "低生命值材质震动",
    "Low motor": "重震马达",
    "Low motor holds a steady presence, floored so it's never silent while gliding; high motor eases in from near-silent toward thrillPeak as speed climbs, shaped by thrillCurve.": "重震马达保持持续存在感，设有最低阈值使其在滑翔时永不沉寂；轻震马达则随着速度提升从近乎无声平稳过渡至 thrillPeak，受 thrillCurve 曲线调制。",
    "Mage": "法师",
    "Manage": "管理",
    "Master Vibration Strength": "主震动强度",
    "Master switch for every loss-of-control cue below. With this off, none of them fire and no loss-of-control events are registered at all.": "下方所有失去控制提示的总开关。关闭后，所有提示均不会触发，且完全不会注册任何失去控制事件。",
    "Master switch. With this off, nothing registers and nothing costs anything.": "总开关。关闭后，不注册任何事件且无任何性能开销。",
    "Melee auto-attack started": "近战自动攻击开始",
    "Melee auto-attack stopped": "近战自动攻击停止",
    "Menus & tabs": "菜单与标签页",
    "Messages": "消息",
    "Minimum severity": "最低严重度",
    "Mode to test": "待测试模式",
    "Most specific wins. A scope set to |cffffd100No rule|r has no opinion and lets the one below it decide; with none of them set, Pulse uses Default.": "最具体的规则优先。若作用域设为|cffffd100无规则|r，则不作设定并由其下级规则决定；若均未设置，Pulse 将使用默认配置。",
    "Movement": "移动",
    "Movement & Travel": "移动与旅行",
    "Multiplies every trigger's intensity. Part of the current profile, not global.": "按倍率缩放每个触发器的强度。属于当前配置文件，非全局设定。",
    "Name the new profile:": "为新配置文件命名：",
    "Navigation": "导航",
    "New profile": "新建配置文件",
    "Next >": "下一步 >",
    "No rule": "无规则",
    "None (full sensory richness)": "无（完全感官丰富度）",
    "None (stock defaults)": "无（初始默认值）",
    "ON — option changes and cue firings will print here.": "开启——选项变更与提示触发将在此处输出。",
    "Ocean Waves & Swell": "海浪与海涌",
    "Ocean waves & swell": "海浪与海涌",
    "Ocean zones only (guessed from zone name)": "仅限海洋区域（根据区域名称推测）",
    "Off by default and deliberately the faintest cue in the addon: this fires for EVERY NPC you talk to, which in a city is constantly. Try it before leaving it on. Untested.": "默认关闭，且有意设计为本插件中最微弱的提示：与任何 NPC 对话时都会触发，而在城市中对话极其频繁。建议在保持开启前先体验测试。未经测试。",
    "Offensive": "进攻",
    "One cue for both directions, same reasoning as the navigation edge cue — a motor can't tell you which way you went.": "双向共用一个提示，原因与导航边界提示相同——马达无法传达你移动的具体方向。",
    "One full-bodied hit on both motors.": "双马达上产生一次饱满有力的敲击。",
    "One long, sombre pulse when a spirit healer's window opens.": "灵魂医者窗口打开时，产生一次漫长而沉郁的脉冲。",
    "One sharp, heavy impact — fast attack, fast decay.": "一次清脆沉重的撞击——快速起振，快速消退。",
    "One strong, sustained pulse.": "一次强烈而持续的脉冲。",
    "One sustained pulse.": "一次持续脉冲。",
    "Open Pulse settings": "打开 Pulse 设置",
    "Other": "其他",
    "Overall heave amplitude of the oceanic swell. Sets the physical displacement intensity of the slow motor.": "海浪起伏的整体振幅。设定重震马达的物理位移强度。",
    "Overall intensity": "整体强度",
    "Overall strength. Meant to sit at the edge of perception — if you notice it as a vibration rather than as being submerged, it is too high. Inherits the old idleFloatAmplitude, which was live-tuned to 0.04.": "整体强度。旨在维持在感官察觉的边缘——若你感觉它是一阵震动而非置身水下，说明强度偏高。继承了旧版 idleFloatAmplitude，实机调校设定为 0.04。",
    "Overdrive kick": "超驱冲量",
    "Overdrive time (s)": "超驱时间 (秒)",
    "Own motor": "独立马达",
    "PLAYER_ALIVE also fires when you release to a graveyard, so this can fire while you are still a ghost.": "释放灵魂到墓地时也会触发 PLAYER_ALIVE，因此当你仍处于幽灵状态时可能触发此提示。",
    "PLAYER_SOFT_FRIEND_CHANGED, occurrence-only, no payload. Worth pairing with the hostile cue above only if you can tell two TICKs apart — if not, give one of them a different shape with its own \"Feels like\" dropdown.": "PLAYER_SOFT_FRIEND_CHANGED，仅事件触发，无附加数据。只有当你能分辨两种不同的“滴答”提示震动时，才建议与上方的敌对提示搭配使用——若无法分辨，请在各自的“触感表现”下拉菜单中为其指定不同的震动形态。",
    "PULSE QUICK SETUP": "PULSE 快速设置",
    "Pacified or school-locked": "处于安抚或法系封锁状态",

    # 50..99
    "Page switches": "页面总开关",
    "Paladin": "圣骑士",
    "Passively polled by observing IsEnabled() on the currently focused element. Fires if the element becomes disabled while focused.": "通过监测当前聚焦元素的 IsEnabled() 进行被动轮询。若聚焦元素在处于焦点状态时变为禁用则触发。",
    "Passively polled via GetUIPanel every 0.05s to eliminate UIParentPanelManager execution taint on protected frames.": "每 0.05 秒通过 GetUIPanel 被动轮询，避免受保护框架产生 UIParentPanelManager 执行污染。",
    "Passively polled via GetUIPanel every 0.05s. Detects when major UI panels are dismissed without callback taint.": "每 0.05 秒通过 GetUIPanel 被动轮询。在不产生回调污染的前提下检测主要界面面板的关闭。",
    "Passively polled via GroupTargeting.isTargetingActive. Fires when the group targeting modifier is released.": "通过 GroupTargeting.isTargetingActive 被动轮询。在释放队伍目标修改键时触发。",
    "Physical tool strikes: anvil hammer strokes, mining pickaxe impacts, tailoring stitches.": "物理工具敲击：铁砧锤击、采矿镐击打、裁缝缝纫针线。",
    "Pick a mode to test below.": "在下方选择要测试的模式。",
    "Play": "播放",
    "Play ": "播放 ",
    "Play a few seconds of this texture at its current intensity. Module-driven preview reproducing authentic physical dynamics and configured intensity.": "以当前强度播放数秒该材质震动。模块驱动的预览能够真实还原物理动态与配置强度。",
    "Presence floor (low)": "最低存在感底限（重震）",
    "Priest": "牧师",
    "Prints every option you change and every cue that actually fires to chat, in real time. Same as /pulse debug — off by default, and resets to off on /reload since it's a testing aid, not a saved preference.": "在聊天栏中实时输出你更改的每个选项以及实际触发的每个提示。等同于 /pulse debug——默认关闭，且在 /reload 后重置为关闭，因为此项仅为测试辅助工具，而非保存的偏好设置。",
    "Profile": "配置文件",
    "Profiles": "配置文件",
    "Profiles and automatic rules": "配置文件与自动规则",
    "Progression": "角色成长",
    "Progressive low build leading to a sharp high break.": "重震渐强积聚，随后爆发清脆的轻震碎裂。",
    "Pull / glide balance": "拉力 / 滑翔平衡",
    "Pulse": "Pulse",
    "Pulse is using |cffffd100%s|r, because a rule is set for %s.": "Pulse 正在使用|cffffd100%s|r，因为已为 %s 设置了规则。",
    "Pulse tunes motor spin-up attack, coast-down release, and breakaway friction to match your physical hardware actuators.": "Pulse 调校马达的起振起跑、减速释放与启动摩擦力，以精确匹配你的实体硬件震动致动器。",
    "Pulse: (Engine recorded %d errors. Last error: %s)": "Pulse: (引擎记录了 %d 个错误。最后错误：%s)",
    "Pulse: /pulse test <mode>|heartbeat|warningbeat — try one of: ": "Pulse: /pulse test <mode>|heartbeat|warningbeat —— 推荐尝试：",
    "Pulse: activated profile \"%s\"": "Pulse: 已激活配置文件“%s”",
    "Pulse: active profile is \"%s\" (%s)": "Pulse: 当前配置文件为“%s” (%s)",
    "Pulse: bound profile \"%s\" to specialization %s": "Pulse: 已将配置文件“%s”绑定至专精 %s",
    "Pulse: could not build settings row %q (%s)": "Pulse: 无法构建设置行 %q (%s)",
    "Pulse: could not build the settings window (": "Pulse: 无法构建设置窗口 (",
    "Pulse: debug ": "Pulse: 调试 ",
    "Pulse: disabled all %d cues in active profile.": "Pulse: 已禁用当前配置文件中的全部 %d 个提示。",
    "Pulse: disabled all %d cues in profile \"%s\".": "Pulse: 已禁用全部 %d 个提示（配置文件“%s”）。",
    "Pulse: disabled all %d cues in profile %s.": "Pulse: 已禁用全部 %d 个提示（配置文件 %s）。",
    "Pulse: enabled all %d cues in active profile.": "Pulse: 已启用当前配置文件中的全部 %d 个提示。",
    "Pulse: enabled all %d cues in profile \"%s\".": "Pulse: 已启用全部 %d 个提示（配置文件“%s”）。",
    "Pulse: enabled all %d cues in profile %s.": "Pulse: 已启用全部 %d 个提示（配置文件 %s）。",
    "Pulse: live oscilloscope is provided by the companion addon PulseDebug (/pdebug scope).": "Pulse: 实时示波器由配套插件 PulseDebug (/pdebug scope) 提供。",
    "Pulse: minimap icon %s": "Pulse: 小地图图标 %s",
    "Pulse: no profile matching \"%s\". Available: %s": "Pulse: 未找到匹配“%s”的配置文件。可用配置：%s",
    "Pulse: switched to profile \"%s\"": "Pulse: 已切换至配置文件“%s”",
    "Pulse: that preview is unavailable.": "Pulse: 该预览不可用。",
    "Pulse: this looks like a %s%s. Pick it above, then press Apply.": "Pulse: 检测到当前设备疑似为 %s%s。请在上方选择它，然后点击应用。",
    "Pure flavour — nothing depends on it. Untested.": "仅用于趣味润色——无任何逻辑依赖它。未经测试。",
    "Pure novelty. Off by default forever, basically — nobody asked for this one.": "纯属新奇体验。基本上永远默认关闭——毕竟没人提出过这种需求。",
    "Put every motor's strength, floor, timing and curve back to the engine defaults. Doesn't touch cues, per-cue intensity, mode tuning or your schema.": "将每个马达的强度、启转阈值、时间节奏与响应曲线恢复为引擎默认值。不会影响提示、单项提示强度、模式调校或你的震动架构方案。",
    "Put the profile in use back to its stock defaults — works on built-ins too, restoring their curated content rather than blank Registry.lua defaults.": "将正在使用的配置文件恢复为初始默认值——对内置配置同样有效，恢复其精心编排的内容而非空白的 Registry.lua 默认设置。",
    "PvP (Tactical Radar)": "PvP（战术雷达）",
    "Quest accepted": "接受任务",
    "Quest offered": "提供任务",

    # 100..149
    "Quest ready to hand in": "任务可交付",
    "Quest turned in": "交付任务",
    "Questing": "任务",
    "Questing & Exploration": "任务与探索",
    "Quests": "任务",
    "Quick Setup": "快速设置",
    "Quick Setup Wizard": "快速设置向导",
    "Radial menu": "轮盘菜单",
    "Radial menu closed": "轮盘菜单已关闭",
    "Radial menu opened": "轮盘菜单已打开",
    "Radial page changed": "轮盘翻页",
    "Radial segment changed": "轮盘扇区切换",
    "Radial segment chosen": "轮盘扇区已选中",
    "Radial segment unavailable": "轮盘扇区不可用",
    "Radial selection cancelled": "轮盘选择已取消",
    "Ranged auto-repeat started": "远程自动射击开始",
    "Ranged auto-repeat stopped": "远程自动射击停止",
    "Rapid staccato triple-click on the high motor.": "轻震马达上快速断奏的三连击。",
    "Reading something": "正在阅读",
    "Reads the segment's own IsEnabled() — the same value Blizzard reads to grey the highlight out, so this matches what you see on screen. Fires in place of \"Radial segment changed\", not alongside it.": "读取该扇区自身的 IsEnabled()——与暴雪用于将高亮置灰的值完全相同，因此与你在屏幕上看到的完全一致。此提示会替代“轮盘扇区切换”触发，而非并列触发。",
    "Ready check": "就位确认",
    "Ready check finished": "就位确认结束",
    "Release time (s)": "释放时间 (秒)",
    "Reload UI": "重载界面",
    "Reload UI to apply the language change.": "重载界面以应用语言更改。",
    "Reload the interface to apply your selected addon language.": "重载界面以应用你所选择的插件语言。",
    "Rename": "重命名",
    "Rename \"%s\" to:": "将“%s”重命名为：",
    "Rename the profile in use. Every rule pointing at it follows the rename. Built-in profiles can't be renamed.": "重命名当前使用的配置文件。指向它的所有规则都会同步更新。内置配置文件无法重命名。",
    "Rename this profile": "重命名此配置文件",
    "Rename...": "重命名...",
    "Repaired equipment": "已修理装备",
    "Reset": "重置",
    "Reset every motor's strength, floor, timing and curve back to the engine defaults? This can't be undone.": "是否将每个马达的强度、启转阈值、时间节奏与响应曲线重置为引擎默认值？此操作无法撤销。",
    "Reset profile \"%s\" to defaults? Every cue, intensity and mode override in it goes back to stock values. This can't be undone.": "是否将配置文件“%s”重置为默认值？其中的所有提示、强度以及模式覆盖都将恢复为初始值。此操作无法撤销。",
    "Reset this profile": "重置此配置文件",
    "Reset...": "重置...",
    "Resources": "资源",
    "Response curve": "响应曲线",
    "Resting": "休息状态",
    "Resurrection offered": "受到复活邀请",
    "Rewards": "奖励",
    "Rogue": "潜行者",
    "Role poll": "职责确认",
    "Rooted": "被定身",
    "Routing & Schema": "路由与架构方案",
    "Rules": "规则",
    "Run Wizard": "运行向导",
    "Run cadence (steps/s)": "奔跑踏步节奏 (步/秒)",
    "Same polled mechanism as \"Confirmation popup appeared\". Untested.": "与“确认弹出窗口出现”相同的轮询机制。未经测试。",

    # 150..199
    "Save & Start Playing": "保存并开始游戏",
    "Scales both the bed and the strikes for %s, before the two shared strengths above.": "在上方的两个共享强度之前，按比例缩放 %s 的持续底震与敲击震颤。",
    "Scales this cue on top of the overall intensity on the Pulse page.": "在 Pulse 主页面的整体强度之上，按比例缩放此提示。",
    "School lockouts are frequent in melee-heavy content. Off by default because a cue every kick you eat can crowd out the ones that mean you cannot act at all.": "在近战较多的场景中法系封锁十分频繁。默认关闭，因为每次被踢断都产生震动提示可能会掩盖那些导致你完全无法行动的关键提示。",
    "Search %d cues...": "搜索 %d 个提示...",
    "Secondary resource full": "次要资源已满",
    "Set Floor": "设定启转阈值",
    "Set but not in force: |cffffd100%s|r. A more specific rule above is winning — clear it to let these take over.": "已设置但未生效：|cffffd100%s|r。上方更具体的规则已生效——清除上级规则即可让此项生效。",
    "Set for Spec": "为专精设定",
    "Setup Summary": "设置概要",
    "Shaman": "萨满祭司",
    "Shares its pulse pattern with the target cue. If your focus is also your target, you get one cue rather than two.": "与目标提示共用相同的脉冲模式。若焦点同时也是你的当前目标，你只会感受到一次提示而非两次。",
    "Sharp high kick layered with heavy low kick and rumble decay.": "清脆的轻震冲量叠加沉重的重震冲量，并伴随渐弱余震。",
    "Show a Play button on every cue": "在每个提示旁显示播放按钮",
    "Show minimap icon": "显示小地图图标",
    "Show per-cue detail controls": "显示单项提示的详细控制项",
    "Shows only the page switches and this page. Every cue keeps its own settings; turn this off to get every page back exactly as it was.": "仅显示页面总开关以及本页面。每个提示都会保留其各自的设置；关闭此项即可完全恢复所有页面的原貌。",
    "Silenced": "被沉默",
    "Simple view": "简洁视图",
    "Slow, harmonic oceanic gravity swells and coastal tides while submerged in deep oceans.": "潜入深海时，产生缓慢而和谐的海洋重力海涌与海岸潮汐感。",
    "Snappy & Taps": "清脆点击",
    "Social & Group": "社交与队伍",
    "Social & Group Communication": "社交与队伍沟通",
    "Soft target interact": "交互软目标",
    "Special casting": "特殊施法",
    "Speeds up or slows down ": "加快或减慢 ",
    "Spirit healer": "灵魂医者",
    "Split left and right": "左右声道分离",
    "Square / X: open settings": "Square / X: 打开设置",
    "Stable opened": "兽栏已打开",
    "Stack split ratchet": "拆分堆叠棘轮感",
    "Standard Rumble": "标准震动",
    "Standard balance across all categories": "所有分类的均衡标准配置",
    "Status: %s": "状态：%s",
    "Step 4: Interface & Social Alerts": "第 4 步：界面与社交警报",
    "Step 6: Master Strength & Completion": "第 6 步：主强度与完成",
    "Steps per second at full running speed. Scaled by how fast you are actually moving.": "全速奔跑时每秒的踏步次数。根据你实际移动的速度进行动态缩放。",
    "Steps per second at normal walking speed.": "正常步行时每秒的踏步次数。",
    "Strength": "强度",
    "Strike strength": "敲击强度",
    "Stroke depth": "划水深度",
    "Stroke rate, fast (Hz)": "划水频率，快速 (Hz)",
    "Stroke rate, slow (Hz)": "划水频率，慢速 (Hz)",
    "Strokes per second at barely-moving speed.": "在极慢微动速度下每秒的划水次数。",
    "Stunned": "被昏迷",
    "Summon offered": "受到召唤",
    "Swapped / Inverted Rumble": "对调 / 反转震动",
    "Swell depth": "海涌深度",
    "Swell rate (Hz)": "海涌频率 (Hz)",
    "Swell strength": "海涌强度",

    # 200..249
    "Switch to this profile": "切换至此配置文件",
    "Switches every cue on the Casting page on or off at once. Each cue keeps its own setting underneath.": "一键开启或关闭“施法”页面上的所有提示。每个提示仍会保留其各自的底层设定。",
    "Switches every cue on the Character & Status page on or off at once. Each cue keeps its own setting underneath.": "一键开启或关闭“角色与状态”页面上的所有提示。每个提示仍会保留其各自的底层设定。",
    "Switches every cue on the Interface & Accessibility page on or off at once. Each cue keeps its own setting underneath.": "一键开启或关闭“界面与辅助功能”页面上的所有提示。每个提示仍会保留其各自的底层设定。",
    "Switches every cue on the Movement & Travel page on or off at once. Each cue keeps its own setting underneath.": "一键开启或关闭“移动与旅行”页面上的所有提示。每个提示仍会保留其各自的底层设定。",
    "Switches every cue on the Social & Group page on or off at once. Each cue keeps its own setting underneath.": "一键开启或关闭“社交与队伍”页面上的所有提示。每个提示仍会保留其各自的底层设定。",
    "Switches every cue on the Target & Focus page on or off at once. Each cue keeps its own setting underneath.": "一键开启或关闭“目标与焦点”页面上的所有提示。每个提示仍会保留其各自的底层设定。",
    "Switches every cue on the World & Environment page on or off at once. Each cue keeps its own setting underneath.": "一键开启或关闭“世界与环境”页面上的所有提示。每个提示仍会保留其各自的底层设定。",
    "Talking to someone": "与某人交谈",
    "Target": "目标",
    "Target & Crosshair Feedback": "目标与准星反馈",
    "Target & Focus": "目标与焦点",
    "Target changed": "目标已切换",
    "Target died": "目标死亡",
    "Target started casting": "目标开始施法",
    "Target used major defensive": "目标使用了主要防御技能",
    "Target's cast stopped": "目标的施法已停止",
    "Targeted by enemy": "被敌人选为目标",
    "Targeting": "目标锁定",
    "Test Alert": "测试警报",
    "Test Impact": "测试撞击",
    "Test Lock": "测试锁定",
    "Test Reward": "测试奖励",
    "Test Rumble": "测试震动",
    "Test Strike": "测试敲击",
    "Test UI": "测试界面",
    "Test the selected mode": "测试所选模式",
    "Textures & Patterns": "材质纹理与模式",
    "The Accessibility section": "辅助功能分类",
    "The Cue Index directory": "提示索引目录",
    "The _QUIET variant covers failures the game prints no error for, so this can fire with nothing visible on screen.": "_QUIET 变体涵盖了游戏未输出错误信息的失败情况，因此在屏幕上没有任何可见提示时也可能触发。",
    "The experimental section": "实验性分类",
    "The lightest possible tick when a conversation window opens with any NPC.": "与任何 NPC 打开对话窗口时，产生最为轻微的提示震动。",
    "The master switch for this page. Also on the Casting page, where the cue lives alongside the other casting cues.": "本页面的总开关。同时也存在于“施法”页面中，与该页面中的其他施法提示并列。",
    "This character": "当前角色",
    "This character reports no specialization, so there is no per-specialization rule to set. The row appears by itself on a character that has one.": "当前角色无专精信息，因此无可设置的专属专精规则。当角色拥有专精时该行将自动显示。",
    "This specialization": "当前专精",
    "This specialization (": "当前专精 (",
    "Three rhythmic thuds.": "三次有节奏的沉重撞击。",
    "Three-stage rising tension building on the low motor.": "重震马达上呈现三段渐强的紧张感积蓄。",
    "Thrill curve (high)": "俯冲快感曲线（轻震）",
    "Thrill peak (high)": "俯冲快感峰值（轻震）",
    "Time in seconds for a complete wave cycle. Real oceanic swells roll every 8 to 12 seconds (~0.10 Hz). Shorter periods feel like choppy coastal chop; longer periods feel like open-ocean rollers.": "一个完整海浪周期的秒数。现实中的大洋涌浪每 8 到 12 秒涌动一次 (~0.10 Hz)。周期较短感觉像近岸波涛碎浪；周期较长感觉像远洋起伏巨浪。",
    "Tracked cooldown ready": "追踪的冷却已就绪",
    "Trade opened": "交易窗口已打开",
    "Triggers, modes, and motor tuning": "触发器、模式与马达调校",
    "Try Texture": "测试震感",
    "Tuned for HD Rumble voice-coil actuators": "专为 HD 震动音圈致动器调校",
    "Turn off every cue in the active profile in one sweep (useful for quiet debugging).": "一键关闭当前配置文件中的所有提示（对静音调试非常实用）。",
    "Turn on every cue in the active profile in one sweep (useful for testing/debugging).": "一键开启当前配置文件中的所有提示（对测试/调试非常实用）。",

    # 250..299
    "Turn whole pages of cues on or off. Each cue keeps its own setting underneath: switching a page back on restores exactly what was there.": "整页开启或关闭提示。每个提示在底层均会保留各自的设置：重新开启页面将完全恢复之前的状态。",
    "Two crisp ticks when a cooldown the built-in Cooldown Manager is tracking comes off cooldown.": "内置冷却管理器追踪的技能结束冷却时，产生两次清脆的提示震动。",
    "Two heavier hits with a gap between them.": "两次较重的敲击，中间带有明显间隔。",
    "Two kinds of trigger: pulses and textures": "两类触发器：脉冲与材质纹理",
    "Two rhythmic thuds.": "两次有节奏的沉重撞击。",
    "Two soft ticks when the action bar pages to a different set of abilities.": "动作条翻页至另一组技能时，产生两次柔和的提示震动。",
    "Two soft ticks when you page the radial left or right with the shoulder buttons.": "使用肩键向左或向右翻动轮盘菜单时，产生两次柔和的提示震动。",
    "UI focus moved": "界面焦点移动",
    "UI navigation hit an edge": "界面导航触碰边缘",
    "UI panel closed": "界面面板已关闭",
    "UI panel opened": "界面面板已打开",
    "Untested whether this also fires on every instant-cast press rather than only real cast-bar completions — if so, it'll feel far too frequent to read as \"that landed\" specifically. Check before relying on it.": "未经测试每次按下瞬发技能是否也会触发，而非仅在实际施法条读条完成时触发——若是前者，震动将过于频繁而无法准确传达“技能命中”的反馈。依赖此项前请先进行验证。",
    "Untested.": "未经测试。",
    "Use the old estimator": "使用旧版估算算法",
    "Using \"%s\" — set for %s.": "正在使用“%s”——已为 %s 设定。",
    "Vendor window opened": "商人窗口已打开",
    "Vibration Mode": "震动模式",
    "Vibration Schema: |cffffd100%s|r": "震动架构方案：|cffffd100%s|r",
    "Vibration schema": "震动架构方案",
    "Voice-coil actuators (LRA), ultra-low 0.025 floor, instant response": "线性音圈致动器 (LRA)，0.025 超低起振阈值，瞬时瞬态响应",
    "Walk cadence (steps/s)": "步行踏步节奏 (步/秒)",
    "Warlock": "术士",
    "Warning lead time": "警报提前量",
    "Warrior": "战士",
    "Watches UNIT_TARGET and target swaps for hostile units whose target is the player. Uses UnitIsUnit('targettarget', 'player') with defensive secrecy guards.": "监测 UNIT_TARGET 以及目标切换，追踪以玩家为目标的敌对单位。使用 UnitIsUnit('targettarget', 'player') 并带有防御性私密保护。",
    "Wave cycle (seconds)": "海浪周期 (秒)",
    "Wave period (sec)": "海浪周期 (秒)",
    "Wave steepness": "海浪波陡度",
    "Weapon or gear swapped": "更换武器或装备",
    "What this does": "功能说明",
    "When mobs are pulled socially — aggroing because a neighbour was pulled — the game often reports status 0 even though you have aggro.": "当怪物被连锁引怪拉脱时（因附近的怪物被引而获得仇恨），游戏往往报告仇恨状态为 0，即便你实际上持有仇恨。",
    "Which of the preset shapes this specific cue plays when it fires. \"": "此提示触发时播放哪种预设震动形态。“",
    "Which physical motors each cue drives. Start with Standard Rumble, then calibrate the motors below.": "每个提示驱动哪些实体马达。建议从“标准震动”开始，然后在下方校准马达。",
    "Which physical motors each trigger drives. Try one, test a mode below, keep the one you can feel.": "每个触发器驱动哪些实体马达。尝试一种并测试下方的模式，保留你能清晰感知的设置。",
    "Which profile to use right now. This writes to whichever rule is currently in force, so picking here always changes what you are actually using rather than editing a rule something more specific is overriding.": "当前使用的配置文件。这会直接写入当前生效的规则，因此在此选择始终会改变你实际使用的配置，而不会编辑被更高优先级规则覆盖的内容。",
    "Wind amplitude": "风力振幅",
    "Wind resistance & thrust surge while flying. Scales dynamically with your flight speed.": "飞行时的风阻与推力涌动。根据飞行速度动态缩放。",
    "Windows": "窗口",
    "World": "世界",
    "World & Environment": "世界与环境",
    "World Immersion": "世界沉浸",
    "You are alive again": "你复活了",
    "You died": "你死亡了",
    "You have aggro": "你获得了仇恨",
    "Your cast ended": "你的施法结束",
    "Your cast failed": "你的施法失败",
    "Your cast started": "你的施法开始",
    "Your cast succeeded": "你的施法成功",
    "Zone changed": "区域已变更",
    "an impact": "一次撞击",

    # 300..330
    "could not apply that preset": "无法应用该预设",
    "could not run that": "无法运行该项",
    "could not set that rule": "无法设置该规则",
    "detection unavailable": "检测不可用",
    "in force": "生效中",
    "no role chosen": "未选择职责",
    "once a minute": "每分钟一次",
    "once every ": "每隔 ",
    "once every %.1f seconds": "每 %.1f 秒一次",
    "|cff00ff00Left-Click:|r Open Settings": "|cff00ff00左键点击：|r打开设置",
    "|cff00ff00Right-Click:|r Toggle Master On/Off": "|cff00ff00右键点击：|r切换主开关开启/关闭",
    "|cff00ff00[Adjusting %d%%]|r Use |cffffffff[← / →]|r to Change, |cff38BDF8[A]|r Confirm & Feel": "|cff00ff00[正在调整 %d%%]|r 使用 |cffffffff[← / →]|r 调整，|cff38BDF8[A]|r 确认并感受",
    "|cff38BDF8[L1 / LB]|r": "|cff38BDF8[L1 / LB]|r",
    "|cff38BDF8[L1/R1]|r Tabs  •  |cff38BDF8[A]|r Toggle Slider / Select": "|cff38BDF8[L1/R1]|r 标签页  •  |cff38BDF8[A]|r 切换滑块 / 选择",
    "|cff38BDF8[R1 / RB]|r": "|cff38BDF8[R1 / RB]|r",
    "|cff444444[L1 / LB]|r": "|cff444444[L1 / LB]|r",
    "|cff444444[R1 / RB]|r": "|cff444444[R1 / RB]|r",
    "|cff4cb8ffPulse:|r Quick setup complete! Type |cffffffff/pulse|r anytime to fine-tune settings.": "|cff4cb8ffPulse:|r 快速设置完成！随时输入 |cffffffff/pulse|r 即可微调各项设置。",
    "|cff4db8ff✔ |r": "|cff4db8ff✔ |r",
    "|cff888888Drag:|r Move Icon": "|cff888888拖动：|r移动图标",
    "|cff888888Loss of control cues are governed by the master switch on the main Pulse page.|r": "|cff888888失去控制提示受 Pulse 主页面上的总开关统一控制。|r",
    "|cff888888Recommended intensity:|r %d%%": "|cff888888推荐强度：|r%d%%",
    "|cffffcc00◀/▶ Adjust Intensity|r   •   %s/%s Lock Value   •   %s Try Texture": "|cffffcc00◀/▶ 调整强度|r   •   %s/%s 锁定数值   •   %s 测试震感",
    "|cffffd100%s|r  |cff00ff00[ACTIVE]|r": "|cffffd100%s|r  |cff00ff00[已激活]|r",
    "|cffffd100/pulseui|r opens it too. |cffffd100/pulse setup|r re-opens Quick Setup, |cffffd100/pulse test <mode>|r plays a shape.": "|cffffd100/pulseui|r 亦可将其打开。|cffffd100/pulse setup|r 重新打开快速设置，|cffffd100/pulse test <mode>|r 试听播放震动形态。",
    "|r, |cffffd100": "|r, |cffffd100",
    "• |r": "• |r",
    "⚔️ Melee DPS": "⚔️ 近战输出",
    "🏹 Ranged DPS": "🏹 远程输出",
    "💚 Healer": "💚 治疗",
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
        if src not in TRANSLATIONS_ZH:
            print(f"ERROR: Missing translation for item [{idx}] (ID {item.get('id')}): {repr(src)}")
            errors += 1
            continue

        tgt = TRANSLATIONS_ZH[src]

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

    out_path = os.path.join(os.path.dirname(__file__), "translated_zhCN_batch1b.json")
    out_data = {
        "items": translated_items
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out_data, f, indent=2, ensure_ascii=False)

    print(f"SUCCESS: Wrote {len(translated_items)} validated translations to {out_path}")

if __name__ == "__main__":
    main()
