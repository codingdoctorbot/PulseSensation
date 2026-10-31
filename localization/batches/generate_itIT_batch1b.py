#!/usr/bin/env python3
"""
Generates and validates translated_itIT_batch1b.json for PulseHaptics Italian localization.
"""

import json
import os
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "tools"))
from validate_catalog import extract_signature, check_color_balance

TRANSLATIONS_IT = {
    # 0..39
    "Low health": "Salute bassa",
    "Low health texture": "Texture salute bassa",
    "Low motor": "Motore a bassa frequenza",
    "Low motor holds a steady presence, floored so it's never silent while gliding; high motor eases in from near-silent toward thrillPeak as speed climbs, shaped by thrillCurve.": "Il motore a bassa frequenza mantiene una presenza costante, impostato con una soglia minima affinché non sia mai silenzioso durante la planata; il motore ad alta frequenza entra gradualmente da quasi impercettibile verso thrillPeak all'aumentare della velocità, modulato da thrillCurve.",
    "Mage": "Mago",
    "Manage": "Gestisci",
    "Master Vibration Strength": "Intensità principale di vibrazione",
    "Master switch for every loss-of-control cue below. With this off, none of them fire and no loss-of-control events are registered at all.": "Interruttore generale per ogni segnale di perdita di controllo sottostante. Se disattivato, nessuno di essi si attiverà e nessun evento di perdita di controllo verrà registrato.",
    "Master switch. With this off, nothing registers and nothing costs anything.": "Interruttore generale. Se disattivato, non viene registrato nulla e non vi è alcun impatto sulle prestazioni.",
    "Melee auto-attack started": "Attacco automatico in mischia iniziato",
    "Melee auto-attack stopped": "Attacco automatico in mischia interrotto",
    "Menus & tabs": "Menu e schede",
    "Messages": "Messaggi",
    "Minimum severity": "Gravità minima",
    "Mode to test": "Modalità da testare",
    "Most specific wins. A scope set to |cffffd100No rule|r has no opinion and lets the one below it decide; with none of them set, Pulse uses Default.": "La regola più specifica ha la priorità. Un ambito impostato su |cffffd100Nessuna regola|r non esprime preferenze e lascia decidere a quello sottostante; se nessuno è impostato, Pulse utilizza Predefinito.",
    "Movement": "Movimento",
    "Movement & Travel": "Movimento e viaggio",
    "Multiplies every trigger's intensity. Part of the current profile, not global.": "Moltiplica l'intensità di ogni innesco. Fa parte del profilo corrente, non è globale.",
    "Name the new profile:": "Assegna un nome al nuovo profilo:",
    "Navigation": "Navigazione",
    "New profile": "Nuovo profilo",
    "Next >": "Avanti >",
    "No rule": "Nessuna regola",
    "None (full sensory richness)": "Nessuno (massima ricchezza sensoriale)",
    "None (stock defaults)": "Nessuno (valori predefiniti)",
    "ON — option changes and cue firings will print here.": "ATTIVO — le modifiche alle opzioni e l'attivazione dei segnali verranno mostrate qui.",
    "Ocean Waves & Swell": "Onde oceaniche e moto ondoso",
    "Ocean waves & swell": "Onde oceaniche e moto ondoso",
    "Ocean zones only (guessed from zone name)": "Solo zone oceaniche (dedotto dal nome della zona)",
    "Off by default and deliberately the faintest cue in the addon: this fires for EVERY NPC you talk to, which in a city is constantly. Try it before leaving it on. Untested.": "Disattivato per impostazione predefinita e deliberatamente il segnale più lieve dell'addon: si attiva per OGNI PNG con cui parli, cosa che in città avviene continuamente. Provalo prima di lasciarlo attivo. Non testato.",
    "Offensive": "Offensivo",
    "One cue for both directions, same reasoning as the navigation edge cue — a motor can't tell you which way you went.": "Un unico segnale per entrambe le direzioni, con la stessa logica del segnale di bordo della navigazione: un motore non può indicare in quale direzione ti sei mosso.",
    "One full-bodied hit on both motors.": "Un colpo corposo su entrambi i motori.",
    "One long, sombre pulse when a spirit healer's window opens.": "Un impulso lungo e cupo all'apertura della finestra del curatore spirituale.",
    "One sharp, heavy impact — fast attack, fast decay.": "Un impatto netto e pesante — attacco rapido, decadimento rapido.",
    "One strong, sustained pulse.": "Un impulso forte e prolungato.",
    "One sustained pulse.": "Un impulso prolungato.",
    "Open Pulse settings": "Apri le impostazioni di Pulse",
    "Other": "Altro",

    # 40..79
    "Overall heave amplitude of the oceanic swell. Sets the physical displacement intensity of the slow motor.": "Ampiezza complessiva del sollevamento del moto ondoso oceanico. Imposta l'intensità di spostamento fisico del motore lento.",
    "Overall intensity": "Intensità complessiva",
    "Overall strength. Meant to sit at the edge of perception — if you notice it as a vibration rather than as being submerged, it is too high. Inherits the old idleFloatAmplitude, which was live-tuned to 0.04.": "Intensità complessiva. Pensata per restare al limite della percezione: se la avverti come una vibrazione invece che come la sensazione di essere immerso, è troppo alta. Eredita la vecchia idleFloatAmplitude, calibrata sul campo a 0,04.",
    "Overdrive kick": "Spinta di overdrive",
    "Overdrive time (s)": "Tempo di overdrive (s)",
    "Own motor": "Motore dedicato",
    "PLAYER_ALIVE also fires when you release to a graveyard, so this can fire while you are still a ghost.": "PLAYER_ALIVE si attiva anche quando rilasci lo spirito al cimitero, quindi questo segnale può attivarsi mentre sei ancora un fantasma.",
    "PLAYER_SOFT_FRIEND_CHANGED, occurrence-only, no payload. Worth pairing with the hostile cue above only if you can tell two TICKs apart — if not, give one of them a different shape with its own \"Feels like\" dropdown.": "PLAYER_SOFT_FRIEND_CHANGED, solo occorrenza, nessun payload. Vale la pena abbinarlo al segnale ostile sopra solo se riesci a distinguere due TIC: altrimenti, assegna a uno di essi una forma diversa tramite il relativo menu a tendina «Sensazione».",
    "PULSE QUICK SETUP": "CONFIGURAZIONE RAPIDA DI PULSE",
    "Pacified or school-locked": "Pacificato o scuola di magia bloccata",
    "Page switches": "Cambi di pagina",
    "Paladin": "Paladino",
    "Passively polled by observing IsEnabled() on the currently focused element. Fires if the element becomes disabled while focused.": "Rilevato passivamente osservando IsEnabled() sull'elemento attualmente selezionato. Si attiva se l'elemento viene disabilitato mentre è selezionato.",
    "Passively polled via GetUIPanel every 0.05s to eliminate UIParentPanelManager execution taint on protected frames.": "Rilevato passivamente tramite GetUIPanel ogni 0,05 s per eliminare la corruzione di esecuzione (taint) di UIParentPanelManager sui frame protetti.",
    "Passively polled via GetUIPanel every 0.05s. Detects when major UI panels are dismissed without callback taint.": "Rilevato passivamente tramite GetUIPanel ogni 0,05 s. Rileva la chiusura dei pannelli principali dell'interfaccia senza contaminazione delle callback.",
    "Passively polled via GroupTargeting.isTargetingActive. Fires when the group targeting modifier is released.": "Rilevato passivamente tramite GroupTargeting.isTargetingActive. Si attiva quando il modificatore di selezione del gruppo viene rilasciato.",
    "Physical tool strikes: anvil hammer strokes, mining pickaxe impacts, tailoring stitches.": "Colpi di attrezzi fisici: colpi di martello sull'incudine, colpi di piccone da estrazione mineraria, punti di cucito per sartoria.",
    "Pick a mode to test below.": "Scegli una modalità da testare qui sotto.",
    "Play": "Riproduci",
    "Play ": "Riproduci ",
    "Play a few seconds of this texture at its current intensity. Module-driven preview reproducing authentic physical dynamics and configured intensity.": "Riproduce alcuni secondi di questa texture all'intensità attuale. Anteprima gestita dal modulo che riproduce autentiche dinamiche fisiche e l'intensità configurata.",
    "Presence floor (low)": "Soglia minima di presenza (bassa)",
    "Priest": "Sacerdote",
    "Prints every option you change and every cue that actually fires to chat, in real time. Same as /pulse debug — off by default, and resets to off on /reload since it's a testing aid, not a saved preference.": "Stampa nella chat ogni opzione modificata e ogni segnale effettivamente attivato, in tempo reale. Equivale a /pulse debug — disattivato per impostazione predefinita e reimpostato su disattivato al /reload trattandosi di uno strumento di test, non di una preferenza salvata.",
    "Profile": "Profilo",
    "Profiles": "Profili",
    "Profiles and automatic rules": "Profili e regole automatiche",
    "Progression": "Progressione",
    "Progressive low build leading to a sharp high break.": "Crescendo progressivo sui bassi che conduce a uno stacco netto sugli acuti.",
    "Pull / glide balance": "Bilanciamento trazione / planata",
    "Pulse": "Pulse",
    "Pulse is using |cffffd100%s|r, because a rule is set for %s.": "Pulse sta utilizzando |cffffd100%s|r, poiché è impostata una regola per %s.",
    "Pulse tunes motor spin-up attack, coast-down release, and breakaway friction to match your physical hardware actuators.": "Pulse calibra l'attacco di avvio del motore, il rilascio per inerzia e l'attrito di stacco in base agli attuatori fisici del tuo hardware.",
    "Pulse: (Engine recorded %d errors. Last error: %s)": "Pulse: (il motore ha registrato %d errori. Ultimo errore: %s)",
    "Pulse: /pulse test <mode>|heartbeat|warningbeat — try one of: ": "Pulse: /pulse test <mode>|heartbeat|warningbeat — prova uno tra: ",
    "Pulse: activated profile \"%s\"": "Pulse: profilo \"%s\" attivato",
    "Pulse: active profile is \"%s\" (%s)": "Pulse: il profilo attivo è \"%s\" (%s)",
    "Pulse: bound profile \"%s\" to specialization %s": "Pulse: associato il profilo \"%s\" alla specializzazione %s",
    "Pulse: could not build settings row %q (%s)": "Pulse: impossibile creare la riga delle impostazioni %q (%s)",
    "Pulse: could not build the settings window (": "Pulse: impossibile creare la finestra delle impostazioni (",

    # 80..119
    "Pulse: debug ": "Pulse: debug ",
    "Pulse: disabled all %d cues in active profile.": "Pulse: disattivati tutti i %d segnali nel profilo attivo.",
    "Pulse: disabled all %d cues in profile \"%s\".": "Pulse: disattivati tutti i %d segnali nel profilo \"%s\".",
    "Pulse: disabled all %d cues in profile %s.": "Pulse: disattivati tutti i %d segnali nel profilo %s.",
    "Pulse: enabled all %d cues in active profile.": "Pulse: attivati tutti i %d segnali nel profilo attivo.",
    "Pulse: enabled all %d cues in profile \"%s\".": "Pulse: attivati tutti i %d segnali nel profilo \"%s\".",
    "Pulse: enabled all %d cues in profile %s.": "Pulse: attivati tutti i %d segnali nel profilo %s.",
    "Pulse: live oscilloscope is provided by the companion addon PulseDebug (/pdebug scope).": "Pulse: l'oscilloscopio in tempo reale è fornito dall'addon complementare PulseDebug (/pdebug scope).",
    "Pulse: minimap icon %s": "Pulse: icona della minimappa %s",
    "Pulse: no profile matching \"%s\". Available: %s": "Pulse: nessun profilo corrispondente a \"%s\". Disponibili: %s",
    "Pulse: switched to profile \"%s\"": "Pulse: passaggio al profilo \"%s\" effettuato",
    "Pulse: that preview is unavailable.": "Pulse: anteprima non disponibile.",
    "Pulse: this looks like a %s%s. Pick it above, then press Apply.": "Pulse: questo sembra un %s%s. Selezionalo sopra, poi premi Applica.",
    "Pure flavour — nothing depends on it. Untested.": "Puro elemento d'atmosfera — nulla dipende da questo. Non testato.",
    "Pure novelty. Off by default forever, basically — nobody asked for this one.": "Pura novità. Praticamente sempre disattivato per impostazione predefinita — nessuno lo ha mai richiesto.",
    "Put every motor's strength, floor, timing and curve back to the engine defaults. Doesn't touch cues, per-cue intensity, mode tuning or your schema.": "Ripristina l'intensità, la soglia minima, la temporizzazione e la curva di ogni motore ai valori predefiniti del sistema. Non modifica i segnali, l'intensità per segnale, la regolazione delle modalità o lo schema.",
    "Put the profile in use back to its stock defaults — works on built-ins too, restoring their curated content rather than blank Registry.lua defaults.": "Ripristina il profilo in uso ai valori predefiniti di fabbrica — funziona anche sui profili integrati, ripristinando le loro impostazioni dedicate anziché i valori vuoti di Registry.lua.",
    "PvP (Tactical Radar)": "PvP (Radar tattico)",
    "Quest accepted": "Missione accettata",
    "Quest offered": "Missione offerta",
    "Quest ready to hand in": "Missione pronta per la consegna",
    "Quest turned in": "Missione completata",
    "Questing": "Missioni",
    "Questing & Exploration": "Missioni ed esplorazione",
    "Quests": "Missioni",
    "Quick Setup": "Configurazione rapida",
    "Quick Setup Wizard": "Configurazione rapida guidata",
    "Radial menu": "Menu radiale",
    "Radial menu closed": "Menu radiale chiuso",
    "Radial menu opened": "Menu radiale aperto",
    "Radial page changed": "Pagina del menu radiale cambiata",
    "Radial segment changed": "Settore del menu radiale cambiato",
    "Radial segment chosen": "Settore del menu radiale selezionato",
    "Radial segment unavailable": "Settore del menu radiale non disponibile",
    "Radial selection cancelled": "Selezione del menu radiale annullata",
    "Ranged auto-repeat started": "Ripetizione automatica a distanza iniziata",
    "Ranged auto-repeat stopped": "Ripetizione automatica a distanza interrotta",
    "Rapid staccato triple-click on the high motor.": "Triplo clic rapido e staccato sul motore ad alta frequenza.",
    "Reading something": "Lettura in corso",
    "Reads the segment's own IsEnabled() — the same value Blizzard reads to grey the highlight out, so this matches what you see on screen. Fires in place of \"Radial segment changed\", not alongside it.": "Legge l'IsEnabled() del settore stesso — lo stesso valore che Blizzard legge per disattivare l'evidenziazione in grigio, corrispondendo a quanto visibile a schermo. Si attiva al posto di «Settore del menu radiale cambiato», non in contemporanea.",

    # 120..159
    "Ready check": "Appello",
    "Ready check finished": "Appello terminato",
    "Release time (s)": "Tempo di rilascio (s)",
    "Reload UI": "Ricarica interfaccia",
    "Reload UI to apply the language change.": "Ricarica l'interfaccia per applicare la modifica della lingua.",
    "Reload the interface to apply your selected addon language.": "Ricarica l'interfaccia per applicare la lingua selezionata dell'addon.",
    "Rename": "Rinomina",
    "Rename \"%s\" to:": "Rinomina \"%s\" in:",
    "Rename the profile in use. Every rule pointing at it follows the rename. Built-in profiles can't be renamed.": "Rinomina il profilo in uso. Ogni regola associata seguirà la ridenominazione. I profili integrati non possono essere rinominati.",
    "Rename this profile": "Rinomina questo profilo",
    "Rename...": "Rinomina...",
    "Repaired equipment": "Equipaggiamento riparato",
    "Reset": "Reimposta",
    "Reset every motor's strength, floor, timing and curve back to the engine defaults? This can't be undone.": "Reimpostare l'intensità, la soglia minima, la temporizzazione e la curva di ogni motore sui valori predefiniti del motore? L'operazione non può essere annullata.",
    "Reset profile \"%s\" to defaults? Every cue, intensity and mode override in it goes back to stock values. This can't be undone.": "Reimpostare il profilo \"%s\" sui valori predefiniti? Ogni segnale, intensità e personalizzazione della modalità al suo interno tornerà ai valori di fabbrica. L'operazione non può essere annullata.",
    "Reset this profile": "Reimposta questo profilo",
    "Reset...": "Reimposta...",
    "Resources": "Risorse",
    "Response curve": "Curva di risposta",
    "Resting": "In riposo",
    "Resurrection offered": "Resurrezione offerta",
    "Rewards": "Ricompense",
    "Rogue": "Ladro",
    "Role poll": "Selezione del ruolo",
    "Rooted": "Radicato",
    "Routing & Schema": "Instradamento e schema",
    "Rules": "Regole",
    "Run Wizard": "Avvia configurazione guidata",
    "Run cadence (steps/s)": "Cadenza di corsa (passi/s)",
    "Same polled mechanism as \"Confirmation popup appeared\". Untested.": "Stesso meccanismo di polling di «Comparsa finestra di conferma». Non testato.",
    "Save & Start Playing": "Salva e inizia a giocare",
    "Scales both the bed and the strikes for %s, before the two shared strengths above.": "Scala sia la base continua sia i colpi per %s, prima delle due intensità condivise sopra.",
    "Scales this cue on top of the overall intensity on the Pulse page.": "Scala questo segnale in aggiunta all'intensità complessiva nella pagina di Pulse.",
    "School lockouts are frequent in melee-heavy content. Off by default because a cue every kick you eat can crowd out the ones that mean you cannot act at all.": "I blocchi delle scuole di magia sono frequenti nei contenuti ricchi di mischia. Disattivato per impostazione predefinita perché un segnale per ogni interruzione subita può mascherare quelli che indicano l'impossibilità totale di agire.",
    "Search %d cues...": "Cerca tra %d segnali...",
    "Secondary resource full": "Risorsa secondaria piena",
    "Set Floor": "Imposta soglia minima",
    "Set but not in force: |cffffd100%s|r. A more specific rule above is winning — clear it to let these take over.": "Impostato ma non in vigore: |cffffd100%s|r. Una regola più specifica in alto ha la priorità — cancellala per far subentrare queste.",
    "Set for Spec": "Imposta per specializzazione",
    "Setup Summary": "Riepilogo configurazione",

    # 160..199
    "Shaman": "Sciamano",
    "Shares its pulse pattern with the target cue. If your focus is also your target, you get one cue rather than two.": "Condivide lo schema di impulsi con il segnale del bersaglio. Se il tuo focus è anche il tuo bersaglio, riceverai un solo segnale anziché due.",
    "Sharp high kick layered with heavy low kick and rumble decay.": "Colpo netto ad alta frequenza sovrapposto a un colpo pesante a bassa frequenza con decadimento della vibrazione.",
    "Show a Play button on every cue": "Mostra un pulsante Riproduci su ogni segnale",
    "Show minimap icon": "Mostra icona della minimappa",
    "Show per-cue detail controls": "Mostra controlli di dettaglio per segnale",
    "Shows only the page switches and this page. Every cue keeps its own settings; turn this off to get every page back exactly as it was.": "Mostra solo i selettori di pagina e questa pagina. Ogni segnale mantiene le proprie impostazioni; disattiva questa opzione per ripristinare ogni pagina esattamente com'era.",
    "Silenced": "Silenziato",
    "Simple view": "Vista semplice",
    "Slow, harmonic oceanic gravity swells and coastal tides while submerged in deep oceans.": "Lente e armoniche onde gravitazionali oceaniche e maree costiere durante l'immersione negli oceani profondi.",
    "Snappy & Taps": "Scatti e tocchi",
    "Social & Group": "Social e gruppo",
    "Social & Group Communication": "Comunicazione social e di gruppo",
    "Soft target interact": "Interazione con bersaglio dinamico",
    "Special casting": "Lancio speciale",
    "Speeds up or slows down ": "Velocizza o rallenta ",
    "Spirit healer": "Curatore spirituale",
    "Split left and right": "Dividi sinistra e destra",
    "Square / X: open settings": "Quadrato / X: apri impostazioni",
    "Stable opened": "Finestra di stallaggio aperta",
    "Stack split ratchet": "Frazionamento pila a scatto",
    "Standard Rumble": "Vibrazione standard",
    "Standard balance across all categories": "Bilanciamento standard tra tutte le categorie",
    "Status: %s": "Stato: %s",
    "Step 4: Interface & Social Alerts": "Fase 4: Avvisi di interfaccia e social",
    "Step 6: Master Strength & Completion": "Fase 6: Intensità principale e completamento",
    "Steps per second at full running speed. Scaled by how fast you are actually moving.": "Passi al secondo alla massima velocità di corsa. Scalato in base alla velocità effettiva di movimento.",
    "Steps per second at normal walking speed.": "Passi al secondo alla normale velocità di camminata.",
    "Strength": "Intensità",
    "Strike strength": "Intensità del colpo",
    "Stroke depth": "Profondità della bracciata",
    "Stroke rate, fast (Hz)": "Frequenza bracciate, veloce (Hz)",
    "Stroke rate, slow (Hz)": "Frequenza bracciate, lenta (Hz)",
    "Strokes per second at barely-moving speed.": "Bracciate al secondo a velocità minima di movimento.",
    "Stunned": "Stordito",
    "Summon offered": "Evocazione offerta",
    "Swapped / Inverted Rumble": "Vibrazione invertita / scambiata",
    "Swell depth": "Profondità del moto ondoso",
    "Swell rate (Hz)": "Frequenza del moto ondoso (Hz)",
    "Swell strength": "Intensità del moto ondoso",

    # 200..249
    "Switch to this profile": "Passa a questo profilo",
    "Switches every cue on the Casting page on or off at once. Each cue keeps its own setting underneath.": "Attiva o disattiva contemporaneamente tutti i segnali nella pagina Incantesimi. Ogni segnale mantiene le proprie impostazioni sottostanti.",
    "Switches every cue on the Character & Status page on or off at once. Each cue keeps its own setting underneath.": "Attiva o disattiva contemporaneamente tutti i segnali nella pagina Personaggio e stato. Ogni segnale mantiene le proprie impostazioni sottostanti.",
    "Switches every cue on the Interface & Accessibility page on or off at once. Each cue keeps its own setting underneath.": "Attiva o disattiva contemporaneamente tutti i segnali nella pagina Interfaccia e accessibilità. Ogni segnale mantiene le proprie impostazioni sottostanti.",
    "Switches every cue on the Movement & Travel page on or off at once. Each cue keeps its own setting underneath.": "Attiva o disattiva contemporaneamente tutti i segnali nella pagina Movimento e viaggio. Ogni segnale mantiene le proprie impostazioni sottostanti.",
    "Switches every cue on the Social & Group page on or off at once. Each cue keeps its own setting underneath.": "Attiva o disattiva contemporaneamente tutti i segnali nella pagina Social e gruppo. Ogni segnale mantiene le proprie impostazioni sottostanti.",
    "Switches every cue on the Target & Focus page on or off at once. Each cue keeps its own setting underneath.": "Attiva o disattiva contemporaneamente tutti i segnali nella pagina Bersaglio e focus. Ogni segnale mantiene le proprie impostazioni sottostanti.",
    "Switches every cue on the World & Environment page on or off at once. Each cue keeps its own setting underneath.": "Attiva o disattiva contemporaneamente tutti i segnali nella pagina Mondo e ambiente. Ogni segnale mantiene le proprie impostazioni sottostanti.",
    "Talking to someone": "Conversazione con un personaggio",
    "Target": "Bersaglio",
    "Target & Crosshair Feedback": "Feedback bersaglio e mirino",
    "Target & Focus": "Bersaglio e focus",
    "Target changed": "Bersaglio cambiato",
    "Target died": "Il bersaglio è morto",
    "Target started casting": "Il bersaglio ha iniziato il lancio",
    "Target used major defensive": "Il bersaglio ha usato un'abilità difensiva principale",
    "Target's cast stopped": "Lancio del bersaglio interrotto",
    "Targeted by enemy": "Preso di mira da un nemico",
    "Targeting": "Selezione del bersaglio",
    "Test Alert": "Prova avviso",
    "Test Impact": "Prova impatto",
    "Test Lock": "Prova blocco",
    "Test Reward": "Prova ricompensa",
    "Test Rumble": "Prova vibrazione",
    "Test Strike": "Prova colpo",
    "Test UI": "Prova interfaccia",
    "Test the selected mode": "Prova la modalità selezionata",
    "Textures & Patterns": "Texture e pattern",
    "The Accessibility section": "La sezione Accessibilità",
    "The Cue Index directory": "La directory dell'Indice dei segnali",
    "The _QUIET variant covers failures the game prints no error for, so this can fire with nothing visible on screen.": "La variante _QUIET copre i fallimenti per cui il gioco non stampa errori, pertanto può attivarsi senza alcun elemento visibile a schermo.",
    "The experimental section": "La sezione sperimentale",
    "The lightest possible tick when a conversation window opens with any NPC.": "Il tic più leggero possibile all'apertura di una finestra di dialogo con qualsiasi PNG.",
    "The master switch for this page. Also on the Casting page, where the cue lives alongside the other casting cues.": "L'interruttore generale per questa pagina. Presente anche nella pagina Incantesimi, dove il segnale si trova insieme agli altri segnali di lancio.",
    "This character": "Questo personaggio",
    "This character reports no specialization, so there is no per-specialization rule to set. The row appears by itself on a character that has one.": "Questo personaggio non segnala alcuna specializzazione, quindi non vi è alcuna regola per specializzazione da impostare. La riga apparirà automaticamente su un personaggio che ne possiede una.",
    "This specialization": "Questa specializzazione",
    "This specialization (": "Questa specializzazione (",
    "Three rhythmic thuds.": "Tre colpi sordi ritmici.",
    "Three-stage rising tension building on the low motor.": "Tensione crescente a tre stadi che si accumula sul motore a bassa frequenza.",
    "Thrill curve (high)": "Curva di brivido (alta)",
    "Thrill peak (high)": "Picco di brivido (alto)",
    "Time in seconds for a complete wave cycle. Real oceanic swells roll every 8 to 12 seconds (~0.10 Hz). Shorter periods feel like choppy coastal chop; longer periods feel like open-ocean rollers.": "Tempo in secondi per un ciclo d'onda completo. Il moto ondoso oceanico reale oscilla ogni 8-12 secondi (~0,10 Hz). Periodi più brevi danno la sensazione di increspature costiere agitate; periodi più lunghi ricordano i grandi marosi dell'oceano aperto.",
    "Tracked cooldown ready": "Tempo di recupero tracciato pronto",
    "Trade opened": "Finestra di scambio aperta",
    "Triggers, modes, and motor tuning": "Inneschi, modalità e calibrazione dei motori",
    "Try Texture": "Prova texture",
    "Tuned for HD Rumble voice-coil actuators": "Calibrato per attuatori a bobina vocale HD Rumble",
    "Turn off every cue in the active profile in one sweep (useful for quiet debugging).": "Disattiva tutti i segnali nel profilo attivo in una sola volta (utile per il debug silenzioso).",
    "Turn on every cue in the active profile in one sweep (useful for testing/debugging).": "Attiva tutti i segnali nel profilo attivo in una sola volta (utile per test/debug).",

    # 250..299
    "Turn whole pages of cues on or off. Each cue keeps its own setting underneath: switching a page back on restores exactly what was there.": "Attiva o disattiva intere pagine di segnali. Ogni segnale mantiene la propria impostazione sottostante: riattivando una pagina si ripristina esattamente ciò che era configurato.",
    "Two crisp ticks when a cooldown the built-in Cooldown Manager is tracking comes off cooldown.": "Due tic netti quando un'abilità monitorata dal gestore dei tempi di recupero integrato torna disponibile.",
    "Two heavier hits with a gap between them.": "Due colpi più pesanti separati da un intervallo.",
    "Two kinds of trigger: pulses and textures": "Due tipi di innesco: impulsi e texture",
    "Two rhythmic thuds.": "Due colpi sordi ritmici.",
    "Two soft ticks when the action bar pages to a different set of abilities.": "Due lievi tic quando la barra delle azioni passa a un diverso set di abilità.",
    "Two soft ticks when you page the radial left or right with the shoulder buttons.": "Due lievi tic quando si sfoglia il menu radiale a sinistra o a destra con i pulsanti dorsali.",
    "UI focus moved": "Spostamento selezione interfaccia",
    "UI navigation hit an edge": "Bordo dell'interfaccia raggiunto nella navigazione",
    "UI panel closed": "Pannello interfaccia chiuso",
    "UI panel opened": "Pannello interfaccia aperto",
    "Untested whether this also fires on every instant-cast press rather than only real cast-bar completions — if so, it'll feel far too frequent to read as \"that landed\" specifically. Check before relying on it.": "Non è stato verificato se questo si attivi anche alla pressione di ogni incantesimo istantaneo anziché solo al completamento effettivo della barra di lancio: in tal caso risulterebbe troppo frequente per essere percepito nello specifico come «colpo andato a segno». Verifica prima di farvi affidamento.",
    "Untested.": "Non testato.",
    "Use the old estimator": "Usa il vecchio stimatore",
    "Using \"%s\" — set for %s.": "In uso \"%s\" — impostato per %s.",
    "Vendor window opened": "Finestra del mercante aperta",
    "Vibration Mode": "Modalità di vibrazione",
    "Vibration Schema: |cffffd100%s|r": "Schema di vibrazione: |cffffd100%s|r",
    "Vibration schema": "Schema di vibrazione",
    "Voice-coil actuators (LRA), ultra-low 0.025 floor, instant response": "Attuatori a bobina vocale (LRA), soglia minima ultrabassa di 0,025, risposta istantanea",
    "Walk cadence (steps/s)": "Cadenza di camminata (passi/s)",
    "Warlock": "Stregone",
    "Warning lead time": "Tempo di preavviso",
    "Warrior": "Guerriero",
    "Watches UNIT_TARGET and target swaps for hostile units whose target is the player. Uses UnitIsUnit('targettarget', 'player') with defensive secrecy guards.": "Monitora UNIT_TARGET e i cambi di bersaglio per unità ostili il cui bersaglio è il giocatore. Utilizza UnitIsUnit('targettarget', 'player') con controlli protetti per evitare la contaminazione.",
    "Wave cycle (seconds)": "Ciclo dell'onda (secondi)",
    "Wave period (sec)": "Periodo dell'onda (sec)",
    "Wave steepness": "Pendenza dell'onda",
    "Weapon or gear swapped": "Arma o equipaggiamento cambiato",
    "What this does": "Cosa fa",
    "When mobs are pulled socially — aggroing because a neighbour was pulled — the game often reports status 0 even though you have aggro.": "Quando i nemici vengono attirati per prossimità (social aggro) — acquisendo aggressività perché un vicino è stato ingaggiato — il gioco spesso riporta lo stato 0 anche se possiedi la minaccia (aggro).",
    "Which of the preset shapes this specific cue plays when it fires. \"": "Quale delle forme predefinite riproduce questo specifico segnale quando si attiva. \"",
    "Which physical motors each cue drives. Start with Standard Rumble, then calibrate the motors below.": "Quali motori fisici vengono azionati da ciascun segnale. Inizia con Vibrazione standard, quindi calibra i motori in basso.",
    "Which physical motors each trigger drives. Try one, test a mode below, keep the one you can feel.": "Quali motori fisici vengono azionati da ciascun innesco. Provane uno, testa una modalità qui sotto e mantieni quella che riesci a percepire.",
    "Which profile to use right now. This writes to whichever rule is currently in force, so picking here always changes what you are actually using rather than editing a rule something more specific is overriding.": "Quale profilo utilizzare attualmente. Questa opzione scrive su qualsiasi regola sia attualmente in vigore, quindi selezionare qui modifica sempre ciò che stai effettivamente utilizzando anziché modificare una regola sovrascritta da una più specifica.",
    "Wind amplitude": "Ampiezza del vento",
    "Wind resistance & thrust surge while flying. Scales dynamically with your flight speed.": "Resistenza del vento e spinta di propulsione durante il volo. Si adatta dinamicamente alla velocità di volo.",
    "Windows": "Finestre",
    "World": "Mondo",
    "World & Environment": "Mondo e ambiente",
    "World Immersion": "Immersione nel mondo",
    "You are alive again": "Sei di nuovo in vita",
    "You died": "Sei morto",
    "You have aggro": "Hai la minaccia (aggro)",
    "Your cast ended": "Il tuo lancio è terminato",
    "Your cast failed": "Il tuo lancio è fallito",
    "Your cast started": "Il tuo lancio è iniziato",
    "Your cast succeeded": "Il tuo lancio è riuscito",
    "Zone changed": "Zona cambiata",
    "an impact": "un impatto",

    # 300..330
    "could not apply that preset": "impossibile applicare questa preimpostazione",
    "could not run that": "impossibile eseguire",
    "could not set that rule": "impossibile impostare questa regola",
    "detection unavailable": "rilevamento non disponibile",
    "in force": "in vigore",
    "no role chosen": "nessun ruolo scelto",
    "once a minute": "una volta al minuto",
    "once every ": "una volta ogni ",
    "once every %.1f seconds": "una volta ogni %.1f secondi",
    "|cff00ff00Left-Click:|r Open Settings": "|cff00ff00Clic sinistro:|r Apri impostazioni",
    "|cff00ff00Right-Click:|r Toggle Master On/Off": "|cff00ff00Clic destro:|r Attiva/Disattiva generale",
    "|cff00ff00[Adjusting %d%%]|r Use |cffffffff[← / →]|r to Change, |cff38BDF8[A]|r Confirm & Feel": "|cff00ff00[Regolazione %d%%]|r Usa |cffffffff[← / →]|r per modificare, |cff38BDF8[A]|r Conferma e prova",
    "|cff38BDF8[L1 / LB]|r": "|cff38BDF8[L1 / LB]|r",
    "|cff38BDF8[L1/R1]|r Tabs  •  |cff38BDF8[A]|r Toggle Slider / Select": "|cff38BDF8[L1/R1]|r Schede  •  |cff38BDF8[A]|r Attiva/Disattiva cursore / Seleziona",
    "|cff38BDF8[R1 / RB]|r": "|cff38BDF8[R1 / RB]|r",
    "|cff444444[L1 / LB]|r": "|cff444444[L1 / LB]|r",
    "|cff444444[R1 / RB]|r": "|cff444444[R1 / RB]|r",
    "|cff4cb8ffPulse:|r Quick setup complete! Type |cffffffff/pulse|r anytime to fine-tune settings.": "|cff4cb8ffPulse:|r Configurazione rapida completata! Digita |cffffffff/pulse|r in qualsiasi momento per perfezionare le impostazioni.",
    "|cff4db8ff✔ |r": "|cff4db8ff✔ |r",
    "|cff888888Drag:|r Move Icon": "|cff888888Trascina:|r Sposta icona",
    "|cff888888Loss of control cues are governed by the master switch on the main Pulse page.|r": "|cff888888I segnali di perdita di controllo sono gestiti dall'interruttore generale nella pagina principale di Pulse.|r",
    "|cff888888Recommended intensity:|r %d%%": "|cff888888Intensità consigliata:|r %d%%",
    "|cffffcc00◀/▶ Adjust Intensity|r   •   %s/%s Lock Value   •   %s Try Texture": "|cffffcc00◀/▶ Regola intensità|r   •   %s/%s Blocca valore   •   %s Prova texture",
    "|cffffd100%s|r  |cff00ff00[ACTIVE]|r": "|cffffd100%s|r  |cff00ff00[ATTIVO]|r",
    "|cffffd100/pulseui|r opens it too. |cffffd100/pulse setup|r re-opens Quick Setup, |cffffd100/pulse test <mode>|r plays a shape.": "Anche |cffffd100/pulseui|r la apre. |cffffd100/pulse setup|r riapre la Configurazione rapida, |cffffd100/pulse test <mode>|r riproduce una forma.",
    "|r, |cffffd100": "|r, |cffffd100",
    "• |r": "• |r",
    "⚔️ Melee DPS": "⚔️ Assaltatore da mischia",
    "🏹 Ranged DPS": "🏹 Assaltatore a distanza",
    "💚 Healer": "💚 Guaritore",
    "🛡️ Tank": "🛡️ Difensore (Tank)",
}

def main():
    batch_path = os.path.join(os.path.dirname(__file__), "batch1b_ui_navigation.json")
    out_path = os.path.join(os.path.dirname(__file__), "translated_itIT_batch1b.json")

    with open(batch_path, "r", encoding="utf-8") as f:
        batch = json.load(f)

    items = batch["items"]
    print(f"Loaded {len(items)} items from {os.path.basename(batch_path)}")

    translated_items = []
    missing = []
    sig_errors = []
    color_errors = []

    for idx, it in enumerate(items):
        src = it["source"]
        if src not in TRANSLATIONS_IT:
            missing.append((idx, src))
            continue

        tgt = TRANSLATIONS_IT[src]
        
        # Validate format specifiers
        sig_src = extract_signature(src)
        sig_tgt = extract_signature(tgt)
        if sig_src != sig_tgt:
            sig_errors.append((idx, src, tgt, sig_src, sig_tgt))

        # Validate color tags balance
        if not check_color_balance(src, tgt):
            color_errors.append((idx, src, tgt))

        translated_items.append({
            "source": src,
            "target": tgt
        })

    if missing:
        print(f"ERROR: {len(missing)} items missing translation:")
        for idx, src in missing:
            print(f"  [{idx}] {src!r}")
        sys.exit(1)

    if sig_errors:
        print(f"ERROR: {len(sig_errors)} signature mismatches:")
        for idx, src, tgt, s_src, s_tgt in sig_errors:
            print(f"  [{idx}] src({s_src})={src!r} != tgt({s_tgt})={tgt!r}")
        sys.exit(1)

    if color_errors:
        print(f"ERROR: {len(color_errors)} color code mismatches:")
        for idx, src, tgt in color_errors:
            print(f"  [{idx}] src={src!r} tgt={tgt!r}")
        sys.exit(1)

    output_data = {"items": translated_items}
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print(f"SUCCESS: Wrote {len(translated_items)} verified translations to {out_path}")

if __name__ == "__main__":
    main()
