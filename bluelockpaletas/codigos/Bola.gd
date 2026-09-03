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
	# Usado por habilidades tipo "TP guiado" (ex: Shark Assault do Kurona):
	# a bola aparece já "dominada" junto do alvo, com velocidade ZERO —
	# diferente de receber_chute_teleguiado(), que aplica um impulso físico
	# de verdade (por isso PODE ser interceptado no caminho). Aqui a bola
	# nunca "viaja" fisicamente de um ponto a outro, então não existe
	# chance de interceptação nenhuma — é um passe automático garantido.
	#
	# Reaproveita o mesmo esquema seguro de resetar() (aplicar a mudança
	# dentro de _integrate_forces) pelo mesmo motivo: mudar a posição
	# diretamente aqui poderia "piscar e voltar" por causa de contatos
	# físicos residuais do frame anterior.
	posicao_reset_pendente = posicao
	pedido_reset = true


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
