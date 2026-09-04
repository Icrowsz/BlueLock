extends RigidBody2D

## Script da bola. A física de "receber o chute" já acontece automaticamente
## pela engine (colisão RigidBody2D x RigidBody2D transfere momento),
## aqui só ajustamos as propriedades pra ficar com "sensação" de bola de verdade.

@export var velocidade_maxima: float = 900.0

## Camada de física dos "Botao" (jogadores) — usada pelo Bee Shot do
## Bachira pra ignorar SÓ a colisão com eles durante o voo, sem afetar
## a colisão com paredes/gol. Ajuste no Inspector se seus botões
## estiverem em outra camada.
@export_flags_2d_physics var camada_botoes: int = 1

var _mascara_original_botoes: int = -1  # -1 = não está intangível agora

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


func mover_para_com_trajetoria(destino: Vector2, duracao: float = 0.4) -> void:
	# Usado por passes "automáticos" (ex: Shark Assault do Kurona): a
	# bola viaja suavemente até o destino, mas chega SEM FORÇA (não
	# empurra quem estiver lá, como se tivesse sido dominada).
	MovimentoSuave.mover(self, destino, duracao)


func ativar_intangivel_para_botoes(duracao: float) -> void:
	# Usado pelo Bee Shot do Bachira: durante o voo, a bola atravessa os
	# botões como se eles não estivessem lá (sem transferir momento, sem
	# ser desviada) — só volta a poder ser interceptada depois de
	# "duracao" segundos. Colisão com paredes/gol continua normal, já
	# que só mexemos na camada dos BOTÕES especificamente.
	if _mascara_original_botoes == -1:
		_mascara_original_botoes = collision_mask
	collision_mask = collision_mask & ~camada_botoes

	var temporizador := get_tree().create_timer(duracao)
	temporizador.timeout.connect(_restaurar_colisao_com_botoes)


func _restaurar_colisao_com_botoes() -> void:
	if _mascara_original_botoes == -1:
		return  # já foi restaurado por um timer anterior (ex: dois Bee Shots seguidos)
	collision_mask = _mascara_original_botoes
	_mascara_original_botoes = -1
