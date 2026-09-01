extends RigidBody2D

## Script base do "botão" de futebol de botão.
## Cada personagem (Isagi, Bachira, etc.) cria uma cena herdada desta
## (Cena > Nova Cena Herdada > Botao.tscn) e adiciona suas próprias
## habilidades por cima deste comportamento.

@export var forca_maxima: float = 800.0
@export var distancia_maxima_arrasto: float = 150.0
@export var multiplicador_forca: float = 6.0
@export var raio_clique: float = 40.0

var arrastando: bool = false
var ponto_inicial: Vector2 = Vector2.ZERO

var posicao_inicial: Vector2
var rotacao_inicial: float

@onready var linha_mira: Line2D = $LinhaMira


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


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pos_mouse := get_global_mouse_position()
		if event.pressed and _mouse_sobre_o_botao(pos_mouse):
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


func _mouse_sobre_o_botao(pos_mouse_global: Vector2) -> bool:
	return global_position.distance_to(pos_mouse_global) < raio_clique


func _atualizar_mira(pos_atual_global: Vector2) -> void:
	if not linha_mira:
		return
	# como a LinhaMira agora é "top_level", precisamos manter ela
	# ancorada manualmente na posição do botão
	linha_mira.global_position = global_position
	var vetor := (ponto_inicial - pos_atual_global).limit_length(distancia_maxima_arrasto)
	linha_mira.points = [Vector2.ZERO, vetor]


func _soltar_e_chutar(pos_solta_global: Vector2) -> void:
	arrastando = false
	if linha_mira:
		linha_mira.visible = false

	var vetor_arrasto := (ponto_inicial - pos_solta_global).limit_length(distancia_maxima_arrasto)
	var forca := (vetor_arrasto * multiplicador_forca).limit_length(forca_maxima)

	apply_central_impulse(forca)


func pode_chutar_bola() -> bool:
	return not arrastando


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
