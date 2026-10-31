#!/usr/bin/env python3
"""
Generates and validates translated_ruRU_batch1a.json for PulseHaptics Russian localization.
"""

import json
import os
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "tools"))
from validate_catalog import extract_signature, check_color_balance

TRANSLATIONS_RU = {
    # 0..17
    " (page off)|r": " (страница выкл.)|r",
    " (reported as \"": " (определяется как \"",
    " Rules and management are on the Profiles page.": " Правила и управление находятся на странице профилей.",
    " as a whole — both its pulses and the gaps between them, so a multi-hit mode keeps its rhythm instead of the hits stretching into their own gaps. 1.0 is the authored default.": " в целом — как его импульсы, так и паузы между ними, чтобы режим с несколькими ударами сохранял свой ритм, а не растягивал удары на паузы. 1.0 — авторское значение по умолчанию.",
    " right now with whatever's currently set on its sliders above.": " прямо сейчас с текущими настройками ползунков выше.",
    "\" is recommended — pick a different one to change how just this cue feels, without affecting anything else that also uses \"": "» рекомендуется — выберите другой, чтобы изменить ощущение только этого сигнала, не затрагивая остальные, которые также используют «",
    "\" — try one of: ": "» — попробуйте один из следующих: ",
    "%d of %d cues on": "%d из %d сигналов включено",
    "%d of %d on": "%d из %d включено",
    "%s (%d)": "%s (%d)",
    "%s Activate   •   %s Try Texture   •   %s Categories": "%s Активировать   •   %s Проверить текстуру   •   %s Категории",
    "%s Adjust Intensity   •   %s Quick Step   •   |cff38BDF8◀/▶|r Controls   •   %s Try Texture   •   %s Categories": "%s Настроить интенсивность   •   %s Быстрый шаг   •   |cff38BDF8◀/▶|r Элементы управления   •   %s Проверить текстуру   •   %s Категории",
    "%s Browse Modes   •   %s Select   •   %s Cancel": "%s Обзор режимов   •   %s Выбрать   •   %s Отмена",
    "%s Select Mode   •   |cff38BDF8◀/▶|r Controls   •   %s Try Texture   •   %s Categories": "%s Выбрать режим   •   |cff38BDF8◀/▶|r Элементы управления   •   %s Проверить текстуру   •   %s Категории",
    "%s Switch Category   •   %s Navigate   •   %s Select   •   %s Close": "%s Сменить категорию   •   %s Навигация   •   %s Выбрать   •   %s Закрыть",
    "%s Toggle   •   |cff38BDF8▶|r Next Control   •   %s Try Texture   •   %s Categories": "%s Переключить   •   |cff38BDF8▶|r След. элемент управления   •   %s Проверить текстуру   •   %s Категории",
    "%s is felt as %s struck about %.1f times a second, over the bed.": "%s ощущается как %s с частотой около %.1f раз в секунду поверх фонового гула.",
    "%s/%s Try Texture   •   |cff38BDF8◀|r Controls   •   %s Categories": "%s/%s Проверить текстуру   •   |cff38BDF8◀|r Элементы управления   •   %s Категории",

    # 18..39
    "(Toggles all continuous sensations)": "(Переключает все непрерывные ощущения)",
    ", heartbeat, warningbeat": ", heartbeat, warningbeat",
    ", not ": ", а не ",
    ", so there is nothing to test.": ", поэтому тестировать нечего.",
    "0 = one soft pulse. 1 = a sharp lub, then a clearly separate softer dub. Derives the knock timing and intensity split automatically — see lowHealthTexture if you want those set by hand instead.": "0 = один мягкий импульс. 1 = резкий первый удар «тук», затем четко отделенный более мягкий второй «тук». Автоматически рассчитывает интервал между ударами и разделение интенсивности — см. lowHealthTexture, если хотите настроить их вручную.",
    "1 = every scripted event, 3 = only the most severe. Higher means rarer, more significant warnings.": "1 = каждое скриптовое событие, 3 = только самые критические. Чем выше значение, тем реже и важнее предупреждения.",
    "3. World": "3. Мир",
    "4. Interface": "4. Интерфейс",
    "5. Immersion": "5. Погружение",
    "6. Finish": "6. Завершение",
    "< Back": "< Назад",
    "A bright tick when you learn a new ability.": "Четкий щелчок при изучении новой способности.",
    "A crisp mechanical snap on the high motor.": "Четкий механический щелчок на высокочастотном моторе.",
    "A dense 3-pulse tactical flurry.": "Плотный тактический шквал из 3 импульсов.",
    "A dry click when you use an ability that has no cast time.": "Сухой щелчок при использовании способности без времени применения.",
    "A heavy, decisive impact when your current target dies.": "Тяжелый, решительный удар при гибели текущей цели.",
    "A light click when a major UI panel is dismissed.": "Легкий щелчок при закрытии основной панели интерфейса.",
    "A light click when the last confirmation dialog closes.": "Легкий щелчок при закрытии последнего диалога подтверждения.",
    "A light tick when you step away from an NPC or close its window.": "Легкий щелчок, когда вы отходите от NPC или закрываете его окно.",
    "A ringing anvil strike when repairing armor and weapons at a vendor.": "Звонкий удар по наковальне при починке брони и оружия у торговца.",
    "A rising celebratory surge when you gain a level.": "Восходящий торжественный всплеск при повышении уровня.",
    "A sharp alert pulse when your hostile target or focus turns to target you.": "Резкий сигнал тревоги, когда враждебная цель или фокус переключается на вас.",

    # 40..69
    "A sharp deflection tick when a cast of yours is rejected outright — out of range, not facing the target, still on cooldown.": "Резкий щелчок отклонения, когда применение вашего заклинания сразу отклоняется — вне зоны действия, цель вне поля зрения, способность еще на перезарядке.",
    "A sharp deflection tick when the game refuses an action — out of range, facing the wrong way, not enough resource, still on cooldown.": "Резкий щелчок отклонения, когда игра отклоняет действие — вне зоны действия, цель вне поля зрения, недостаточно ресурсов, способность еще на перезарядке.",
    "A sharp snap when a harmful effect lands on you.": "Резкий щелчок при наложении на вас вредоносного эффекта.",
    "A sharp snap with a short tail.": "Резкий щелчок с коротким затуханием.",
    "A short warning before a significant scripted boss ability, using Blizzard's own built-in Boss Warnings timeline.": "Короткое предупреждение перед важной особой способностью босса на основе встроенной шкалы времени предупреждений Blizzard.",
    "A short, sharp tick instead of the normal one when the segment you land on can't be used.": "Короткий резкий щелчок вместо обычного, когда выбранный сектор невозможно использовать.",
    "A single dry click, lighter than a tick.": "Одиночный сухой щелчок, легче обычного щелчка.",
    "A single very short, very hard hit.": "Одиночный очень короткий, очень сильный удар.",
    "A slow low/high oscillation — the caller supplies the phase.": "Медленные колебания между низко- и высокочастотным моторами — фаза передается вызывающей функцией.",
    "A soft tick followed by a brighter one.": "Мягкий щелчок, за которым следует более звонкий.",
    "A soft tick when releasing the group targeting modifier back to normal navigation.": "Мягкий щелчок при отпускании модификатора выбора участников группы и возврате к обычной навигации.",
    "A soft tick when you cancel a radial selection instead of committing to it.": "Мягкий щелчок при отмене выбора в круговом меню вместо подтверждения.",
    "A soft tick when you start auto-attacking with a ranged weapon (Auto Shot, Shoot, wands).": "Мягкий щелчок при начале автоатаки оружием дальнего боя (Автоматическая стрельба, Выстрел, жезлы).",
    "A soft tick when you start meleeing.": "Мягкий щелчок при начале автоатаки в ближнем бою.",
    "A soft tick when you start resting in an inn or major city.": "Мягкий щелчок при переходе в режим отдыха в таверне или столице.",
    "A soft tick when your melee auto-attack stops — catches walking out of range or a target dying without noticing.": "Мягкий щелчок при остановке автоатаки ближнего боя — срабатывает при выходе из зоны действия или незамеченной гибели цели.",
    "A soft, quick tick.": "Мягкий, быстрый щелчок.",
    "A steady, low ambient texture.": "Равномерная, низкая фоновая текстура.",
    "A steady, stronger texture — meant to be scaled by the caller (e.g. speed).": "Равномерная, более выраженная текстура — масштабируется вызывающей функцией (например, по скорости).",
    "A tactile micro-tick each time the stack splitter quantity slider changes.": "Тактильный микрощелчок при каждом изменении ползунка количества в окне разделения стопки.",
    "A tactile recoil kick on every Auto Shot arrow, timed to the real shot, not estimated.": "Тактильная отдача при каждом выстреле «Автоматической стрельбы», синхронизированная с реальным выстрелом, а не приблизительная.",
    "A tap when a confirmation dialog opens.": "Легкий импульс при открытии диалога подтверждения.",
    "A tap when an NPC or world object opens a window nothing else here covers.": "Легкий импульс, когда NPC или объект игрового мира открывает окно, не охваченное другими сигналами.",
    "A texture that builds as your gliding speed climbs toward a boost.": "Текстура, нарастающая по мере того, как скорость планирования приближается к ускорению.",
    "A tick when a book, plaque, gravestone or signpost opens to be read.": "Щелчок при открытии для чтения книги, таблички, надгробия или указателя.",
    "A tick when a piece of your gear's durability drops into the low or broken range.": "Щелчок, когда прочность элемента вашей экипировки опускается до низкого уровня или ломается.",
    "A tiny blip when you gain experience.": "Крошечный импульс при получении опыта.",
    "A tiny low blip, for things that happen often.": "Крошечный низкий импульс для часто происходящих событий.",
    "A triumphant dual-tone chime when you earn an achievement.": "Торжественный двухтональный перезвон при получении достижения.",
    "A very light micro-pulse.": "Очень легкий микроимпульс.",

    # 70..99
    "A very light tick per combo point, building toward a full resource.": "Очень легкий щелчок за каждый прием серии, нарастающий по мере заполнения ресурса.",
    "A very light tick when your equipped gear changes.": "Очень легкий щелчок при смене надетой экипировки.",
    "A very short, sharp tick when you avoid an incoming attack.": "Очень короткий резкий щелчок при избежании входящей атаки.",
    "AFK or DND toggled": "Переключение статуса «Отошел» или «Не беспокоить»",
    "Ability pulse": "Импульс способности",
    "Achievement earned": "Получено достижение",
    "Action bar page changed": "Смена страницы панели команд",
    "Action bars": "Панели команд",
    "Action failed": "Действие не удалось",
    "Action feedback": "Отклик на действия",
    "Activate": "Активировать",
    "Active Profile: |cffffd100%s|r": "Активный профиль: |cffffd100%s|r",
    "Active profile": "Активный профиль",
    "Actuator profile: %s\n%s": "Профиль привода: %s\n%s",
    "Addon language": "Язык модификации",
    "Adjust your global master vibration strength. Individual cues can always be fine-tuned in settings.": "Настройте общую мастер-силу вибрации. Отдельные сигналы всегда можно точно настроить в параметрах.",
    "Advanced Settings": "Расширенные настройки",
    "Also fires when you cancel a cast yourself, or move out of range — it means \"your cast did not finish\", not specifically \"you were kicked\".": "Также срабатывает, когда вы сами отменяете заклинание или выходите из зоны действия — это означает «заклинание не завершено», а не обязательно «вас сбили».",
    "Also fires when you switch to a target that is already mid-cast.": "Также срабатывает, когда вы переключаетесь на цель, уже применяющую заклинание.",
    "Alternates between the motors — an unsteady, rolling feel.": "Чередуется между моторами — создает неравномерное, перекатывающееся ощущение.",
    "Alternating low thud and high snap across motors.": "Чередование низкого глухого удара и высокого щелчка между моторами.",
    "Any other window": "Любое другое окно",
    "Anything else": "Все остальное",
    "Applies only while this character is in this specialization. Switching specialization switches profile with it, with no further action from you.": "Применяется, только когда этот персонаж находится в этой специализации. При смене специализации профиль переключается автоматически.",
    "Applies to this character whatever specialization it is in. This is the rule the profile picker on the Pulse page has always written to.": "Применяется к этому персонажу независимо от специализации. Именно это правило всегда использовалось при выборе профиля на главной странице Pulse.",
    "Attack time (s)": "Время нарастания (с)",
    "Attentive triage. Emergency low health warnings, dispel/CC alerts, kick warnings, and heal completion confirmation with subdued personal damage.": "Внимательное распределение приоритетов: экстренные предупреждения о низком здоровье, оповещения о рассеивании/контроле, предупреждения о сбивании кастов и подтверждение завершения исцеления с приглушенными эффектами получаемого урона.",
    "Auto Shot fired": "Выстрел «Автоматической стрельбы»",
    "Auto-switch in %s": "Автопереключение в %s",
    "Automatic — game language": "Автоматически — язык игры",
    "Automatically switch to %s whenever this character is in this specialization.": "Автоматически переключаться на %s, когда этот персонаж находится в этой специализации.",

    # 100..129
    "Battleground queue ready": "Очередь на поле боя готова",
    "Bed strength": "Интенсивность фонового гула",
    "Bends the relationship between what a cue asks for and what the motor is told. Below 1.0 makes quiet cues louder; above 1.0 makes them quieter and reserves more of the range for strong ones. 1.0 is the unbent default.": "Корректирует кривую зависимости между запросом сигнала и командой мотору. Значения ниже 1.0 делают тихие сигналы громче; выше 1.0 делают их тише, сохраняя больший диапазон для мощных эффектов. 1.0 — стандартная линейная зависимость.",
    "Boss ability warning": "Предупреждение о способности босса",
    "Boss chat warning": "Предупреждение о боссе в чате",
    "Boss encounter ended": "Бой с боссом завершен",
    "Boss encounter started": "Бой с боссом начался",
    "Breakaway floor": "Порог страгивания",
    "Builds from a low hum into a high pulse.": "Нарастает от низкого гула до высокого импульса.",
    "CLICK %s:LeftButton": "CLICK %s:LeftButton",
    "Cancel": "Отмена",
    "Cast outcomes": "Итоги применения заклинаний",
    "Cast presence (low)": "Присутствие применения (низкочастотный)",
    "Cast sent": "Заклинание отправлено",
    "Cast swell peak (high)": "Пик нарастания применения (высокочастотный)",
    "Cast texture, cast finish confirmation, lockout/pushback warnings, proc glows, kick alerts": "Текстура применения заклинаний, подтверждение завершения, предупреждения о блокировке/задержке, свечение проков, оповещения о сбивании",
    "Casting": "Применение заклинаний",
    "Casting texture": "Текстура применения заклинаний",
    "Change threshold": "Порог изменения",
    "Character & Status": "Персонаж и статус",
    "Character state": "Состояние персонажа",
    "Checked via C_UnitAuras.AuraIsBigDefensive. Occurrence only.": "Проверяется через C_UnitAuras.AuraIsBigDefensive. Только факт срабатывания.",
    "Choose the addon display language. Automatic follows the game client. Missing translations use English. Changes apply after /reload.": "Выберите язык интерфейса модификации. Вариант «Автоматически» следует языку игры. Отсутствующие переводы заменяются английскими. Изменения вступают в силу после /reload.",
    "Click to open settings": "Щелкните, чтобы открыть настройки",
    "Climbs this motor slowly from silence to %d%% power over %d seconds, ": "Плавно разгоняет этот мотор от тишины до %d%% мощности за %d сек., ",
    "Close": "Закрыть",
    "Combo point gained": "Получен прием серии",
    "Companion tools": "Сопутствующие инструменты",
    "Competitive & Baseline": "Соревновательные и базовые",
    "Configure tactile rewards for exploring Azeroth and sensory spatial awareness for targeting.": "Настройте тактильный отклик за исследование Азерота и пространственное восприятие целей.",

    # 130..159
    "Confirmation popup appeared": "Появилось окно подтверждения",
    "Confirmation popup closed": "Окно подтверждения закрыто",
    "Confused or possessed": "Замешательство или подчинение",
    "Conversation & reading": "Диалоги и чтение",
    "Copy": "Копировать",
    "Copy \"%s\" to a new custom profile named:": "Скопировать «%s» в новый пользовательский профиль с именем:",
    "Copy \"%s\" to a new profile named:": "Скопировать «%s» в новый профиль с именем:",
    "Copy this profile": "Скопировать этот профиль",
    "Copy...": "Копировать...",
    "Create": "Создать",
    "Create a new editable custom profile that starts as an exact copy of %s.": "Создать новый редактируемый пользовательский профиль, являющийся точной копией %s.",
    "Create a new profile from Registry.lua's stock defaults and switch to it.": "Создать новый профиль со стандартными настройками из Registry.lua и переключиться на него.",
    "Create a new profile that starts as an exact copy of the one in use, and switch to it. The two are independent from the first edit.": "Создать новый профиль, являющийся точной копией текущего, и переключиться на него. Профили становятся полностью независимыми с момента первого изменения.",
    "Create editable copy": "Создать редактируемую копию",
    "Create...": "Создать...",
    "Crest froth & spray": "Пена и брызги гребня волны",
    "Cue index": "Указатель сигналов",
    "Danger start threshold": "Порог начала опасности",
    "Death Knight": "Рыцарь смерти",
    "Debuff received": "Получен отрицательный эффект",
    "Debug logging": "Журнал отладки",
    "Default": "По умолчанию",
    "Default (Balanced Baseline)": "По умолчанию (сбалансированная база)",
    "Default profiles": "Стандартные профили",
    "Defensive": "Защитные способности",
    "Delete": "Удалить",
    "Delete profile \"%s\"? This can't be undone.": "Удалить профиль «%s»? Это действие нельзя отменить.",
    "Delete this profile": "Удалить этот профиль",
    "Delete...": "Удалить...",
    "Device": "Устройство",

    # 160..189
    "Disable All": "Отключить все",
    "Disable all cues": "Отключить все сигналы",
    "Disable all cues in profile": "Отключить все сигналы в профиле",
    "Disable every vibration cue in the active profile in one sweep for quiet testing or building a profile from scratch.": "Отключить сразу все тактильные сигналы в активном профиле для тихого тестирования или создания профиля с нуля.",
    "Disarmed": "Обезоруживание",
    "Displays a shortcut button on the edge of your minimap for quick access to settings and toggling vibration.": "Отображает кнопку на краю миникарты для быстрого доступа к настройкам и переключения вибрации.",
    "Distinctiveness": "Выразительность",
    "Distinguished from cancelling by Blizzard's own `isCancelled` flag, which it sets before ending the selection — so a cancel never counts as a choice.": "Отличается от отмены собственным флагом Blizzard `isCancelled`, устанавливаемым перед завершением выбора, поэтому отмена никогда не считается сделанным выбором.",
    "Doubles as the catch-all: a loss-of-control type this addon does not recognise — a new one added by a patch — fires this generic cue instead of being silently dropped.": "Служит универсальным запасным вариантом: не распознанный модификацией тип потери контроля (например, добавленный в новом патче) вызывает этот общий сигнал вместо тихого игнорирования.",
    "Druid": "Друид",
    "Dual asymmetrical ERM motors, balanced 75ms spin-up": "Два асимметричных ERM-мотора, сбалансированный разгон 75 мс",
    "Dual-motor rumble & vibration schemas": "Схемы двухмоторной вибрации и виброотклика",
    "Duel request": "Запрос дуэли",
    "Dungeon queue popped": "Очередь в подземелье подошла",
    "Dungeon: Caster": "Подземелье: Заклинатель",
    "Dungeon: Caster DPS": "Подземелье: Заклинатель-боец",
    "Dungeon: Healer": "Подземелье: Лекарь",
    "Dungeon: Hunter": "Подземелье: Охотник",
    "Dungeon: Melee": "Подземелье: Ближний бой",
    "Dungeon: Melee DPS": "Подземелье: Боец ближнего боя",
    "Dungeon: Tank": "Подземелье: Танк",
    "Effort peak": "Пик усилия",
    "Empowered cast stage": "Ступень усиленного заклинания",
    "Enable All": "Включить все",
    "Enable Cue": "Включить сигнал",
    "Enable Pulse": "Включить Pulse",
    "Enable all cues": "Включить все сигналы",
    "Enable all cues in profile": "Включить все сигналы в профиле",
    "Enable every vibration cue in the active profile in one sweep for testing and debugging.": "Включить сразу все тактильные сигналы в активном профиле для тестирования и отладки.",
    "Encounter": "Сражение",

    # 190..219
    "Entered a vehicle": "Посадка в транспорт",
    "Entered melee range": "Вход в радиус ближнего боя",
    "Environment": "Окружающий мир",
    "Equipment": "Экипировка",
    "Every character": "Каждый персонаж",
    "Evoker-only in practice. It stays registered for every class and simply never fires for the others.": "На практике только для пробудителей. Остается зарегистрированным для всех классов, но просто не срабатывает для остальных.",
    "Experience gained": "Получен опыт",
    "Experimental": "Экспериментальное",
    "Fast attack time constant used specifically for discrete impacts, clicks, and strikes. Gives snappy transients without making sustained immersion textures harsh.": "Быстрая постоянная времени нарастания, используемая специально для дискретных ударов, щелчков и атак. Обеспечивает резкие переходные процессы, не делая продолжительные текстуры погружения грубыми.",
    "Feared or charmed": "Страх или подчинение",
    "Feel ": "Ощутить ",
    "Feel Strength": "Сила ощущения",
    "Feel this texture": "Ощутить эту текстуру",
    "Feels like": "Ощущается как",
    "Feels like: ": "Ощущается как: ",
    "Find breakaway floor": "Найти порог страгивания",
    "Fires as an empowered cast of yours begins and ends.": "Срабатывает в начале и конце применения вашего усиленного заклинания.",
    "Fires at most ": "Срабатывает не чаще чем ",
    "Fires for any summon confirmation dialog, not only a player summoning you.": "Срабатывает для любого диалога подтверждения призыва, а не только при призыве игроком.",
    "Fires on PLAYER_TARGET_DIED.": "Срабатывает по событию PLAYER_TARGET_DIED.",
    "Fires on input, so it also fires for casts that then fail. That is intentional: this is an input-acknowledgement cue, not a success cue.": "Срабатывает при вводе команды, поэтому срабатывает и для заклинаний, которые затем срываются. Это сделано намеренно: данный сигнал подтверждает ввод, а не успех действия.",
    "Fires on the change itself, not on every flag update.": "Срабатывает при самом изменении, а не при каждом обновлении флага.",
    "Fires on the crossing into low, not repeatedly while low.": "Срабатывает при переходе к низкому уровню, а не непрерывно при низком значении.",
    "Fires on the yellow informational messages the game shows in the top centre of the screen.": "Срабатывает при появлении желтых информационных сообщений по центру в верхней части экрана.",
    "Fires only when a queue enters the ready-to-enter state, not on every status update.": "Срабатывает только тогда, когда очередь переходит в статус готовности к входу, а не при каждом обновлении статуса.",
    "Fires the instant you press a cast, before the server has confirmed it.": "Срабатывает в момент нажатия заклинания, еще до подтверждения сервером.",
    "Fires upon arrival at destination when player control is restored.": "Срабатывает по прибытии в пункт назначения, когда управление возвращается игроку.",
    "Fires when a battleground or arena queue is ready to enter.": "Срабатывает, когда очередь на поле боя или арену готова к входу.",
    "Fires when a boss encounter begins.": "Срабатывает при начале боя с боссом.",
    "Fires when a boss encounter ends, in victory or in a wipe.": "Срабатывает при завершении боя с боссом — победой или гибелью группы.",

    # 220..249
    "Fires when a flight master's map opens.": "Срабатывает при открытии карты распорядителя полетов.",
    "Fires when a loading screen ends and the world is back.": "Срабатывает, когда экран загрузки завершается и мир снова отображается.",
    "Fires when a quest is handed in and its reward is taken.": "Срабатывает при сдаче задания и получении награды.",
    "Fires when a quest's completion page opens, ready to hand in.": "Срабатывает при открытии страницы завершения задания, готового к сдаче.",
    "Fires when a quest's detail page opens, ready to accept.": "Срабатывает при открытии страницы с описанием задания, готового к принятию.",
    "Fires when a ready check completes or times out.": "Срабатывает при завершении проверки готовности или истечении ее времени.",
    "Fires when a ready check starts.": "Срабатывает при начале проверки готовности.",
    "Fires when a role check starts.": "Срабатывает при начале проверки ролей.",
    "Fires when a trade window opens.": "Срабатывает при открытии окна торговли.",
    "Fires when a vendor window opens.": "Срабатывает при открытии окна торговца.",
    "Fires when an innkeeper asks to make this your home.": "Срабатывает, когда трактирщик предлагает сделать таверну вашим домом.",
    "Fires when gaining money with an open vendor window.": "Срабатывает при получении денег при открытом окне торговца.",
    "Fires when group leadership changes hands.": "Срабатывает при передаче лидерства в группе.",
    "Fires when one of your own casts begins.": "Срабатывает при начале применения вашего заклинания.",
    "Fires when one of your own casts completes successfully — distinct from a cast simply ending.": "Срабатывает при успешном завершении вашего заклинания — в отличие от простого окончания применения.",
    "Fires when one of your own casts ends, whether or not it completed.": "Срабатывает при окончании применения вашего заклинания независимо от того, завершилось ли оно успешно.",
    "Fires when someone challenges you to a duel.": "Срабатывает, когда кто-то вызывает вас на дуэль.",
    "Fires when someone invites you to a group.": "Срабатывает, когда вас приглашают в группу.",
    "Fires when someone joins or leaves your group.": "Срабатывает, когда кто-то присоединяется к вашей группе или покидает ее.",
    "Fires when someone offers you a resurrection and the accept dialog appears.": "Срабатывает, когда вам предлагают воскрешение и появляется окно подтверждения.",
    "Fires when someone summons you and the accept dialog appears.": "Срабатывает, когда вас призывают и появляется окно подтверждения.",
    "Fires when spending money with an open vendor window.": "Срабатывает при трате денег при открытом окне торговца.",
    "Fires when the stable master's window opens.": "Срабатывает при открытии окна смотрителя стойл.",
    "Fires when you accept a quest.": "Срабатывает при принятии задания.",
    "Fires when you are confused or possessed (CONFUSE, POSSESS).": "Срабатывает при замешательстве или подчинении (CONFUSE, POSSESS).",
    "Fires when you are disarmed (DISARM).": "Срабатывает при обезоруживании (DISARM).",
    "Fires when you are feared or charmed (FEAR, FEAR_MECHANIC, CHARM).": "Срабатывает при страхе или подчинении (FEAR, FEAR_MECHANIC, CHARM).",
    "Fires when you are resurrected or leave ghost form.": "Срабатывает при воскрешении или выходе из формы призрака.",
    "Fires when you are rooted in place (ROOT). You can still act, so this is a rung below the cues that stop you entirely.": "Срабатывает при обездвиживании (ROOT). Вы все еще можете действовать, поэтому данный сигнал на ступень ниже тех, что полностью сковывают вас.",
    "Fires when you are silenced (SILENCE).": "Срабатывает при наложении немоты (SILENCE).",

    # 250..279
    "Fires when you are stunned (STUN, STUN_MECHANIC).": "Срабатывает при оглушении (STUN, STUN_MECHANIC).",
    "Fires when you change target, including when you clear it.": "Срабатывает при смене цели, включая ее сброс.",
    "Fires when you die.": "Срабатывает при вашей гибели.",
    "Fires when you enter a new zone.": "Срабатывает при входе в новую зону.",
    "Fires when you enter a vehicle and your action bar is replaced.": "Срабатывает при посадке в транспорт, когда заменяется ваша панель команд.",
    "Fires when you leave a vehicle and your own action bar returns.": "Срабатывает при выходе из транспорта, когда возвращается ваша панель команд.",
    "Fires when you set or clear your focus target.": "Срабатывает при установке или сбросе фокуса.",
    "Fires when your class's secondary resource fills up — combo points, holy power, soul shards, chi, arcane charges, essence or runes, whichever your specialisation uses.": "Срабатывает при заполнении вторичного ресурса вашего класса — приемов серии, энергии Света, осколков душ, ци, зарядов чародейства, сущности или рун, в зависимости от специализации.",
    "Fires when your focus target begins casting.": "Срабатывает, когда цель в фокусе начинает применение заклинания.",
    "Fires when your own away or do-not-disturb flag actually changes.": "Срабатывает при фактическом изменении вашего статуса «Отошел» или «Не беспокоить».",
    "Flight map opened": "Карта полетов открыта",
    "Focus": "Фокус",
    "Focus changed": "Фокус изменен",
    "Focus started casting": "Фокус начал применение заклинания",
    "Focused element became unavailable": "Выбранный элемент стал недоступен",
    "Four rapid, sharp ticks.": "Четыре быстрых резких щелчка.",
    "Gait strength": "Интенсивность походки",
    "Gasp peak": "Пик нехватки воздуха",
    "Gear needs repair": "Экипировке требуется починка",
    "Generic / Unknown": "Общие / Неизвестные",
    "Generic / unknown": "Общие / неизвестные",
    "Gentle steady engine-like cruise vibration while riding flight master gryphons, bats, or wyverns.": "Мягкая равномерная крейсерская вибрация при полете на грифонах, нетопырях или вивернах распорядителя полетов.",
    "Group changes": "Изменения в группе",
    "Group readiness": "Готовность группы",
    "Group roster changed": "Состав группы изменен",
    "Group targeting active": "Выбор участников группы активен",
    "Group targeting released": "Выбор участников группы отключен",
    "Hardware & Presets": "Оборудование и пресеты",
    "Harvest complete": "Сбор ресурсов завершен",
    "Heal casts and low-health triage": "Применение исцеления и приоритеты низкого здоровья",

    # 280..309
    "Healing received": "Получено исцеление",
    "Health & survival": "Здоровье и выживание",
    "Heart rate (BPM)": "Пульс (уд./мин)",
    "Heart rate (calm), BPM": "Пульс (в покое), уд./мин",
    "Heavy Impacts": "Тяжелые удары",
    "Heavy left counterweight (85ms), light right counterweight (45ms)": "Тяжелый левый противовес (85 мс), легкий правый противовес (45 мс)",
    "High Motor Only": "Только высокочастотный мотор",
    "High motor": "Высокочастотный мотор",
    "Hooks StackSplitFrame:UpdateStackText.": "Перехватывает StackSplitFrame:UpdateStackText.",
    "How far the hum swells either side of its baseline. 0 is a flat hold.": "Насколько сильно гул отклоняется в обе стороны от базового уровня. 0 — ровное удержание.",
    "How fast the wingbeat-style undulation cycles.": "Скорость волнообразных циклов взмахов крыльев.",
    "How many seconds before the scripted moment this fires.": "За сколько секунд до запланированного момента это срабатывает.",
    "How pronounced each stroke is against its own baseline. Higher values (0.80-1.0) allow the counterweight to physically spin down during the glide phase between strokes. 0 is a flat drag with no rhythm at all.": "Насколько отчетлив каждый взмах относительно базового уровня. Более высокие значения (0.80–1.0) позволяют противовесу физически замедляться во время фазы планирования между взмахами. 0 — ровное скольжение без ритма.",
    "How steady the low motor stays regardless of speed. Only audible while actually gliding.": "Насколько стабильно работает низкочастотный мотор независимо от скорости. Ощущается только во время планирования.",
    "How strong the hum gets by the moment a regular cast completes. Only audible if \"Casting texture\" is also enabled on its own tab.": "Насколько усиливается гул к моменту завершения обычного заклинания. Ощущается, только если «Текстура применения заклинаний» также включена на соответствующей вкладке.",
    "Hunter": "Охотник",
    "If nothing is happening": "Если ничего не происходит",
    "Immediately switch to %s for the current character.": "Немедленно переключиться на %s для текущего персонажа.",
    "Immersion: Caster": "Погружение: Заклинатель",
    "Immersion: Melee": "Погружение: Ближний бой",
    "Immersion: Ranged": "Погружение: Дальний бой",
    "Impact attack (s)": "Атака удара (с)",
    "Initial software voltage boost applied during transient onset to accelerate the motor rapidly to target speed. 1.0 is disabled.": "Начальное программное повышение напряжения во время переходного процесса для быстрого разгона мотора до целевой скорости. 1.0 — отключено.",
    "Innkeeper hearth prompt": "Предложение трактирщика сделать таверну домом",
    "Input device changed": "Устройство ввода изменено",
    "Input mode": "Режим ввода",
    "Instant ability used": "Использована мгновенная способность",
    "Intensity": "Интенсивность",
    "Intensity Slider": "Ползунок интенсивности",
    "Interface": "Интерфейс",

    # 310..329
    "Interface & Accessibility": "Интерфейс и специальные возможности",
    "Interface message": "Сообщение интерфейса",
    "Interface tab changed": "Вкладка интерфейса изменена",
    "Inventory full warning": "Предупреждение о переполнении инвентаря",
    "Invites & requests": "Приглашения и запросы",
    "Jarring physical weapon clatter": "Резкий металлический скрежет оружия",
    "LRA (Classic ERM Emulation)": "LRA (классическая эмуляция ERM)",
    "Landed": "Приземление",
    "Leave this scope with no opinion and let the next one decide.": "Оставить эту область без явного выбора и позволить следующему уровню принять решение.",
    "Left a vehicle": "Выход из транспорта",
    "Left melee range": "Выход из радиуса ближнего боя",
    "Level up": "Новый уровень",
    "Lifecycle (advanced)": "Жизненный цикл (расширенный)",
    "Load its starting values": "Загрузить начальные значения",
    "Loading screen finished": "Экран загрузки завершен",
    "Loss of control": "Потеря контроля",
    "Loss of control cues": "Сигналы потери контроля",
    "Low Health Heartbeat": "Сердцебиение при низком здоровье",
    "Low Motor Only": "Только низкочастотный мотор",
}

def main():
    batch_path = "/home/deck/developer/wow/PulseSensation/localization/batches/batch1a_ui_navigation.json"
    with open(batch_path, "r", encoding="utf-8") as f:
        batch = json.load(f)

    items = batch["items"]
    print(f"Loaded batch1a with {len(items)} items.")
    print(f"TRANSLATIONS_RU dict has {len(TRANSLATIONS_RU)} entries.")

    errors = 0
    translated_items = []

    for idx, it in enumerate(items):
        src = it["source"]
        if src not in TRANSLATIONS_RU:
            print(f"ERROR: Missing translation for item [{idx}] (id={it.get('id')}): {repr(src)}")
            errors += 1
            continue

        tgt = TRANSLATIONS_RU[src]

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

    out_path = "/home/deck/developer/wow/PulseSensation/localization/batches/translated_ruRU_batch1a.json"
    out_data = {
        "items": translated_items
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out_data, f, indent=2, ensure_ascii=False)

    print(f"SUCCESS: Wrote {len(translated_items)} validated translations to {out_path}")

if __name__ == "__main__":
    main()
