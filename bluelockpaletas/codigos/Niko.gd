extends Botao
class_name Niko

## Niko
##
## - Transition Pass: desliza até a bola. Se alcançar (ela ficar dentro
##   do AreaAlcance ao terminar o movimento), oferece a opção de
##   escolher um inimigo PRÓXIMO pra travar o movimento dele por 2
##   turnos (aplicar_bloqueio_movimento, na base — reaproveita o mesmo
##   mecanismo do Snake Hunt do Aiku). Em seguida, faz um desarme/passe
##   AUTOMÁTICO pro aliado MAIS LONGE do Niko em campo — um chute de
##   verdade (receber_chute_teleguiado), então PODE ser interceptado no
##   caminho. Cooldown de 6 turnos.
##
## - Metavisão: igual à do Isagi (mira com trajetória e ricochete —
##   implementada no Botao.gd base), só que em vez de ser PRÓPRIA, o
##   Niko CONCEDE ela a todos os aliados em campo por 4 turnos, via
##   conceder_visao_estendida(). O Niko em si não ganha nada com isso.
##   Cooldown de 6 turnos.

@export_group("Transition Pass")
@export var duracao_movimento_transition_pass: float = 0.5
@export var distancia_parada_da_bola: float = 30.0
@export var alcance_alvo_bloqueio: float = 250.0  ## distância máxima pra oferecer o bloqueio de movimento num inimigo
@export var duracao_bloqueio_alvo: int = 2
@export var forca_passe_transition: float = 170.0
@export var cooldown_transition_pass: int = 6

@export_group("Metavisão (concedida)")
@export var duracao_metavisao_aliados: int = 4
@export var cooldown_metavisao: int = 6

const NOME_TRANSITION_PASS := "Transition Pass"
const NOME_METAVISAO := "Metavisão"


func habilidades_proprias() -> Array[String]:
	return [NOME_TRANSITION_PASS, NOME_METAVISAO]


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_TRANSITION_PASS:
			_executar_transition_pass()
			iniciar_cooldown(nome, cooldown_transition_pass)
		NOME_METAVISAO:
			_executar_metavisao_concedida()
			iniciar_cooldown(nome, cooldown_metavisao)


## --- Transition Pass ---

func _executar_transition_pass() -> void:
	var bola := encontrar_bola()
	if not bola:
		return

	var direcao := (global_position - bola.global_position)
	direcao = direcao.normalized() if direcao.length() > 1.0 else Vector2.RIGHT
	var destino := bola.global_position + direcao * distancia_parada_da_bola

	MovimentoSuave.mover(self, destino, duracao_movimento_transition_pass, func() -> void:
		if not bola_no_alcance:
			Eventos.mensagem_solicitada.emit("Transition Pass! Niko não alcançou a bola dessa vez.")
			return
		_oferecer_bloqueio_ou_passar()
	)


func _oferecer_bloqueio_ou_passar() -> void:
	var inimigo := _inimigo_mais_proximo_no_alcance()
	if not inimigo:
		Eventos.mensagem_solicitada.emit("Transition Pass! Nenhum inimigo próximo pra travar — passando direto.")
		_completar_passe_transition()
		return

	SelecaoAlvo.pedir_alvo(self, func(alvo: Botao) -> void:
		if alvo == inimigo:
			alvo.aplicar_bloqueio_movimento(duracao_bloqueio_alvo)
			Eventos.mensagem_solicitada.emit("Transition Pass! %s ficou sem poder se mover por %d turnos." % [alvo.name, duracao_bloqueio_alvo])
		_completar_passe_transition()
	, "Escolha um inimigo próximo pra travar (ou clique em qualquer lugar pra só passar)")


func _completar_passe_transition() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var alvo := _aliado_mais_distante()
	if not alvo:
		Eventos.mensagem_solicitada.emit("Não há aliados em campo pra receber o passe!")
		return

	var direcao := (alvo.global_position - bola.global_position).normalized()
	bola.receber_chute_teleguiado(direcao, forca_passe_transition)
	Eventos.mensagem_solicitada.emit("Transition Pass! Passe enviado pro aliado mais distante (%s) — pode ser interceptado." % alvo.name)


func _inimigo_mais_proximo_no_alcance() -> Botao:
	var mais_proximo: Botao = null
	var menor_distancia := alcance_alvo_bloqueio
	for nodo in get_tree().get_nodes_in_group("botoes"):
		var botao := nodo as Botao
		if not botao or botao.time == time:
			continue
		var distancia := global_position.distance_to(botao.global_position)
		if distancia <= menor_distancia:
			menor_distancia = distancia
			mais_proximo = botao
	return mais_proximo


func _aliado_mais_distante() -> Botao:
	var mais_distante: Botao = null
	var maior_distancia := -1.0
	for nodo in get_tree().get_nodes_in_group("botoes"):
		var botao := nodo as Botao
		if not botao or botao == self or botao.time != time:
			continue
		var distancia := global_position.distance_to(botao.global_position)
		if distancia > maior_distancia:
			maior_distancia = distancia
			mais_distante = botao
	return mais_distante


## --- Metavisão (concedida aos aliados) ---

func _executar_metavisao_concedida() -> void:
	var aliados_afetados := 0
	for nodo in get_tree().get_nodes_in_group("botoes"):
		var botao := nodo as Botao
		if botao and botao.time == time:
			botao.conceder_visao_estendida(duracao_metavisao_aliados)
			aliados_afetados += 1

	Eventos.mensagem_solicitada.emit("Metavisão! Todos os aliados enxergam a trajetória completa por %d turnos." % duracao_metavisao_aliados)
