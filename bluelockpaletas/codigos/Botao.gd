extends RigidBody2D

## Script base do "botão" de futebol de botão.
## Cada personagem (Isagi, Bachira, etc.) cria uma cena herdada desta
## (Cena > Nova Cena Herdada > Botao.tscn) e adiciona suas próprias
## habilidades por cima deste comportamento.

@export var forca_maxima: float = 800.0              # limite de força do chute
@export var distancia_maxima_arrasto: float = 150.0  # até onde a "seta" pode esticar
@export var multiplicador_forca: float = 6.0          # converte pixels arrastados em força física
@export var raio_clique: float = 40.0                 # distância mínima do mouse pra "pegar" o botão

var arrastando: bool = false
var ponto_inicial: Vector2 = Vector2.ZERO

@onready var linha_mira: Line2D = $LinhaMira


func _ready() -> void:
	gravity_scale = 0      # jogo top-down, sem queda
	linear_damp = 1.5       # simula o atrito indo devagar até parar
	angular_damp = 2.0
	if linha_mira:
		linha_mira.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _mouse_sobre_o_botao(event.position):
			arrastando = true
			ponto_inicial = event.position
			if linha_mira:
				linha_mira.visible = true
		elif not event.pressed and arrastando:
			_soltar_e_chutar(event.position)

	elif event is InputEventMouseMotion and arrastando:
		_atualizar_mira(event.position)


func _mouse_sobre_o_botao(pos_mouse: Vector2) -> bool:
	# Checagem simples por distância. Se preferir, troque por uma Area2D
	# com um sinal input_event, que é mais preciso.
	return global_position.distance_to(pos_mouse) < raio_clique


func _atualizar_mira(pos_atual: Vector2) -> void:
	if not linha_mira:
		return
	# a seta aponta para trás de onde o mouse está (estilo estilingue)
	var vetor := (ponto_inicial - pos_atual).limit_length(distancia_maxima_arrasto)
	linha_mira.points = [Vector2.ZERO, vetor]


func _soltar_e_chutar(pos_solta: Vector2) -> void:
	arrastando = false
	if linha_mira:
		linha_mira.visible = false

	var vetor_arrasto := (ponto_inicial - pos_solta).limit_length(distancia_maxima_arrasto)
	var forca := (vetor_arrasto * multiplicador_forca).limit_length(forca_maxima)

	apply_central_impulse(forca)


func pode_chutar_bola() -> bool:
	# Função "gancho" pensada pra ser sobrescrita ou usada pelos personagens
	# na hora de detectar colisão com a bola e decidir a força do chute.
	return not arrastando
