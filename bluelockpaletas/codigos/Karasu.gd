extends Botao
class_name Karasu

## Karasu
##
## - Raven Relay: passe AUTOMÁTICO e garantido pro aliado escolhido,
##   DENTRO DO ALCANCE MÁXIMO — mesma técnica do Shark Assault do Kurona
##   (MovimentoSuave, sem física real, sem chance de interceptação: ele
##   SEMPRE chega no alvo). Ao chegar, o alvo GANHA a habilidade New
##   Goal Method: um chute médio de força fixa (200) que ignora colisão
##   com os PRÓPRIOS aliados (reaproveita receber_chute_curvo com
##   intensidade de curva 0 — vira uma linha reta, mas mantém o "ignora
##   aliados" que só esse método tem), mirando automaticamente no gol
##   inimigo. Cooldown de 7 turnos.
##
## - Wing Arm Block: escolhe DOIS inimigos dentro do alcance (uma
##   distância simples, não o AreaAlcance — que é só pra bola) e os
##   puxa pra perto de si (MovimentoSuave.mover) enquanto trava as
##   habilidades dos dois (aplicar_bloqueio_habilidade, a mesma base do
##   Snake Hunt do Aiku) por 4 turnos. Diferente de um bloqueio comum,
##   esse também acaba ANTES do prazo se o Karasu se afastar demais de
##   um dos presos — checado a cada frame de física em
##   _physics_process(), não só na troca de turno, já que "sair do
##   alcance" é uma condição espacial, não temporal. Cooldown de 6
##   turnos.

@export_group("Raven Relay")
@export var duracao_raven_relay: float = 0.6
@export var alcance_maximo_raven_relay: float = 600.0  ## distância MÁXIMA até o aliado escolhido
@export var cooldown_raven_relay: int = 7

@export_group("New Goal Method (concedida)")
@export var forca_new_goal_method: float = 240.0  ## "chute médio", valor fixo
@export var duracao_new_goal_method: float = 1.0
@export var turnos_para_expirar_new_goal_method: int = 3  ## se quem recebeu não usar a tempo, a concessão expira sozinha
@export var new_goal_method_consome_acao: bool = true

@export_group("Wing Arm Block")
@export var alcance_wing_arm_block: float = 200.0  ## distância simples (não o AreaAlcance) pra escolher os inimigos E pra saber se Karasu "saiu do alcance" depois
@export var distancia_puxao_final: float = 65.0  ## a que distância de Karasu cada inimigo puxado para, pra não empilhar os dois em cima dele
@export var duracao_puxao_wing_arm: float = 0.4
@export var duracao_bloqueio_wing_arm: int = 4
@export var cooldown_wing_arm_block: int = 6

const NOME_RAVEN_RELAY := "Raven Relay"
const NOME_NEW_GOAL_METHOD := "New Goal Method"
const NOME_WING_ARM_BLOCK := "Wing Arm Block"

## Inimigos atualmente presos pelo Wing Arm Block — verificados a cada
## frame de física pra soltar cedo se o Karasu sair do alcance deles.
var _inimigos_presos_wing_arm: Array[Botao] = []


func habilidades_proprias() -> Array[String]:
	return [NOME_RAVEN_RELAY, NOME_WING_ARM_BLOCK]


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_RAVEN_RELAY:
		if bola_no_alcance == null:
			return "A bola precisa estar por perto para usar %s!" % NOME_RAVEN_RELAY
		if _aliados_no_alcance_raven_relay().is_empty():
			return "Nenhum aliado dentro do alcance do Raven Relay!"
	if nome == NOME_WING_ARM_BLOCK and _inimigos_no_alcance().size() < 2:
		return "Precisa de pelo menos 2 inimigos no alcance para usar %s!" % NOME_WING_ARM_BLOCK
	return ""


func _habilidade_propria_consome_acao(nome: String) -> bool:
	if nome == NOME_RAVEN_RELAY:
		# consumida manualmente em _tentar_passe_raven_relay(), só quando
		# o passe de fato sai — escolher um alvo inválido ou fora de
		# alcance não desperdiça a ação nem o cooldown
		return false
	return true


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_RAVEN_RELAY:
			_executar_raven_relay()
			iniciar_cooldown(nome, cooldown_raven_relay)
		NOME_WING_ARM_BLOCK:
			_executar_wing_arm_block()
			iniciar_cooldown(nome, cooldown_wing_arm_block)


## --- Raven Relay ---

func _aliados_no_alcance_raven_relay() -> Array[Botao]:
	var lista: Array[Botao] = []
	for nodo in get_tree().get_nodes_in_group("botoes"):
		var botao := nodo as Botao
		if botao and botao != self and botao.time == time and global_position.distance_to(botao.global_position) <= alcance_maximo_raven_relay:
			lista.append(botao)
	return lista


func _executar_raven_relay() -> void:
	SelecaoAlvo.pedir_alvo(self, func(alvo: Botao) -> void:
		_tentar_passe_raven_relay(alvo)
	, "Escolha o aliado alvo do Raven Relay")


func _tentar_passe_raven_relay(alvo: Botao) -> void:
	if alvo == self or alvo.time != time:
		Eventos.mensagem_solicitada.emit("Escolha um companheiro de time como alvo!")
		return

	if global_position.distance_to(alvo.global_position) > alcance_maximo_raven_relay:
		Eventos.mensagem_solicitada.emit("Esse aliado está fora do alcance do Raven Relay!")
		return

	var bola := bola_no_alcance
	if not bola:
		Eventos.mensagem_solicitada.emit("A bola não está mais por perto — Raven Relay cancelado.")
		return

	consumir_acao_habilidade()
	iniciar_cooldown(NOME_RAVEN_RELAY, cooldown_raven_relay)

	# passe AUTOMÁTICO e garantido (mesma técnica do Shark Assault do
	# Kurona) — sem física real, então SEMPRE chega; por isso podemos
	# conceder o New Goal Method direto no "ao_terminar" do movimento,
	# sem precisar de temporizador/espera por interceptação como antes
	MovimentoSuave.mover(bola, alvo.global_position, duracao_raven_relay, func() -> void:
		_conceder_new_goal_method(alvo)
	)

	Eventos.mensagem_solicitada.emit("Raven Relay! Passe automático enviado pra %s." % alvo.name)


func _conceder_new_goal_method(alvo: Botao) -> void:
	if not is_instance_valid(alvo):
		return

	alvo.conceder_habilidade(NOME_NEW_GOAL_METHOD, func() -> void:
		_executar_new_goal_method(alvo)
	, new_goal_method_consome_acao, turnos_para_expirar_new_goal_method)

	Eventos.mensagem_solicitada.emit("Raven Relay chegou! %s ganhou o New Goal Method." % alvo.name)


func _executar_new_goal_method(quem_recebeu: Botao) -> void:
	var bola := quem_recebeu.bola_no_alcance
	if not bola:
		Eventos.mensagem_solicitada.emit("New Goal Method! A bola não estava mais por perto de %s." % quem_recebeu.name)
		return

	var gol := quem_recebeu.encontrar_gol_inimigo()
	if not gol:
		return

	# intensidade_curva = 0.0 -> vira uma linha reta (sem custo de
	# processamento de curva), mas MANTÉM o "ignora colisão com
	# aliados" do receber_chute_curvo, que é exatamente o pedido —
	# parar_ao_chegar = false pra continuar entrando no gol, igual a
	# qualquer chute de verdade
	bola.receber_chute_curvo(gol.ponto_para_mira(), forca_new_goal_method, quem_recebeu.time, 0.0, duracao_new_goal_method, false)
	Eventos.mensagem_solicitada.emit("New Goal Method! %s arrisca o chute, ignorando os próprios aliados no caminho." % quem_recebeu.name)


## --- Wing Arm Block ---

func _executar_wing_arm_block() -> void:
	SelecaoAlvo.pedir_alvo(self, func(primeiro: Botao) -> void:
		_pedir_segundo_alvo_wing_arm(primeiro)
	, "Escolha o PRIMEIRO inimigo do Wing Arm Block")


func _pedir_segundo_alvo_wing_arm(primeiro: Botao) -> void:
	if not _eh_inimigo_valido_wing_arm(primeiro):
		return

	SelecaoAlvo.pedir_alvo(self, func(segundo: Botao) -> void:
		_confirmar_wing_arm_block(primeiro, segundo)
	, "Escolha o SEGUNDO inimigo do Wing Arm Block")


func _confirmar_wing_arm_block(primeiro: Botao, segundo: Botao) -> void:
	if segundo == primeiro:
		Eventos.mensagem_solicitada.emit("Escolha dois inimigos DIFERENTES pro Wing Arm Block!")
		return
	if not _eh_inimigo_valido_wing_arm(segundo):
		return

	_puxar_e_prender(primeiro)
	_puxar_e_prender(segundo)

	Eventos.mensagem_solicitada.emit("Wing Arm Block! %s e %s foram puxados e ficaram sem habilidades por %d turnos." % [primeiro.name, segundo.name, duracao_bloqueio_wing_arm])


func _eh_inimigo_valido_wing_arm(alvo: Botao) -> bool:
	if alvo == self or alvo.time == time:
		Eventos.mensagem_solicitada.emit("Escolha um INIMIGO pro Wing Arm Block, não um aliado!")
		return false
	if global_position.distance_to(alvo.global_position) > alcance_wing_arm_block:
		Eventos.mensagem_solicitada.emit("Esse alvo está fora do alcance do Wing Arm Block!")
		return false
	return true


func _puxar_e_prender(inimigo: Botao) -> void:
	inimigo.aplicar_bloqueio_habilidade(duracao_bloqueio_wing_arm)

	if inimigo not in _inimigos_presos_wing_arm:
		_inimigos_presos_wing_arm.append(inimigo)

	# puxa o inimigo pra perto de Karasu, mas parando um pouco antes do
	# centro (distancia_puxao_final) — assim, com os DOIS puxões, eles
	# não ficam empilhados exatamente em cima um do outro
	var direcao := inimigo.global_position - global_position
	direcao = direcao.normalized() if direcao.length() > 1.0 else Vector2.RIGHT
	var destino := global_position + direcao * distancia_puxao_final

	MovimentoSuave.mover(inimigo, destino, duracao_puxao_wing_arm)


func _inimigos_no_alcance() -> Array[Botao]:
	var lista: Array[Botao] = []
	for nodo in get_tree().get_nodes_in_group("botoes"):
		var botao := nodo as Botao
		if botao and botao.time != time and global_position.distance_to(botao.global_position) <= alcance_wing_arm_block:
			lista.append(botao)
	return lista


func _physics_process(_delta: float) -> void:
	# checagem espacial de "saiu do alcance" — TEM que ser por frame
	# (não só na troca de turno), porque é uma condição de posição, não
	# de tempo. Roda mesmo fora do turno do Karasu, porque o inimigo
	# preso pode se mover no turno DELE e escapar por conta própria.
	if _inimigos_presos_wing_arm.is_empty():
		return

	for i in range(_inimigos_presos_wing_arm.size() - 1, -1, -1):
		var inimigo := _inimigos_presos_wing_arm[i]

		if not is_instance_valid(inimigo):
			_inimigos_presos_wing_arm.remove_at(i)
			continue

		if global_position.distance_to(inimigo.global_position) > alcance_wing_arm_block:
			_inimigos_presos_wing_arm.remove_at(i)
			# ATENÇÃO: zera o bloqueio de habilidade geral do alvo — se
			# outra habilidade também estiver usando
			# bloqueado_de_usar_habilidade_turnos_restantes ao mesmo
			# tempo nesse mesmo inimigo, ela seria liberada cedo demais
			# também (mesma ressalva que já existe pra
			# multiplicador_forca_externo em Botao.gd)
			inimigo.bloqueado_de_usar_habilidade_turnos_restantes = 0
			Eventos.mensagem_solicitada.emit("%s escapou do alcance do Wing Arm Block — habilidades liberadas." % inimigo.name)
