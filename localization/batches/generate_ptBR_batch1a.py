#!/usr/bin/env python3
"""
Generates and validates translated_ptBR_batch1a.json for PulseHaptics Brazilian Portuguese localization.
"""

import json
import os
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "tools"))
from validate_catalog import extract_signature, check_color_balance

TRANSLATIONS_PT = {
    # 0..17
    " (page off)|r": " (página desativada)|r",
    " (reported as \"": " (identificado como \"",
    " Rules and management are on the Profiles page.": " As regras e o gerenciamento estão na página Perfis.",
    " as a whole — both its pulses and the gaps between them, so a multi-hit mode keeps its rhythm instead of the hits stretching into their own gaps. 1.0 is the authored default.": " como um todo — tanto seus pulsos quanto os intervalos entre eles, para que um modo de múltiplos golpes mantenha seu ritmo em vez de os golpes se estenderem pelos próprios intervalos. 1,0 é o padrão original.",
    " right now with whatever's currently set on its sliders above.": " agora com as configurações atuais dos controles deslizantes acima.",
    "\" is recommended — pick a different one to change how just this cue feels, without affecting anything else that also uses \"": "\" é recomendado — escolha outro para mudar a sensação apenas deste sinal, sem afetar nada mais que também use \"",
    "\" — try one of: ": "\" — tente um destes: ",
    "%d of %d cues on": "%d de %d sinais ativados",
    "%d of %d on": "%d de %d ativados",
    "%s (%d)": "%s (%d)",
    "%s Activate   •   %s Try Texture   •   %s Categories": "%s Ativar   •   %s Testar textura   •   %s Categorias",
    "%s Adjust Intensity   •   %s Quick Step   •   |cff38BDF8◀/▶|r Controls   •   %s Try Texture   •   %s Categories": "%s Ajustar intensidade   •   %s Passo rápido   •   |cff38BDF8◀/▶|r Controles   •   %s Testar textura   •   %s Categorias",
    "%s Browse Modes   •   %s Select   •   %s Cancel": "%s Explorar modos   •   %s Selecionar   •   %s Cancelar",
    "%s Select Mode   •   |cff38BDF8◀/▶|r Controls   •   %s Try Texture   •   %s Categories": "%s Selecionar modo   •   |cff38BDF8◀/▶|r Controles   •   %s Testar textura   •   %s Categorias",
    "%s Switch Category   •   %s Navigate   •   %s Select   •   %s Close": "%s Mudar categoria   •   %s Navegar   •   %s Selecionar   •   %s Fechar",
    "%s Toggle   •   |cff38BDF8▶|r Next Control   •   %s Try Texture   •   %s Categories": "%s Alternar   •   |cff38BDF8▶|r Próximo controle   •   %s Testar textura   •   %s Categorias",
    "%s is felt as %s struck about %.1f times a second, over the bed.": "%s é sentido como %s aplicado cerca de %.1f vezes por segundo, sobre a base contínua.",
    "%s/%s Try Texture   •   |cff38BDF8◀|r Controls   •   %s Categories": "%s/%s Testar textura   •   |cff38BDF8◀|r Controles   •   %s Categorias",

    # 18..39
    "(Toggles all continuous sensations)": "(Alterna todas as sensações contínuas)",
    ", heartbeat, warningbeat": ", heartbeat, warningbeat",
    ", not ": ", não ",
    ", so there is nothing to test.": ", portanto não há nada para testar.",
    "0 = one soft pulse. 1 = a sharp lub, then a clearly separate softer dub. Derives the knock timing and intensity split automatically — see lowHealthTexture if you want those set by hand instead.": "0 = um pulso suave. 1 = um \"lub\" nítido, seguido por um \"dub\" mais suave e claramente separado. Deriva a temporização da batida e a divisão de intensidade automaticamente — consulte lowHealthTexture se preferir defini-los manualmente.",
    "1 = every scripted event, 3 = only the most severe. Higher means rarer, more significant warnings.": "1 = todo evento programado, 3 = apenas os mais graves. Valores mais altos significam avisos mais raros e significativos.",
    "3. World": "3. Mundo",
    "4. Interface": "4. Interface",
    "5. Immersion": "5. Imersão",
    "6. Finish": "6. Concluir",
    "< Back": "< Voltar",
    "A bright tick when you learn a new ability.": "Um estalido nítido ao aprender uma nova habilidade.",
    "A crisp mechanical snap on the high motor.": "Um estalo mecânico nítido no motor leve/rápido.",
    "A dense 3-pulse tactical flurry.": "Uma rajada tática densa de 3 pulsos.",
    "A dry click when you use an ability that has no cast time.": "Um clique seco ao usar uma habilidade sem tempo de lançamento.",
    "A heavy, decisive impact when your current target dies.": "Um impacto pesado e decisivo quando seu alvo atual morre.",
    "A light click when a major UI panel is dismissed.": "Um clique suave ao fechar um painel principal da interface.",
    "A light click when the last confirmation dialog closes.": "Um clique suave quando a última janela de confirmação se fecha.",
    "A light tick when you step away from an NPC or close its window.": "Um estalido suave ao se afastar de um PNJ ou fechar sua janela.",
    "A ringing anvil strike when repairing armor and weapons at a vendor.": "Um golpe sonoro de bigorna ao reparar armaduras e armas em um comerciante.",
    "A rising celebratory surge when you gain a level.": "Uma onda festiva ascendente ao subir de nível.",
    "A sharp alert pulse when your hostile target or focus turns to target you.": "Um pulso nítido de alerta quando seu alvo hostil ou foco muda o alvo para você.",

    # 40..69
    "A sharp deflection tick when a cast of yours is rejected outright — out of range, not facing the target, still on cooldown.": "Um estalido nítido de deflexão quando um lançamento seu é recusado de imediato — fora de alcance, sem estar de frente para o alvo, ainda em recarga.",
    "A sharp deflection tick when the game refuses an action — out of range, facing the wrong way, not enough resource, still on cooldown.": "Um estalido nítido de deflexão quando o jogo recusa uma ação — fora de alcance, virado para a direção errada, recurso insuficiente, ainda em recarga.",
    "A sharp snap when a harmful effect lands on you.": "Um estalo nítido quando um efeito nocivo atinge você.",
    "A sharp snap with a short tail.": "Um estalo nítido com uma cauda curta.",
    "A short warning before a significant scripted boss ability, using Blizzard's own built-in Boss Warnings timeline.": "Um aviso breve antes de uma habilidade programada importante de chefe, usando a linha do tempo de Avisos de Chefe integrada da Blizzard.",
    "A short, sharp tick instead of the normal one when the segment you land on can't be used.": "Um estalido curto e nítido em vez do normal quando o segmento selecionado não pode ser usado.",
    "A single dry click, lighter than a tick.": "Um único clique seco, mais suave que um estalido.",
    "A single very short, very hard hit.": "Um único golpe muito curto e muito forte.",
    "A slow low/high oscillation — the caller supplies the phase.": "Uma oscilação lenta entre os motores pesado e leve — a chamada fornece a fase.",
    "A soft tick followed by a brighter one.": "Um estalido suave seguido por um mais nítido.",
    "A soft tick when releasing the group targeting modifier back to normal navigation.": "Um estalido suave ao soltar o modificador de mira de grupo voltando à navegação normal.",
    "A soft tick when you cancel a radial selection instead of committing to it.": "Um estalido suave ao cancelar uma seleção radial em vez de confirmá-la.",
    "A soft tick when you start auto-attacking with a ranged weapon (Auto Shot, Shoot, wands).": "Um estalido suave ao iniciar o ataque automático com arma de longo alcance (Tiro Automático, Disparar, varinhas).",
    "A soft tick when you start meleeing.": "Um estalido suave ao iniciar o combate corpo a corpo.",
    "A soft tick when you start resting in an inn or major city.": "Um estalido suave ao começar a descansar em uma estalagem ou cidade principal.",
    "A soft tick when your melee auto-attack stops — catches walking out of range or a target dying without noticing.": "Um estalido suave quando seu ataque automático corpo a corpo para — detecta ao sair de alcance ou se o alvo morrer sem você notar.",
    "A soft, quick tick.": "Um estalido suave e rápido.",
    "A steady, low ambient texture.": "Uma textura ambiente constante e de baixa frequência.",
    "A steady, stronger texture — meant to be scaled by the caller (e.g. speed).": "Uma textura constante e mais forte — projetada para ser dimensionada pela chamada (ex.: velocidade).",
    "A tactile micro-tick each time the stack splitter quantity slider changes.": "Um microestalido tátil a cada alteração no controle deslizante de quantidade da divisão de pilha.",
    "A tactile recoil kick on every Auto Shot arrow, timed to the real shot, not estimated.": "Um recuo tátil em cada flecha de Tiro Automático, sincronizado com o disparo real, não estimado.",
    "A tap when a confirmation dialog opens.": "Um toque suave quando uma janela de confirmação se abre.",
    "A tap when an NPC or world object opens a window nothing else here covers.": "Um toque suave quando um PNJ ou objeto do mundo abre uma janela não coberta por outra opção.",
    "A texture that builds as your gliding speed climbs toward a boost.": "Uma textura que se intensifica conforme sua velocidade de planar aumenta em direção a um impulso.",
    "A tick when a book, plaque, gravestone or signpost opens to be read.": "Um estalido quando um livro, placa, lápide ou tabuleta se abre para leitura.",
    "A tick when a piece of your gear's durability drops into the low or broken range.": "Um estalido quando a durabilidade de um item do seu equipamento fica baixa ou quebrada.",
    "A tiny blip when you gain experience.": "Um microaviso sonoro quando você ganha experiência.",
    "A tiny low blip, for things that happen often.": "Um microaviso suave de baixa frequência, para coisas que acontecem com frequência.",
    "A triumphant dual-tone chime when you earn an achievement.": "Um som cristalino triunfante de tom duplo quando você obtém uma conquista.",
    "A very light micro-pulse.": "Um micropulso muito leve.",

    # 70..99
    "A very light tick per combo point, building toward a full resource.": "Um estalido muito leve por ponto de combo, acumulando até o recurso máximo.",
    "A very light tick when your equipped gear changes.": "Um estalido muito leve quando seu equipamento equipado muda.",
    "A very short, sharp tick when you avoid an incoming attack.": "Um estalido muito curto e nítido quando você evita um ataque recebido.",
    "AFK or DND toggled": "Ausente ou Não Perturbe alternado",
    "Ability pulse": "Pulso de habilidade",
    "Achievement earned": "Conquista obtida",
    "Action bar page changed": "Página da barra de ações alterada",
    "Action bars": "Barras de ações",
    "Action failed": "Falha na ação",
    "Action feedback": "Resposta de ação",
    "Activate": "Ativar",
    "Active Profile: |cffffd100%s|r": "Perfil ativo: |cffffd100%s|r",
    "Active profile": "Perfil ativo",
    "Actuator profile: %s\n%s": "Perfil do atuador: %s\n%s",
    "Addon language": "Idioma do addon",
    "Adjust your global master vibration strength. Individual cues can always be fine-tuned in settings.": "Ajuste a intensidade geral principal de vibração. Os sinais individuais sempre podem ser refinados nas configurações.",
    "Advanced Settings": "Configurações avançadas",
    "Also fires when you cancel a cast yourself, or move out of range — it means \"your cast did not finish\", not specifically \"you were kicked\".": "Também é acionado ao cancelar um lançamento manualmente ou sair do alcance — significa que \"seu lançamento não terminou\", não especificamente que \"você foi interrompido\".",
    "Also fires when you switch to a target that is already mid-cast.": "Também é acionado ao mudar para um alvo que já esteja no meio de um lançamento.",
    "Alternates between the motors — an unsteady, rolling feel.": "Alterna entre os motores — uma sensação oscilante e contínua.",
    "Alternating low thud and high snap across motors.": "Baque pesado e estalo nítido alternados entre os motores.",
    "Any other window": "Qualquer outra janela",
    "Anything else": "Qualquer outra coisa",
    "Applies only while this character is in this specialization. Switching specialization switches profile with it, with no further action from you.": "Aplica-se apenas enquanto este personagem estiver nesta especialização. Trocar de especialização altera o perfil automaticamente, sem nenhuma ação adicional de sua parte.",
    "Applies to this character whatever specialization it is in. This is the rule the profile picker on the Pulse page has always written to.": "Aplica-se a este personagem independentemente da especialização. Esta é a regra padrão definida pelo seletor de perfis na página Pulse.",
    "Attack time (s)": "Tempo de ataque (s)",
    "Attentive triage. Emergency low health warnings, dispel/CC alerts, kick warnings, and heal completion confirmation with subdued personal damage.": "Triagem atenta. Avisos de emergência de vida baixa, alertas de dissipação/controle de grupo, avisos de interrupção e confirmação de cura concluída com dano pessoal atenuado.",
    "Auto Shot fired": "Tiro Automático disparado",
    "Auto-switch in %s": "Troca automática em %s",
    "Automatic — game language": "Automático — idioma do jogo",

    # 100..129
    "Automatically switch to %s whenever this character is in this specialization.": "Alternar automaticamente para %s sempre que este personagem estiver nesta especialização.",
    "Battleground queue ready": "Fila de campo de batalha pronta",
    "Bed strength": "Intensidade da base contínua",
    "Bends the relationship between what a cue asks for and what the motor is told. Below 1.0 makes quiet cues louder; above 1.0 makes them quieter and reserves more of the range for strong ones. 1.0 is the unbent default.": "Modifica a curva de resposta entre o que um sinal solicita e o que é enviado ao motor. Abaixo de 1,0 torna sinais suaves mais intensos; acima de 1,0 torna-os mais suaves e reserva maior alcance para sinais fortes. 1,0 é o padrão linear.",
    "Boss ability warning": "Aviso de habilidade de chefe",
    "Boss chat warning": "Aviso de bate-papo de chefe",
    "Boss encounter ended": "Encontro com chefe finalizado",
    "Boss encounter started": "Encontro com chefe iniciado",
    "Breakaway floor": "Limiar mínimo de ativação",
    "Builds from a low hum into a high pulse.": "Intensifica-se de um zumbido grave para um pulso agudo.",
    "CLICK %s:LeftButton": "CLICK %s:LeftButton",
    "Cancel": "Cancelar",
    "Cast outcomes": "Resultados de lançamento",
    "Cast presence (low)": "Presença de lançamento (motor pesado)",
    "Cast sent": "Lançamento enviado",
    "Cast swell peak (high)": "Pico de expansão de lançamento (motor leve)",
    "Cast texture, cast finish confirmation, lockout/pushback warnings, proc glows, kick alerts": "Textura de lançamento, confirmação de conclusão de lançamento, avisos de bloqueio/recuo, brilhos de ativação e alertas de interrupção",
    "Casting": "Lançamento",
    "Casting texture": "Textura de lançamento",
    "Change threshold": "Limiar de alteração",
    "Character & Status": "Personagem e Estado",
    "Character state": "Estado do personagem",
    "Checked via C_UnitAuras.AuraIsBigDefensive. Occurrence only.": "Verificado via C_UnitAuras.AuraIsBigDefensive. Apenas ocorrência.",
    "Choose the addon display language. Automatic follows the game client. Missing translations use English. Changes apply after /reload.": "Escolha o idioma de exibição do addon. Automático segue o cliente do jogo. Traduções ausentes usam inglês. As alterações se aplicam após /reload.",
    "Click to open settings": "Clique para abrir as configurações",
    "Climbs this motor slowly from silence to %d%% power over %d seconds, ": "Aumenta a potência deste motor lentamente do silêncio a %d%% ao longo de %d segundos, ",
    "Close": "Fechar",
    "Combo point gained": "Ponto de combo obtido",
    "Companion tools": "Ferramentas complementares",
    "Competitive & Baseline": "Competitivo e Linha de base",
    "Configure tactile rewards for exploring Azeroth and sensory spatial awareness for targeting.": "Configure recompensas táteis para a exploração de Azeroth e percepção espacial sensorial para mira.",

    # 130..159
    "Confirmation popup appeared": "Janela pop-up de confirmação exibida",
    "Confirmation popup closed": "Janela pop-up de confirmação fechada",
    "Confused or possessed": "Confuso ou possuído",
    "Conversation & reading": "Conversas e leitura",
    "Copy": "Copiar",
    "Copy \"%s\" to a new custom profile named:": "Copiar \"%s\" para um novo perfil personalizado chamado:",
    "Copy \"%s\" to a new profile named:": "Copiar \"%s\" para um novo perfil chamado:",
    "Copy this profile": "Copiar este perfil",
    "Copy...": "Copiar...",
    "Create": "Criar",
    "Create a new editable custom profile that starts as an exact copy of %s.": "Cria um novo perfil personalizado editável que começa como uma cópia exata de %s.",
    "Create a new profile from Registry.lua's stock defaults and switch to it.": "Cria um novo perfil a partir dos padrões originais de Registry.lua e alterna para ele.",
    "Create a new profile that starts as an exact copy of the one in use, and switch to it. The two are independent from the first edit.": "Cria um novo perfil que começa como uma cópia exata daquele em uso e alterna para ele. Os dois tornam-se independentes a partir da primeira edição.",
    "Create editable copy": "Criar cópia editável",
    "Create...": "Criar...",
    "Crest froth & spray": "Espuma e borrifos da crista",
    "Cue index": "Índice do sinal",
    "Danger start threshold": "Limiar de início de perigo",
    "Death Knight": "Cavaleiro da Morte",
    "Debuff received": "Penalidade recebida",
    "Debug logging": "Registro de depuração",
    "Default": "Padrão",
    "Default (Balanced Baseline)": "Padrão (Linha de base equilibrada)",
    "Default profiles": "Perfis padrão",
    "Defensive": "Defensivo",
    "Delete": "Excluir",
    "Delete profile \"%s\"? This can't be undone.": "Excluir o perfil \"%s\"? Esta ação não pode ser desfeita.",
    "Delete this profile": "Excluir este perfil",
    "Delete...": "Excluir...",
    "Device": "Dispositivo",

    # 160..189
    "Disable All": "Desativar tudo",
    "Disable all cues": "Desativar todos os sinais",
    "Disable all cues in profile": "Desativar todos os sinais no perfil",
    "Disable every vibration cue in the active profile in one sweep for quiet testing or building a profile from scratch.": "Desativa todos os sinais de vibração no perfil ativo de uma só vez para testes silenciosos ou criação de um perfil do zero.",
    "Disarmed": "Desarmado",
    "Displays a shortcut button on the edge of your minimap for quick access to settings and toggling vibration.": "Exibe um botão de atalho na borda do seu minimapa para acesso rápido às configurações e alternância de vibração.",
    "Distinctiveness": "Distintividade",
    "Distinguished from cancelling by Blizzard's own `isCancelled` flag, which it sets before ending the selection — so a cancel never counts as a choice.": "Distingue-se do cancelamento pela flag `isCancelled` da própria Blizzard, definida antes de encerrar a seleção — de modo que o cancelamento nunca conte como escolha.",
    "Doubles as the catch-all: a loss-of-control type this addon does not recognise — a new one added by a patch — fires this generic cue instead of being silently dropped.": "Funciona também como tratamento geral: um tipo de perda de controle não reconhecido por este addon — como um novo adicionado por uma atualização — aciona este sinal genérico em vez de ser descartado em silêncio.",
    "Druid": "Druida",
    "Dual asymmetrical ERM motors, balanced 75ms spin-up": "Dois motores ERM assimétricos, aceleração equilibrada de 75ms",
    "Dual-motor rumble & vibration schemas": "Esquemas de vibração e retorno tátil de motor duplo",
    "Duel request": "Solicitação de duelo",
    "Dungeon queue popped": "Fila de masmorra disponível",
    "Dungeon: Caster": "Masmorra: Conjurador",
    "Dungeon: Caster DPS": "Masmorra: Conjurador Dano",
    "Dungeon: Healer": "Masmorra: Curador",
    "Dungeon: Hunter": "Masmorra: Caçador",
    "Dungeon: Melee": "Masmorra: Corpo a corpo",
    "Dungeon: Melee DPS": "Masmorra: Dano corpo a corpo",
    "Dungeon: Tank": "Masmorra: Tanque",
    "Effort peak": "Pico de esforço",
    "Empowered cast stage": "Estágio de lançamento fortalecido",
    "Enable All": "Ativar tudo",
    "Enable Cue": "Ativar sinal",
    "Enable Pulse": "Ativar Pulse",
    "Enable all cues": "Ativar todos os sinais",
    "Enable all cues in profile": "Ativar todos os sinais no perfil",
    "Enable every vibration cue in the active profile in one sweep for testing and debugging.": "Ativa todos os sinais de vibração no perfil ativo de uma só vez para testes e depuração.",
    "Encounter": "Encontro",

    # 190..219
    "Entered a vehicle": "Entrou em um veículo",
    "Entered melee range": "Entrou no alcance corpo a corpo",
    "Environment": "Ambiente",
    "Equipment": "Equipamento",
    "Every character": "Todos os personagens",
    "Evoker-only in practice. It stays registered for every class and simply never fires for the others.": "Na prática, exclusivo de Conjurante. Permanece registrado para todas as classes e simplesmente nunca é acionado nas demais.",
    "Experience gained": "Experiência obtida",
    "Experimental": "Experimental",
    "Fast attack time constant used specifically for discrete impacts, clicks, and strikes. Gives snappy transients without making sustained immersion textures harsh.": "Constante de tempo de ataque rápido usada especificamente para impactos discretos, cliques e golpes. Proporciona transientes rápidos sem tornar ríspidas as texturas contínuas de imersão.",
    "Feared or charmed": "Aterrorizado ou encantado",
    "Feel ": "Sentir ",
    "Feel Strength": "Intensidade da sensação",
    "Feel this texture": "Sentir esta textura",
    "Feels like": "Sensação tátil",
    "Feels like: ": "Sensação tátil: ",
    "Find breakaway floor": "Localizar limiar mínimo de ativação",
    "Fires as an empowered cast of yours begins and ends.": "É acionado quando um lançamento fortalecido seu se inicia e termina.",
    "Fires at most ": "É acionado no máximo ",
    "Fires for any summon confirmation dialog, not only a player summoning you.": "É acionado para qualquer janela de confirmação de evocação, não apenas quando um jogador evoca você.",
    "Fires on PLAYER_TARGET_DIED.": "É acionado em PLAYER_TARGET_DIED.",
    "Fires on input, so it also fires for casts that then fail. That is intentional: this is an input-acknowledgement cue, not a success cue.": "É acionado na entrada do comando, portanto também ocorre para lançamentos que venham a falhar. Isso é intencional: trata-se de um sinal de confirmação de entrada, não de sucesso.",
    "Fires on the change itself, not on every flag update.": "É acionado na alteração em si, não a cada atualização de estado.",
    "Fires on the crossing into low, not repeatedly while low.": "É acionado na transição para o nível baixo, não repetidamente enquanto estiver baixo.",
    "Fires on the yellow informational messages the game shows in the top centre of the screen.": "É acionado nas mensagens informativas amarelas exibidas pelo jogo na parte superior central da tela.",
    "Fires only when a queue enters the ready-to-enter state, not on every status update.": "É acionado apenas quando uma fila atinge o estado pronta para entrar, não a cada atualização de status.",
    "Fires the instant you press a cast, before the server has confirmed it.": "É acionado no instante em que você pressiona para lançar, antes da confirmação do servidor.",
    "Fires upon arrival at destination when player control is restored.": "É acionado ao chegar ao destino quando o controle do jogador é restaurado.",
    "Fires when a battleground or arena queue is ready to enter.": "É acionado quando uma fila de campo de batalha ou arena está pronta para entrar.",
    "Fires when a boss encounter begins.": "É acionado quando um encontro com chefe começa.",

    # 220..249
    "Fires when a boss encounter ends, in victory or in a wipe.": "É acionado quando um encontro com chefe termina, seja em vitória ou derrota total.",
    "Fires when a flight master's map opens.": "É acionado quando o mapa do mestre de voo se abre.",
    "Fires when a loading screen ends and the world is back.": "É acionado quando uma tela de carregamento termina e o mundo reaparece.",
    "Fires when a quest is handed in and its reward is taken.": "É acionado quando uma missão é entregue e sua recompensa é recebida.",
    "Fires when a quest's completion page opens, ready to hand in.": "É acionado quando a página de conclusão de uma missão se abre, pronta para entrega.",
    "Fires when a quest's detail page opens, ready to accept.": "É acionado quando a página de detalhes de uma missão se abre, pronta para aceitar.",
    "Fires when a ready check completes or times out.": "É acionado quando uma confirmação de prontidão termina ou atinge o limite de tempo.",
    "Fires when a ready check starts.": "É acionado quando uma confirmação de prontidão começa.",
    "Fires when a role check starts.": "É acionado quando uma verificação de função começa.",
    "Fires when a trade window opens.": "É acionado quando uma janela de negociação se abre.",
    "Fires when a vendor window opens.": "É acionado quando a janela de um comerciante se abre.",
    "Fires when an innkeeper asks to make this your home.": "É acionado quando um estalajadeiro pergunta se deseja fazer deste local seu lar.",
    "Fires when gaining money with an open vendor window.": "É acionado ao receber dinheiro com a janela do comerciante aberta.",
    "Fires when group leadership changes hands.": "É acionado quando a liderança do grupo é transferida.",
    "Fires when one of your own casts begins.": "É acionado quando um lançamento próprio começa.",
    "Fires when one of your own casts completes successfully — distinct from a cast simply ending.": "É acionado quando um lançamento próprio é concluído com sucesso — diferente de um lançamento simplesmente terminar.",
    "Fires when one of your own casts ends, whether or not it completed.": "É acionado quando um lançamento próprio termina, quer tenha sido concluído ou não.",
    "Fires when someone challenges you to a duel.": "É acionado quando alguém desafia você para um duelo.",
    "Fires when someone invites you to a group.": "É acionado quando alguém convida você para um grupo.",
    "Fires when someone joins or leaves your group.": "É acionado quando alguém entra ou sai do seu grupo.",
    "Fires when someone offers you a resurrection and the accept dialog appears.": "É acionado quando alguém oferece uma ressurreição a você e a caixa de diálogo de aceitação aparece.",
    "Fires when someone summons you and the accept dialog appears.": "É acionado quando alguém evoca você e a caixa de diálogo de aceitação aparece.",
    "Fires when spending money with an open vendor window.": "É acionado ao gastar dinheiro com a janela do comerciante aberta.",
    "Fires when the stable master's window opens.": "É acionado quando a janela do mestre de estábulo se abre.",
    "Fires when you accept a quest.": "É acionado quando você aceita uma missão.",
    "Fires when you are confused or possessed (CONFUSE, POSSESS).": "É acionado quando você está confuso ou possuído (CONFUSE, POSSESS).",
    "Fires when you are disarmed (DISARM).": "É acionado quando você é desarmado (DISARM).",
    "Fires when you are feared or charmed (FEAR, FEAR_MECHANIC, CHARM).": "É acionado quando você está aterrorizado ou encantado (FEAR, FEAR_MECHANIC, CHARM).",
    "Fires when you are resurrected or leave ghost form.": "É acionado quando você é ressuscitado ou sai da forma de espírito.",
    "Fires when you are rooted in place (ROOT). You can still act, so this is a rung below the cues that stop you entirely.": "É acionado quando você fica enraizado no local (ROOT). Você ainda pode agir, portanto este sinal está um degrau abaixo dos sinais que o impedem totalmente.",
    "Fires when you are silenced (SILENCE).": "É acionado quando você está silenciado (SILENCE).",

    # 250..279
    "Fires when you are stunned (STUN, STUN_MECHANIC).": "É acionado quando você está atordoado (STUN, STUN_MECHANIC).",
    "Fires when you change target, including when you clear it.": "É acionado quando você muda de alvo, inclusive ao limpá-lo.",
    "Fires when you die.": "É acionado quando você morre.",
    "Fires when you enter a new zone.": "É acionado quando você entra em uma nova zona.",
    "Fires when you enter a vehicle and your action bar is replaced.": "É acionado quando você entra em um veículo e sua barra de ações é substituída.",
    "Fires when you leave a vehicle and your own action bar returns.": "É acionado quando você sai de um veículo e sua própria barra de ações retorna.",
    "Fires when you set or clear your focus target.": "É acionado quando você define ou limpa seu alvo de foco.",
    "Fires when your class's secondary resource fills up — combo points, holy power, soul shards, chi, arcane charges, essence or runes, whichever your specialisation uses.": "É acionado quando o recurso secundário da sua classe se enche — pontos de combo, poder sagrado, fragmentos de alma, chi, cargas arcanas, essência ou runas, conforme a sua especialização utilizar.",
    "Fires when your focus target begins casting.": "É acionado quando seu alvo de foco começa a lançar um feitiço.",
    "Fires when your own away or do-not-disturb flag actually changes.": "É acionado quando o seu próprio status de ausente ou não perturbe realmente muda.",
    "Flight map opened": "Mapa de voo aberto",
    "Focus": "Foco",
    "Focus changed": "Foco alterado",
    "Focus started casting": "Foco começou a lançar",
    "Focused element became unavailable": "Elemento em foco tornou-se indisponível",
    "Four rapid, sharp ticks.": "Quatro estalidos rápidos e nítidos.",
    "Gait strength": "Intensidade da marcha",
    "Gasp peak": "Pico de ofego",
    "Gear needs repair": "Equipamento precisa de reparos",
    "Generic / Unknown": "Genérico / Desconhecido",
    "Generic / unknown": "Genérico / desconhecido",
    "Gentle steady engine-like cruise vibration while riding flight master gryphons, bats, or wyverns.": "Vibração de cruzeiro suave e constante, semelhante a um motor, ao voar em grifos, morcegos ou mantícoras de mestre de voo.",
    "Group changes": "Alterações de grupo",
    "Group readiness": "Prontidão do grupo",
    "Group roster changed": "Formação do grupo alterada",
    "Group targeting active": "Mira de grupo ativa",
    "Group targeting released": "Mira de grupo liberada",
    "Hardware & Presets": "Hardware e Predefinições",
    "Harvest complete": "Coleta concluída",
    "Heal casts and low-health triage": "Lançamentos de cura e triagem de vida baixa",

    # 280..309
    "Healing received": "Cura recebida",
    "Health & survival": "Vida e sobrevivência",
    "Heart rate (BPM)": "Frequência cardíaca (BPM)",
    "Heart rate (calm), BPM": "Frequência cardíaca (em repouso), BPM",
    "Heavy Impacts": "Impactos pesados",
    "Heavy left counterweight (85ms), light right counterweight (45ms)": "Contrapeso pesado esquerdo (85 ms), contrapeso leve direito (45 ms)",
    "High Motor Only": "Apenas motor leve/rápido",
    "High motor": "Motor leve/rápido",
    "Hooks StackSplitFrame:UpdateStackText.": "Intercepta StackSplitFrame:UpdateStackText.",
    "How far the hum swells either side of its baseline. 0 is a flat hold.": "O quanto o zumbido oscila para cada lado da sua base. 0 representa sustentação contínua plana.",
    "How fast the wingbeat-style undulation cycles.": "A rapidez com que a oscilação em estilo de bater de asas se repete.",
    "How many seconds before the scripted moment this fires.": "Quantos segundos antes do momento programado isso é acionado.",
    "How pronounced each stroke is against its own baseline. Higher values (0.80-1.0) allow the counterweight to physically spin down during the glide phase between strokes. 0 is a flat drag with no rhythm at all.": "O quanto cada braçada se destaca em relação à sua própria base contínua. Valores mais altos (0,80-1,0) permitem que o contrapeso desacelere fisicamente durante a fase de deslize entre as braçadas. 0 representa um arrasto constante sem ritmo algum.",
    "How steady the low motor stays regardless of speed. Only audible while actually gliding.": "O quanto o motor pesado/lento se mantém constante, independentemente da velocidade. Apenas perceptível enquanto estiver planando.",
    "How strong the hum gets by the moment a regular cast completes. Only audible if \"Casting texture\" is also enabled on its own tab.": "A intensidade que o zumbido atinge no momento em que um lançamento comum se completa. Perceptível apenas se \"Textura de lançamento\" também estiver ativada em sua própria aba.",
    "Hunter": "Caçador",
    "If nothing is happening": "Se nada estiver acontecendo",
    "Immediately switch to %s for the current character.": "Alternar imediatamente para %s no personagem atual.",
    "Immersion: Caster": "Imersão: Conjurador",
    "Immersion: Melee": "Imersão: Corpo a corpo",
    "Immersion: Ranged": "Imersão: Longo alcance",
    "Impact attack (s)": "Ataque de impacto (s)",
    "Initial software voltage boost applied during transient onset to accelerate the motor rapidly to target speed. 1.0 is disabled.": "Aumento inicial de tensão via software aplicado durante o início do transiente para acelerar o motor rapidamente até a velocidade desejada. 1,0 é desativado.",
    "Innkeeper hearth prompt": "Mensagem de pedra de regresso do estalajadeiro",
    "Input device changed": "Dispositivo de entrada alterado",
    "Input mode": "Modo de entrada",
    "Instant ability used": "Habilidade instantânea usada",
    "Intensity": "Intensidade",
    "Intensity Slider": "Controle deslizante de intensidade",
    "Interface": "Interface",

    # 310..329
    "Interface & Accessibility": "Interface e Acessibilidade",
    "Interface message": "Mensagem da interface",
    "Interface tab changed": "Aba da interface alterada",
    "Inventory full warning": "Aviso de inventário cheio",
    "Invites & requests": "Convites e solicitações",
    "Jarring physical weapon clatter": "Ruído metálico áspero de armas",
    "LRA (Classic ERM Emulation)": "LRA (Emulação ERM Clássica)",
    "Landed": "Aterrissou",
    "Leave this scope with no opinion and let the next one decide.": "Deixar este escopo sem preferência e permitir que o seguinte decida.",
    "Left a vehicle": "Saiu de um veículo",
    "Left melee range": "Saiu do alcance corpo a corpo",
    "Level up": "Subiu de nível",
    "Lifecycle (advanced)": "Ciclo de vida (avançado)",
    "Load its starting values": "Carregar seus valores iniciais",
    "Loading screen finished": "Tela de carregamento concluída",
    "Loss of control": "Perda de controle",
    "Loss of control cues": "Sinais de perda de controle",
    "Low Health Heartbeat": "Batimento cardíaco de vida baixa",
    "Low Motor Only": "Apenas motor pesado/lento",
}

def main():
    batch_path = "/home/deck/developer/wow/PulseSensation/localization/batches/batch1a_ui_navigation.json"
    with open(batch_path, "r", encoding="utf-8") as f:
        batch = json.load(f)

    items = batch["items"]
    print(f"Loaded batch1a with {len(items)} items.")
    print(f"TRANSLATIONS_PT dict has {len(TRANSLATIONS_PT)} entries.")

    errors = 0
    translated_items = []

    for idx, it in enumerate(items):
        src = it["source"]
        if src not in TRANSLATIONS_PT:
            print(f"ERROR: Missing translation for item [{idx}] (id={it.get('id')}): {repr(src)}")
            errors += 1
            continue

        tgt = TRANSLATIONS_PT[src]

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

    out_path = "/home/deck/developer/wow/PulseSensation/localization/batches/translated_ptBR_batch1a.json"
    out_data = {
        "items": translated_items
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out_data, f, indent=2, ensure_ascii=False)

    print(f"SUCCESS: Wrote {len(translated_items)} validated translations to {out_path}")

if __name__ == "__main__":
    main()
