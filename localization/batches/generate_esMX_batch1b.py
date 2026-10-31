#!/usr/bin/env python3
"""
Generates and validates translated_esMX_batch1b.json for PulseHaptics Latin American Spanish localization.
Adheres strictly to GLOSSARY.md, esMX terminology (control, calabozos), format specifier signatures, and color tags.
"""

import json
import os
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "tools"))
from validate_catalog import extract_signature, check_color_balance

TRANSLATIONS_ESMX = {
    # 000..049
    "Low health": "Salud baja",
    "Low health texture": "Textura de salud baja",
    "Low motor": "Motor lento",
    "Low motor holds a steady presence, floored so it's never silent while gliding; high motor eases in from near-silent toward thrillPeak as speed climbs, shaped by thrillCurve.": "El motor lento mantiene una presencia constante, con un límite inferior para que nunca esté en silencio al planear; el motor rápido entra suavemente desde casi el silencio hacia thrillPeak a medida que aumenta la velocidad, moldeado por thrillCurve.",
    "Mage": "Mago",
    "Manage": "Gestionar",
    "Master Vibration Strength": "Fuerza de vibración maestra",
    "Master switch for every loss-of-control cue below. With this off, none of them fire and no loss-of-control events are registered at all.": "Interruptor maestro para cada señal de pérdida de control a continuación. Con esto desactivado, ninguna se activa y no se registra ningún evento de pérdida de control.",
    "Master switch. With this off, nothing registers and nothing costs anything.": "Interruptor maestro. Con esto desactivado, nada se registra y nada consume recursos.",
    "Melee auto-attack started": "Ataque automático cuerpo a cuerpo iniciado",
    "Melee auto-attack stopped": "Ataque automático cuerpo a cuerpo detenido",
    "Menus & tabs": "Menús y pestañas",
    "Messages": "Mensajes",
    "Minimum severity": "Severidad mínima",
    "Mode to test": "Modo a probar",
    "Most specific wins. A scope set to |cffffd100No rule|r has no opinion and lets the one below it decide; with none of them set, Pulse uses Default.": "El más específico tiene prioridad. Un ámbito configurado en |cffffd100Sin regla|r no tiene preferencia y deja que el inferior decida; si ninguno está configurado, Pulse usa Predeterminado.",
    "Movement": "Movimiento",
    "Movement & Travel": "Movimiento y viaje",
    "Multiplies every trigger's intensity. Part of the current profile, not global.": "Multiplica la intensidad de cada disparador. Parte del perfil actual, no global.",
    "Name the new profile:": "Nombra el nuevo perfil:",
    "Navigation": "Navegación",
    "New profile": "Nuevo perfil",
    "Next >": "Siguiente >",
    "No rule": "Sin regla",
    "None (full sensory richness)": "Ninguno (riqueza sensorial completa)",
    "None (stock defaults)": "Ninguno (valores por defecto originales)",
    "ON — option changes and cue firings will print here.": "ACTIVADO: los cambios de opciones y las activaciones de señales se mostrarán aquí.",
    "Ocean Waves & Swell": "Olas oceánicas y mar de fondo",
    "Ocean waves & swell": "Olas oceánicas y mar de fondo",
    "Ocean zones only (guessed from zone name)": "Solo zonas oceánicas (deducido del nombre de la zona)",
    "Off by default and deliberately the faintest cue in the addon: this fires for EVERY NPC you talk to, which in a city is constantly. Try it before leaving it on. Untested.": "Desactivado por defecto y deliberadamente la señal más tenue del accesorio: esto se activa con CADA PNJ con el que hablas, lo que en una ciudad ocurre constantemente. Pruébala antes de dejarla activada. No probado.",
    "Offensive": "Ofensivo",
    "One cue for both directions, same reasoning as the navigation edge cue — a motor can't tell you which way you went.": "Una sola señal para ambas direcciones, el mismo razonamiento que la señal de límite de navegación: un motor no puede indicarte en qué dirección fuiste.",
    "One full-bodied hit on both motors.": "Un golpe con cuerpo en ambos motores.",
    "One long, sombre pulse when a spirit healer's window opens.": "Un pulso largo y sombrío cuando se abre la ventana de un Sanador de almas.",
    "One sharp, heavy impact — fast attack, fast decay.": "Un impacto seco y pesado: ataque rápido, caída rápida.",
    "One strong, sustained pulse.": "Un pulso fuerte y sostenido.",
    "One sustained pulse.": "Un pulso sostenido.",
    "Open Pulse settings": "Abrir opciones de Pulse",
    "Other": "Otro",
    "Overall heave amplitude of the oceanic swell. Sets the physical displacement intensity of the slow motor.": "Amplitud general de oscilación del mar de fondo. Establece la intensidad de desplazamiento físico del motor lento.",
    "Overall intensity": "Intensidad general",
    "Overall strength. Meant to sit at the edge of perception — if you notice it as a vibration rather than as being submerged, it is too high. Inherits the old idleFloatAmplitude, which was live-tuned to 0.04.": "Fuerza general. Pensada para estar al límite de la percepción: si la notas como una vibración en lugar de como estar sumergido, es demasiado alta. Hereda el antiguo idleFloatAmplitude, que se ajustó en vivo a 0.04.",
    "Overdrive kick": "Golpe de sobremarcha",
    "Overdrive time (s)": "Tiempo de sobremarcha (s)",
    "Own motor": "Motor propio",
    "PLAYER_ALIVE also fires when you release to a graveyard, so this can fire while you are still a ghost.": "PLAYER_ALIVE también se activa cuando liberas al cementerio, por lo que esto puede activarse mientras aún eres un fantasma.",
    "PLAYER_SOFT_FRIEND_CHANGED, occurrence-only, no payload. Worth pairing with the hostile cue above only if you can tell two TICKs apart — if not, give one of them a different shape with its own \"Feels like\" dropdown.": "PLAYER_SOFT_FRIEND_CHANGED, solo ocurrencia, sin datos adicionales. Vale la pena emparejarlo con la señal hostil anterior solo si puedes distinguir dos CHASQUIDOS; si no, dale a uno de ellos una forma diferente con su propio menú desplegable \"Se siente como\".",
    "PULSE QUICK SETUP": "CONFIGURACIÓN RÁPIDA DE PULSE",
    "Pacified or school-locked": "Pacificado o con escuela bloqueada",

    # 050..099
    "Page switches": "Cambios de página",
    "Paladin": "Paladín",
    "Passively polled by observing IsEnabled() on the currently focused element. Fires if the element becomes disabled while focused.": "Sondeado pasivamente observando IsEnabled() en el elemento enfocado actualmente. Se activa si el elemento queda deshabilitado mientras tiene el foco.",
    "Passively polled via GetUIPanel every 0.05s to eliminate UIParentPanelManager execution taint on protected frames.": "Sondeado pasivamente mediante GetUIPanel cada 0.05 s para eliminar la contaminación de ejecución de UIParentPanelManager en marcos protegidos.",
    "Passively polled via GetUIPanel every 0.05s. Detects when major UI panels are dismissed without callback taint.": "Sondeado pasivamente mediante GetUIPanel cada 0.05 s. Detecta cuándo se cierran paneles principales de la interfaz sin contaminación de retrollamada.",
    "Passively polled via GroupTargeting.isTargetingActive. Fires when the group targeting modifier is released.": "Sondeado pasivamente mediante GroupTargeting.isTargetingActive. Se activa cuando se suelta el modificador de selección de grupo.",
    "Physical tool strikes: anvil hammer strokes, mining pickaxe impacts, tailoring stitches.": "Golpes físicos con herramientas: martillazos en el yunque, impactos de pico de minería, puntadas de sastrería.",
    "Pick a mode to test below.": "Elige un modo para probar a continuación.",
    "Play": "Reproducir",
    "Play ": "Reproducir ",
    "Play a few seconds of this texture at its current intensity. Module-driven preview reproducing authentic physical dynamics and configured intensity.": "Reproduce unos segundos de esta textura a su intensidad actual. Vista previa guiada por el módulo que reproduce una dinámica física auténtica y la intensidad configurada.",
    "Presence floor (low)": "Límite mínimo de presencia (lento)",
    "Priest": "Sacerdote",
    "Prints every option you change and every cue that actually fires to chat, in real time. Same as /pulse debug — off by default, and resets to off on /reload since it's a testing aid, not a saved preference.": "Muestra en el chat cada opción que cambias y cada señal que se activa, en tiempo real. Igual que /pulse debug: desactivado por defecto, y se restablece a desactivado con /reload ya que es una ayuda para pruebas, no una preferencia guardada.",
    "Profile": "Perfil",
    "Profiles": "Perfiles",
    "Profiles and automatic rules": "Perfiles y reglas automáticas",
    "Progression": "Progresión",
    "Progressive low build leading to a sharp high break.": "Acumulación progresiva en el motor lento que culmina en un quiebre seco en el rápido.",
    "Pull / glide balance": "Balance de tracción / planeo",
    "Pulse": "Pulse",
    "Pulse is using |cffffd100%s|r, because a rule is set for %s.": "Pulse está usando |cffffd100%s|r, porque hay una regla configurada para %s.",
    "Pulse tunes motor spin-up attack, coast-down release, and breakaway friction to match your physical hardware actuators.": "Pulse calibra el ataque de aceleración del motor, la desaceleración y la fricción inicial para adaptarse a los actuadores físicos de tu hardware.",
    "Pulse: (Engine recorded %d errors. Last error: %s)": "Pulse: (El motor registró %d errores. Último error: %s)",
    "Pulse: /pulse test <mode>|heartbeat|warningbeat — try one of: ": "Pulse: /pulse test <modo>|heartbeat|warningbeat — prueba uno de: ",
    "Pulse: activated profile \"%s\"": "Pulse: perfil activado \"%s\"",
    "Pulse: active profile is \"%s\" (%s)": "Pulse: el perfil activo es \"%s\" (%s)",
    "Pulse: bound profile \"%s\" to specialization %s": "Pulse: perfil \"%s\" vinculado a la especialización %s",
    "Pulse: could not build settings row %q (%s)": "Pulse: no se pudo crear la fila de opciones %q (%s)",
    "Pulse: could not build the settings window (": "Pulse: no se pudo crear la ventana de opciones (",
    "Pulse: debug ": "Pulse: depuración ",
    "Pulse: disabled all %d cues in active profile.": "Pulse: se desactivaron todas las %d señales en el perfil activo.",
    "Pulse: disabled all %d cues in profile \"%s\".": "Pulse: se desactivaron todas las %d señales en el perfil \"%s\".",
    "Pulse: disabled all %d cues in profile %s.": "Pulse: se desactivaron todas las %d señales en el perfil %s.",
    "Pulse: enabled all %d cues in active profile.": "Pulse: se activaron todas las %d señales en el perfil activo.",
    "Pulse: enabled all %d cues in profile \"%s\".": "Pulse: se activaron todas las %d señales en el perfil \"%s\".",
    "Pulse: enabled all %d cues in profile %s.": "Pulse: se activaron todas las %d señales en el perfil %s.",
    "Pulse: live oscilloscope is provided by the companion addon PulseDebug (/pdebug scope).": "Pulse: el osciloscopio en vivo lo proporciona el accesorio complementario PulseDebug (/pdebug scope).",
    "Pulse: minimap icon %s": "Pulse: icono del minimapa %s",
    "Pulse: no profile matching \"%s\". Available: %s": "Pulse: ningún perfil coincide con \"%s\". Disponibles: %s",
    "Pulse: switched to profile \"%s\"": "Pulse: cambiado al perfil \"%s\"",
    "Pulse: that preview is unavailable.": "Pulse: esa vista previa no está disponible.",
    "Pulse: this looks like a %s%s. Pick it above, then press Apply.": "Pulse: esto parece un %s%s. Selecciónalo arriba y luego presiona Aplicar.",
    "Pure flavour — nothing depends on it. Untested.": "Pura ambientación: nada depende de esto. No probado.",
    "Pure novelty. Off by default forever, basically — nobody asked for this one.": "Pura novedad. Desactivado por defecto de forma permanente: básicamente, nadie pidió esto.",
    "Put every motor's strength, floor, timing and curve back to the engine defaults. Doesn't touch cues, per-cue intensity, mode tuning or your schema.": "Restablece la fuerza, el límite inferior, la sincronización y la curva de cada motor a los valores predeterminados del sistema. No modifica las señales, la intensidad por señal, el ajuste de modos ni tu esquema.",
    "Put the profile in use back to its stock defaults — works on built-ins too, restoring their curated content rather than blank Registry.lua defaults.": "Restablece el perfil en uso a sus valores por defecto originales: también funciona con los perfiles integrados, restaurando su contenido seleccionado en lugar de los valores predeterminados vacíos de Registry.lua.",
    "PvP (Tactical Radar)": "JcJ (Radar táctico)",
    "Quest accepted": "Misión aceptada",
    "Quest offered": "Misión ofrecida",

    # 100..149
    "Quest ready to hand in": "Misión lista para entregar",
    "Quest turned in": "Misión entregada",
    "Questing": "Misiones",
    "Questing & Exploration": "Misiones y exploración",
    "Quests": "Misiones",
    "Quick Setup": "Configuración rápida",
    "Quick Setup Wizard": "Asistente de configuración rápida",
    "Radial menu": "Menú radial",
    "Radial menu closed": "Menú radial cerrado",
    "Radial menu opened": "Menú radial abierto",
    "Radial page changed": "Página radial cambiada",
    "Radial segment changed": "Segmento radial cambiado",
    "Radial segment chosen": "Segmento radial elegido",
    "Radial segment unavailable": "Segmento radial no disponible",
    "Radial selection cancelled": "Selección radial cancelada",
    "Ranged auto-repeat started": "Repetición automática a distancia iniciada",
    "Ranged auto-repeat stopped": "Repetición automática a distancia detenida",
    "Rapid staccato triple-click on the high motor.": "Triple clic rápido en staccato en el motor rápido.",
    "Reading something": "Leyendo algo",
    "Reads the segment's own IsEnabled() — the same value Blizzard reads to grey the highlight out, so this matches what you see on screen. Fires in place of \"Radial segment changed\", not alongside it.": "Lee el propio IsEnabled() del segmento: el mismo valor que lee Blizzard para atenuar el resaltado, de modo que coincide con lo que ves en pantalla. Se activa en lugar de \"Segmento radial cambiado\", no junto a este.",
    "Ready check": "Comprobación de preparación",
    "Ready check finished": "Comprobación de preparación finalizada",
    "Release time (s)": "Tiempo de liberación (s)",
    "Reload UI": "Recargar interfaz",
    "Reload UI to apply the language change.": "Recarga la interfaz para aplicar el cambio de idioma.",
    "Reload the interface to apply your selected addon language.": "Recarga la interfaz para aplicar el idioma del accesorio seleccionado.",
    "Rename": "Renombrar",
    "Rename \"%s\" to:": "Renombrar \"%s\" a:",
    "Rename the profile in use. Every rule pointing at it follows the rename. Built-in profiles can't be renamed.": "Renombra el perfil en uso. Cada regla que apunta a él sigue el cambio de nombre. Los perfiles integrados no se pueden renombrar.",
    "Rename this profile": "Renombrar este perfil",
    "Rename...": "Renombrar...",
    "Repaired equipment": "Equipo reparado",
    "Reset": "Restablecer",
    "Reset every motor's strength, floor, timing and curve back to the engine defaults? This can't be undone.": "¿Restablecer la fuerza, el límite inferior, la sincronización y la curva de cada motor a los valores predeterminados del sistema? Esto no se puede deshacer.",
    "Reset profile \"%s\" to defaults? Every cue, intensity and mode override in it goes back to stock values. This can't be undone.": "¿Restablecer el perfil \"%s\" a los valores predeterminados? Cada señal, intensidad y anulación de modo en él volverá a los valores originales. Esto no se puede deshacer.",
    "Reset this profile": "Restablecer este perfil",
    "Reset...": "Restablecer...",
    "Resources": "Recursos",
    "Response curve": "Curva de respuesta",
    "Resting": "Descansando",
    "Resurrection offered": "Resurrección ofrecida",
    "Rewards": "Recompensas",
    "Rogue": "Pícaro",
    "Role poll": "Sondeo de rol",
    "Rooted": "Enraizado",
    "Routing & Schema": "Enrutamiento y esquema",
    "Rules": "Reglas",
    "Run Wizard": "Ejecutar asistente",
    "Run cadence (steps/s)": "Cadencia de carrera (pasos/s)",
    "Same polled mechanism as \"Confirmation popup appeared\". Untested.": "Mismo mecanismo sondeado que \"Apareció ventana emergente de confirmación\". No probado.",

    # 150..199
    "Save & Start Playing": "Guardar y comenzar a jugar",
    "Scales both the bed and the strikes for %s, before the two shared strengths above.": "Escala tanto la base como los golpes para %s, antes de las dos fuerzas compartidas anteriores.",
    "Scales this cue on top of the overall intensity on the Pulse page.": "Escala esta señal sobre la intensidad general en la página de Pulse.",
    "School lockouts are frequent in melee-heavy content. Off by default because a cue every kick you eat can crowd out the ones that mean you cannot act at all.": "Los bloqueos de escuela de magia son frecuentes en combates con predominio cuerpo a cuerpo. Desactivado por defecto porque una señal por cada corte recibido puede opacar a las que indican que no puedes actuar en absoluto.",
    "Search %d cues...": "Buscar %d señales...",
    "Secondary resource full": "Recurso secundario lleno",
    "Set Floor": "Establecer límite inferior",
    "Set but not in force: |cffffd100%s|r. A more specific rule above is winning — clear it to let these take over.": "Configurado pero no vigente: |cffffd100%s|r. Una regla superior más específica tiene prioridad; bórrala para que esta tome el control.",
    "Set for Spec": "Establecer para especialización",
    "Setup Summary": "Resumen de configuración",
    "Shaman": "Chamán",
    "Shares its pulse pattern with the target cue. If your focus is also your target, you get one cue rather than two.": "Comparte su patrón de pulsos con la señal del objetivo. Si tu foco es también tu objetivo, recibes una sola señal en lugar de dos.",
    "Sharp high kick layered with heavy low kick and rumble decay.": "Golpe seco en el motor rápido combinado con un golpe pesado en el motor lento y atenuación de vibración.",
    "Show a Play button on every cue": "Mostrar un botón de Reproducir en cada señal",
    "Show minimap icon": "Mostrar icono del minimapa",
    "Show per-cue detail controls": "Mostrar controles detallados por señal",
    "Shows only the page switches and this page. Every cue keeps its own settings; turn this off to get every page back exactly as it was.": "Muestra únicamente los selectores de página y esta página. Cada señal conserva su propia configuración; desactiva esto para volver a ver todas las páginas exactamente como estaban.",
    "Silenced": "Silenciado",
    "Simple view": "Vista simple",
    "Slow, harmonic oceanic gravity swells and coastal tides while submerged in deep oceans.": "Mar de fondo armónico lento y mareas costeras al estar sumergido en aguas oceánicas profundas.",
    "Snappy & Taps": "Seco y toques",
    "Social & Group": "Social y grupo",
    "Social & Group Communication": "Comunicación social y de grupo",
    "Soft target interact": "Interacción con objetivo dinámico",
    "Special casting": "Lanzamiento especial",
    "Speeds up or slows down ": "Acelera o ralentiza ",
    "Spirit healer": "Sanador de almas",
    "Split left and right": "Dividir izquierda y derecha",
    "Square / X: open settings": "Cuadrado / X: abrir opciones",
    "Stable opened": "Establo abierto",
    "Stack split ratchet": "Trinquete de división de acumulaciones",
    "Standard Rumble": "Vibración estándar",
    "Standard balance across all categories": "Balance estándar en todas las categorías",
    "Status: %s": "Estado: %s",
    "Step 4: Interface & Social Alerts": "Paso 4: Alertas de interfaz y sociales",
    "Step 6: Master Strength & Completion": "Paso 6: Intensidad general y finalización",
    "Steps per second at full running speed. Scaled by how fast you are actually moving.": "Pasos por segundo a velocidad máxima de carrera. Se escala según qué tan rápido te muevas realmente.",
    "Steps per second at normal walking speed.": "Pasos por segundo a velocidad normal de caminata.",
    "Strength": "Fuerza",
    "Strike strength": "Fuerza de golpe",
    "Stroke depth": "Profundidad de brazada",
    "Stroke rate, fast (Hz)": "Frecuencia de brazada, rápida (Hz)",
    "Stroke rate, slow (Hz)": "Frecuencia de brazada, lenta (Hz)",
    "Strokes per second at barely-moving speed.": "Brazadas por segundo a velocidad de movimiento mínimo.",
    "Stunned": "Aturdido",
    "Summon offered": "Invocación ofrecida",
    "Swapped / Inverted Rumble": "Vibración invertida / intercambiada",
    "Swell depth": "Profundidad del oleaje",
    "Swell rate (Hz)": "Frecuencia del oleaje (Hz)",
    "Swell strength": "Fuerza del oleaje",

    # 200..249
    "Switch to this profile": "Cambiar a este perfil",
    "Switches every cue on the Casting page on or off at once. Each cue keeps its own setting underneath.": "Activa o desactiva todas las señales de la página de Lanzamiento al mismo tiempo. Cada señal conserva su propia configuración por debajo.",
    "Switches every cue on the Character & Status page on or off at once. Each cue keeps its own setting underneath.": "Activa o desactiva todas las señales de la página de Personaje y estado al mismo tiempo. Cada señal conserva su propia configuración por debajo.",
    "Switches every cue on the Interface & Accessibility page on or off at once. Each cue keeps its own setting underneath.": "Activa o desactiva todas las señales de la página de Interfaz y accesibilidad al mismo tiempo. Cada señal conserva su propia configuración por debajo.",
    "Switches every cue on the Movement & Travel page on or off at once. Each cue keeps its own setting underneath.": "Activa o desactiva todas las señales de la página de Movimiento y viaje al mismo tiempo. Cada señal conserva su propia configuración por debajo.",
    "Switches every cue on the Social & Group page on or off at once. Each cue keeps its own setting underneath.": "Activa o desactiva todas las señales de la página de Social y grupo al mismo tiempo. Cada señal conserva su propia configuración por debajo.",
    "Switches every cue on the Target & Focus page on or off at once. Each cue keeps its own setting underneath.": "Activa o desactiva todas las señales de la página de Objetivo y foco al mismo tiempo. Cada señal conserva su propia configuración por debajo.",
    "Switches every cue on the World & Environment page on or off at once. Each cue keeps its own setting underneath.": "Activa o desactiva todas las señales de la página de Mundo y entorno al mismo tiempo. Cada señal conserva su propia configuración por debajo.",
    "Talking to someone": "Hablando con alguien",
    "Target": "Objetivo",
    "Target & Crosshair Feedback": "Respuesta de objetivo y retícula",
    "Target & Focus": "Objetivo y foco",
    "Target changed": "Objetivo cambiado",
    "Target died": "Objetivo muerto",
    "Target started casting": "El objetivo comenzó a lanzar",
    "Target used major defensive": "El objetivo usó defensivo mayor",
    "Target's cast stopped": "Lanzamiento del objetivo detenido",
    "Targeted by enemy": "Fijado por un enemigo",
    "Targeting": "Selección de objetivos",
    "Test Alert": "Probar alerta",
    "Test Impact": "Probar impacto",
    "Test Lock": "Probar bloqueo",
    "Test Reward": "Probar recompensa",
    "Test Rumble": "Probar vibración",
    "Test Strike": "Probar golpe",
    "Test UI": "Probar interfaz",
    "Test the selected mode": "Probar el modo seleccionado",
    "Textures & Patterns": "Texturas y patrones",
    "The Accessibility section": "La sección de Accesibilidad",
    "The Cue Index directory": "El directorio del índice de señales",
    "The _QUIET variant covers failures the game prints no error for, so this can fire with nothing visible on screen.": "La variante _QUIET cubre fallos para los cuales el juego no muestra ningún error, por lo que esto puede activarse sin nada visible en pantalla.",
    "The experimental section": "La sección experimental",
    "The lightest possible tick when a conversation window opens with any NPC.": "El chasquido más ligero posible cuando se abre una ventana de conversación con cualquier PNJ.",
    "The master switch for this page. Also on the Casting page, where the cue lives alongside the other casting cues.": "El interruptor maestro para esta página. También se encuentra en la página de Lanzamiento, donde reside la señal junto a las demás señales de lanzamiento.",
    "This character": "Este personaje",
    "This character reports no specialization, so there is no per-specialization rule to set. The row appears by itself on a character that has one.": "Este personaje no reporta especialización, por lo que no hay regla por especialización para configurar. La fila aparece por sí sola en un personaje que tenga una.",
    "This specialization": "Esta especialización",
    "This specialization (": "Esta especialización (",
    "Three rhythmic thuds.": "Tres golpes sordos rítmicos.",
    "Three-stage rising tension building on the low motor.": "Tensión creciente de tres etapas acumulándose en el motor lento.",
    "Thrill curve (high)": "Curva de emoción (rápido)",
    "Thrill peak (high)": "Pico de emoción (rápido)",
    "Time in seconds for a complete wave cycle. Real oceanic swells roll every 8 to 12 seconds (~0.10 Hz). Shorter periods feel like choppy coastal chop; longer periods feel like open-ocean rollers.": "Tiempo en segundos para un ciclo completo de ola. El mar de fondo oceánico real oscila cada 8 a 12 segundos (~0.10 Hz). Períodos más cortos se sienten como oleaje costero picado; períodos más largos se sienten como olas de mar abierto.",
    "Tracked cooldown ready": "Tiempo de reutilización rastreado listo",
    "Trade opened": "Comercio abierto",
    "Triggers, modes, and motor tuning": "Disparadores, modos y calibración de motores",
    "Try Texture": "Probar textura",
    "Tuned for HD Rumble voice-coil actuators": "Calibrado para actuadores de bobina móvil HD Rumble",
    "Turn off every cue in the active profile in one sweep (useful for quiet debugging).": "Desactiva todas las señales en el perfil activo de una sola vez (útil para depuración silenciosa).",
    "Turn on every cue in the active profile in one sweep (useful for testing/debugging).": "Activa todas las señales en el perfil activo de una sola vez (útil para pruebas/depuración).",

    # 250..299
    "Turn whole pages of cues on or off. Each cue keeps its own setting underneath: switching a page back on restores exactly what was there.": "Activa o desactiva páginas enteras de señales. Cada señal conserva su propia configuración por debajo: reactivar una página restaura exactamente lo que había.",
    "Two crisp ticks when a cooldown the built-in Cooldown Manager is tracking comes off cooldown.": "Dos chasquidos secos cuando un tiempo de reutilización que el Gestor de tiempos de reutilización integrado rastrea vuelve a estar disponible.",
    "Two heavier hits with a gap between them.": "Dos golpes más pesados con un intervalo entre ellos.",
    "Two kinds of trigger: pulses and textures": "Dos tipos de disparadores: pulsos y texturas",
    "Two rhythmic thuds.": "Dos golpes sordos rítmicos.",
    "Two soft ticks when the action bar pages to a different set of abilities.": "Dos chasquidos suaves cuando la barra de acción cambia de página a un conjunto diferente de facultades.",
    "Two soft ticks when you page the radial left or right with the shoulder buttons.": "Dos chasquidos suaves cuando cambias la página del radial a la izquierda o derecha con los botones superiores.",
    "UI focus moved": "Foco de la interfaz desplazado",
    "UI navigation hit an edge": "La navegación de interfaz llegó al borde",
    "UI panel closed": "Panel de la interfaz cerrado",
    "UI panel opened": "Panel de la interfaz abierto",
    "Untested whether this also fires on every instant-cast press rather than only real cast-bar completions — if so, it'll feel far too frequent to read as \"that landed\" specifically. Check before relying on it.": "No probado si esto también se activa con cada pulsación de lanzamiento instantáneo en lugar de solo al completarse barras de lanzamiento reales; de ser así, se sentirá demasiado frecuente como para interpretarse específicamente como \"eso impactó\". Compruébalo antes de confiar en ello.",
    "Untested.": "No probado.",
    "Use the old estimator": "Usar el estimador antiguo",
    "Using \"%s\" — set for %s.": "Usando \"%s\" — configurado para %s.",
    "Vendor window opened": "Ventana de comerciante abierta",
    "Vibration Mode": "Modo de vibración",
    "Vibration Schema: |cffffd100%s|r": "Esquema de vibración: |cffffd100%s|r",
    "Vibration schema": "Esquema de vibración",
    "Voice-coil actuators (LRA), ultra-low 0.025 floor, instant response": "Actuadores de bobina móvil (LRA), umbral de arranque ultra bajo de 0.025, respuesta instantánea",
    "Walk cadence (steps/s)": "Cadencia de caminata (pasos/s)",
    "Warlock": "Brujo",
    "Warning lead time": "Tiempo de aviso previo",
    "Warrior": "Guerrero",
    "Watches UNIT_TARGET and target swaps for hostile units whose target is the player. Uses UnitIsUnit('targettarget', 'player') with defensive secrecy guards.": "Supervisa UNIT_TARGET y cambios de objetivo para unidades hostiles cuyo objetivo es el jugador. Usa UnitIsUnit('targettarget', 'player') con protecciones de valores secretos defensivas.",
    "Wave cycle (seconds)": "Ciclo de ola (segundos)",
    "Wave period (sec)": "Período de ola (s)",
    "Wave steepness": "Inclinación de la ola",
    "Weapon or gear swapped": "Arma o equipo intercambiado",
    "What this does": "Qué hace esto",
    "When mobs are pulled socially — aggroing because a neighbour was pulled — the game often reports status 0 even though you have aggro.": "Cuando los enemigos son atraídos en grupo (generando amenaza porque un vecino fue atraído), el juego a menudo reporta estado 0 aunque tengas la amenaza.",
    "Which of the preset shapes this specific cue plays when it fires. \"": "Cuál de las formas preestablecidas reproduce esta señal específica cuando se activa. \"",
    "Which physical motors each cue drives. Start with Standard Rumble, then calibrate the motors below.": "Qué motores físicos impulsa cada señal. Comienza con Vibración estándar, luego calibra los motores a continuación.",
    "Which physical motors each trigger drives. Try one, test a mode below, keep the one you can feel.": "Qué motores físicos acciona cada disparador. Prueba uno, ensaya un modo a continuación y quédate con el que puedas sentir.",
    "Which profile to use right now. This writes to whichever rule is currently in force, so picking here always changes what you are actually using rather than editing a rule something more specific is overriding.": "Qué perfil usar ahora mismo. Esto escribe en la regla que esté actualmente vigente, por lo que elegir aquí siempre cambia lo que estás usando en realidad en lugar de editar una regla anulada por otra más específica.",
    "Wind amplitude": "Amplitud del viento",
    "Wind resistance & thrust surge while flying. Scales dynamically with your flight speed.": "Resistencia del viento y empuje de propulsión al volar. Se escala dinámicamente con tu velocidad de vuelo.",
    "Windows": "Ventanas",
    "World": "Mundo",
    "World & Environment": "Mundo y entorno",
    "World Immersion": "Inmersión en el mundo",
    "You are alive again": "Has revivido",
    "You died": "Has muerto",
    "You have aggro": "Tienes la amenaza",
    "Your cast ended": "Tu lanzamiento terminó",
    "Your cast failed": "Tu lanzamiento falló",
    "Your cast started": "Tu lanzamiento comenzó",
    "Your cast succeeded": "Tu lanzamiento tuvo éxito",
    "Zone changed": "Zona cambiada",
    "an impact": "un impacto",

    # 300..330
    "could not apply that preset": "no se pudo aplicar ese ajuste preestablecido",
    "could not run that": "no se pudo ejecutar eso",
    "could not set that rule": "no se pudo establecer esa regla",
    "detection unavailable": "detección no disponible",
    "in force": "vigente",
    "no role chosen": "sin rol elegido",
    "once a minute": "una vez por minuto",
    "once every ": "una vez cada ",
    "once every %.1f seconds": "una vez cada %.1f segundos",
    "|cff00ff00Left-Click:|r Open Settings": "|cff00ff00Clic izquierdo:|r Abrir opciones",
    "|cff00ff00Right-Click:|r Toggle Master On/Off": "|cff00ff00Clic derecho:|r Alternar general act./desact.",
    "|cff00ff00[Adjusting %d%%]|r Use |cffffffff[← / →]|r to Change, |cff38BDF8[A]|r Confirm & Feel": "|cff00ff00[Ajustando %d%%]|r Usa |cffffffff[← / →]|r para cambiar, |cff38BDF8[A]|r Confirmar y sentir",
    "|cff38BDF8[L1 / LB]|r": "|cff38BDF8[L1 / LB]|r",
    "|cff38BDF8[L1/R1]|r Tabs  •  |cff38BDF8[A]|r Toggle Slider / Select": "|cff38BDF8[L1/R1]|r Pestañas  •  |cff38BDF8[A]|r Alternar deslizador / Seleccionar",
    "|cff38BDF8[R1 / RB]|r": "|cff38BDF8[R1 / RB]|r",
    "|cff444444[L1 / LB]|r": "|cff444444[L1 / LB]|r",
    "|cff444444[R1 / RB]|r": "|cff444444[R1 / RB]|r",
    "|cff4cb8ffPulse:|r Quick setup complete! Type |cffffffff/pulse|r anytime to fine-tune settings.": "|cff4cb8ffPulse:|r ¡Configuración rápida completada! Escribe |cffffffff/pulse|r en cualquier momento para ajustar las opciones.",
    "|cff4db8ff✔ |r": "|cff4db8ff✔ |r",
    "|cff888888Drag:|r Move Icon": "|cff888888Arrastrar:|r Mover icono",
    "|cff888888Loss of control cues are governed by the master switch on the main Pulse page.|r": "|cff888888Las señales de pérdida de control se rigen por el interruptor maestro en la página principal de Pulse.|r",
    "|cff888888Recommended intensity:|r %d%%": "|cff888888Intensidad recomendada:|r %d%%",
    "|cffffcc00◀/▶ Adjust Intensity|r   •   %s/%s Lock Value   •   %s Try Texture": "|cffffcc00◀/▶ Ajustar intensidad|r   •   %s/%s Bloquear valor   •   %s Probar textura",
    "|cffffd100%s|r  |cff00ff00[ACTIVE]|r": "|cffffd100%s|r  |cff00ff00[ACTIVO]|r",
    "|cffffd100/pulseui|r opens it too. |cffffd100/pulse setup|r re-opens Quick Setup, |cffffd100/pulse test <mode>|r plays a shape.": "|cffffd100/pulseui|r también lo abre. |cffffd100/pulse setup|r vuelve a abrir Configuración rápida, |cffffd100/pulse test <modo>|r reproduce una forma.",
    "|r, |cffffd100": "|r, |cffffd100",
    "• |r": "• |r",
    "⚔️ Melee DPS": "⚔️ DPS cuerpo a cuerpo",
    "🏹 Ranged DPS": "🏹 DPS a distancia",
    "💚 Healer": "💚 Sanador",
    "🛡️ Tank": "🛡️ Tanque",
}

def main():
    batch_path = os.path.join(os.path.dirname(__file__), "batch1b_ui_navigation.json")
    out_path = os.path.join(os.path.dirname(__file__), "translated_esMX_batch1b.json")

    with open(batch_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    items = data.get("items", data)
    print(f"Loaded {len(items)} items from batch1b.")

    translated_items = []
    missing = 0
    errors = 0

    for idx, item in enumerate(items):
        src = item["source"]
        if src not in TRANSLATIONS_ESMX:
            print(f"MISSING [{idx}]: {repr(src)}")
            missing += 1
            continue

        tgt = TRANSLATIONS_ESMX[src]

        # 1. Signature validation
        sig_s = extract_signature(src)
        sig_t = extract_signature(tgt)
        if sig_s != sig_t:
            print(f"SIGNATURE MISMATCH [{idx}]: src='{sig_s}' tgt='{sig_t}'")
            print(f"  src: {repr(src)}")
            print(f"  tgt: {repr(tgt)}")
            errors += 1

        # 2. Color balance validation
        if not check_color_balance(src, tgt):
            print(f"COLOR BALANCE MISMATCH [{idx}]:")
            print(f"  src: {repr(src)}")
            print(f"  tgt: {repr(tgt)}")
            errors += 1

        translated_items.append({
            "source": src,
            "target": tgt
        })

    print(f"Processed: {len(translated_items)} items. Missing: {missing}, Errors: {errors}")

    if missing > 0 or errors > 0:
        print("Validation failed!")
        sys.exit(1)

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({"items": translated_items}, f, ensure_ascii=False, indent=2)

    print(f"Wrote {len(translated_items)} translated items to {out_path}")

if __name__ == "__main__":
    main()
