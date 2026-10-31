#!/usr/bin/env python3
"""
Generates and validates translated_ptBR_batch1b.json for PulseHaptics Brazilian Portuguese localization.
"""

import json
import os
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "tools"))
from validate_catalog import extract_signature, check_color_balance

TRANSLATIONS_PTBR = {
    # 000..019
    "Low health": "Vida baixa",
    "Low health texture": "Textura de vida baixa",
    "Low motor": "Motor pesado/lento",
    "Low motor holds a steady presence, floored so it's never silent while gliding; high motor eases in from near-silent toward thrillPeak as speed climbs, shaped by thrillCurve.": "O motor pesado/lento mantém uma presença constante, com limiar mínimo para nunca ficar em silêncio ao planar; o motor leve/rápido surge quase do silêncio em direção a thrillPeak conforme a velocidade aumenta, moldado por thrillCurve.",
    "Mage": "Mago",
    "Manage": "Gerenciar",
    "Master Vibration Strength": "Força geral de vibração",
    "Master switch for every loss-of-control cue below. With this off, none of them fire and no loss-of-control events are registered at all.": "Interruptor principal para cada sinal de perda de controle abaixo. Com isso desativado, nenhum deles dispara e nenhum evento de perda de controle é registrado.",
    "Master switch. With this off, nothing registers and nothing costs anything.": "Interruptor principal. Com isso desativado, nada é registrado e não há custo de processamento.",
    "Melee auto-attack started": "Ataque automático corpo a corpo iniciado",
    "Melee auto-attack stopped": "Ataque automático corpo a corpo interrompido",
    "Menus & tabs": "Menus e abas",
    "Messages": "Mensagens",
    "Minimum severity": "Gravidade mínima",
    "Mode to test": "Modo a testar",
    "Most specific wins. A scope set to |cffffd100No rule|r has no opinion and lets the one below it decide; with none of them set, Pulse uses Default.": "A regra mais específica prevalece. Um escopo definido como |cffffd100Sem regra|r é neutro e deixa o nível abaixo decidir; sem nenhum definido, o Pulse usa o Padrão.",
    "Movement": "Movimento",
    "Movement & Travel": "Movimento e viagem",
    "Multiplies every trigger's intensity. Part of the current profile, not global.": "Multiplica a intensidade de cada gatilho. Faz parte do perfil atual, não é global.",
    "Name the new profile:": "Nomeie o novo perfil:",

    # 020..039
    "Navigation": "Navegação",
    "New profile": "Novo perfil",
    "Next >": "Avançar >",
    "No rule": "Sem regra",
    "None (full sensory richness)": "Nenhum (riqueza sensorial completa)",
    "None (stock defaults)": "Nenhum (padrões originais)",
    "ON — option changes and cue firings will print here.": "LIGADO — alterações de opções e disparos de sinais serão exibidos aqui.",
    "Ocean Waves & Swell": "Ondas oceânicas e ondulação",
    "Ocean waves & swell": "Ondas oceânicas e ondulação",
    "Ocean zones only (guessed from zone name)": "Apenas zonas oceânicas (deduzidas pelo nome da zona)",
    "Off by default and deliberately the faintest cue in the addon: this fires for EVERY NPC you talk to, which in a city is constantly. Try it before leaving it on. Untested.": "Desativado por padrão e deliberadamente o sinal mais sutil do addon: dispara para CADA PNJ com quem você conversa, o que em uma cidade ocorre constantemente. Experimente antes de manter ativado. Não testado.",
    "Offensive": "Ofensivo",
    "One cue for both directions, same reasoning as the navigation edge cue — a motor can't tell you which way you went.": "Um único sinal para ambas as direções, pelo mesmo motivo do sinal de borda de navegação — um motor não pode indicar para qual direção você foi.",
    "One full-bodied hit on both motors.": "Um impacto encorpado em ambos os motores.",
    "One long, sombre pulse when a spirit healer's window opens.": "Um pulso longo e sombrio quando a janela do anjo da cura se abre.",
    "One sharp, heavy impact — fast attack, fast decay.": "Um impacto seco e pesado — ataque rápido, decaimento rápido.",
    "One strong, sustained pulse.": "Um pulso forte e sustentado.",
    "One sustained pulse.": "Um pulso sustentado.",
    "Open Pulse settings": "Abrir configurações do Pulse",
    "Other": "Outro",

    # 040..059
    "Overall heave amplitude of the oceanic swell. Sets the physical displacement intensity of the slow motor.": "Amplitude geral de elevação da ondulação oceânica. Define a intensidade de deslocamento físico do motor lento.",
    "Overall intensity": "Intensidade geral",
    "Overall strength. Meant to sit at the edge of perception — if you notice it as a vibration rather than as being submerged, it is too high. Inherits the old idleFloatAmplitude, which was live-tuned to 0.04.": "Força geral. Projetada para ficar no limiar da percepção — se você notar isso como uma vibração em vez de sensação de submersão, está alta demais. Herda o antigo idleFloatAmplitude, ajustado em jogo para 0.04.",
    "Overdrive kick": "Impulso de sobrecarga",
    "Overdrive time (s)": "Tempo de sobrecarga (s)",
    "Own motor": "Motor próprio",
    "PLAYER_ALIVE also fires when you release to a graveyard, so this can fire while you are still a ghost.": "PLAYER_ALIVE também dispara quando você libera o espírito para o cemitério, então isso pode disparar enquanto você ainda é um fantasma.",
    "PLAYER_SOFT_FRIEND_CHANGED, occurrence-only, no payload. Worth pairing with the hostile cue above only if you can tell two TICKs apart — if not, give one of them a different shape with its own \"Feels like\" dropdown.": "PLAYER_SOFT_FRIEND_CHANGED, apenas ocorrência, sem payload. Vale a pena combinar com o sinal hostil acima apenas se você conseguir distinguir dois ESTALIDOS — caso contrário, atribua a um deles um formato diferente com seu menu suspenso \"Sensação tátil\".",
    "PULSE QUICK SETUP": "CONFIGURAÇÃO RÁPIDA DO PULSE",
    "Pacified or school-locked": "Pacificado ou escola bloqueada",
    "Page switches": "Trocas de página",
    "Paladin": "Paladino",
    "Passively polled by observing IsEnabled() on the currently focused element. Fires if the element becomes disabled while focused.": "Monitorado passivamente observando IsEnabled() no elemento atualmente focado. Dispara se o elemento for desativado enquanto focado.",
    "Passively polled via GetUIPanel every 0.05s to eliminate UIParentPanelManager execution taint on protected frames.": "Monitorado passivamente via GetUIPanel a cada 0.05s para eliminar contaminação de execução de UIParentPanelManager em quadros protegidos.",
    "Passively polled via GetUIPanel every 0.05s. Detects when major UI panels are dismissed without callback taint.": "Monitorado passivamente via GetUIPanel a cada 0.05s. Detecta quando painéis principais da interface são fechados sem contaminação por retorno.",
    "Passively polled via GroupTargeting.isTargetingActive. Fires when the group targeting modifier is released.": "Monitorado passivamente via GroupTargeting.isTargetingActive. Dispara quando o modificador de seleção de grupo é liberado.",
    "Physical tool strikes: anvil hammer strokes, mining pickaxe impacts, tailoring stitches.": "Golpes de ferramentas físicas: marteladas na bigorna, impactos da picareta de mineração, pontos de costura de alfaiataria.",
    "Pick a mode to test below.": "Escolha um modo para testar abaixo.",
    "Play": "Reproduzir",
    "Play ": "Reproduzir ",

    # 060..079
    "Play a few seconds of this texture at its current intensity. Module-driven preview reproducing authentic physical dynamics and configured intensity.": "Reproduz alguns segundos desta textura em sua intensidade atual. Pré-visualização orientada por módulo reproduzindo dinâmica física autêntica e intensidade configurada.",
    "Presence floor (low)": "Limiar mínimo de presença (lento)",
    "Priest": "Sacerdote",
    "Prints every option you change and every cue that actually fires to chat, in real time. Same as /pulse debug — off by default, and resets to off on /reload since it's a testing aid, not a saved preference.": "Exibe no bate-papo cada opção alterada e cada sinal disparado em tempo real. Igual a /pulse debug — desativado por padrão e redefinido para desativado ao recarregar a interface (/reload), pois é um auxílio de teste e não uma preferência salva.",
    "Profile": "Perfil",
    "Profiles": "Perfis",
    "Profiles and automatic rules": "Perfis e regras automáticas",
    "Progression": "Progressão",
    "Progressive low build leading to a sharp high break.": "Construção progressiva no motor lento culminando em uma quebra nítida no rápido.",
    "Pull / glide balance": "Equilíbrio de tração / planeio",
    "Pulse": "Pulse",
    "Pulse is using |cffffd100%s|r, because a rule is set for %s.": "O Pulse está usando |cffffd100%s|r, porque há uma regra definida para %s.",
    "Pulse tunes motor spin-up attack, coast-down release, and breakaway friction to match your physical hardware actuators.": "O Pulse ajusta o ataque de aceleração do motor, a desaceleração gradual e a inércia mecânica para corresponder aos atuadores físicos do seu hardware.",
    "Pulse: (Engine recorded %d errors. Last error: %s)": "Pulse: (O mecanismo registrou %d erros. Último erro: %s)",
    "Pulse: /pulse test <mode>|heartbeat|warningbeat — try one of: ": "Pulse: /pulse test <mode>|heartbeat|warningbeat — experimente um destes: ",
    "Pulse: activated profile \"%s\"": "Pulse: perfil \"%s\" ativado",
    "Pulse: active profile is \"%s\" (%s)": "Pulse: o perfil ativo é \"%s\" (%s)",
    "Pulse: bound profile \"%s\" to specialization %s": "Pulse: perfil \"%s\" vinculado à especialização %s",
    "Pulse: could not build settings row %q (%s)": "Pulse: não foi possível criar a linha de configurações %q (%s)",
    "Pulse: could not build the settings window (": "Pulse: não foi possível criar a janela de configurações (",

    # 080..099
    "Pulse: debug ": "Pulse: depuração ",
    "Pulse: disabled all %d cues in active profile.": "Pulse: todos os %d sinais desativados no perfil ativo.",
    "Pulse: disabled all %d cues in profile \"%s\".": "Pulse: todos os %d sinais desativados no perfil \"%s\".",
    "Pulse: disabled all %d cues in profile %s.": "Pulse: todos os %d sinais desativados no perfil %s.",
    "Pulse: enabled all %d cues in active profile.": "Pulse: todos os %d sinais ativados no perfil ativo.",
    "Pulse: enabled all %d cues in profile \"%s\".": "Pulse: todos os %d sinais ativados no perfil \"%s\".",
    "Pulse: enabled all %d cues in profile %s.": "Pulse: todos os %d sinais ativados no perfil %s.",
    "Pulse: live oscilloscope is provided by the companion addon PulseDebug (/pdebug scope).": "Pulse: o osciloscópio em tempo real é fornecido pelo addon complementar PulseDebug (/pdebug scope).",
    "Pulse: minimap icon %s": "Pulse: ícone do minimapa %s",
    "Pulse: no profile matching \"%s\". Available: %s": "Pulse: nenhum perfil corresponde a \"%s\". Disponíveis: %s",
    "Pulse: switched to profile \"%s\"": "Pulse: alternado para o perfil \"%s\"",
    "Pulse: that preview is unavailable.": "Pulse: essa pré-visualização não está disponível.",
    "Pulse: this looks like a %s%s. Pick it above, then press Apply.": "Pulse: este dispositivo parece ser um %s%s. Selecione-o acima e pressione Aplicar.",
    "Pure flavour — nothing depends on it. Untested.": "Puramente imersivo — nada depende disso. Não testado.",
    "Pure novelty. Off by default forever, basically — nobody asked for this one.": "Pura novidade. Basicamente desativado por padrão para sempre — ninguém pediu por isso.",
    "Put every motor's strength, floor, timing and curve back to the engine defaults. Doesn't touch cues, per-cue intensity, mode tuning or your schema.": "Restaura a força, o limiar mínimo, a temporização e a curva de cada motor para os padrões do mecanismo. Não altera sinais, intensidade por sinal, ajustes de modo ou seu esquema.",
    "Put the profile in use back to its stock defaults — works on built-ins too, restoring their curated content rather than blank Registry.lua defaults.": "Restaura o perfil em uso para seus padrões de fábrica — também funciona nos perfis integrados, restaurando seu conteúdo selecionado em vez dos padrões vazios de Registry.lua.",
    "PvP (Tactical Radar)": "JxJ (Radar tático)",
    "Quest accepted": "Missão aceita",
    "Quest offered": "Missão oferecida",

    # 100..119
    "Quest ready to hand in": "Missão pronta para entrega",
    "Quest turned in": "Missão entregue",
    "Questing": "Missões",
    "Questing & Exploration": "Missões e exploração",
    "Quests": "Missões",
    "Quick Setup": "Configuração rápida",
    "Quick Setup Wizard": "Assistente de configuração rápida",
    "Radial menu": "Menu radial",
    "Radial menu closed": "Menu radial fechado",
    "Radial menu opened": "Menu radial aberto",
    "Radial page changed": "Página radial alterada",
    "Radial segment changed": "Segmento radial alterado",
    "Radial segment chosen": "Segmento radial escolhido",
    "Radial segment unavailable": "Segmento radial indisponível",
    "Radial selection cancelled": "Seleção radial cancelada",
    "Ranged auto-repeat started": "Disparo automático de longo alcance iniciado",
    "Ranged auto-repeat stopped": "Disparo automático de longo alcance interrompido",
    "Rapid staccato triple-click on the high motor.": "Clique triplo em staccato rápido no motor leve/rápido.",
    "Reading something": "Lendo algo",
    "Reads the segment's own IsEnabled() — the same value Blizzard reads to grey the highlight out, so this matches what you see on screen. Fires in place of \"Radial segment changed\", not alongside it.": "Lê o IsEnabled() do próprio segmento — o mesmo valor que a Blizzard lê para esmaecer o destaque, correspondendo exatamente ao que você vê na tela. Dispara no lugar de \"Segmento radial alterado\", e não simultaneamente.",

    # 120..139
    "Ready check": "Confirmação de prontidão",
    "Ready check finished": "Confirmação de prontidão concluída",
    "Release time (s)": "Tempo de liberação (s)",
    "Reload UI": "Recarregar interface",
    "Reload UI to apply the language change.": "Recarregue a interface para aplicar a alteração de idioma.",
    "Reload the interface to apply your selected addon language.": "Recarregue a interface para aplicar o idioma selecionado do addon.",
    "Rename": "Renomear",
    "Rename \"%s\" to:": "Renomear \"%s\" para:",
    "Rename the profile in use. Every rule pointing at it follows the rename. Built-in profiles can't be renamed.": "Renomeia o perfil em uso. Todas as regras vinculadas a ele seguirão a alteração. Perfis integrados não podem ser renomeados.",
    "Rename this profile": "Renomear este perfil",
    "Rename...": "Renomear...",
    "Repaired equipment": "Equipamento reparado",
    "Reset": "Redefinir",
    "Reset every motor's strength, floor, timing and curve back to the engine defaults? This can't be undone.": "Redefinir a força, o limiar mínimo, a temporização e a curva de cada motor para os padrões do mecanismo? Esta ação não pode ser desfeita.",
    "Reset profile \"%s\" to defaults? Every cue, intensity and mode override in it goes back to stock values. This can't be undone.": "Redefinir o perfil \"%s\" para os padrões? Cada sinal, intensidade e substituição de modo nele retornará aos valores originais. Esta ação não pode ser desfeita.",
    "Reset this profile": "Redefinir este perfil",
    "Reset...": "Redefinir...",
    "Resources": "Recursos",
    "Response curve": "Curva de resposta",
    "Resting": "Descansando",

    # 140..159
    "Resurrection offered": "Ressurreição oferecida",
    "Rewards": "Recompensas",
    "Rogue": "Ladino",
    "Role poll": "Votação de função",
    "Rooted": "Enraizado",
    "Routing & Schema": "Roteamento e esquema",
    "Rules": "Regras",
    "Run Wizard": "Executar assistente",
    "Run cadence (steps/s)": "Cadência de corrida (passos/s)",
    "Same polled mechanism as \"Confirmation popup appeared\". Untested.": "Mesmo mecanismo monitorado de \"Janela pop-up de confirmação exibida\". Não testado.",
    "Save & Start Playing": "Salvar e começar a jogar",
    "Scales both the bed and the strikes for %s, before the two shared strengths above.": "Escala tanto a base contínua quanto os golpes para %s, antes das duas forças compartilhadas acima.",
    "Scales this cue on top of the overall intensity on the Pulse page.": "Escala este sinal sobreposto à intensidade geral na página do Pulse.",
    "School lockouts are frequent in melee-heavy content. Off by default because a cue every kick you eat can crowd out the ones that mean you cannot act at all.": "Bloqueios de escola de magia são frequentes em conteúdos com muitos ataques corpo a corpo. Desativado por padrão porque um sinal a cada chute recebido pode ofuscar aqueles que indicam incapacidade total de agir.",
    "Search %d cues...": "Pesquisar %d sinais...",
    "Secondary resource full": "Recurso secundário cheio",
    "Set Floor": "Definir limiar mínimo",
    "Set but not in force: |cffffd100%s|r. A more specific rule above is winning — clear it to let these take over.": "Definido, mas inativo: |cffffd100%s|r. Uma regra mais específica acima está prevalecendo — remova-a para permitir que estas assumam o controle.",
    "Set for Spec": "Definir para especialização",
    "Setup Summary": "Resumo da configuração",

    # 160..179
    "Shaman": "Xamã",
    "Shares its pulse pattern with the target cue. If your focus is also your target, you get one cue rather than two.": "Compartilha seu padrão de pulso com o sinal de alvo. Se o seu foco também for o seu alvo, você receberá apenas um sinal em vez de dois.",
    "Sharp high kick layered with heavy low kick and rumble decay.": "Golpe seco no motor leve/rápido sobreposto a um golpe pesado no motor lento com decaimento de vibração.",
    "Show a Play button on every cue": "Mostrar botão Reproduzir em cada sinal",
    "Show minimap icon": "Mostrar ícone do minimapa",
    "Show per-cue detail controls": "Mostrar controles detalhados por sinal",
    "Shows only the page switches and this page. Every cue keeps its own settings; turn this off to get every page back exactly as it was.": "Mostra apenas as opções de troca de página e esta página. Cada sinal mantém suas próprias configurações; desative para restaurar todas as páginas exatamente como estavam.",
    "Silenced": "Silenciado",
    "Simple view": "Visualização simples",
    "Slow, harmonic oceanic gravity swells and coastal tides while submerged in deep oceans.": "Ondulações gravitacionais oceânicas lentas e harmônicas e marés costeiras enquanto submerso em oceanos profundos.",
    "Snappy & Taps": "Toques secos e rápidos",
    "Social & Group": "Social e grupo",
    "Social & Group Communication": "Comunicação social e de grupo",
    "Soft target interact": "Interação com alvo suave",
    "Special casting": "Lançamento especial",
    "Speeds up or slows down ": "Acelera ou desacelera ",
    "Spirit healer": "Anjo da cura",
    "Split left and right": "Dividir esquerda e direita",
    "Square / X: open settings": "Quadrado / X: abrir configurações",
    "Stable opened": "Estábulo aberto",

    # 180..199
    "Stack split ratchet": "Catraca de divisão de pilha",
    "Standard Rumble": "Vibração padrão",
    "Standard balance across all categories": "Equilíbrio padrão em todas as categorias",
    "Status: %s": "Status: %s",
    "Step 4: Interface & Social Alerts": "Etapa 4: Alertas de interface e sociais",
    "Step 6: Master Strength & Completion": "Etapa 6: Força geral e conclusão",
    "Steps per second at full running speed. Scaled by how fast you are actually moving.": "Passos por segundo na velocidade máxima de corrida. Dimensionado de acordo com a velocidade real de movimento.",
    "Steps per second at normal walking speed.": "Passos por segundo na velocidade normal de caminhada.",
    "Strength": "Força",
    "Strike strength": "Força do golpe",
    "Stroke depth": "Profundidade da braçada",
    "Stroke rate, fast (Hz)": "Frequência de braçada, rápida (Hz)",
    "Stroke rate, slow (Hz)": "Frequência de braçada, lenta (Hz)",
    "Strokes per second at barely-moving speed.": "Braçadas por segundo em velocidade mínima de movimento.",
    "Stunned": "Atordoado",
    "Summon offered": "Evocação oferecida",
    "Swapped / Inverted Rumble": "Vibração invertida / trocada",
    "Swell depth": "Profundidade da ondulação",
    "Swell rate (Hz)": "Frequência de ondulação (Hz)",
    "Swell strength": "Força da ondulação",

    # 200..219
    "Switch to this profile": "Alternar para este perfil",
    "Switches every cue on the Casting page on or off at once. Each cue keeps its own setting underneath.": "Ativa ou desativa todos os sinais da página Lançamento de uma só vez. Cada sinal mantém sua configuração individual subjacente.",
    "Switches every cue on the Character & Status page on or off at once. Each cue keeps its own setting underneath.": "Ativa ou desativa todos os sinais da página Personagem e status de uma só vez. Cada sinal mantém sua configuração individual subjacente.",
    "Switches every cue on the Interface & Accessibility page on or off at once. Each cue keeps its own setting underneath.": "Ativa ou desativa todos os sinais da página Interface e acessibilidade de uma só vez. Cada sinal mantém sua configuração individual subjacente.",
    "Switches every cue on the Movement & Travel page on or off at once. Each cue keeps its own setting underneath.": "Ativa ou desativa todos os sinais da página Movimento e viagem de uma só vez. Cada sinal mantém sua configuração individual subjacente.",
    "Switches every cue on the Social & Group page on or off at once. Each cue keeps its own setting underneath.": "Ativa ou desativa todos os sinais da página Social e grupo de uma só vez. Cada sinal mantém sua configuração individual subjacente.",
    "Switches every cue on the Target & Focus page on or off at once. Each cue keeps its own setting underneath.": "Ativa ou desativa todos os sinais da página Alvo e foco de uma só vez. Cada sinal mantém sua configuração individual subjacente.",
    "Switches every cue on the World & Environment page on or off at once. Each cue keeps its own setting underneath.": "Ativa ou desativa todos os sinais da página Mundo e ambiente de uma só vez. Cada sinal mantém sua configuração individual subjacente.",
    "Talking to someone": "Conversando com alguém",
    "Target": "Alvo",
    "Target & Crosshair Feedback": "Retorno de alvo e retículo",
    "Target & Focus": "Alvo e foco",
    "Target changed": "Alvo alterado",
    "Target died": "Alvo morreu",
    "Target started casting": "Alvo começou a lançar feitiço",
    "Target used major defensive": "Alvo usou habilidade defensiva importante",
    "Target's cast stopped": "Lançamento do alvo interrompido",
    "Targeted by enemy": "Alvo de inimigo",
    "Targeting": "Seleção de alvos",
    "Test Alert": "Testar alerta",

    # 220..239
    "Test Impact": "Testar impacto",
    "Test Lock": "Testar bloqueio",
    "Test Reward": "Testar recompensa",
    "Test Rumble": "Testar vibração",
    "Test Strike": "Testar golpe",
    "Test UI": "Testar interface",
    "Test the selected mode": "Testar o modo selecionado",
    "Textures & Patterns": "Texturas e padrões",
    "The Accessibility section": "A seção de Acessibilidade",
    "The Cue Index directory": "O diretório do Índice de sinais",
    "The _QUIET variant covers failures the game prints no error for, so this can fire with nothing visible on screen.": "A variante _QUIET cobre falhas para as quais o jogo não exibe nenhum erro, portanto pode disparar sem nada visível na tela.",
    "The experimental section": "A seção experimental",
    "The lightest possible tick when a conversation window opens with any NPC.": "O estalido mais sutil possível quando uma janela de conversa se abre com qualquer PNJ.",
    "The master switch for this page. Also on the Casting page, where the cue lives alongside the other casting cues.": "O interruptor principal para esta página. Também presente na página Lançamento, onde o sinal reside junto com os outros sinais de lançamento.",
    "This character": "Este personagem",
    "This character reports no specialization, so there is no per-specialization rule to set. The row appears by itself on a character that has one.": "Este personagem não informa especialização, portanto não há regra por especialização para definir. A linha aparecerá automaticamente em um personagem que possua uma.",
    "This specialization": "Esta especialização",
    "This specialization (": "Esta especialização (",
    "Three rhythmic thuds.": "Três impactos rítmicos.",
    "Three-stage rising tension building on the low motor.": "Tensão crescente em três etapas aumentando no motor pesado/lento.",

    # 240..259
    "Thrill curve (high)": "Curva de adrenalina (rápido)",
    "Thrill peak (high)": "Pico de adrenalina (rápido)",
    "Time in seconds for a complete wave cycle. Real oceanic swells roll every 8 to 12 seconds (~0.10 Hz). Shorter periods feel like choppy coastal chop; longer periods feel like open-ocean rollers.": "Tempo em segundos para um ciclo completo de onda. Ondulações oceânicas reais ocorrem a cada 8 a 12 segundos (~0.10 Hz). Períodos mais curtos parecem águas costeiras agitadas; períodos mais longos parecem vagas de mar aberto.",
    "Tracked cooldown ready": "Tempo de recarga monitorado pronto",
    "Trade opened": "Negociação aberta",
    "Triggers, modes, and motor tuning": "Gatilhos, modos e ajustes de motores",
    "Try Texture": "Testar textura",
    "Tuned for HD Rumble voice-coil actuators": "Ajustado para atuadores de bobina de voz HD Rumble",
    "Turn off every cue in the active profile in one sweep (useful for quiet debugging).": "Desativa todos os sinais no perfil ativo de uma só vez (útil para depuração silenciosa).",
    "Turn on every cue in the active profile in one sweep (useful for testing/debugging).": "Ativa todos os sinais no perfil ativo de uma só vez (útil para testes/depuração).",
    "Turn whole pages of cues on or off. Each cue keeps its own setting underneath: switching a page back on restores exactly what was there.": "Ativa ou desativa páginas inteiras de sinais. Cada sinal mantém sua configuração individual subjacente: reativar uma página restaura exatamente o que estava lá.",
    "Two crisp ticks when a cooldown the built-in Cooldown Manager is tracking comes off cooldown.": "Dois estalidos nítidos quando uma recarga monitorada pelo Gerenciador de recargas integrado fica disponível.",
    "Two heavier hits with a gap between them.": "Dois impactos mais pesados com um intervalo entre eles.",
    "Two kinds of trigger: pulses and textures": "Dois tipos de gatilho: pulsos e texturas",
    "Two rhythmic thuds.": "Dois impactos rítmicos.",
    "Two soft ticks when the action bar pages to a different set of abilities.": "Dois estalidos suaves quando a barra de ações muda para outro conjunto de habilidades.",
    "Two soft ticks when you page the radial left or right with the shoulder buttons.": "Dois estalidos suaves ao alternar o menu radial para a esquerda ou direita com os botões superiores.",
    "UI focus moved": "Foco da interface movido",
    "UI navigation hit an edge": "Navegação da interface atingiu uma borda",
    "UI panel closed": "Painel da interface fechado",

    # 260..279
    "UI panel opened": "Painel da interface aberto",
    "Untested whether this also fires on every instant-cast press rather than only real cast-bar completions — if so, it'll feel far too frequent to read as \"that landed\" specifically. Check before relying on it.": "Não foi testado se isso também dispara a cada toque de lançamento instantâneo em vez de apenas nas conclusões reais da barra de lançamento — se for o caso, parecerá frequente demais para ser interpretado como \"atingiu o alvo\" especificamente. Verifique antes de confiar nisso.",
    "Untested.": "Não testado.",
    "Use the old estimator": "Usar o estimador antigo",
    "Using \"%s\" — set for %s.": "Usando \"%s\" — definido para %s.",
    "Vendor window opened": "Janela do comerciante aberta",
    "Vibration Mode": "Modo de vibração",
    "Vibration Schema: |cffffd100%s|r": "Esquema de vibração: |cffffd100%s|r",
    "Vibration schema": "Esquema de vibração",
    "Voice-coil actuators (LRA), ultra-low 0.025 floor, instant response": "Atuadores de bobina de voz (LRA), limiar mínimo ultrabaixo de 0.025, resposta instantânea",
    "Walk cadence (steps/s)": "Cadência de caminhada (passos/s)",
    "Warlock": "Bruxo",
    "Warning lead time": "Tempo de antecedência do aviso",
    "Warrior": "Guerreiro",
    "Watches UNIT_TARGET and target swaps for hostile units whose target is the player. Uses UnitIsUnit('targettarget', 'player') with defensive secrecy guards.": "Monitora UNIT_TARGET e trocas de alvo em busca de unidades hostis cujo alvo seja o jogador. Usa UnitIsUnit('targettarget', 'player') com proteção defensiva contra falhas.",
    "Wave cycle (seconds)": "Ciclo de onda (segundos)",
    "Wave period (sec)": "Período da onda (s)",
    "Wave steepness": "Declividade da onda",
    "Weapon or gear swapped": "Arma ou equipamento trocado",
    "What this does": "O que isto faz",

    # 280..299
    "When mobs are pulled socially — aggroing because a neighbour was pulled — the game often reports status 0 even though you have aggro.": "Quando criaturas entram em combate socialmente — gerando agressividade porque uma criatura vizinha foi atraída — o jogo geralmente relata status 0, mesmo que você esteja com a ameaça.",
    "Which of the preset shapes this specific cue plays when it fires. \"": "Qual dos formatos predefinidos este sinal específico reproduz quando dispara. \"",
    "Which physical motors each cue drives. Start with Standard Rumble, then calibrate the motors below.": "Quais motores físicos cada sinal aciona. Comece com Vibração padrão e calibre os motores abaixo.",
    "Which physical motors each trigger drives. Try one, test a mode below, keep the one you can feel.": "Quais motores físicos cada gatilho aciona. Experimente um, teste um modo abaixo e mantenha aquele que conseguir sentir.",
    "Which profile to use right now. This writes to whichever rule is currently in force, so picking here always changes what you are actually using rather than editing a rule something more specific is overriding.": "Qual perfil usar no momento. Isso altera a regra que está em vigor no momento, de modo que selecionar aqui sempre altera o que você está usando de fato, em vez de editar uma regra que algo mais específico está substituindo.",
    "Wind amplitude": "Amplitude do vento",
    "Wind resistance & thrust surge while flying. Scales dynamically with your flight speed.": "Resistência do vento e impulso de propulsão ao voar. Dimensiona-se dinamicamente com sua velocidade de voo.",
    "Windows": "Janelas",
    "World": "Mundo",
    "World & Environment": "Mundo e ambiente",
    "World Immersion": "Imersão no mundo",
    "You are alive again": "Você está vivo novamente",
    "You died": "Você morreu",
    "You have aggro": "Você está com a ameaça",
    "Your cast ended": "Seu lançamento terminou",
    "Your cast failed": "Seu lançamento falhou",
    "Your cast started": "Seu lançamento começou",
    "Your cast succeeded": "Seu lançamento foi bem-sucedido",
    "Zone changed": "Zona alterada",
    "an impact": "um impacto",

    # 300..319
    "could not apply that preset": "não foi possível aplicar essa predefinição",
    "could not run that": "não foi possível executar isso",
    "could not set that rule": "não foi possível definir essa regra",
    "detection unavailable": "detecção indisponível",
    "in force": "em vigor",
    "no role chosen": "nenhuma função escolhida",
    "once a minute": "uma vez por minuto",
    "once every ": "uma vez a cada ",
    "once every %.1f seconds": "uma vez a cada %.1f segundos",
    "|cff00ff00Left-Click:|r Open Settings": "|cff00ff00Clique com o botão esquerdo:|r Abrir configurações",
    "|cff00ff00Right-Click:|r Toggle Master On/Off": "|cff00ff00Clique com o botão direito:|r Alternar geral ligado/desligado",
    "|cff00ff00[Adjusting %d%%]|r Use |cffffffff[← / →]|r to Change, |cff38BDF8[A]|r Confirm & Feel": "|cff00ff00[Ajustando %d%%]|r Use |cffffffff[← / →]|r para alterar, |cff38BDF8[A]|r Confirmar e sentir",
    "|cff38BDF8[L1 / LB]|r": "|cff38BDF8[L1 / LB]|r",
    "|cff38BDF8[L1/R1]|r Tabs  •  |cff38BDF8[A]|r Toggle Slider / Select": "|cff38BDF8[L1/R1]|r Abas  •  |cff38BDF8[A]|r Alternar controle deslizante / Selecionar",
    "|cff38BDF8[R1 / RB]|r": "|cff38BDF8[R1 / RB]|r",
    "|cff444444[L1 / LB]|r": "|cff444444[L1 / LB]|r",
    "|cff444444[R1 / RB]|r": "|cff444444[R1 / RB]|r",
    "|cff4cb8ffPulse:|r Quick setup complete! Type |cffffffff/pulse|r anytime to fine-tune settings.": "|cff4cb8ffPulse:|r Configuração rápida concluída! Digite |cffffffff/pulse|r a qualquer momento para ajustar as configurações.",
    "|cff4db8ff✔ |r": "|cff4db8ff✔ |r",
    "|cff888888Drag:|r Move Icon": "|cff888888Arrastar:|r Mover ícone",

    # 320..330
    "|cff888888Loss of control cues are governed by the master switch on the main Pulse page.|r": "|cff888888Os sinais de perda de controle são gerenciados pelo interruptor principal na página inicial do Pulse.|r",
    "|cff888888Recommended intensity:|r %d%%": "|cff888888Intensidade recomendada:|r %d%%",
    "|cffffcc00◀/▶ Adjust Intensity|r   •   %s/%s Lock Value   •   %s Try Texture": "|cffffcc00◀/▶ Ajustar intensidade|r   •   %s/%s Bloquear valor   •   %s Testar textura",
    "|cffffd100%s|r  |cff00ff00[ACTIVE]|r": "|cffffd100%s|r  |cff00ff00[ATIVO]|r",
    "|cffffd100/pulseui|r opens it too. |cffffd100/pulse setup|r re-opens Quick Setup, |cffffd100/pulse test <mode>|r plays a shape.": "|cffffd100/pulseui|r também abre a janela. |cffffd100/pulse setup|r reabre a Configuração rápida, |cffffd100/pulse test <modo>|r reproduz um formato.",
    "|r, |cffffd100": "|r, |cffffd100",
    "• |r": "• |r",
    "⚔️ Melee DPS": "⚔️ DPS Corpo a Corpo",
    "🏹 Ranged DPS": "🏹 DPS de Longo Alcance",
    "💚 Healer": "💚 Curador",
    "🛡️ Tank": "🛡️ Tanque",
}

def main():
    batch_path = "/home/deck/developer/wow/PulseSensation/localization/batches/batch1b_ui_navigation.json"
    with open(batch_path, "r", encoding="utf-8") as f:
        batch_data = json.load(f)

    items = batch_data["items"]
    print(f"Total items in batch1b: {len(items)}")

    errors = 0
    missing = 0
    translated_items = []

    for idx, item in enumerate(items):
        src = item["source"]
        if src not in TRANSLATIONS_PTBR:
            print(f"MISSING: [{idx}] (id={item.get('id')}): {repr(src)}")
            missing += 1
            errors += 1
            continue

        tgt = TRANSLATIONS_PTBR[src]

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
        print(f"\nFAILED with {errors} errors ({missing} missing keys). Aborting.")
        sys.exit(1)

    out_path = "/home/deck/developer/wow/PulseSensation/localization/batches/translated_ptBR_batch1b.json"
    out_data = {
        "items": translated_items
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out_data, f, indent=2, ensure_ascii=False)

    print(f"SUCCESS: Wrote {len(translated_items)} validated translations to {out_path}")

if __name__ == "__main__":
    main()
