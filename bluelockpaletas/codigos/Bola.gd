extends RigidBody2D

## Script da bola. A física de "receber o chute" já acontece automaticamente
## pela engine (colisão RigidBody2D x RigidBody2D transfere momento),
## aqui só ajustamos as propriedades pra ficar com "sensação" de bola de verdade.

@export var velocidade_maxima: float = 900.0

@onready var material_fisico := PhysicsMaterial.new()


func _ready() -> void:
	add_to_group("bola")     # usado pelo Gol.gd para reconhecer a bola

	gravity_scale = 0
	mass = 0.3               # bem mais leve que o botão, pra "voar" longe com pouca força
	linear_damp = 0.8        # perde velocidade aos poucos (atrito com o gramado)
	angular_damp = 1.0

	material_fisico.bounce = 0.6     # quica nas bordas do campo
	material_fisico.friction = 0.3
	physics_material_override = material_fisico


func _physics_process(_delta: float) -> void:
	# evita que a bola saia "voando" rápido demais depois de vários choques seguidos
	if linear_velocity.length() > velocidade_maxima:
		linear_velocity = linear_velocity.limit_length(velocidade_maxima)


var pedido_reset: bool = false
var posicao_reset_pendente: Vector2 = Vector2.ZERO


func resetar(posicao_inicial: Vector2) -> void:
	# NÃO mudamos a posição aqui diretamente. Só marcamos o pedido.
	# A mudança de verdade acontece em _integrate_forces(), que é o
	# único lugar onde a física garante que a mudança "gruda" sem ser
	# sobrescrita por contatos/colisões residuais do frame anterior
	# (causa real do bug "pisca e volta pro lugar errado").
	posicao_reset_pendente = posicao_inicial
	pedido_reset = true


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if pedido_reset:
		state.transform = Transform2D(0.0, posicao_reset_pendente)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		pedido_reset = false


func receber_dominio_instantaneo(posicao: Vector2) -> void:
	# Usado pelos passes AUTOMÁTICOS do Kurona (One Two e Shark Assault):
	# a bola aparece já dominada junto do alvo, com velocidade ZERO —
	# diferente de receber_chute_teleguiado(), que aplica um impulso
	# físico de verdade (por isso PODE ser interceptado no caminho).
	# Aqui a bola nunca "viaja" fisicamente, então é 100% garantido.
	#
	# CUIDADO COM A FÍSICA: só zerar posição/velocidade não é suficiente
	# — se o ponto de chegada encostar no corpo físico de alguém (ex: o
	# próprio alvo), o solver de colisão do Godot vai "empurrar" os dois
	# pra se separar NO MESMO frame, e a bola sairia voando de novo,
	# quebrando a ideia de "chegou parada, já dominada". Pra evitar isso
	# de vez (mesmo se o ponto calculado ficar meio apertado), desligamos
	# a colisão física da bola por 2 frames ao redor do teleporte —
	# tempo suficiente pro motor assentar a nova posição sem gerar
	# nenhum impulso de separação.
	var camada_original := collision_layer
	var mascara_original := collision_mask
	collision_layer = 0
	collision_mask = 0

	posicao_reset_pendente = posicao
	pedido_reset = true

	await get_tree().physics_frame
	await get_tree().physics_frame

	collision_layer = camada_original
	collision_mask = mascara_original


func receber_chute_teleguiado(direcao: Vector2, forca: float) -> void:
	# Usado por habilidades especiais (ex: Chute Direto do Isagi) que
	# precisam de um chute preciso numa direção exata, ignorando pra
	# onde a bola estava indo antes.
	#
	# Isso é seguro de chamar diretamente (sem o esquema de _integrate_forces
	# do resetar()) porque é chamado a partir de um clique de UI, fora do
	# passo de física — igual ao chute normal por arrasto do Botao.gd.
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	apply_central_impulse(direcao.normalized() * forca)
