#!/usr/bin/env python3
"""
Generates and validates translated_zhCN_batch1a.json for PulseHaptics Simplified Chinese localization.
"""

import json
import os
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "tools"))
from validate_catalog import extract_signature, check_color_balance

TRANSLATIONS_ZH = {
    # 0..17
    " (page off)|r": " (页面已关闭)|r",
    " (reported as \"": " (识别为 \"",
    " Rules and management are on the Profiles page.": " 规则与管理请见配置文件页面。",
    " as a whole — both its pulses and the gaps between them, so a multi-hit mode keeps its rhythm instead of the hits stretching into their own gaps. 1.0 is the authored default.": " 作为一个整体——包括其脉冲以及脉冲之间的间隔，从而使多重打击模式保持其固有节奏，而不是让打击延伸进入其自身的间隔中。1.0 为作者设定的默认值。",
    " right now with whatever's currently set on its sliders above.": " 立即以其上方滑块的当前设定播放。",
    "\" is recommended — pick a different one to change how just this cue feels, without affecting anything else that also uses \"": "\" 为推荐设置——选择其它模式可以仅改变该提示的震感，而不会影响其他同样使用 \"",
    "\" — try one of: ": "\" —— 推荐尝试：",
    "%d of %d cues on": "%d / %d 个提示已开启",
    "%d of %d on": "%d / %d 个已开启",
    "%s (%d)": "%s (%d)",
    "%s Activate   •   %s Try Texture   •   %s Categories": "%s 激活   •   %s 测试震感   •   %s 分类",
    "%s Adjust Intensity   •   %s Quick Step   •   |cff38BDF8◀/▶|r Controls   •   %s Try Texture   •   %s Categories": "%s 调整强度   •   %s 快捷步进   •   |cff38BDF8◀/▶|r 控制项   •   %s 测试震感   •   %s 分类",
    "%s Browse Modes   •   %s Select   •   %s Cancel": "%s 浏览模式   •   %s 选择   •   %s 取消",
    "%s Select Mode   •   |cff38BDF8◀/▶|r Controls   •   %s Try Texture   •   %s Categories": "%s 选择模式   •   |cff38BDF8◀/▶|r 控制项   •   %s 测试震感   •   %s 分类",
    "%s Switch Category   •   %s Navigate   •   %s Select   •   %s Close": "%s 切换分类   •   %s 导航   •   %s 选择   •   %s 关闭",
    "%s Toggle   •   |cff38BDF8▶|r Next Control   •   %s Try Texture   •   %s Categories": "%s 切换   •   |cff38BDF8▶|r 下一个控制项   •   %s 测试震感   •   %s 分类",
    "%s is felt as %s struck about %.1f times a second, over the bed.": "%s 的感受如同 %s 在持续底震之上每秒敲击约 %.1f 次。",
    "%s/%s Try Texture   •   |cff38BDF8◀|r Controls   •   %s Categories": "%s/%s 测试震感   •   |cff38BDF8◀|r 控制项   •   %s 分类",

    # 18..32
    "(Toggles all continuous sensations)": "(切换所有持续震感)",
    ", heartbeat, warningbeat": ", heartbeat, warningbeat",
    ", not ": ", 而非 ",
    ", so there is nothing to test.": ", 因此无可测试内容。",
    "0 = one soft pulse. 1 = a sharp lub, then a clearly separate softer dub. Derives the knock timing and intensity split automatically — see lowHealthTexture if you want those set by hand instead.": "0 = 单次柔和脉冲。1 = 清脆的 lub 音，紧接着明显区分的柔和 dub 音。自动计算敲击间隔与强度分配——若想手动调整，请参阅 lowHealthTexture。",
    "1 = every scripted event, 3 = only the most severe. Higher means rarer, more significant warnings.": "1 = 所有脚本事件，3 = 仅最严重的事件。数值越高表示警报越罕见且越关键。",
    "3. World": "3. 世界",
    "4. Interface": "4. 界面",
    "5. Immersion": "5. 沉浸",
    "6. Finish": "6. 完成",
    "< Back": "< 返回",
    "A bright tick when you learn a new ability.": "学会新技能时，产生清脆的提示震动。",
    "A crisp mechanical snap on the high motor.": "轻震马达上清脆的机械敲击震动。",
    "A dense 3-pulse tactical flurry.": "密集的3脉冲战术疾风连击。",
    "A dry click when you use an ability that has no cast time.": "使用瞬发技能时，产生干脆的轻按震动。",

    # 33..65
    "A heavy, decisive impact when your current target dies.": "当前目标死亡时，产生沉重且具决断感的撞击震动。",
    "A light click when a major UI panel is dismissed.": "关闭主要界面面板时，产生轻微的点击震动。",
    "A light click when the last confirmation dialog closes.": "关闭最后一个确认对话框时，产生轻微的点击震动。",
    "A light tick when you step away from an NPC or close its window.": "离开NPC或关闭其窗口时，产生轻微的提示震动。",
    "A ringing anvil strike when repairing armor and weapons at a vendor.": "在商人处修理护甲与武器时，产生铁砧敲击的清脆鸣响震动。",
    "A rising celebratory surge when you gain a level.": "提升等级时，产生逐渐增强的庆祝跃动震感。",
    "A sharp alert pulse when your hostile target or focus turns to target you.": "敌对目标或焦点目标转向以你为目标时，产生尖锐的警报脉冲。",
    "A sharp deflection tick when a cast of yours is rejected outright — out of range, not facing the target, still on cooldown.": "你的施法被直接拒绝时（超出范围、未面对目标、仍在冷却中），产生清脆的偏斜提示震动。",
    "A sharp deflection tick when the game refuses an action — out of range, facing the wrong way, not enough resource, still on cooldown.": "游戏拒绝某个动作时（超出范围、朝向错误、资源不足、仍在冷却中），产生清脆的偏斜提示震动。",
    "A sharp snap when a harmful effect lands on you.": "受到有害效果影响时，产生清脆的抽击震动。",
    "A sharp snap with a short tail.": "带有短尾音的清脆抽击震动。",
    "A short warning before a significant scripted boss ability, using Blizzard's own built-in Boss Warnings timeline.": "在重大首领脚本技能施放前发出简短预警，使用暴雪自带的内置首领预警时间线。",
    "A short, sharp tick instead of the normal one when the segment you land on can't be used.": "当停留的扇区不可用时，以简短干脆的提示震动代替常规震动。",
    "A single dry click, lighter than a tick.": "单次干脆的点击震动，比轻触提示更微弱。",
    "A single very short, very hard hit.": "单次极短促、极其强烈的冲击。",
    "A slow low/high oscillation — the caller supplies the phase.": "缓慢的重震/轻震交替振荡——由调用方提供相位。",
    "A soft tick followed by a brighter one.": "一次轻微的提示震动，随后伴随一次更清脆的提示震动。",
    "A soft tick when releasing the group targeting modifier back to normal navigation.": "松开小队目标修饰键恢复正常导航时，产生柔和的轻微提示震动。",
    "A soft tick when you cancel a radial selection instead of committing to it.": "取消轮盘选择而非确认时，产生柔和的轻微提示震动。",
    "A soft tick when you start auto-attacking with a ranged weapon (Auto Shot, Shoot, wands).": "使用远程武器开始自动攻击（自动射击、射击、魔杖）时，产生柔和的轻微提示震动。",
    "A soft tick when you start meleeing.": "开始近战自动攻击时，产生柔和的轻微提示震动。",
    "A soft tick when you start resting in an inn or major city.": "在旅店或主城进入休息状态时，产生柔和的轻微提示震动。",
    "A soft tick when your melee auto-attack stops — catches walking out of range or a target dying without noticing.": "近战自动攻击停止时产生柔和的轻微提示震动——用于提示走出近战范围或未注意到的目标死亡。",
    "A soft, quick tick.": "柔和短促的轻微提示震动。",
    "A steady, low ambient texture.": "平稳的低频环境氛围震感。",
    "A steady, stronger texture — meant to be scaled by the caller (e.g. speed).": "平稳且更强烈的材质震感——供调用方缩放调节（例如根据速度）。",
    "A tactile micro-tick each time the stack splitter quantity slider changes.": "拆分堆叠数量滑块每次改变时，产生触感微小的提示震动。",
    "A tactile recoil kick on every Auto Shot arrow, timed to the real shot, not estimated.": "每次自动射击箭矢射出时产生真实的后坐力冲击，精确同步于实际射击时刻，而非估算。",
    "A tap when a confirmation dialog opens.": "确认对话框弹出时产生轻触震动。",
    "A tap when an NPC or world object opens a window nothing else here covers.": "NPC或世界物体打开未被其他项涵盖的窗口时产生轻触震动。",
    "A texture that builds as your gliding speed climbs toward a boost.": "随着滑翔速度提升接近加速时逐渐增强的材质震感。",
    "A tick when a book, plaque, gravestone or signpost opens to be read.": "打开书籍、牌匾、墓碑或路标阅读时产生轻微提示震动。",
    "A tick when a piece of your gear's durability drops into the low or broken range.": "某件装备的耐久度降至过低或损坏区间时产生轻微提示震动。",

    # 66..99
    "A tiny blip when you gain experience.": "获得经验值时产生微弱短促的提示震动。",
    "A tiny low blip, for things that happen often.": "适用于频繁发生事件的微弱低频轻颤。",
    "A triumphant dual-tone chime when you earn an achievement.": "获得成就时产生凯旋的双音调清鸣震动。",
    "A very light micro-pulse.": "极轻微的微脉冲震动。",
    "A very light tick per combo point, building toward a full resource.": "每个连击点数产生极轻微的提示震动，向满资源递增。",
    "A very light tick when your equipped gear changes.": "已装备的装备发生变更时产生极轻微的提示震动。",
    "A very short, sharp tick when you avoid an incoming attack.": "避开敌人攻击（闪避/招架/未命中）时产生极短促清脆的提示震动。",
    "AFK or DND toggled": "暂离或请勿打扰状态切换",
    "Ability pulse": "技能脉冲",
    "Achievement earned": "获得成就",
    "Action bar page changed": "动作条分页已切换",
    "Action bars": "动作条",
    "Action failed": "动作失败",
    "Action feedback": "动作反馈",
    "Activate": "激活",
    "Active Profile: |cffffd100%s|r": "当前配置文件：|cffffd100%s|r",
    "Active profile": "当前配置文件",
    "Actuator profile: %s\n%s": "执行器配置文件：%s\n%s",
    "Addon language": "插件语言",
    "Adjust your global master vibration strength. Individual cues can always be fine-tuned in settings.": "调节全局主震动强度。单个提示的强度始终可以在设置中进行微调。",
    "Advanced Settings": "高级设置",
    "Also fires when you cancel a cast yourself, or move out of range — it means \"your cast did not finish\", not specifically \"you were kicked\".": "当你自行取消施法或移出范围时也会触发——它的含义是“你的施法未能完成”，而非特指“你被法术反制/打断”。",
    "Also fires when you switch to a target that is already mid-cast.": "切换至正在施法中的目标时也会触发。",
    "Alternates between the motors — an unsteady, rolling feel.": "在不同马达之间交替——营造不稳定、翻滚的体感。",
    "Alternating low thud and high snap across motors.": "在马达间交替出现低频重击与高频抽击。",
    "Any other window": "任何其他窗口",
    "Anything else": "其他任何内容",
    "Applies only while this character is in this specialization. Switching specialization switches profile with it, with no further action from you.": "仅当此角色处于该专精时生效。切换专精将自动随之切换配置文件，无需任何额外操作。",
    "Applies to this character whatever specialization it is in. This is the rule the profile picker on the Pulse page has always written to.": "无论该角色处于何种专精均生效。这是 Pulse 页面上的配置文件选择器一直以来写入的规则。",
    "Attack time (s)": "起振时间 (秒)",
    "Attentive triage. Emergency low health warnings, dispel/CC alerts, kick warnings, and heal completion confirmation with subdued personal damage.": "专注救急支援。紧急低生命值预警、驱散/控制警报、打断警报以及治疗完成确认，同时降低自身承受伤害的提示干扰。",
    "Auto Shot fired": "自动射击已发射",
    "Auto-switch in %s": "在 %s 中自动切换",
    "Automatic — game language": "自动 — 游戏语言",

    # 100..132
    "Automatically switch to %s whenever this character is in this specialization.": "每当该角色处于此专精时，自动切换至 %s。",
    "Battleground queue ready": "战场排队就绪",
    "Bed strength": "底震强度",
    "Bends the relationship between what a cue asks for and what the motor is told. Below 1.0 makes quiet cues louder; above 1.0 makes them quieter and reserves more of the range for strong ones. 1.0 is the unbent default.": "调节提示请求强度与马达实际输出之间的响应曲线。低于1.0会放大微弱提示；高于1.0会削弱微弱提示并将更多动态范围留给强烈冲击。1.0 为未作调节的默认值。",
    "Boss ability warning": "首领技能预警",
    "Boss chat warning": "首领喊话预警",
    "Boss encounter ended": "首领战结束",
    "Boss encounter started": "首领战开始",
    "Breakaway floor": "启转阈值",
    "Builds from a low hum into a high pulse.": "从低频嗡鸣逐渐增强为高频脉冲。",
    "CLICK %s:LeftButton": "CLICK %s:LeftButton",
    "Cancel": "取消",
    "Cast outcomes": "施法结果",
    "Cast presence (low)": "施法常驻感 (低频)",
    "Cast sent": "施法请求已发送",
    "Cast swell peak (high)": "施法渐强峰值 (高频)",
    "Cast texture, cast finish confirmation, lockout/pushback warnings, proc glows, kick alerts": "施法材质震动、施法完成确认、沉默/推迟施法预警、触发高亮、打断警报",
    "Casting": "正在施法",
    "Casting texture": "施法材质震动",
    "Change threshold": "变更阈值",
    "Character & Status": "角色与状态",
    "Character state": "角色状态",
    "Checked via C_UnitAuras.AuraIsBigDefensive. Occurrence only.": "通过 C_UnitAuras.AuraIsBigDefensive 检查。仅在发生时触发。",
    "Choose the addon display language. Automatic follows the game client. Missing translations use English. Changes apply after /reload.": "选择插件显示语言。“自动”将跟随游戏客户端语言。缺失的本地化文本将回退显示为英文。更改在重载界面（/reload）后生效。",
    "Click to open settings": "点击打开设置",
    "Climbs this motor slowly from silence to %d%% power over %d seconds, ": "使该马达从静音缓慢攀升至 %d%% 功率，历时 %d 秒，",
    "Close": "关闭",
    "Combo point gained": "获得连击点数",
    "Companion tools": "配套工具",
    "Competitive & Baseline": "竞技与基础",
    "Configure tactile rewards for exploring Azeroth and sensory spatial awareness for targeting.": "配置探索艾泽拉斯的触觉奖励以及用于目标选择的空间感知震动。",
    "Confirmation popup appeared": "确认弹窗出现",
    "Confirmation popup closed": "确认弹窗关闭",

    # 133..165
    "Confused or possessed": "迷乱或被心控",
    "Conversation & reading": "对话与阅读",
    "Copy": "复制",
    "Copy \"%s\" to a new custom profile named:": "将“%s”复制到名为以下内容的新自定义配置文件：",
    "Copy \"%s\" to a new profile named:": "将“%s”复制到名为以下内容的新配置文件：",
    "Copy this profile": "复制此配置文件",
    "Copy...": "复制...",
    "Create": "创建",
    "Create a new editable custom profile that starts as an exact copy of %s.": "创建一个新的可编辑自定义配置文件，初始内容为 %s 的完整副本。",
    "Create a new profile from Registry.lua's stock defaults and switch to it.": "基于 Registry.lua 的内置默认值创建新配置文件并切换至该文件。",
    "Create a new profile that starts as an exact copy of the one in use, and switch to it. The two are independent from the first edit.": "创建一个以当前使用配置为完全副本的新配置文件并切换至该文件。从初次编辑起两者即完全独立。",
    "Create editable copy": "创建可编辑副本",
    "Create...": "创建...",
    "Crest froth & spray": "浪头泡沫与飞沫",
    "Cue index": "提示索引",
    "Danger start threshold": "危险起始阈值",
    "Death Knight": "死亡骑士",
    "Debuff received": "受到减益效果",
    "Debug logging": "调试日志",
    "Default": "默认",
    "Default (Balanced Baseline)": "默认 (平衡基准)",
    "Default profiles": "默认配置文件",
    "Defensive": "防御",
    "Delete": "删除",
    "Delete profile \"%s\"? This can't be undone.": "确定删除配置文件“%s”？此操作无法撤销。",
    "Delete this profile": "删除此配置文件",
    "Delete...": "删除...",
    "Device": "设备",
    "Disable All": "全部禁用",
    "Disable all cues": "禁用所有提示",
    "Disable all cues in profile": "禁用配置文件中的所有提示",
    "Disable every vibration cue in the active profile in one sweep for quiet testing or building a profile from scratch.": "一键禁用当前配置文件中的每个震动提示，用于静音测试或从零开始构建配置文件。",
    "Disarmed": "被缴械",

    # 166..199
    "Displays a shortcut button on the edge of your minimap for quick access to settings and toggling vibration.": "在小地图边缘显示快捷按钮，以便快速打开设置和切换震动开关。",
    "Distinctiveness": "辨识度",
    "Distinguished from cancelling by Blizzard's own `isCancelled` flag, which it sets before ending the selection — so a cancel never counts as a choice.": "通过暴雪自带的 `isCancelled` 标记与取消操作区分开来，该标记在结束选择前设置——因此取消绝不会被计为确认选择。",
    "Doubles as the catch-all: a loss-of-control type this addon does not recognise — a new one added by a patch — fires this generic cue instead of being silently dropped.": "兼作通用兜底处理：若插件无法识别某种失控类型（例如补丁新增的类型），将触发此通用提示，而非被静默忽略。",
    "Druid": "德鲁伊",
    "Dual asymmetrical ERM motors, balanced 75ms spin-up": "双非对称 ERM 马达，平衡 75 毫秒起转",
    "Dual-motor rumble & vibration schemas": "双马达震动方案",
    "Duel request": "决斗请求",
    "Dungeon queue popped": "地下城排队就绪",
    "Dungeon: Caster": "地下城：法系",
    "Dungeon: Caster DPS": "地下城：法系输出",
    "Dungeon: Healer": "地下城：治疗",
    "Dungeon: Hunter": "地下城：猎人",
    "Dungeon: Melee": "地下城：近战",
    "Dungeon: Melee DPS": "地下城：近战输出",
    "Dungeon: Tank": "地下城：坦克",
    "Effort peak": "发力峰值",
    "Empowered cast stage": "蓄力施法阶段",
    "Enable All": "全部启用",
    "Enable Cue": "启用提示",
    "Enable Pulse": "启用 Pulse",
    "Enable all cues": "启用所有提示",
    "Enable all cues in profile": "启用配置文件中的所有提示",
    "Enable every vibration cue in the active profile in one sweep for testing and debugging.": "一键启用当前配置文件中的每个震动提示，用于测试与调试。",
    "Encounter": "首领战斗",
    "Entered a vehicle": "进入载具",
    "Entered melee range": "进入近战范围",
    "Environment": "环境",
    "Equipment": "装备",
    "Every character": "所有角色",
    "Evoker-only in practice. It stays registered for every class and simply never fires for the others.": "实际上仅适用于唤魔师。它对所有职业保持注册状态，但对其他职业绝不触发。",
    "Experience gained": "获得经验值",
    "Experimental": "实验性",
    "Fast attack time constant used specifically for discrete impacts, clicks, and strikes. Gives snappy transients without making sustained immersion textures harsh.": "专用于离散撞击、点击与打击的快速起振时间常数。提供干脆利落的瞬态响应，同时避免持续沉浸材质震感变得生硬刺手。",

    # 200..232
    "Feared or charmed": "恐惧或魅惑",
    "Feel ": "体验 ",
    "Feel Strength": "体感强度",
    "Feel this texture": "体验此震感",
    "Feels like": "体感效果",
    "Feels like: ": "体感效果：",
    "Find breakaway floor": "查找启转阈值",
    "Fires as an empowered cast of yours begins and ends.": "在你的蓄力施法开始和结束时触发。",
    "Fires at most ": "最多触发 ",
    "Fires for any summon confirmation dialog, not only a player summoning you.": "在出现任何召唤确认对话框时触发，不仅限于其他玩家召唤你。",
    "Fires on PLAYER_TARGET_DIED.": "在收到 PLAYER_TARGET_DIED 事件时触发。",
    "Fires on input, so it also fires for casts that then fail. That is intentional: this is an input-acknowledgement cue, not a success cue.": "在按键输入时触发，因此对于随后失败的施法也会触发。这是有意设计的：本提示为按键确认提示，而非成功提示。",
    "Fires on the change itself, not on every flag update.": "仅在状态本身发生改变时触发，而非在每次标记刷新时触发。",
    "Fires on the crossing into low, not repeatedly while low.": "仅在耐久度跌入过低区间时触发一次，而非在低耐久状态下重复触发。",
    "Fires on the yellow informational messages the game shows in the top centre of the screen.": "在屏幕顶部中央显示黄色游戏提示信息时触发。",
    "Fires only when a queue enters the ready-to-enter state, not on every status update.": "仅在排队进入“可进入”状态时触发，而非在每次状态更新时触发。",
    "Fires the instant you press a cast, before the server has confirmed it.": "在你按下施法瞬间触发，无需等待服务器确认。",
    "Fires upon arrival at destination when player control is restored.": "在到达目的地且玩家角色控制权恢复时触发。",
    "Fires when a battleground or arena queue is ready to enter.": "战场或竞技场排队准备就绪可进入时触发。",
    "Fires when a boss encounter begins.": "首领战开始时触发。",
    "Fires when a boss encounter ends, in victory or in a wipe.": "首领战结束时触发（无论是获胜还是团灭）。",
    "Fires when a flight master's map opens.": "飞行管理员地图打开时触发。",
    "Fires when a loading screen ends and the world is back.": "加载界面结束且游戏世界重新显现时触发。",
    "Fires when a quest is handed in and its reward is taken.": "交付任务并领取奖励时触发。",
    "Fires when a quest's completion page opens, ready to hand in.": "任务完成页面打开、准备交付任务时触发。",
    "Fires when a quest's detail page opens, ready to accept.": "任务详情页面打开、准备接受任务时触发。",
    "Fires when a ready check completes or times out.": "就位确认完成或超时时触发。",
    "Fires when a ready check starts.": "发起就位确认时触发。",
    "Fires when a role check starts.": "发起职责确认时触发。",
    "Fires when a trade window opens.": "交易窗口打开时触发。",
    "Fires when a vendor window opens.": "商人窗口打开时触发。",
    "Fires when an innkeeper asks to make this your home.": "旅店老板询问是否将此处设为家时触发。",
    "Fires when gaining money with an open vendor window.": "商人窗口打开状态下获得金钱时触发。",

    # 233..265
    "Fires when group leadership changes hands.": "队伍领袖变更时触发。",
    "Fires when one of your own casts begins.": "你自身的施法开始时触发。",
    "Fires when one of your own casts completes successfully — distinct from a cast simply ending.": "你自身的施法成功完成时触发——与施法单纯结束有所区别。",
    "Fires when one of your own casts ends, whether or not it completed.": "你自身的施法结束时触发（无论是否成功完成）。",
    "Fires when someone challenges you to a duel.": "有人向你发起决斗挑战时触发。",
    "Fires when someone invites you to a group.": "有人邀请你加入队伍时触发。",
    "Fires when someone joins or leaves your group.": "有人加入或离开你的队伍时触发。",
    "Fires when someone offers you a resurrection and the accept dialog appears.": "有人对你施放复活且弹出接受复活对话框时触发。",
    "Fires when someone summons you and the accept dialog appears.": "有人召唤你且弹出接受召唤对话框时触发。",
    "Fires when spending money with an open vendor window.": "商人窗口打开状态下花费金钱时触发。",
    "Fires when the stable master's window opens.": "兽栏管理员窗口打开时触发。",
    "Fires when you accept a quest.": "接受任务时触发。",
    "Fires when you are confused or possessed (CONFUSE, POSSESS).": "当你陷入迷乱或被心控（CONFUSE、POSSESS）时触发。",
    "Fires when you are disarmed (DISARM).": "当你被缴械（DISARM）时触发。",
    "Fires when you are feared or charmed (FEAR, FEAR_MECHANIC, CHARM).": "当你受到恐惧或魅惑（FEAR、FEAR_MECHANIC、CHARM）时触发。",
    "Fires when you are resurrected or leave ghost form.": "当你复活或脱离灵魂形态时触发。",
    "Fires when you are rooted in place (ROOT). You can still act, so this is a rung below the cues that stop you entirely.": "当你被定身（ROOT）时触发。你仍可行动，因此其提示级别低于完全限制行动的失控效果。",
    "Fires when you are silenced (SILENCE).": "当你被沉默（SILENCE）时触发。",
    "Fires when you are stunned (STUN, STUN_MECHANIC).": "当你被昏迷（STUN、STUN_MECHANIC）时触发。",
    "Fires when you change target, including when you clear it.": "切换目标时触发（包括清除当前目标）。",
    "Fires when you die.": "死亡时触发。",
    "Fires when you enter a new zone.": "进入新区域时触发。",
    "Fires when you enter a vehicle and your action bar is replaced.": "进入载具且动作条被替换时触发。",
    "Fires when you leave a vehicle and your own action bar returns.": "离开载具且原有动作条恢复时触发。",
    "Fires when you set or clear your focus target.": "设置或清除焦点目标时触发。",
    "Fires when your class's secondary resource fills up — combo points, holy power, soul shards, chi, arcane charges, essence or runes, whichever your specialisation uses.": "当职业副资源蓄满时触发——连击点数、圣能、灵魂碎片、真气、奥术充能、精华或符文，视当前专精所用资源而定。",
    "Fires when your focus target begins casting.": "焦点目标开始施法时触发。",
    "Fires when your own away or do-not-disturb flag actually changes.": "自身的暂离或请勿打扰状态发生改变时触发。",
    "Flight map opened": "飞行地图已打开",
    "Focus": "焦点",
    "Focus changed": "焦点目标已更改",
    "Focus started casting": "焦点目标开始施法",
    "Focused element became unavailable": "焦点元素变为不可用",

    # 266..299
    "Four rapid, sharp ticks.": "四次快速清脆的提示震动。",
    "Gait strength": "步态强度",
    "Gasp peak": "喘息峰值",
    "Gear needs repair": "装备需要修理",
    "Generic / Unknown": "通用 / 未知",
    "Generic / unknown": "通用 / 未知",
    "Gentle steady engine-like cruise vibration while riding flight master gryphons, bats, or wyverns.": "骑乘飞行管理员的狮鹫、蝙蝠或双足飞龙时，产生类似引擎巡航般平缓稳定的震动。",
    "Group changes": "队伍变动",
    "Group readiness": "队伍就位",
    "Group roster changed": "队伍名册已变更",
    "Group targeting active": "小队目标选择已激活",
    "Group targeting released": "小队目标选择已释放",
    "Hardware & Presets": "硬件与预设",
    "Harvest complete": "采集完成",
    "Heal casts and low-health triage": "治疗施法与低生命急救",
    "Healing received": "受到治疗",
    "Health & survival": "生命与生存",
    "Heart rate (BPM)": "心率 (BPM)",
    "Heart rate (calm), BPM": "心率 (平静)，BPM",
    "Heavy Impacts": "重度撞击",
    "Heavy left counterweight (85ms), light right counterweight (45ms)": "左侧重配重块 (85毫秒)，右侧轻配重块 (45毫秒)",
    "High Motor Only": "仅轻震马达",
    "High motor": "轻震马达",
    "Hooks StackSplitFrame:UpdateStackText.": "挂钩 StackSplitFrame:UpdateStackText。",
    "How far the hum swells either side of its baseline. 0 is a flat hold.": "嗡鸣声围绕基线起伏膨胀的幅度。0 表示平稳维持。",
    "How fast the wingbeat-style undulation cycles.": "振翅式起伏波动的循环速率。",
    "How many seconds before the scripted moment this fires.": "在脚本时刻到来前多少秒触发。",
    "How pronounced each stroke is against its own baseline. Higher values (0.80-1.0) allow the counterweight to physically spin down during the glide phase between strokes. 0 is a flat drag with no rhythm at all.": "每个划行动作相对于其基线的明显程度。较高的数值（0.80-1.0）允许配重块在两次划水之间的滑行阶段自然减速。0 为完全没有节奏的单调拖拽。",
    "How steady the low motor stays regardless of speed. Only audible while actually gliding.": "无论速度如何，重震马达保持平稳的程度。仅在实际滑翔时可被感知。",
    "How strong the hum gets by the moment a regular cast completes. Only audible if \"Casting texture\" is also enabled on its own tab.": "常规施法完成瞬间嗡鸣达到的强度。仅在对应标签页中同样启用了“施法材质震动”时方可感知。",
    "Hunter": "猎人",
    "If nothing is happening": "如果没有事件发生",
    "Immediately switch to %s for the current character.": "立即为当前角色切换至 %s。",
    "Immersion: Caster": "沉浸：法系",

    # 300..329
    "Immersion: Melee": "沉浸：近战",
    "Immersion: Ranged": "沉浸：远程",
    "Impact attack (s)": "撞击起振 (秒)",
    "Initial software voltage boost applied during transient onset to accelerate the motor rapidly to target speed. 1.0 is disabled.": "在瞬态开始时应用的初始软件电压增强，以使马达迅速加速至目标转速。1.0 为禁用。",
    "Innkeeper hearth prompt": "旅店老板炉石绑定提示",
    "Input device changed": "输入设备已更改",
    "Input mode": "输入模式",
    "Instant ability used": "已使用瞬发技能",
    "Intensity": "强度",
    "Intensity Slider": "强度滑块",
    "Interface": "界面",
    "Interface & Accessibility": "界面与辅助功能",
    "Interface message": "界面信息",
    "Interface tab changed": "界面标签页已切换",
    "Inventory full warning": "背包已满警告",
    "Invites & requests": "邀请与请求",
    "Jarring physical weapon clatter": "剧烈的物理武器碰撞声",
    "LRA (Classic ERM Emulation)": "LRA (经典 ERM 模拟)",
    "Landed": "着陆",
    "Leave this scope with no opinion and let the next one decide.": "保持当前作用域未设定，交由下一层级决定。",
    "Left a vehicle": "离开载具",
    "Left melee range": "离开近战范围",
    "Level up": "升级",
    "Lifecycle (advanced)": "生命周期 (高级)",
    "Load its starting values": "加载其初始预设值",
    "Loading screen finished": "加载界面结束",
    "Loss of control": "失去控制",
    "Loss of control cues": "失去控制提示",
    "Low Health Heartbeat": "低生命值心跳",
    "Low Motor Only": "仅重震马达",
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

    out_path = "/home/deck/developer/wow/PulseSensation/localization/batches/translated_zhCN_batch1a.json"
    out_data = {
        "items": translated_items
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out_data, f, indent=2, ensure_ascii=False)

    print(f"SUCCESS: Wrote {len(translated_items)} validated translations to {out_path}")

if __name__ == "__main__":
    main()
