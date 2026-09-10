extends Node

## AUTOLOAD (Singleton).
## Configure em: Project Settings > Autoload > adicione este script com o
## nome "ReacoesQuimicas". IMPORTANTE: coloque ele DEPOIS do "Eventos" na
## lista de autoloads (ele se conecta aos sinais do Eventos em _ready()).
##
## Sistema genérico de "Chemical Reaction": uma sinergia (ou rivalidade)
## entre DOIS personagens que se ativa quando um GATILHO (uma habilidade
## específica de um personagem X) é seguido, dentro de uma JANELA de tempo,
## por uma CONDIÇÃO (a bola entrar no alcance de um personagem Y). Quando
## os dois se encontram, dispara um EFEITO em Y.
##
## Pra adicionar uma reação nova (outra sinergia, ou uma rivalidade que
## ATRAPALHA em vez de ajudar): adicione uma entrada em REACOES lá embaixo.
## Nenhum personagem precisa saber que a reação existe — tudo acontece por
## fora, escutando Eventos.habilidade_executada e Eventos.bola_entrou_alcance
## (ver Botao.gd), então não há nenhum "if nome == 'Bachira'" espalhado
## pelo código dos personagens.

## Cada entrada de REACOES é um Dictionary com:
## - "nome": nome de exibição (só pra mensagens/debug e chave do cooldown)
## - "gatilho_classe": a classe (script) do personagem que PROVOCA a reação
## - "gatilho_habilidade": nome da habilidade que precisa ter sido usada
## - "alvo_classe": a classe do personagem que RECEBE o efeito
## - "mesmo_time": true = só dispara se gatilho e alvo forem do MESMO time
##   (sinergia); false = só dispara se forem de times OPOSTOS (rivalidade)
## - "janela_segundos": por quanto tempo, depois do gatilho, a bola ainda
##   pode "chegar" no alvo e contar como a MESMA jogada
## - "cooldown_turnos": opcional — turnos de cooldown INTERNO depois de
##   disparar (padrão: COOLDOWN_TURNOS_PADRAO). Não aparece pra nenhum
##   jogador, é só pra evitar a mesma Chemical Reaction repetir cedo demais
##   e desbalancear o jogo.
## - "efeito": Callable(alvo: Botao) -> void, chamado quando a reação dispara

## Cooldown padrão de qualquer reação que não definir "cooldown_turnos"
## própria. 16 turnos = contando qualquer troca de turno (do próprio time
## ou do adversário), igual ao cooldown de habilidade comum do Botao.gd.
const COOLDOWN_TURNOS_PADRAO := 16

var REACOES: Array[Dictionary] = [
	{
		"nome": "Desire",
		"gatilho_classe": Bachira,
		"gatilho_habilidade": Bachira.NOME_BEE_SHOT,
		"alvo_classe": Isagi,
		"mesmo_time": true,
		"janela_segundos": 2.5,
		"efeito": func(alvo: Botao) -> void:
			var isagi := alvo as Isagi
			isagi.conceder_acao_habilidade_extra(1)
			isagi.conceder_habilidade(
				"Strongest Guy",
				func() -> void: isagi.executar_strongest_guy(),
				true,   # custa_acao
				-1,     # turnos_para_expirar: não expira sozinha por turno,
						# é de uso único mesmo (some assim que for usada)
				true,   # disponivel_imediatamente: PRECISA valer já neste
						# turno, senão a janela da jogada já passou
			)
			Eventos.mensagem_solicitada.emit(
				"Chemical Reaction: Desire! Isagi ganhou uma ação de habilidade extra e a Strongest Guy!"
			)
			},
]

## Gatilhos armados aguardando a condição (a bola chegar no alvo certo),
## um Dictionary por gatilho pendente: {"reacao": Dictionary, "botao_gatilho": Botao}.
## Cada um se autoexpira sozinho via create_timer() em _on_habilidade_executada
## — mesmo padrão que Bola.gd já usa em ativar_intangivel_para_botoes().
var _pendentes: Array[Dictionary] = []

## Cooldown INTERNO por reação (chave = "nome" da reação, valor = turnos
## restantes). NUNCA exibido pro jogador — só existe pra impedir a MESMA
## reação de dois personagens específicos de disparar de novo cedo demais.
## Decrementado a cada troca de turno, em _on_turno_mudou() — mesma ideia
## do dicionário "cooldowns" que o Botao.gd já usa por personagem, só que
## aqui é um único dicionário global, compartilhado por todas as reações.
var _cooldowns: Dictionary = {}


func _ready() -> void:
	Eventos.habilidade_executada.connect(_on_habilidade_executada)
	Eventos.bola_entrou_alcance.connect(_on_bola_entrou_alcance)
	Turnos.turno_iniciado.connect(_on_turno_mudou)


func _on_turno_mudou(_time_iniciado: String) -> void:
	for nome in _cooldowns.keys():
		if _cooldowns[nome] > 0:
			_cooldowns[nome] -= 1


func _reacao_em_cooldown(reacao: Dictionary) -> bool:
	return _cooldowns.get(reacao["nome"], 0) > 0


func _iniciar_cooldown(reacao: Dictionary) -> void:
	_cooldowns[reacao["nome"]] = reacao.get("cooldown_turnos", COOLDOWN_TURNOS_PADRAO)


func _on_habilidade_executada(botao: Botao, nome: String) -> void:
	for reacao in REACOES:
		if nome != reacao["gatilho_habilidade"]:
			continue
		if not is_instance_of(botao, reacao["gatilho_classe"]):
			continue
		if _reacao_em_cooldown(reacao):
			# cooldown interno: a jogada acontece normalmente (Bee Shot sai
			# igual), só a Chemical Reaction em si não arma — e como isso
			# não é comunicado ao jogador, o cooldown fica realmente invisível
			continue

		var pendente := {"reacao": reacao, "botao_gatilho": botao}
		_pendentes.append(pendente)

		# rede de segurança: se a condição (bola no alcance do alvo) nunca
		# chegar a acontecer dentro da janela — ex: a Bee Shot foi
		# interceptada, ou não tinha ninguém do alvo por perto — o gatilho
		# pendente é descartado sozinho, sem ficar "armado" pra sempre
		var temporizador := get_tree().create_timer(reacao["janela_segundos"])
		temporizador.timeout.connect(func() -> void:
			_pendentes.erase(pendente)
		)


func _on_bola_entrou_alcance(botao: Botao) -> void:
	for i in range(_pendentes.size() - 1, -1, -1):
		var pendente: Dictionary = _pendentes[i]
		var reacao: Dictionary = pendente["reacao"]
		var gatilho: Botao = pendente["botao_gatilho"]

		if not is_instance_valid(gatilho) or botao == gatilho:
			continue
		if not is_instance_of(botao, reacao["alvo_classe"]):
			continue
		if (botao.time == gatilho.time) != reacao["mesmo_time"]:
			continue

		reacao["efeito"].call(botao)
		_iniciar_cooldown(reacao)
		# uso único por gatilho: evita disparar de novo se a bola sair do
		# alcance do alvo e voltar a entrar dentro da mesma janela
		_pendentes.remove_at(i)
