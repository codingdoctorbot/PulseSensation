#!/usr/bin/env python3
"""
Generates and validates translated_esES_batch1a.json for PulseHaptics European Spanish localization.
"""

import json
import os
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "tools"))
from validate_catalog import extract_signature, check_color_balance

TRANSLATIONS_ES = {
    # 0..17
    " (page off)|r": " (página desactivada)|r",
    " (reported as \"": " (detectado como \"",
    " Rules and management are on the Profiles page.": " Las reglas y la gestión están en la página Perfiles.",
    " as a whole — both its pulses and the gaps between them, so a multi-hit mode keeps its rhythm instead of the hits stretching into their own gaps. 1.0 is the authored default.": " en su conjunto: tanto sus pulsos como los intervalos entre ellos, de modo que un modo con múltiples impactos mantenga su ritmo en lugar de que los impactos se prolonguen en sus propios intervalos. 1.0 es el valor predeterminado del autor.",
    " right now with whatever's currently set on its sliders above.": " ahora mismo con la configuración actual de sus deslizadores superiores.",
    "\" is recommended — pick a different one to change how just this cue feels, without affecting anything else that also uses \"": "\" es la recomendada; elige otra para cambiar cómo se siente esta señal en particular, sin alterar nada más que también utilice \"",
    "\" — try one of: ": "\" — prueba una de estas opciones: ",
    "%d of %d cues on": "%d de %d señales activadas",
    "%d of %d on": "%d de %d activadas",
    "%s (%d)": "%s (%d)",
    "%s Activate   •   %s Try Texture   •   %s Categories": "%s Activar   •   %s Probar textura   •   %s Categorías",
    "%s Adjust Intensity   •   %s Quick Step   •   |cff38BDF8◀/▶|r Controls   •   %s Try Texture   •   %s Categories": "%s Ajustar intensidad   •   %s Paso rápido   •   |cff38BDF8◀/▶|r Controles   •   %s Probar textura   •   %s Categorías",
    "%s Browse Modes   •   %s Select   •   %s Cancel": "%s Explorar modos   •   %s Seleccionar   •   %s Cancelar",
    "%s Select Mode   •   |cff38BDF8◀/▶|r Controls   •   %s Try Texture   •   %s Categories": "%s Seleccionar modo   •   |cff38BDF8◀/▶|r Controles   •   %s Probar textura   •   %s Categorías",
    "%s Switch Category   •   %s Navigate   •   %s Select   •   %s Close": "%s Cambiar categoría   •   %s Navegar   •   %s Seleccionar   •   %s Cerrar",
    "%s Toggle   •   |cff38BDF8▶|r Next Control   •   %s Try Texture   •   %s Categories": "%s Alternar   •   |cff38BDF8▶|r Siguiente control   •   %s Probar textura   •   %s Categorías",
    "%s is felt as %s struck about %.1f times a second, over the bed.": "%s se siente como %s marcado unas %.1f veces por segundo, sobre la base continua.",
    "%s/%s Try Texture   •   |cff38BDF8◀|r Controls   •   %s Categories": "%s/%s Probar textura   •   |cff38BDF8◀|r Controles   •   %s Categorías",

    # 18..39
    "(Toggles all continuous sensations)": "(Alterna todas las sensaciones continuas)",
    ", heartbeat, warningbeat": ", heartbeat, warningbeat",
    ", not ": ", no ",
    ", so there is nothing to test.": ", por lo que no hay nada que probar.",
    "0 = one soft pulse. 1 = a sharp lub, then a clearly separate softer dub. Derives the knock timing and intensity split automatically — see lowHealthTexture if you want those set by hand instead.": "0 = un pulso suave. 1 = un «lub» seco, seguido de un «dub» más suave claramente separado. Calcula el intervalo del golpe y la división de intensidad automáticamente; consulta lowHealthTexture si prefieres configurarlos manualmente.",
    "1 = every scripted event, 3 = only the most severe. Higher means rarer, more significant warnings.": "1 = cada evento programado, 3 = solo los más graves. Un valor mayor implica avisos más infrecuentes y de mayor relevancia.",
    "3. World": "3. Mundo",
    "4. Interface": "4. Interfaz",
    "5. Immersion": "5. Inmersión",
    "6. Finish": "6. Finalizar",
    "< Back": "< Atrás",
    "A bright tick when you learn a new ability.": "Un chasquido ligero al aprender una nueva facultad.",
    "A crisp mechanical snap on the high motor.": "Un chasquido mecánico seco en el motor rápido.",
    "A dense 3-pulse tactical flurry.": "Una densa ráfaga táctica de 3 pulsos.",
    "A dry click when you use an ability that has no cast time.": "Un clic seco al usar una facultad sin tiempo de lanzamiento.",
    "A heavy, decisive impact when your current target dies.": "Un impacto pesado y decisivo cuando muere tu objetivo actual.",
    "A light click when a major UI panel is dismissed.": "Un clic ligero cuando se descarta un panel principal de la interfaz.",
    "A light click when the last confirmation dialog closes.": "Un clic ligero cuando se cierra el último diálogo de confirmación.",
    "A light tick when you step away from an NPC or close its window.": "Un chasquido ligero al alejarte de un PNJ o cerrar su ventana.",
    "A ringing anvil strike when repairing armor and weapons at a vendor.": "Un golpe de yunque resonante al reparar armaduras y armas en un comerciante.",
    "A rising celebratory surge when you gain a level.": "Una oleada festiva creciente al subir de nivel.",
    "A sharp alert pulse when your hostile target or focus turns to target you.": "Un pulso de alerta agudo cuando tu objetivo hostil o tu foco pasa a seleccionarte como objetivo.",

    # 40..69
    "A sharp deflection tick when a cast of yours is rejected outright — out of range, not facing the target, still on cooldown.": "Un chasquido seco de desvío cuando un lanzamiento tuyo es rechazado por completo: fuera de alcance, de espaldas al objetivo o aún en reutilización.",
    "A sharp deflection tick when the game refuses an action — out of range, facing the wrong way, not enough resource, still on cooldown.": "Un chasquido seco de desvío cuando el juego rechaza una acción: fuera de alcance, mirando hacia el lado erróneo, recursos insuficientes o aún en reutilización.",
    "A sharp snap when a harmful effect lands on you.": "Un chasquido agudo cuando te alcanza un efecto perjudicial.",
    "A sharp snap with a short tail.": "Un chasquido agudo con una estela corta.",
    "A short warning before a significant scripted boss ability, using Blizzard's own built-in Boss Warnings timeline.": "Un breve aviso antes de una facultad importante programada del jefe, utilizando la cronología integrada de avisos de jefe de Blizzard.",
    "A short, sharp tick instead of the normal one when the segment you land on can't be used.": "Un chasquido corto y seco en lugar del habitual cuando el segmento en el que te sitúas no se puede utilizar.",
    "A single dry click, lighter than a tick.": "Un único clic seco, más suave que un chasquido.",
    "A single very short, very hard hit.": "Un único golpe muy corto y muy contundente.",
    "A slow low/high oscillation — the caller supplies the phase.": "Una oscilación lenta entre frecuencias graves y agudas: el invocador proporciona la fase.",
    "A soft tick followed by a brighter one.": "Un chasquido suave seguido de uno más brillante.",
    "A soft tick when releasing the group targeting modifier back to normal navigation.": "Un chasquido suave al soltar el modificador de selección de grupo para volver a la navegación normal.",
    "A soft tick when you cancel a radial selection instead of committing to it.": "Un chasquido suave al cancelar una selección radial en lugar de confirmarla.",
    "A soft tick when you start auto-attacking with a ranged weapon (Auto Shot, Shoot, wands).": "Un chasquido suave al empezar el ataque automático con un arma a distancia (Disparo automático, Disparar, varitas).",
    "A soft tick when you start meleeing.": "Un chasquido suave al iniciar el combate cuerpo a cuerpo.",
    "A soft tick when you start resting in an inn or major city.": "Un chasquido suave al empezar a descansar en una taberna o ciudad importante.",
    "A soft tick when your melee auto-attack stops — catches walking out of range or a target dying without noticing.": "Un chasquido suave cuando se detiene tu ataque automático cuerpo a cuerpo: detecta cuando te sales de alcance o un objetivo muere sin darte cuenta.",
    "A soft, quick tick.": "Un chasquido suave y rápido.",
    "A steady, low ambient texture.": "Una textura ambiental constante y grave.",
    "A steady, stronger texture — meant to be scaled by the caller (e.g. speed).": "Una textura constante más intensa, pensada para ser escalada por el invocador (p. ej., según la velocidad).",
    "A tactile micro-tick each time the stack splitter quantity slider changes.": "Un microchasquido táctil cada vez que cambia el deslizador de cantidad al dividir montones.",
    "A tactile recoil kick on every Auto Shot arrow, timed to the real shot, not estimated.": "Un retroceso táctil con cada flecha de Disparo automático, sincronizado con el disparo real, sin estimaciones.",
    "A tap when a confirmation dialog opens.": "Un toque cuando se abre un cuadro de diálogo de confirmación.",
    "A tap when an NPC or world object opens a window nothing else here covers.": "Un toque cuando un PNJ u objeto del mundo abre una ventana no cubierta por ninguna otra opción.",
    "A texture that builds as your gliding speed climbs toward a boost.": "Una textura que se intensifica a medida que tu velocidad de planeo aumenta hacia un impulso.",
    "A tick when a book, plaque, gravestone or signpost opens to be read.": "Un chasquido cuando se abre un libro, placa, lápida o poste indicador para ser leído.",
    "A tick when a piece of your gear's durability drops into the low or broken range.": "Un chasquido cuando la durabilidad de una pieza de tu equipo cae a un nivel bajo o se rompe.",
    "A tiny blip when you gain experience.": "Un pitido diminuto al ganar experiencia.",
    "A tiny low blip, for things that happen often.": "Un pitido diminuto y grave, para eventos que suceden con frecuencia.",
    "A triumphant dual-tone chime when you earn an achievement.": "Un campanilleo triunfal de dos tonos al obtener un logro.",
    "A very light micro-pulse.": "Un micropulso muy ligero.",

    # 70..99
    "A very light tick per combo point, building toward a full resource.": "Un chasquido muy ligero por cada punto de combo, intensificándose hacia el recurso completo.",
    "A very light tick when your equipped gear changes.": "Un chasquido muy ligero cuando cambia tu equipo equipado.",
    "A very short, sharp tick when you avoid an incoming attack.": "Un chasquido muy corto y seco cuando evitas un ataque recibido.",
    "AFK or DND toggled": "Ausente o No molestar alternado",
    "Ability pulse": "Pulso de facultad",
    "Achievement earned": "Logro conseguido",
    "Action bar page changed": "Página de la barra de acción cambiada",
    "Action bars": "Barras de acción",
    "Action failed": "Acción fallida",
    "Action feedback": "Respuesta de acción",
    "Activate": "Activar",
    "Active Profile: |cffffd100%s|r": "Perfil activo: |cffffd100%s|r",
    "Active profile": "Perfil activo",
    "Actuator profile: %s\n%s": "Perfil del actuador: %s\n%s",
    "Addon language": "Idioma del accesorio",
    "Adjust your global master vibration strength. Individual cues can always be fine-tuned in settings.": "Ajusta la intensidad maestra global de la vibración. Las señales individuales siempre se pueden calibrar en los ajustes.",
    "Advanced Settings": "Ajustes avanzados",
    "Also fires when you cancel a cast yourself, or move out of range — it means \"your cast did not finish\", not specifically \"you were kicked\".": "También se activa cuando cancelas tú mismo un lanzamiento o te sales del alcance: significa que «tu lanzamiento no terminó», no específicamente que «te hayan interrumpido».",
    "Also fires when you switch to a target that is already mid-cast.": "También se activa al cambiar a un objetivo que ya está en pleno lanzamiento.",
    "Alternates between the motors — an unsteady, rolling feel.": "Alterna entre los motores: una sensación ondulante e inestable.",
    "Alternating low thud and high snap across motors.": "Golpe sordo y chasquido agudo alternados entre los motores.",
    "Any other window": "Cualquier otra ventana",
    "Anything else": "Cualquier otra cosa",
    "Applies only while this character is in this specialization. Switching specialization switches profile with it, with no further action from you.": "Se aplica solo mientras este personaje use esta especialización. Al cambiar de especialización cambiará de perfil automáticamente, sin ninguna otra acción por tu parte.",
    "Applies to this character whatever specialization it is in. This is the rule the profile picker on the Pulse page has always written to.": "Se aplica a este personaje en cualquier especialización en la que se encuentre. Esta es la regla en la que siempre ha escrito el selector de perfiles de la página de Pulse.",
    "Attack time (s)": "Tiempo de ataque (s)",
    "Attentive triage. Emergency low health warnings, dispel/CC alerts, kick warnings, and heal completion confirmation with subdued personal damage.": "Triaje atento: avisos de emergencia por salud baja, alertas de disipación y control de masas, avisos de interrupción y confirmación de sanación completada con daño personal atenuado.",
    "Auto Shot fired": "Disparo automático disparado",
    "Auto-switch in %s": "Cambio automático en %s",
    "Automatic — game language": "Automático: idioma del juego",
    "Automatically switch to %s whenever this character is in this specialization.": "Cambiar automáticamente a %s siempre que este personaje esté en esta especialización.",

    # 100..129
    "Battleground queue ready": "Cola del campo de batalla lista",
    "Bed strength": "Intensidad de la base continua",
    "Bends the relationship between what a cue asks for and what the motor is told. Below 1.0 makes quiet cues louder; above 1.0 makes them quieter and reserves more of the range for strong ones. 1.0 is the unbent default.": "Modifica la curva de respuesta entre lo que solicita una señal y lo que recibe el motor. Por debajo de 1.0 intensifica las señales débiles; por encima de 1.0 las atenúa y reserva más rango para las señales fuertes. 1.0 es el valor predeterminado sin modificación.",
    "Boss ability warning": "Aviso de facultad de jefe",
    "Boss chat warning": "Aviso de chat de jefe",
    "Boss encounter ended": "Encuentro con jefe finalizado",
    "Boss encounter started": "Encuentro con jefe iniciado",
    "Breakaway floor": "Umbral de arranque",
    "Builds from a low hum into a high pulse.": "Aumenta desde un zumbido grave hasta un pulso agudo.",
    "CLICK %s:LeftButton": "CLICK %s:LeftButton",
    "Cancel": "Cancelar",
    "Cast outcomes": "Resultados de lanzamientos",
    "Cast presence (low)": "Presencia de lanzamiento (motor lento)",
    "Cast sent": "Lanzamiento enviado",
    "Cast swell peak (high)": "Pico de aumento de lanzamiento (motor rápido)",
    "Cast texture, cast finish confirmation, lockout/pushback warnings, proc glows, kick alerts": "Textura de lanzamiento, confirmación de lanzamiento completado, avisos de bloqueo/retroceso, destellos de activación y alertas de interrupción",
    "Casting": "Lanzamiento",
    "Casting texture": "Textura de lanzamiento",
    "Change threshold": "Umbral de cambio",
    "Character & Status": "Personaje y estado",
    "Character state": "Estado del personaje",
    "Checked via C_UnitAuras.AuraIsBigDefensive. Occurrence only.": "Comprobado mediante C_UnitAuras.AuraIsBigDefensive. Solo aparición.",
    "Choose the addon display language. Automatic follows the game client. Missing translations use English. Changes apply after /reload.": "Elige el idioma visual del accesorio. Automático sigue el cliente del juego. Las traducciones faltantes usan inglés. Los cambios se aplican tras /reload.",
    "Click to open settings": "Clic para abrir los ajustes",
    "Climbs this motor slowly from silence to %d%% power over %d seconds, ": "Aumenta este motor lentamente desde el silencio hasta el %d%% de potencia a lo largo de %d segundos, ",
    "Close": "Cerrar",
    "Combo point gained": "Punto de combo obtenido",
    "Companion tools": "Herramientas complementarias",
    "Competitive & Baseline": "Competitivo y básico",
    "Configure tactile rewards for exploring Azeroth and sensory spatial awareness for targeting.": "Configura respuestas táctiles al explorar Azeroth y percepción espacial sensorial para la selección de objetivos.",

    # 130..159
    "Confirmation popup appeared": "Apareció ventana emergente de confirmación",
    "Confirmation popup closed": "Se cerró ventana emergente de confirmación",
    "Confused or possessed": "Confuso o poseído",
    "Conversation & reading": "Conversación y lectura",
    "Copy": "Copiar",
    "Copy \"%s\" to a new custom profile named:": "Copiar «%s» a un nuevo perfil personalizado llamado:",
    "Copy \"%s\" to a new profile named:": "Copiar «%s» a un nuevo perfil llamado:",
    "Copy this profile": "Copiar este perfil",
    "Copy...": "Copiar...",
    "Create": "Crear",
    "Create a new editable custom profile that starts as an exact copy of %s.": "Crea un nuevo perfil personalizado editable que comienza como una copia exacta de %s.",
    "Create a new profile from Registry.lua's stock defaults and switch to it.": "Crea un nuevo perfil a partir de los valores predeterminados de Registry.lua y cambia a él.",
    "Create a new profile that starts as an exact copy of the one in use, and switch to it. The two are independent from the first edit.": "Crea un nuevo perfil que comienza como una copia exacta del que está en uso y cambia a él. Ambos serán independientes desde la primera edición.",
    "Create editable copy": "Crear copia editable",
    "Create...": "Crear...",
    "Crest froth & spray": "Espuma de cresta y salpicadura",
    "Cue index": "Índice de señales",
    "Danger start threshold": "Umbral de inicio de peligro",
    "Death Knight": "Caballero de la Muerte",
    "Debuff received": "Perjuicio recibido",
    "Debug logging": "Registro de depuración",
    "Default": "Predeterminado",
    "Default (Balanced Baseline)": "Predeterminado (Base equilibrada)",
    "Default profiles": "Perfiles predeterminados",
    "Defensive": "Defensivo",
    "Delete": "Eliminar",
    "Delete profile \"%s\"? This can't be undone.": "¿Eliminar el perfil «%s»? Esto no se puede deshacer.",
    "Delete this profile": "Eliminar este perfil",
    "Delete...": "Eliminar...",
    "Device": "Dispositivo",

    # 160..189
    "Disable All": "Desactivar todo",
    "Disable all cues": "Desactivar todas las señales",
    "Disable all cues in profile": "Desactivar todas las señales del perfil",
    "Disable every vibration cue in the active profile in one sweep for quiet testing or building a profile from scratch.": "Desactiva todas las señales de vibración del perfil activo a la vez para realizar pruebas silenciosas o crear un perfil desde cero.",
    "Disarmed": "Desarmado",
    "Displays a shortcut button on the edge of your minimap for quick access to settings and toggling vibration.": "Muestra un botón de acceso directo en el borde de tu minimapa para acceder rápidamente a los ajustes y alternar la vibración.",
    "Distinctiveness": "Distintividad",
    "Distinguished from cancelling by Blizzard's own `isCancelled` flag, which it sets before ending the selection — so a cancel never counts as a choice.": "Se distingue de la cancelación mediante el propio indicador `isCancelled` de Blizzard, que se activa antes de terminar la selección, de modo que cancelar nunca cuenta como una elección.",
    "Doubles as the catch-all: a loss-of-control type this addon does not recognise — a new one added by a patch — fires this generic cue instead of being silently dropped.": "Sirve también como comodín: cualquier tipo de pérdida de control que este accesorio no reconozca (como los añadidos por un parche) activará esta señal genérica en lugar de ignorarse en silencio.",
    "Druid": "Druida",
    "Dual asymmetrical ERM motors, balanced 75ms spin-up": "Motores ERM asimétricos duales, aceleración equilibrada de 75 ms",
    "Dual-motor rumble & vibration schemas": "Esquemas de vibración y temblor de motor dual",
    "Duel request": "Petición de duelo",
    "Dungeon queue popped": "Cola de mazmorra disponible",
    "Dungeon: Caster": "Mazmorra: Taumaturgo",
    "Dungeon: Caster DPS": "Mazmorra: DPS taumaturgo",
    "Dungeon: Healer": "Mazmorra: Sanador",
    "Dungeon: Hunter": "Mazmorra: Cazador",
    "Dungeon: Melee": "Mazmorra: Cuerpo a cuerpo",
    "Dungeon: Melee DPS": "Mazmorra: DPS cuerpo a cuerpo",
    "Dungeon: Tank": "Mazmorra: Tanque",
    "Effort peak": "Pico de esfuerzo",
    "Empowered cast stage": "Fase de lanzamiento potenciado",
    "Enable All": "Activar todo",
    "Enable Cue": "Activar señal",
    "Enable Pulse": "Activar Pulse",
    "Enable all cues": "Activar todas las señales",
    "Enable all cues in profile": "Activar todas las señales del perfil",
    "Enable every vibration cue in the active profile in one sweep for testing and debugging.": "Activa todas las señales de vibración del perfil activo a la vez para realizar pruebas y depuración.",
    "Encounter": "Encuentro",

    # 190..219
    "Entered a vehicle": "Subido a un vehículo",
    "Entered melee range": "Entrado en alcance cuerpo a cuerpo",
    "Environment": "Entorno",
    "Equipment": "Equipo",
    "Every character": "Todos los personajes",
    "Evoker-only in practice. It stays registered for every class and simply never fires for the others.": "En la práctica, solo para evocadores. Permanece registrada para todas las clases y sencillamente nunca se activa para las demás.",
    "Experience gained": "Experiencia obtenida",
    "Experimental": "Experimental",
    "Fast attack time constant used specifically for discrete impacts, clicks, and strikes. Gives snappy transients without making sustained immersion textures harsh.": "Constante de tiempo de ataque rápido utilizada específicamente para impactos individuales, clics y golpes. Proporciona transitorios secos sin que las texturas de inmersión continuas resulten bruscas.",
    "Feared or charmed": "Aterrorizado o seducido",
    "Feel ": "Sentir ",
    "Feel Strength": "Intensidad de sensación",
    "Feel this texture": "Sentir esta textura",
    "Feels like": "Se siente como",
    "Feels like: ": "Se siente como: ",
    "Find breakaway floor": "Buscar umbral de arranque",
    "Fires as an empowered cast of yours begins and ends.": "Se activa cuando un lanzamiento potenciado tuyo comienza y termina.",
    "Fires at most ": "Se activa como máximo ",
    "Fires for any summon confirmation dialog, not only a player summoning you.": "Se activa con cualquier diálogo de confirmación de invocación, no solo cuando un jugador te invoca.",
    "Fires on PLAYER_TARGET_DIED.": "Se activa con PLAYER_TARGET_DIED.",
    "Fires on input, so it also fires for casts that then fail. That is intentional: this is an input-acknowledgement cue, not a success cue.": "Se activa con la pulsación, por lo que también se activa en lanzamientos que luego fallan. Es intencionado: es una señal de confirmación de entrada, no de éxito.",
    "Fires on the change itself, not on every flag update.": "Se activa con el cambio en sí, no con cada actualización de estado.",
    "Fires on the crossing into low, not repeatedly while low.": "Se activa al cruzar el umbral bajo, no de forma repetida mientras permanezca bajo.",
    "Fires on the yellow informational messages the game shows in the top centre of the screen.": "Se activa con los mensajes informativos amarillos que el juego muestra en la parte superior central de la pantalla.",
    "Fires only when a queue enters the ready-to-enter state, not on every status update.": "Se activa solo cuando una cola pasa al estado lista para entrar, no con cada actualización de estado.",
    "Fires the instant you press a cast, before the server has confirmed it.": "Se activa en el instante en que pulsas un lanzamiento, antes de que el servidor lo haya confirmado.",
    "Fires upon arrival at destination when player control is restored.": "Se activa al llegar a tu destino cuando se restablece el control del jugador.",
    "Fires when a battleground or arena queue is ready to enter.": "Se activa cuando una cola de campo de batalla o arena está lista para entrar.",
    "Fires when a boss encounter begins.": "Se activa cuando comienza un encuentro contra un jefe.",
    "Fires when a boss encounter ends, in victory or in a wipe.": "Se activa cuando termina un encuentro contra un jefe, ya sea con victoria o con derrota de todo el grupo.",

    # 220..249
    "Fires when a flight master's map opens.": "Se activa cuando se abre el mapa de un maestro de vuelo.",
    "Fires when a loading screen ends and the world is back.": "Se activa cuando termina una pantalla de carga y reaparece el mundo.",
    "Fires when a quest is handed in and its reward is taken.": "Se activa cuando se entrega una misión y se recoge su recompensa.",
    "Fires when a quest's completion page opens, ready to hand in.": "Se activa cuando se abre la página de completar misión, lista para entregar.",
    "Fires when a quest's detail page opens, ready to accept.": "Se activa cuando se abre la página de detalles de una misión, lista para aceptar.",
    "Fires when a ready check completes or times out.": "Se activa cuando una comprobación de listos finaliza o se agota su tiempo.",
    "Fires when a ready check starts.": "Se activa cuando se inicia una comprobación de listos.",
    "Fires when a role check starts.": "Se activa cuando se inicia una comprobación de función.",
    "Fires when a trade window opens.": "Se activa cuando se abre una ventana de comercio.",
    "Fires when a vendor window opens.": "Se activa cuando se abre una ventana de comerciante.",
    "Fires when an innkeeper asks to make this your home.": "Se activa cuando un tabernero te ofrece fijar este lugar como tu hogar.",
    "Fires when gaining money with an open vendor window.": "Se activa al recibir dinero con una ventana de comerciante abierta.",
    "Fires when group leadership changes hands.": "Se activa cuando el liderazgo del grupo cambia de manos.",
    "Fires when one of your own casts begins.": "Se activa cuando comienza uno de tus propios lanzamientos.",
    "Fires when one of your own casts completes successfully — distinct from a cast simply ending.": "Se activa cuando uno de tus propios lanzamientos se completa con éxito: a diferencia de que simplemente termine.",
    "Fires when one of your own casts ends, whether or not it completed.": "Se activa cuando finaliza uno de tus propios lanzamientos, se haya completado o no.",
    "Fires when someone challenges you to a duel.": "Se activa cuando alguien te reta a un duelo.",
    "Fires when someone invites you to a group.": "Se activa cuando alguien te invita a un grupo.",
    "Fires when someone joins or leaves your group.": "Se activa cuando alguien se une a tu grupo o lo abandona.",
    "Fires when someone offers you a resurrection and the accept dialog appears.": "Se activa cuando alguien te ofrece una resurrección y aparece el cuadro de diálogo para aceptar.",
    "Fires when someone summons you and the accept dialog appears.": "Se activa cuando alguien te invoca y aparece el cuadro de diálogo para aceptar.",
    "Fires when spending money with an open vendor window.": "Se activa al gastar dinero con una ventana de comerciante abierta.",
    "Fires when the stable master's window opens.": "Se activa cuando se abre la ventana del maestro de establos.",
    "Fires when you accept a quest.": "Se activa cuando aceptas una misión.",
    "Fires when you are confused or possessed (CONFUSE, POSSESS).": "Se activa cuando estás confuso o poseído (CONFUSE, POSSESS).",
    "Fires when you are disarmed (DISARM).": "Se activa cuando estás desarmado (DISARM).",
    "Fires when you are feared or charmed (FEAR, FEAR_MECHANIC, CHARM).": "Se activa cuando estás aterrorizado o seducido (FEAR, FEAR_MECHANIC, CHARM).",
    "Fires when you are resurrected or leave ghost form.": "Se activa cuando resucitas o abandonas la forma de fantasma.",
    "Fires when you are rooted in place (ROOT). You can still act, so this is a rung below the cues that stop you entirely.": "Se activa cuando estás inmovilizado en el sitio (ROOT). Aún puedes actuar, por lo que está un peldaño por debajo de las señales que te detienen por completo.",
    "Fires when you are silenced (SILENCE).": "Se activa cuando estás silenciado (SILENCE).",

    # 250..279
    "Fires when you are stunned (STUN, STUN_MECHANIC).": "Se activa cuando estás aturdido (STUN, STUN_MECHANIC).",
    "Fires when you change target, including when you clear it.": "Se activa cuando cambias de objetivo, incluso cuando lo deseleccionas.",
    "Fires when you die.": "Se activa cuando mueres.",
    "Fires when you enter a new zone.": "Se activa cuando entras en una nueva zona.",
    "Fires when you enter a vehicle and your action bar is replaced.": "Se activa cuando subes a un vehículo y se reemplaza tu barra de acción.",
    "Fires when you leave a vehicle and your own action bar returns.": "Se activa cuando bajas de un vehículo y regresa tu propia barra de acción.",
    "Fires when you set or clear your focus target.": "Se activa cuando estableces o eliminas tu objetivo del foco.",
    "Fires when your class's secondary resource fills up — combo points, holy power, soul shards, chi, arcane charges, essence or runes, whichever your specialisation uses.": "Se activa cuando se llena el recurso secundario de tu clase: puntos de combo, poder sagrado, fragmentos de alma, chi, cargas arcanas, esencia o runas, según lo que use tu especialización.",
    "Fires when your focus target begins casting.": "Se activa cuando tu objetivo del foco comienza a lanzar un hechizo.",
    "Fires when your own away or do-not-disturb flag actually changes.": "Se activa cuando tu estado de Ausente o No molestar cambia realmente.",
    "Flight map opened": "Mapa de vuelo abierto",
    "Focus": "Foco",
    "Focus changed": "Foco cambiado",
    "Focus started casting": "El foco empezó a lanzar",
    "Focused element became unavailable": "El elemento enfocado ya no está disponible",
    "Four rapid, sharp ticks.": "Cuatro chasquidos rápidos y secos.",
    "Gait strength": "Fuerza de la marcha",
    "Gasp peak": "Pico de jadeo",
    "Gear needs repair": "El equipo necesita reparación",
    "Generic / Unknown": "Genérico / Desconocido",
    "Generic / unknown": "Genérico / desconocido",
    "Gentle steady engine-like cruise vibration while riding flight master gryphons, bats, or wyverns.": "Vibración de crucero suave y constante similar a un motor al montar en grifos, murciélagos o dracoleones de maestros de vuelo.",
    "Group changes": "Cambios de grupo",
    "Group readiness": "Disponibilidad del grupo",
    "Group roster changed": "Lista del grupo modificada",
    "Group targeting active": "Selección de grupo activa",
    "Group targeting released": "Selección de grupo liberada",
    "Hardware & Presets": "Hardware y ajustes preestablecidos",
    "Harvest complete": "Recolección completada",
    "Heal casts and low-health triage": "Lanzamientos de sanación y triaje de salud baja",

    # 280..309
    "Healing received": "Sanación recibida",
    "Health & survival": "Salud y supervivencia",
    "Heart rate (BPM)": "Frecuencia cardíaca (PPM)",
    "Heart rate (calm), BPM": "Frecuencia cardíaca (en reposo), PPM",
    "Heavy Impacts": "Impactos pesados",
    "Heavy left counterweight (85ms), light right counterweight (45ms)": "Contrapeso izquierdo pesado (85 ms), contrapeso derecho ligero (45 ms)",
    "High Motor Only": "Solo motor rápido",
    "High motor": "Motor rápido",
    "Hooks StackSplitFrame:UpdateStackText.": "Intercepta StackSplitFrame:UpdateStackText.",
    "How far the hum swells either side of its baseline. 0 is a flat hold.": "Cuánto oscila el zumbido por encima y por debajo de su base continua. 0 es un nivel plano sin oscilación.",
    "How fast the wingbeat-style undulation cycles.": "La velocidad a la que se suceden los ciclos de ondulación estilo aleteo.",
    "How many seconds before the scripted moment this fires.": "Cuántos segundos antes del momento programado se activa esto.",
    "How pronounced each stroke is against its own baseline. Higher values (0.80-1.0) allow the counterweight to physically spin down during the glide phase between strokes. 0 is a flat drag with no rhythm at all.": "Cómo de pronunciada es cada brazada respecto a su propia base continua. Los valores más altos (0.80-1.0) permiten que el contrapeso desacelere físicamente durante la fase de planeo entre brazadas. 0 es un arrastre plano sin ningún tipo de ritmo.",
    "How steady the low motor stays regardless of speed. Only audible while actually gliding.": "Cómo de estable permanece el motor lento sin importar la velocidad. Solo se percibe mientras se planea activamente.",
    "How strong the hum gets by the moment a regular cast completes. Only audible if \"Casting texture\" is also enabled on its own tab.": "La intensidad que alcanza el zumbido en el instante en que finaliza un lanzamiento normal. Solo se percibe si «Textura de lanzamiento» también está activada en su propia pestaña.",
    "Hunter": "Cazador",
    "If nothing is happening": "Si no está ocurriendo nada",
    "Immediately switch to %s for the current character.": "Cambiar inmediatamente a %s para el personaje actual.",
    "Immersion: Caster": "Inmersión: Taumaturgo",
    "Immersion: Melee": "Inmersión: Cuerpo a cuerpo",
    "Immersion: Ranged": "Inmersión: A distancia",
    "Impact attack (s)": "Ataque del impacto (s)",
    "Initial software voltage boost applied during transient onset to accelerate the motor rapidly to target speed. 1.0 is disabled.": "Aumento inicial de voltaje por software aplicado durante el inicio transitorio para acelerar el motor rápidamente a la velocidad objetivo. 1.0 significa desactivado.",
    "Innkeeper hearth prompt": "Aviso de piedra de hogar del tabernero",
    "Input device changed": "Dispositivo de entrada cambiado",
    "Input mode": "Modo de entrada",
    "Instant ability used": "Facultad instantánea usada",
    "Intensity": "Intensidad",
    "Intensity Slider": "Deslizador de intensidad",
    "Interface": "Interfaz",

    # 310..329
    "Interface & Accessibility": "Interfaz y accesibilidad",
    "Interface message": "Mensaje de interfaz",
    "Interface tab changed": "Pestaña de la interfaz cambiada",
    "Inventory full warning": "Aviso de inventario lleno",
    "Invites & requests": "Invitaciones y peticiones",
    "Jarring physical weapon clatter": "Estridente traqueteo físico de armas",
    "LRA (Classic ERM Emulation)": "LRA (Emulación clásica de ERM)",
    "Landed": "Aterrizado",
    "Leave this scope with no opinion and let the next one decide.": "Deja este ámbito sin preferencia y permite que el siguiente decida.",
    "Left a vehicle": "Bajado de un vehículo",
    "Left melee range": "Salido del alcance cuerpo a cuerpo",
    "Level up": "Subida de nivel",
    "Lifecycle (advanced)": "Ciclo de vida (avanzado)",
    "Load its starting values": "Cargar sus valores iniciales",
    "Loading screen finished": "Pantalla de carga finalizada",
    "Loss of control": "Pérdida de control",
    "Loss of control cues": "Señales de pérdida de control",
    "Low Health Heartbeat": "Latido de salud baja",
    "Low Motor Only": "Solo motor lento",
}

def main():
    batch_path = "/home/deck/developer/wow/PulseSensation/localization/batches/batch1a_ui_navigation.json"
    with open(batch_path, "r", encoding="utf-8") as f:
        batch = json.load(f)

    items = batch["items"]
    print(f"Loaded batch1a with {len(items)} items.")
    print(f"TRANSLATIONS_ES dict has {len(TRANSLATIONS_ES)} entries.")

    errors = 0
    translated_items = []

    for idx, it in enumerate(items):
        src = it["source"]
        if src not in TRANSLATIONS_ES:
            print(f"ERROR: Missing translation for item [{idx}] (id={it.get('id')}): {repr(src)}")
            errors += 1
            continue

        tgt = TRANSLATIONS_ES[src]

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

    out_path = "/home/deck/developer/wow/PulseSensation/localization/batches/translated_esES_batch1a.json"
    out_data = {
        "items": translated_items
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out_data, f, indent=2, ensure_ascii=False)

    print(f"SUCCESS: Wrote {len(translated_items)} validated translations to {out_path}")

if __name__ == "__main__":
    main()
