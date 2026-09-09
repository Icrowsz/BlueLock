extends Botao
class_name Lorenzo

## Lorenzo
##
## - Rest in Money: escolhe um inimigo e avança até perto dele. A partir
##   daí, o alvo tem exatamente UM turno (do time dele) pra sair do
##   alcance grande da habilidade. Se, quando esse turno terminar, ele
##   ainda estiver dentro do alcance, fica travado (SEM poder se mover
##   NEM usar habilidade) por vários turnos. Cooldown de 7 turnos.
##
## - Undead Pass: escolhe um aliado e um inimigo. Um passe DE VERDADE
##   (física normal, então PODE ser interceptado) sai em direção ao
##   aliado; o inimigo escolhido fica sem poder se mover por 3 turnos.
##   Cooldown de 6 turnos.
##
## - Mafia: escolhe dois aliados e um inimigo. Os dois aliados se
##   deslocam até perto do inimigo (cercando ele); Lorenzo ganha uma
##   ação de movimento extra. Cooldown de 7 turnos.

@export_group("Rest in Money")
@export var distancia_aproximacao_rest_in_money: float = 80.0
@export var alcance_rest_in_money: float = 400.0
@export var duracao_bloqueio_rest_in_money: int = 5
@export var cooldown_rest_in_money: int = 7

@export_group("Undead Pass")
@export var forca_undead_pass: float = 140.0
@export var duracao_bloqueio_undead_pass: int = 3
@export var cooldown_undead_pass: int = 6

@export_group("Mafia")
@export var distancia_cerco_mafia: float = 60.0
@export var cooldown_mafia: int = 7

const NOME_REST_IN_MONEY := "Rest in Money"
const NOME_UNDEAD_PASS := "Undead Pass"
const NOME_MAFIA := "Mafia"

var _undead_pass_aliado: Botao = null
var _mafia_aliados: Array[Botao] = []

## Máquina de estados do Rest in Money: 0 = inativo, 1 = esperando o
## turno do alvo COMEÇAR, 2 = turno do alvo em andamento (esperando ele
## TERMINAR pra checar se conseguiu fugir)
var _rest_in_money_fase: int = 0
var _rest_in_money_alvo: Botao = null
var _rest_in_money_centro: Vector2 = Vector2.ZERO


func habilidades_proprias() -> Array[String]:
	return [NOME_REST_IN_MONEY, NOME_UNDEAD_PASS, NOME_MAFIA]


func _habilidade_propria_consome_acao(_nome: String) -> bool:
	# as três dependem de seleção de alvo em várias etapas — a ação só é
	# consumida quando a jogada REALMENTE se completa (ver cada fluxo
	# abaixo), pra cancelar no meio (botão direito/Esc) não custar nada
	return false


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_UNDEAD_PASS and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_REST_IN_MONEY:
			SelecaoAlvo.pedir_alvo(self, _on_alvo_rest_in_money, "Selecione um inimigo para o Rest in Money")
		NOME_UNDEAD_PASS:
			SelecaoAlvo.pedir_alvo(self, _on_aliado_undead_pass, "Selecione o ALIADO do Undead Pass")
		NOME_MAFIA:
			_mafia_aliados = []
			SelecaoAlvo.pedir_alvo(self, _on_primeiro_aliado_mafia, "Selecione o PRIMEIRO aliado do Mafia")


## --- Rest in Money ---

func _on_alvo_rest_in_money(alvo: Botao) -> void:
	if alvo == self or alvo.time == time:
		Eventos.mensagem_solicitada.emit("Escolha um oponente como alvo!")
		return

	consumir_acao_habilidade()
	iniciar_cooldown(NOME_REST_IN_MONEY, cooldown_rest_in_money)

	var direcao_aproximacao := (global_position - alvo.global_position)
	direcao_aproximacao = direcao_aproximacao.normalized() if direcao_aproximacao.length() > 1.0 else Vector2.RIGHT
	var destino := alvo.global_position + direcao_aproximacao * distancia_aproximacao_rest_in_money
	MovimentoSuave.mover(self, destino)

	_rest_in_money_alvo = alvo
	_rest_in_money_centro = destino
	_rest_in_money_fase = 1

	if not Turnos.turno_iniciado.is_connected(_on_turno_rest_in_money):
		Turnos.turno_iniciado.connect(_on_turno_rest_in_money)

	Eventos.mensagem_solicitada.emit("Rest in Money! %s tem até o fim do próprio turno para fugir do alcance." % alvo.name)


func _on_turno_rest_in_money(time_iniciado: String) -> void:
	if not _rest_in_money_alvo or not is_instance_valid(_rest_in_money_alvo):
		_encerrar_rest_in_money()
		return

	if _rest_in_money_fase == 1 and time_iniciado == _rest_in_money_alvo.time:
		# o turno de fuga do alvo está começando agora
		_rest_in_money_fase = 2
		return

	if _rest_in_money_fase == 2 and time_iniciado != _rest_in_money_alvo.time:
		# o turno de fuga do alvo acabou de terminar — hora de checar
		var distancia := _rest_in_money_centro.distance_to(_rest_in_money_alvo.global_position)
		if distancia <= alcance_rest_in_money:
			_rest_in_money_alvo.aplicar_bloqueio_movimento(duracao_bloqueio_rest_in_money)
			_rest_in_money_alvo.aplicar_bloqueio_habilidade(duracao_bloqueio_rest_in_money)
			Eventos.mensagem_solicitada.emit("%s não conseguiu fugir! Travado por %d turnos." % [_rest_in_money_alvo.name, duracao_bloqueio_rest_in_money])
		else:
			Eventos.mensagem_solicitada.emit("%s escapou do alcance do Rest in Money!" % _rest_in_money_alvo.name)
		_encerrar_rest_in_money()


func _encerrar_rest_in_money() -> void:
	_rest_in_money_fase = 0
	_rest_in_money_alvo = null
	if Turnos.turno_iniciado.is_connected(_on_turno_rest_in_money):
		Turnos.turno_iniciado.disconnect(_on_turno_rest_in_money)


## --- Undead Pass ---

func _on_aliado_undead_pass(aliado: Botao) -> void:
	if aliado == self or aliado.time != time:
		Eventos.mensagem_solicitada.emit("Escolha um companheiro de time como aliado!")
		return

	_undead_pass_aliado = aliado
	SelecaoAlvo.pedir_alvo(self, _on_inimigo_undead_pass, "Selecione o INIMIGO do Undead Pass")


func _on_inimigo_undead_pass(inimigo: Botao) -> void:
	var aliado := _undead_pass_aliado
	_undead_pass_aliado = null

	if inimigo.time == time:
		Eventos.mensagem_solicitada.emit("Escolha um oponente como segundo alvo!")
		return

	var bola := bola_no_alcance
	if not bola:
		Eventos.mensagem_solicitada.emit("A bola não está mais por perto!")
		return

	consumir_acao_habilidade()
	iniciar_cooldown(NOME_UNDEAD_PASS, cooldown_undead_pass)

	var direcao := (aliado.global_position - bola.global_position).normalized()
	bola.receber_chute_teleguiado(direcao, forca_undead_pass)

	inimigo.aplicar_bloqueio_movimento(duracao_bloqueio_undead_pass)

	Eventos.mensagem_solicitada.emit("Undead Pass! Passe pra %s, %s travado por %d turnos." % [aliado.name, inimigo.name, duracao_bloqueio_undead_pass])


## --- Mafia ---

func _on_primeiro_aliado_mafia(aliado: Botao) -> void:
	if aliado == self or aliado.time != time:
		Eventos.mensagem_solicitada.emit("Escolha um companheiro de time!")
		_mafia_aliados = []
		return

	_mafia_aliados = [aliado]
	SelecaoAlvo.pedir_alvo(self, _on_segundo_aliado_mafia, "Selecione o SEGUNDO aliado do Mafia")


func _on_segundo_aliado_mafia(aliado: Botao) -> void:
	if aliado == self or aliado.time != time or aliado in _mafia_aliados:
		Eventos.mensagem_solicitada.emit("Escolha um segundo companheiro DIFERENTE do primeiro!")
		_mafia_aliados = []
		return

	_mafia_aliados.append(aliado)
	SelecaoAlvo.pedir_alvo(self, _on_inimigo_mafia, "Selecione o inimigo alvo do Mafia")


func _on_inimigo_mafia(inimigo: Botao) -> void:
	var aliados := _mafia_aliados
	_mafia_aliados = []

	if inimigo.time == time:
		Eventos.mensagem_solicitada.emit("Escolha um oponente como alvo!")
		return

	consumir_acao_habilidade()
	iniciar_cooldown(NOME_MAFIA, cooldown_mafia)

	for aliado in aliados:
		var direcao := (aliado.global_position - inimigo.global_position)
		direcao = direcao.normalized() if direcao.length() > 1.0 else Vector2.RIGHT
		var destino := inimigo.global_position + direcao * distancia_cerco_mafia
		MovimentoSuave.mover(aliado, destino)

	conceder_acao_movimento_extra(1)

	Eventos.mensagem_solicitada.emit("Mafia! %s e %s cercaram %s. Lorenzo ganhou uma ação de movimento extra." % [aliados[0].name, aliados[1].name, inimigo.name])
