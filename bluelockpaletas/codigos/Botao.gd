class_name Botao
extends RigidBody2D

## Script base do "botão" de futebol de botão.
## Cada personagem (Isagi, Bachira, etc.) cria uma cena herdada desta
## (Cena > Nova Cena Herdada > Botao.tscn), troca o script pra um que
## "extends Botao" (ex: Isagi.gd), e sobrescreve nome_habilidade(),
## pode_usar_habilidade() e usar_habilidade().

@export var forca_maxima: float = 800.0
@export var distancia_maxima_arrasto: float = 150.0
@export var multiplicador_forca: float = 6.0
@export var raio_clique: float = 40.0
@export_enum("A", "B") var time: String = "A"

@export_group("Aura do time")
@export var raio_aura: float = 46.0
@export var largura_aura: float = 4.0

@export_group("Mira")
@export var cor_mira_padrao: Color = Color(1, 1, 1)

var arrastando: bool = false
var ponto_inicial: Vector2 = Vector2.ZERO

var posicao_inicial: Vector2
var rotacao_inicial: float

var bola_no_alcance: RigidBody2D = null

## Cooldowns de habilidade: chave = nome_habilidade(), valor = turnos restantes.
## Um dicionário (não uma variável fixa) porque cada habilidade pode ter
## seu próprio tempo de recarga, e personagens futuros terão nomes
## diferentes — isso funciona sem precisar de nenhum caso especial.
var cooldowns: Dictionary = {}

@onready var linha_mira: Line2D = $LinhaMira
@onready var area_alcance: Area2D = $AreaAlcance


func _ready() -> void:
	add_to_group("botoes")   # usado pelo Placar pra resetar todos de uma vez

	# guarda a posição/rotação "de origem" pra poder devolver o botão
	# aqui depois de um gol
	posicao_inicial = global_position
	rotacao_inicial = rotation

	gravity_scale = 0
	linear_damp = 1.5
	angular_damp = 2.0

	if linha_mira:
		linha_mira.visible = false
		# CORREÇÃO DO BUG: faz a seta ignorar a rotação/escala do botão.
		# Sem isso, quando o botão gira (após uma colisão), a seta gira
		# junto e para de apontar corretamente em relação ao mouse.
		linha_mira.top_level = true

	if area_alcance:
		area_alcance.body_entered.connect(_on_bola_entrou_alcance)
		area_alcance.body_exited.connect(_on_bola_saiu_alcance)

	Turnos.turno_iniciado.connect(_on_turno_mudou)

	queue_redraw()  # garante que a aura do time seja desenhada logo de cara


func _draw() -> void:
	# desenha um anel colorido ao redor do botão indicando o time.
	# 100% visual: _draw() não participa de física nem colisão nenhuma.
	draw_arc(Vector2.ZERO, raio_aura, 0.0, TAU, 64, Times.cor_do_time(time), largura_aura, true)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pos_mouse := get_global_mouse_position()
		if event.pressed and _mouse_no_corpo(pos_mouse):
			# clicar SEMPRE seleciona o personagem pra UI mostrar as
			# habilidades dele — independe de ser a vez do time ou não,
			# assim dá pra "inspecionar" qualquer botão em campo
			Eventos.botao_selecionado.emit(self)

			if _pode_arrastar():
				arrastando = true
				ponto_inicial = pos_mouse
				if linha_mira:
					linha_mira.visible = true
		elif not event.pressed and arrastando:
			_soltar_e_chutar(pos_mouse)

	elif event is InputEventMouseMotion and arrastando:
		# CORREÇÃO DO BUG: usar get_global_mouse_position() em vez de
		# event.position, que é coordenada de TELA e não do MUNDO do jogo.
		_atualizar_mira(get_global_mouse_position())


func _mouse_no_corpo(pos_mouse_global: Vector2) -> bool:
	return global_position.distance_to(pos_mouse_global) < raio_clique


func _pode_arrastar() -> bool:
	return pode_agir() and Turnos.tem_acao_disponivel("movimento")


func _atualizar_mira(pos_atual_global: Vector2) -> void:
	if not linha_mira:
		return
	# como a LinhaMira agora é "top_level", precisamos manter ela
	# ancorada manualmente na posição do botão
	linha_mira.global_position = global_position
	var vetor := (ponto_inicial - pos_atual_global).limit_length(distancia_maxima_arrasto)
	_desenhar_mira(vetor)


func _desenhar_mira(vetor: Vector2) -> void:
	# desenho PADRÃO da mira: uma linha simples indicando a direção do
	# chute. Personagens com habilidades de mira estendida (ex: a
	# Metavisão do Isagi) sobrescrevem isso pra desenhar uma trajetória
	# mais completa, com ricochetes.
	linha_mira.default_color = cor_mira_padrao
	linha_mira.points = [Vector2.ZERO, vetor]


func _soltar_e_chutar(pos_solta_global: Vector2) -> void:
	arrastando = false
	if linha_mira:
		linha_mira.visible = false

	var vetor_arrasto := (ponto_inicial - pos_solta_global).limit_length(distancia_maxima_arrasto)

	# um arrasto muito curto (ex: clique acidental sem soltar longe) não
	# conta como jogada de verdade, então não gasta a ação do turno
	const ARRASTO_MINIMO := 5.0
	if vetor_arrasto.length() < ARRASTO_MINIMO:
		_apos_chute(false)
		return

	var forca := (vetor_arrasto * multiplicador_forca).limit_length(forca_maxima)
	apply_central_impulse(forca)

	Turnos.usar_acao("movimento")
	_apos_chute(true)


func _apos_chute(_sucesso: bool) -> void:
	# gancho pra personagens reagirem depois de um chute (com sucesso ou
	# não) — ex: a Metavisão do Isagi só dura até o PRÓXIMO chute de
	# verdade, então ele desliga o efeito aqui quando sucesso == true.
	pass


func pode_chutar_bola() -> bool:
	return not arrastando


func pode_agir() -> bool:
	# usado tanto pro movimento quanto como base pra habilidades:
	# só pode agir se for a vez do TIME desse botão
	return Turnos.eh_turno_do_time(time)


func _on_bola_entrou_alcance(body: Node) -> void:
	if not body.is_in_group("bola"):
		return
	bola_no_alcance = body


func _on_bola_saiu_alcance(body: Node) -> void:
	if not body.is_in_group("bola") or bola_no_alcance != body:
		return
	bola_no_alcance = null


func gol_inimigo_lado() -> String:
	return Times.gol_inimigo_do_time(time)


## --- Sistema de habilidades: cada personagem pode ter VÁRIAS ---
## O botão base não tem nenhuma. Personagens sobrescrevem os métodos
## abaixo — a maioria já tem um comportamento padrão sensato, então só
## precisa sobrescrever o que for diferente.

func lista_habilidades() -> Array[String]:
	# nomes das habilidades desse personagem, na ordem que devem
	# aparecer na UI. Botão base: nenhuma.
	return []


func habilidade_consome_acao(_nome: String) -> bool:
	# a maioria das habilidades consome a ação de "habilidade" do turno.
	# Personagens sobrescrevem caso a caso pra exceções (ex: a Metavisão
	# do Isagi não consome nada, só entra em cooldown).
	return true


func requisito_extra_habilidade(_nome: String) -> String:
	# gancho pra requisitos específicos de cada habilidade (ex: "precisa
	# da bola por perto"). Retorna "" se não há requisito extra, ou a
	# mensagem de bloqueio pronta pra mostrar ao jogador.
	return ""


func pode_usar_habilidade(nome: String) -> bool:
	if nome not in lista_habilidades():
		return false
	if not pode_agir():
		return false
	if esta_em_cooldown(nome):
		return false
	if habilidade_consome_acao(nome) and not Turnos.tem_acao_disponivel("habilidade"):
		return false
	if requisito_extra_habilidade(nome) != "":
		return false
	return true


func motivo_bloqueio_habilidade(nome: String) -> String:
	# retorna uma string vazia se a habilidade PODE ser usada agora;
	# senão, o motivo específico do bloqueio, pronto pra mostrar ao
	# jogador. Centralizado aqui pra qualquer UI reaproveitar sem
	# duplicar a ordem de prioridade das checagens.
	if nome not in lista_habilidades():
		return "Esse personagem não tem essa habilidade."

	if not pode_agir():
		return "Não é a vez do Time %s!" % time

	if esta_em_cooldown(nome):
		return "%s em cooldown! Aguarde mais %d turno(s)." % [nome, turnos_restantes_cooldown(nome)]

	if habilidade_consome_acao(nome) and not Turnos.tem_acao_disponivel("habilidade"):
		return "Sem ações de habilidade restantes neste turno!"

	var extra := requisito_extra_habilidade(nome)
	if extra != "":
		return extra

	return ""


func usar_habilidade(_nome: String) -> void:
	pass  # cada personagem decide o que cada habilidade faz


func esta_em_cooldown(habilidade: String) -> bool:
	return cooldowns.get(habilidade, 0) > 0


func turnos_restantes_cooldown(habilidade: String) -> int:
	return cooldowns.get(habilidade, 0)


func iniciar_cooldown(habilidade: String, turnos: int) -> void:
	cooldowns[habilidade] = turnos


func _on_turno_mudou(_time: String) -> void:
	for chave in cooldowns.keys():
		if cooldowns[chave] > 0:
			cooldowns[chave] -= 1


var pedido_reset: bool = false


func resetar() -> void:
	# NÃO mudamos a posição aqui diretamente — só marcamos o pedido.
	# Ver explicação completa em Bola.gd sobre por que isso precisa
	# acontecer dentro de _integrate_forces().
	pedido_reset = true


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if pedido_reset:
		state.transform = Transform2D(rotacao_inicial, posicao_inicial)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		pedido_reset = false
