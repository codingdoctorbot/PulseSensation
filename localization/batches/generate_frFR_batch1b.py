#!/usr/bin/env python3
"""
Generates and validates translated_frFR_batch1b.json for PulseHaptics French (frFR) localization.
"""

import json
import os
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "tools"))
from validate_catalog import extract_signature, check_color_balance

BATCH1B_JSON = os.path.join(os.path.dirname(__file__), "batch1b_ui_navigation.json")
OUTPUT_JSON = os.path.join(os.path.dirname(__file__), "translated_frFR_batch1b.json")

TRANSLATIONS_FR = {
    # 0..49
    "Low health": "Santé faible",
    "Low health texture": "Texture de santé faible",
    "Low motor": "Moteur lourd",
    "Low motor holds a steady presence, floored so it's never silent while gliding; high motor eases in from near-silent toward thrillPeak as speed climbs, shaped by thrillCurve.": "Le moteur lourd maintient une présence constante, avec un seuil minimal pour ne jamais être silencieux en vol plané ; le moteur rapide s'introduit progressivement depuis un niveau quasi silencieux vers thrillPeak à mesure que la vitesse augmente, selon la forme de thrillCurve.",
    "Mage": "Mage",
    "Manage": "Gérer",
    "Master Vibration Strength": "Puissance générale des vibrations",
    "Master switch for every loss-of-control cue below. With this off, none of them fire and no loss-of-control events are registered at all.": "Interrupteur général pour tous les signaux de perte de contrôle ci-dessous. S'il est désactivé, aucun d'entre eux ne se déclenche et aucun événement de perte de contrôle n'est enregistré.",
    "Master switch. With this off, nothing registers and nothing costs anything.": "Interrupteur général. Lorsqu'il est désactivé, rien n'est enregistré et aucune ressource n'est consommée.",
    "Melee auto-attack started": "Attaque automatique en mêlée commencée",
    "Melee auto-attack stopped": "Attaque automatique en mêlée arrêtée",
    "Menus & tabs": "Menus et onglets",
    "Messages": "Messages",
    "Minimum severity": "Gravité minimale",
    "Mode to test": "Mode à tester",
    "Most specific wins. A scope set to |cffffd100No rule|r has no opinion and lets the one below it decide; with none of them set, Pulse uses Default.": "La règle la plus spécifique l'emporte. Une portée définie sur |cffffd100Aucune règle|r n'exprime aucun choix et laisse celle du dessous décider ; si aucune n'est définie, Pulse utilise Par défaut.",
    "Movement": "Déplacement",
    "Movement & Travel": "Déplacement et voyage",
    "Multiplies every trigger's intensity. Part of the current profile, not global.": "Multiplie l'intensité de chaque déclencheur. Fait partie du profil actuel, non global.",
    "Name the new profile:": "Nommer le nouveau profil :",
    "Navigation": "Navigation",
    "New profile": "Nouveau profil",
    "Next >": "Suivant >",
    "No rule": "Aucune règle",
    "None (full sensory richness)": "Aucun (richesse sensorielle maximale)",
    "None (stock defaults)": "Aucun (valeurs par défaut d'origine)",
    "ON — option changes and cue firings will print here.": "ACTIVÉ — les modifications d'options et les déclenchements de signaux s'afficheront ici.",
    "Ocean Waves & Swell": "Vagues océaniques et houle",
    "Ocean waves & swell": "Vagues océaniques et houle",
    "Ocean zones only (guessed from zone name)": "Zones océaniques uniquement (détectées d'après le nom de zone)",
    "Off by default and deliberately the faintest cue in the addon: this fires for EVERY NPC you talk to, which in a city is constantly. Try it before leaving it on. Untested.": "Désactivé par défaut et délibérément le signal le plus discret de l'addon : il se déclenche pour CHAQUE PNJ auquel vous parlez, ce qui est permanent en ville. Essayez-le avant de le laisser activé. Non testé.",
    "Offensive": "Offensif",
    "One cue for both directions, same reasoning as the navigation edge cue — a motor can't tell you which way you went.": "Un seul signal pour les deux directions, selon la même logique que pour le signal de bord de navigation — un moteur ne peut pas indiquer la direction empruntée.",
    "One full-bodied hit on both motors.": "Une frappe ample sur les deux moteurs.",
    "One long, sombre pulse when a spirit healer's window opens.": "Une longue impulsion sourde à l'ouverture de la fenêtre d'un gardien des âmes.",
    "One sharp, heavy impact — fast attack, fast decay.": "Un impact net et lourd — attaque rapide, déclin rapide.",
    "One strong, sustained pulse.": "Une impulsion forte et prolongée.",
    "One sustained pulse.": "Une impulsion prolongée.",
    "Open Pulse settings": "Ouvrir les réglages de Pulse",
    "Other": "Autre",
    "Overall heave amplitude of the oceanic swell. Sets the physical displacement intensity of the slow motor.": "Amplitude globale de soulèvement de la houle océanique. Définit l'intensité du déplacement physique du moteur lent.",
    "Overall intensity": "Intensité globale",
    "Overall strength. Meant to sit at the edge of perception — if you notice it as a vibration rather than as being submerged, it is too high. Inherits the old idleFloatAmplitude, which was live-tuned to 0.04.": "Puissance globale. Conçue pour se situer à la limite de la perception — si vous la ressentez comme une vibration plutôt que comme une immersion, elle est trop élevée. Hérite de l'ancien idleFloatAmplitude, calibré en direct à 0,04.",
    "Overdrive kick": "Impulsion d'overdrive",
    "Overdrive time (s)": "Durée d'overdrive (s)",
    "Own motor": "Moteur propre",
    "PLAYER_ALIVE also fires when you release to a graveyard, so this can fire while you are still a ghost.": "PLAYER_ALIVE se déclenche également lors de la libération vers un cimetière, ce qui peut donc se produire pendant que vous êtes encore un fantôme.",
    "PLAYER_SOFT_FRIEND_CHANGED, occurrence-only, no payload. Worth pairing with the hostile cue above only if you can tell two TICKs apart — if not, give one of them a different shape with its own \"Feels like\" dropdown.": "PLAYER_SOFT_FRIEND_CHANGED, occurrence uniquement, sans charge utile. À associer au signal hostile ci-dessus uniquement si vous distinguez deux TICs — sinon, donnez à l'un d'eux une forme différente avec sa propre liste déroulante « Sensation ».",
    "PULSE QUICK SETUP": "CONFIGURATION RAPIDE DE PULSE",
    "Pacified or school-locked": "Pacifié ou verrouillé par école de magie",

    # 50..99
    "Page switches": "Changements de page",
    "Paladin": "Paladin",
    "Passively polled by observing IsEnabled() on the currently focused element. Fires if the element becomes disabled while focused.": "Interrogé passivement en surveillant IsEnabled() sur l'élément actuellement sélectionné. Se déclenche si l'élément devient désactivé pendant qu'il a le focus.",
    "Passively polled via GetUIPanel every 0.05s to eliminate UIParentPanelManager execution taint on protected frames.": "Interrogé passivement via GetUIPanel toutes les 0,05 s pour éliminer la corruption d'exécution (taint) de UIParentPanelManager sur les cadres protégés.",
    "Passively polled via GetUIPanel every 0.05s. Detects when major UI panels are dismissed without callback taint.": "Interrogé passivement via GetUIPanel toutes les 0,05 s. Détecte la fermeture des panneaux d'interface majeurs sans corruption de rappel (callback taint).",
    "Passively polled via GroupTargeting.isTargetingActive. Fires when the group targeting modifier is released.": "Interrogé passivement via GroupTargeting.isTargetingActive. Se déclenche lorsque le modificateur de ciblage de groupe est relâché.",
    "Physical tool strikes: anvil hammer strokes, mining pickaxe impacts, tailoring stitches.": "Frappes physiques d'outils : coups de marteau sur l'enclume, coups de pioche de minage, points de couture.",
    "Pick a mode to test below.": "Choisissez un mode à tester ci-dessous.",
    "Play": "Jouer",
    "Play ": "Jouer ",
    "Play a few seconds of this texture at its current intensity. Module-driven preview reproducing authentic physical dynamics and configured intensity.": "Joue quelques secondes de cette texture à son intensité actuelle. Aperçu géré par le module reproduisant la dynamique physique authentique et l'intensité configurée.",
    "Presence floor (low)": "Seuil de présence (lourd)",
    "Priest": "Prêtre",
    "Prints every option you change and every cue that actually fires to chat, in real time. Same as /pulse debug — off by default, and resets to off on /reload since it's a testing aid, not a saved preference.": "Affiche dans la discussion chaque option modifiée et chaque signal déclenché, en temps réel. Identique à /pulse debug — désactivé par défaut, et réinitialisé sur désactivé lors d'un /reload car il s'agit d'une aide au test et non d'une préférence enregistrée.",
    "Profile": "Profil",
    "Profiles": "Profils",
    "Profiles and automatic rules": "Profils et règles automatiques",
    "Progression": "Progression",
    "Progressive low build leading to a sharp high break.": "Montée progressive sur le moteur lourd menant à une rupture nette sur le moteur rapide.",
    "Pull / glide balance": "Équilibre traction / glisse",
    "Pulse": "Pulse",
    "Pulse is using |cffffd100%s|r, because a rule is set for %s.": "Pulse utilise |cffffd100%s|r, car une règle est définie pour %s.",
    "Pulse tunes motor spin-up attack, coast-down release, and breakaway friction to match your physical hardware actuators.": "Pulse calibre l'attaque d'accélération des moteurs, le relâchement en décélération et le frottement de décollement pour correspondre à vos actionneurs physiques.",
    "Pulse: (Engine recorded %d errors. Last error: %s)": "Pulse : (Le moteur a enregistré %d erreurs. Dernière erreur : %s)",
    "Pulse: /pulse test <mode>|heartbeat|warningbeat — try one of: ": "Pulse : /pulse test <mode>|heartbeat|warningbeat — essayez l'un de : ",
    "Pulse: activated profile \"%s\"": "Pulse : profil « %s » activé",
    "Pulse: active profile is \"%s\" (%s)": "Pulse : le profil actif est « %s » (%s)",
    "Pulse: bound profile \"%s\" to specialization %s": "Pulse : profil « %s » lié à la spécialisation %s",
    "Pulse: could not build settings row %q (%s)": "Pulse : impossible de créer la ligne de réglages %q (%s)",
    "Pulse: could not build the settings window (": "Pulse : impossible de créer la fenêtre des réglages (",
    "Pulse: debug ": "Pulse : débogage ",
    "Pulse: disabled all %d cues in active profile.": "Pulse : tous les %d signaux du profil actif ont été désactivés.",
    "Pulse: disabled all %d cues in profile \"%s\".": "Pulse : tous les %d signaux du profil « %s » ont été désactivés.",
    "Pulse: disabled all %d cues in profile %s.": "Pulse : tous les %d signaux du profil %s ont été désactivés.",
    "Pulse: enabled all %d cues in active profile.": "Pulse : tous les %d signaux du profil actif ont été activés.",
    "Pulse: enabled all %d cues in profile \"%s\".": "Pulse : tous les %d signaux du profil « %s » ont été activés.",
    "Pulse: enabled all %d cues in profile %s.": "Pulse : tous les %d signaux du profil %s ont été activés.",
    "Pulse: live oscilloscope is provided by the companion addon PulseDebug (/pdebug scope).": "Pulse : l'oscilloscope en direct est fourni par l'addon associé PulseDebug (/pdebug scope).",
    "Pulse: minimap icon %s": "Pulse : icône de minicarte %s",
    "Pulse: no profile matching \"%s\". Available: %s": "Pulse : aucun profil correspondant à « %s ». Disponibles : %s",
    "Pulse: switched to profile \"%s\"": "Pulse : basculé sur le profil « %s »",
    "Pulse: that preview is unavailable.": "Pulse : cet aperçu est indisponible.",
    "Pulse: this looks like a %s%s. Pick it above, then press Apply.": "Pulse : cela ressemble à %s%s. Choisissez-le ci-dessus, puis appuyez sur Appliquer.",
    "Pure flavour — nothing depends on it. Untested.": "Purement immersif — rien n'en dépend. Non testé.",
    "Pure novelty. Off by default forever, basically — nobody asked for this one.": "Simple curiosité. Désactivé par défaut en permanence — quasiment personne ne l'a demandé.",
    "Put every motor's strength, floor, timing and curve back to the engine defaults. Doesn't touch cues, per-cue intensity, mode tuning or your schema.": "Rétablit la puissance, le seuil, la durée et la courbe de chaque moteur aux valeurs par défaut du moteur haptique. Ne modifie pas les signaux, l'intensité par signal, le réglage des modes ni votre schéma.",
    "Put the profile in use back to its stock defaults — works on built-ins too, restoring their curated content rather than blank Registry.lua defaults.": "Rétablit le profil utilisé à ses valeurs par défaut d'origine — fonctionne aussi pour les profils intégrés, restaurant leur contenu préparé plutôt que les valeurs vides de Registry.lua.",
    "PvP (Tactical Radar)": "JcJ (radar tactique)",
    "Quest accepted": "Quête acceptée",
    "Quest offered": "Quête proposée",

    # 100..149
    "Quest ready to hand in": "Quête prête à être rendue",
    "Quest turned in": "Quête terminée",
    "Questing": "Quêtes",
    "Questing & Exploration": "Quêtes et exploration",
    "Quests": "Quêtes",
    "Quick Setup": "Configuration rapide",
    "Quick Setup Wizard": "Assistant de configuration rapide",
    "Radial menu": "Menu radial",
    "Radial menu closed": "Menu radial fermé",
    "Radial menu opened": "Menu radial ouvert",
    "Radial page changed": "Page du menu radial changée",
    "Radial segment changed": "Segment radial changé",
    "Radial segment chosen": "Segment radial choisi",
    "Radial segment unavailable": "Segment radial indisponible",
    "Radial selection cancelled": "Sélection radiale annulée",
    "Ranged auto-repeat started": "Tir automatique à distance commencé",
    "Ranged auto-repeat stopped": "Tir automatique à distance arrêté",
    "Rapid staccato triple-click on the high motor.": "Triple clic rapide en staccato sur le moteur rapide.",
    "Reading something": "Lecture d'un document",
    "Reads the segment's own IsEnabled() — the same value Blizzard reads to grey the highlight out, so this matches what you see on screen. Fires in place of \"Radial segment changed\", not alongside it.": "Lit le IsEnabled() propre au segment — la même valeur que Blizzard utilise pour griser la surbrillance, correspondant ainsi à ce que vous voyez à l'écran. Se déclenche à la place de « Segment radial changé », et non en parallèle.",
    "Ready check": "Appel",
    "Ready check finished": "Appel terminé",
    "Release time (s)": "Temps de relâchement (s)",
    "Reload UI": "Recharger l'IU",
    "Reload UI to apply the language change.": "Rechargez l'IU pour appliquer le changement de langue.",
    "Reload the interface to apply your selected addon language.": "Rechargez l'interface pour appliquer la langue sélectionnée pour l'addon.",
    "Rename": "Renommer",
    "Rename \"%s\" to:": "Renommer « %s » en :",
    "Rename the profile in use. Every rule pointing at it follows the rename. Built-in profiles can't be renamed.": "Renomme le profil en cours d'utilisation. Chaque règle qui pointe vers lui suit le renommage. Les profils intégrés ne peuvent pas être renommés.",
    "Rename this profile": "Renommer ce profil",
    "Rename...": "Renommer...",
    "Repaired equipment": "Équipement réparé",
    "Reset": "Réinitialiser",
    "Reset every motor's strength, floor, timing and curve back to the engine defaults? This can't be undone.": "Réinitialiser la puissance, le seuil, la durée et la courbe de chaque moteur aux valeurs par défaut du moteur haptique ? Cette action est irréversible.",
    "Reset profile \"%s\" to defaults? Every cue, intensity and mode override in it goes back to stock values. This can't be undone.": "Réinitialiser le profil « %s » à ses valeurs par défaut ? Chaque signal, intensité et remplacement de mode qu'il contient retrouvera ses valeurs d'origine. Cette action est irréversible.",
    "Reset this profile": "Réinitialiser ce profil",
    "Reset...": "Réinitialiser...",
    "Resources": "Ressources",
    "Response curve": "Courbe de réponse",
    "Resting": "Repos",
    "Resurrection offered": "Résurrection proposée",
    "Rewards": "Récompenses",
    "Rogue": "Voleur",
    "Role poll": "Vérification des rôles",
    "Rooted": "Immobilisé",
    "Routing & Schema": "Acheminement et schéma",
    "Rules": "Règles",
    "Run Wizard": "Lancer l'assistant",
    "Run cadence (steps/s)": "Cadence de course (pas/s)",
    "Same polled mechanism as \"Confirmation popup appeared\". Untested.": "Même mécanisme d'interrogation que pour « Fenêtre de confirmation apparue ». Non testé.",

    # 150..199
    "Save & Start Playing": "Enregistrer et commencer à jouer",
    "Scales both the bed and the strikes for %s, before the two shared strengths above.": "Ajuste à la fois le lit vibratoire et les frappes pour %s, avant les deux puissances partagées ci-dessus.",
    "Scales this cue on top of the overall intensity on the Pulse page.": "Ajuste ce signal en plus de l'intensité globale sur la page Pulse.",
    "School lockouts are frequent in melee-heavy content. Off by default because a cue every kick you eat can crowd out the ones that mean you cannot act at all.": "Les verrouillages d'école de magie sont fréquents en mêlée. Désactivé par défaut car un signal pour chaque interruption subie peut masquer ceux qui vous empêchent totalement d'agir.",
    "Search %d cues...": "Rechercher parmi %d signaux...",
    "Secondary resource full": "Ressource secondaire pleine",
    "Set Floor": "Définir le seuil",
    "Set but not in force: |cffffd100%s|r. A more specific rule above is winning — clear it to let these take over.": "Défini mais non actif : |cffffd100%s|r. Une règle plus spécifique ci-dessus prévaut — effacez-la pour laisser celle-ci prendre le relais.",
    "Set for Spec": "Définir pour la spécialisation",
    "Setup Summary": "Résumé de la configuration",
    "Shaman": "Chaman",
    "Shares its pulse pattern with the target cue. If your focus is also your target, you get one cue rather than two.": "Partage son motif d'impulsion avec le signal de cible. Si votre focalisation est aussi votre cible, vous recevez un seul signal au lieu de deux.",
    "Sharp high kick layered with heavy low kick and rumble decay.": "Impulsion nette sur le moteur rapide superposée à une impulsion lourde sur le moteur lourd avec déclin de vibration.",
    "Show a Play button on every cue": "Afficher un bouton Jouer sur chaque signal",
    "Show minimap icon": "Afficher l'icône de la minicarte",
    "Show per-cue detail controls": "Afficher les commandes détaillées par signal",
    "Shows only the page switches and this page. Every cue keeps its own settings; turn this off to get every page back exactly as it was.": "Affiche uniquement les interrupteurs de page et cette page. Chaque signal conserve ses propres réglages ; désactivez cette option pour rétablir chaque page exactement telle qu'elle était.",
    "Silenced": "Réduit au silence",
    "Simple view": "Vue simple",
    "Slow, harmonic oceanic gravity swells and coastal tides while submerged in deep oceans.": "Houles océaniques harmoniques lentes et marées côtières en immersion en haute mer.",
    "Snappy & Taps": "Vif et impulsions",
    "Social & Group": "Social et groupe",
    "Social & Group Communication": "Communication sociale et de groupe",
    "Soft target interact": "Interaction avec cible souple",
    "Special casting": "Incantations spéciales",
    "Speeds up or slows down ": "Accélère ou ralentit ",
    "Spirit healer": "Gardien des âmes",
    "Split left and right": "Séparer gauche et droite",
    "Square / X: open settings": "Carré / X : ouvrir les réglages",
    "Stable opened": "Écurie ouverte",
    "Stack split ratchet": "Cran de division de pile",
    "Standard Rumble": "Vibration standard",
    "Standard balance across all categories": "Équilibre standard sur toutes les catégories",
    "Status: %s": "État : %s",
    "Step 4: Interface & Social Alerts": "Étape 4 : Alertes d'interface et sociales",
    "Step 6: Master Strength & Completion": "Étape 6 : Puissance générale et finalisation",
    "Steps per second at full running speed. Scaled by how fast you are actually moving.": "Pas par seconde à pleine vitesse de course. Ajusté selon votre vitesse réelle de déplacement.",
    "Steps per second at normal walking speed.": "Pas par seconde à vitesse de marche normale.",
    "Strength": "Puissance",
    "Strike strength": "Force de frappe",
    "Stroke depth": "Amplitude des mouvements",
    "Stroke rate, fast (Hz)": "Fréquence des mouvements, rapide (Hz)",
    "Stroke rate, slow (Hz)": "Fréquence des mouvements, lente (Hz)",
    "Strokes per second at barely-moving speed.": "Mouvements par seconde à vitesse minimale.",
    "Stunned": "Étourdi",
    "Summon offered": "Invocation proposée",
    "Swapped / Inverted Rumble": "Vibration permutée / inversée",
    "Swell depth": "Profondeur de la houle",
    "Swell rate (Hz)": "Fréquence de la houle (Hz)",
    "Swell strength": "Puissance de la houle",

    # 200..249
    "Switch to this profile": "Basculer sur ce profil",
    "Switches every cue on the Casting page on or off at once. Each cue keeps its own setting underneath.": "Active ou désactive d'un coup tous les signaux de la page Incantation. Chaque signal conserve son propre réglage sous-jacent.",
    "Switches every cue on the Character & Status page on or off at once. Each cue keeps its own setting underneath.": "Active ou désactive d'un coup tous les signaux de la page Personnage et état. Chaque signal conserve son propre réglage sous-jacent.",
    "Switches every cue on the Interface & Accessibility page on or off at once. Each cue keeps its own setting underneath.": "Active ou désactive d'un coup tous les signaux de la page Interface et accessibilité. Chaque signal conserve son propre réglage sous-jacent.",
    "Switches every cue on the Movement & Travel page on or off at once. Each cue keeps its own setting underneath.": "Active ou désactive d'un coup tous les signaux de la page Déplacement et voyage. Chaque signal conserve son propre réglage sous-jacent.",
    "Switches every cue on the Social & Group page on or off at once. Each cue keeps its own setting underneath.": "Active ou désactive d'un coup tous les signaux de la page Social et groupe. Chaque signal conserve son propre réglage sous-jacent.",
    "Switches every cue on the Target & Focus page on or off at once. Each cue keeps its own setting underneath.": "Active ou désactive d'un coup tous les signaux de la page Cible et focalisation. Chaque signal conserve son propre réglage sous-jacent.",
    "Switches every cue on the World & Environment page on or off at once. Each cue keeps its own setting underneath.": "Active ou désactive d'un coup tous les signaux de la page Monde et environnement. Chaque signal conserve son propre réglage sous-jacent.",
    "Talking to someone": "Discussion avec un interlocuteur",
    "Target": "Cible",
    "Target & Crosshair Feedback": "Retour de cible et de réticule",
    "Target & Focus": "Cible et focalisation",
    "Target changed": "Cible changée",
    "Target died": "Cible morte",
    "Target started casting": "La cible a commencé à incanter",
    "Target used major defensive": "La cible a utilisé un sort défensif majeur",
    "Target's cast stopped": "Incantation de la cible interrompue",
    "Targeted by enemy": "Ciblé par un ennemi",
    "Targeting": "Ciblage",
    "Test Alert": "Tester l'alerte",
    "Test Impact": "Tester l'impact",
    "Test Lock": "Tester le verrouillage",
    "Test Reward": "Tester la récompense",
    "Test Rumble": "Tester la vibration",
    "Test Strike": "Tester la frappe",
    "Test UI": "Tester l'IU",
    "Test the selected mode": "Tester le mode sélectionné",
    "Textures & Patterns": "Textures et motifs",
    "The Accessibility section": "La section Accessibilité",
    "The Cue Index directory": "Le répertoire d'index des signaux",
    "The _QUIET variant covers failures the game prints no error for, so this can fire with nothing visible on screen.": "La variante _QUIET couvre les échecs pour lesquels le jeu n'affiche aucune erreur, cela peut donc se déclencher sans rien de visible à l'écran.",
    "The experimental section": "La section expérimentale",
    "The lightest possible tick when a conversation window opens with any NPC.": "Le tic le plus discret possible lorsqu'une fenêtre de dialogue s'ouvre avec un PNJ.",
    "The master switch for this page. Also on the Casting page, where the cue lives alongside the other casting cues.": "L'interrupteur général pour cette page. Figure également sur la page Incantation, où le signal réside aux côtés des autres signaux d'incantation.",
    "This character": "Ce personnage",
    "This character reports no specialization, so there is no per-specialization rule to set. The row appears by itself on a character that has one.": "Ce personnage ne signale aucune spécialisation, il n'y a donc pas de règle par spécialisation à définir. La ligne apparaît d'elle-même sur un personnage qui en possède une.",
    "This specialization": "Cette spécialisation",
    "This specialization (": "Cette spécialisation (",
    "Three rhythmic thuds.": "Trois secousses sourdes et rythmées.",
    "Three-stage rising tension building on the low motor.": "Montée en tension en trois étapes progressant sur le moteur lourd.",
    "Thrill curve (high)": "Courbe de frisson (rapide)",
    "Thrill peak (high)": "Pic de frisson (rapide)",
    "Time in seconds for a complete wave cycle. Real oceanic swells roll every 8 to 12 seconds (~0.10 Hz). Shorter periods feel like choppy coastal chop; longer periods feel like open-ocean rollers.": "Durée en secondes pour un cycle complet de vagues. Les véritables houles océaniques déferlent toutes les 8 à 12 secondes (~0,10 Hz). Des périodes plus courtes donnent la sensation d'un clapotis côtier agité ; des périodes plus longues évoquent de puissants rouleaux de haute mer.",
    "Tracked cooldown ready": "Temps de recharge surveillé prêt",
    "Trade opened": "Échange ouvert",
    "Triggers, modes, and motor tuning": "Déclencheurs, modes et calibrage des moteurs",
    "Try Texture": "Tester la texture",
    "Tuned for HD Rumble voice-coil actuators": "Calibré pour les actionneurs à bobine mobile HD Rumble",
    "Turn off every cue in the active profile in one sweep (useful for quiet debugging).": "Désactiver d'un seul coup tous les signaux du profil actif (utile pour un débogage discret).",
    "Turn on every cue in the active profile in one sweep (useful for testing/debugging).": "Activer d'un seul coup tous les signaux du profil actif (utile pour les tests et le débogage).",

    # 250..299
    "Turn whole pages of cues on or off. Each cue keeps its own setting underneath: switching a page back on restores exactly what was there.": "Activez ou désactivez des pages entières de signaux. Chaque signal conserve son propre réglage sous-jacent : réactiver une page rétablit exactement ce qui s'y trouvait.",
    "Two crisp ticks when a cooldown the built-in Cooldown Manager is tracking comes off cooldown.": "Deux tics nets lorsqu'un temps de recharge surveillé par le gestionnaire intégré redevient disponible.",
    "Two heavier hits with a gap between them.": "Deux frappes plus lourdes séparées par un intervalle.",
    "Two kinds of trigger: pulses and textures": "Deux types de déclencheurs : impulsions et textures",
    "Two rhythmic thuds.": "Deux secousses sourdes et rythmées.",
    "Two soft ticks when the action bar pages to a different set of abilities.": "Deux tics discrets lorsque la barre d'action change de page vers un ensemble d'actions différent.",
    "Two soft ticks when you page the radial left or right with the shoulder buttons.": "Deux tics discrets lorsque vous changez de page du menu radial vers la gauche ou la droite avec les boutons de tranche.",
    "UI focus moved": "Focus de l'IU déplacé",
    "UI navigation hit an edge": "Bord atteint lors de la navigation dans l'IU",
    "UI panel closed": "Panneau d'IU fermé",
    "UI panel opened": "Panneau d'IU ouvert",
    "Untested whether this also fires on every instant-cast press rather than only real cast-bar completions — if so, it'll feel far too frequent to read as \"that landed\" specifically. Check before relying on it.": "Non vérifié : reste à savoir si cela se déclenche aussi à chaque utilisation d'un sort instantané plutôt qu'uniquement à la fin d'une véritable barre d'incantation — si c'est le cas, la fréquence sera bien trop élevée pour être perçue spécifiquement comme « sort réussi ». Vérifiez avant de vous y fier.",
    "Untested.": "Non testé.",
    "Use the old estimator": "Utiliser l'ancien estimateur",
    "Using \"%s\" — set for %s.": "Utilisation de « %s » — défini pour %s.",
    "Vendor window opened": "Fenêtre de marchand ouverte",
    "Vibration Mode": "Mode de vibration",
    "Vibration Schema: |cffffd100%s|r": "Schéma de vibration : |cffffd100%s|r",
    "Vibration schema": "Schéma de vibration",
    "Voice-coil actuators (LRA), ultra-low 0.025 floor, instant response": "Actionneurs à bobine mobile (LRA), seuil ultra-bas de 0,025, réponse instantanée",
    "Walk cadence (steps/s)": "Cadence de marche (pas/s)",
    "Warlock": "Démoniste",
    "Warning lead time": "Délai d'avertissement anticipé",
    "Warrior": "Guerrier",
    "Watches UNIT_TARGET and target swaps for hostile units whose target is the player. Uses UnitIsUnit('targettarget', 'player') with defensive secrecy guards.": "Surveille UNIT_TARGET et les changements de cible pour les unités hostiles ciblant le joueur. Utilise UnitIsUnit('targettarget', 'player') avec des protections contre la divulgation.",
    "Wave cycle (seconds)": "Cycle de vague (secondes)",
    "Wave period (sec)": "Période des vagues (s)",
    "Wave steepness": "Cambrure de la vague",
    "Weapon or gear swapped": "Arme ou équipement changé",
    "What this does": "Description",
    "When mobs are pulled socially — aggroing because a neighbour was pulled — the game often reports status 0 even though you have aggro.": "Lorsque des monstres sont attirés par proximité sociale — prenant l'aggro parce qu'un voisin a été attaqué — le jeu signale souvent un statut 0 bien que vous ayez l'aggro.",
    "Which of the preset shapes this specific cue plays when it fires. \"": "Quelle forme prédéfinie ce signal joue lorsqu'il se déclenche. « ",
    "Which physical motors each cue drives. Start with Standard Rumble, then calibrate the motors below.": "Quels moteurs physiques chaque signal pilote. Commencez par Vibration standard, puis calibrez les moteurs ci-dessous.",
    "Which physical motors each trigger drives. Try one, test a mode below, keep the one you can feel.": "Quels moteurs physiques chaque déclencheur actionne. Essayez-en un, testez un mode ci-dessous, conservez celui que vous ressentez.",
    "Which profile to use right now. This writes to whichever rule is currently in force, so picking here always changes what you are actually using rather than editing a rule something more specific is overriding.": "Quel profil utiliser actuellement. Cela met à jour la règle active en vigueur ; choisir ici modifie donc toujours ce que vous utilisez réellement plutôt que de modifier une règle supplantée par une autre plus spécifique.",
    "Wind amplitude": "Amplitude du vent",
    "Wind resistance & thrust surge while flying. Scales dynamically with your flight speed.": "Résistance du vent et poussée d'accélération en vol. S'adapte dynamiquement à votre vitesse de vol.",
    "Windows": "Fenêtres",
    "World": "Monde",
    "World & Environment": "Monde et environnement",
    "World Immersion": "Immersion en extérieur",
    "You are alive again": "Vous êtes de nouveau en vie",
    "You died": "Vous êtes mort",
    "You have aggro": "Vous avez l'aggro",
    "Your cast ended": "Votre incantation est terminée",
    "Your cast failed": "Votre incantation a échoué",
    "Your cast started": "Votre incantation a commencé",
    "Your cast succeeded": "Votre incantation a réussi",
    "Zone changed": "Changement de zone",
    "an impact": "un impact",

    # 300..330
    "could not apply that preset": "impossible d'appliquer ce préréglage",
    "could not run that": "impossible d'exécuter cela",
    "could not set that rule": "impossible de définir cette règle",
    "detection unavailable": "détection indisponible",
    "in force": "en vigueur",
    "no role chosen": "aucun rôle sélectionné",
    "once a minute": "une fois par minute",
    "once every ": "une fois toutes les ",
    "once every %.1f seconds": "une fois toutes les %.1f secondes",
    "|cff00ff00Left-Click:|r Open Settings": "|cff00ff00Clic gauche :|r Ouvrir les réglages",
    "|cff00ff00Right-Click:|r Toggle Master On/Off": "|cff00ff00Clic droit :|r Activer/Désactiver l'interrupteur général",
    "|cff00ff00[Adjusting %d%%]|r Use |cffffffff[← / →]|r to Change, |cff38BDF8[A]|r Confirm & Feel": "|cff00ff00[Ajustement %d%%]|r Utilisez |cffffffff[← / →]|r pour changer, |cff38BDF8[A]|r Confirmer & Ressentir",
    "|cff38BDF8[L1 / LB]|r": "|cff38BDF8[L1 / LB]|r",
    "|cff38BDF8[L1/R1]|r Tabs  •  |cff38BDF8[A]|r Toggle Slider / Select": "|cff38BDF8[L1/R1]|r Onglets  •  |cff38BDF8[A]|r Activer curseur / Sélectionner",
    "|cff38BDF8[R1 / RB]|r": "|cff38BDF8[R1 / RB]|r",
    "|cff444444[L1 / LB]|r": "|cff444444[L1 / LB]|r",
    "|cff444444[R1 / RB]|r": "|cff444444[R1 / RB]|r",
    "|cff4cb8ffPulse:|r Quick setup complete! Type |cffffffff/pulse|r anytime to fine-tune settings.": "|cff4cb8ffPulse :|r Configuration rapide terminée ! Tapez |cffffffff/pulse|r à tout moment pour affiner vos réglages.",
    "|cff4db8ff✔ |r": "|cff4db8ff✔ |r",
    "|cff888888Drag:|r Move Icon": "|cff888888Glisser :|r Déplacer l'icône",
    "|cff888888Loss of control cues are governed by the master switch on the main Pulse page.|r": "|cff888888Les signaux de perte de contrôle sont régis par l'interrupteur général sur la page principale de Pulse.|r",
    "|cff888888Recommended intensity:|r %d%%": "|cff888888Intensité recommandée :|r %d%%",
    "|cffffcc00◀/▶ Adjust Intensity|r   •   %s/%s Lock Value   •   %s Try Texture": "|cffffcc00◀/▶ Ajuster l'intensité|r   •   %s/%s Verrouiller   •   %s Tester la texture",
    "|cffffd100%s|r  |cff00ff00[ACTIVE]|r": "|cffffd100%s|r  |cff00ff00[ACTIF]|r",
    "|cffffd100/pulseui|r opens it too. |cffffd100/pulse setup|r re-opens Quick Setup, |cffffd100/pulse test <mode>|r plays a shape.": "|cffffd100/pulseui|r l'ouvre aussi. |cffffd100/pulse setup|r rouvre la configuration rapide, |cffffd100/pulse test <mode>|r joue une vibration.",
    "|r, |cffffd100": "|r, |cffffd100",
    "• |r": "• |r",
    "⚔️ Melee DPS": "⚔️ DPS mêlée",
    "🏹 Ranged DPS": "🏹 DPS distance",
    "💚 Healer": "💚 Soigneur",
    "🛡️ Tank": "🛡️ Tank",
}

def main():
    with open(BATCH1B_JSON, "r", encoding="utf-8") as f:
        batch_data = json.load(f)

    batch_items = batch_data["items"]
    print(f"Loaded {len(batch_items)} items from {BATCH1B_JSON}")

    missing = []
    errors = 0
    output_items = []

    for it in batch_items:
        src = it["source"]
        if src not in TRANSLATIONS_FR:
            missing.append(src)
            continue

        tgt = TRANSLATIONS_FR[src]

        # 1. Signature validation
        sig_src = extract_signature(src)
        sig_tgt = extract_signature(tgt)
        if sig_src != sig_tgt:
            print(f"ERROR: Signature mismatch for {repr(src)}: expected {repr(sig_src)}, got {repr(sig_tgt)}")
            errors += 1

        # 2. Color code balance validation
        if not check_color_balance(src, tgt):
            print(f"ERROR: Color code mismatch for {repr(src)} -> {repr(tgt)}")
            errors += 1

        output_items.append({
            "source": src,
            "target": tgt
        })

    if missing:
        print(f"ERROR: {len(missing)} items missing from TRANSLATIONS_FR:")
        for m in missing:
            print(f"  - {repr(m)}")
        sys.exit(1)

    if errors > 0:
        print(f"ERROR: Encountered {errors} validation errors.")
        sys.exit(1)

    output_data = {
        "items": output_items
    }

    with open(OUTPUT_JSON, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print(f"Successfully generated {OUTPUT_JSON} with {len(output_items)} items.")

if __name__ == "__main__":
    main()
