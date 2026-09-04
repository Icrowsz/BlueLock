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


func _physics_process(delta: float) -> void:
	# evita que a bola saia "voando" rápido demais depois de vários choques seguidos
	if linear_velocity.length() > velocidade_maxima:
		linear_velocity = linear_velocity.limit_length(velocidade_maxima)

	_atualizar_curva(delta)


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


func ativar_intangivel_para_botoes(duracao: float = 1.0) -> void:
	# Usado por chutes "garantidos" (ex: Bee Shot do Bachira): durante
	# "duracao" segundos, a bola ignora colisão com TODOS os botões (dos
	# dois times) — ninguém consegue interceptar. Mesma técnica de
	# exceção de colisão temporária do chute curvo do Rin, mas aplicada
	# a todo mundo em vez de só um time.
	var botoes_ignorados: Array[Botao] = []
	for nodo in get_tree().get_nodes_in_group("botoes"):
		var botao := nodo as Botao
		if botao:
			add_collision_exception_with(botao)
			botoes_ignorados.append(botao)

	var temporizador := get_tree().create_timer(duracao)
	temporizador.timeout.connect(func() -> void:
		for botao in botoes_ignorados:
			if is_instance_valid(botao):
				remove_collision_exception_with(botao)
	)


## --- Chute curvo (ex: Curve Shot do Rin) ---
##
## A curva é uma Bézier quadrática (origem -> ponto de controle lateral
## -> alvo), calculada UMA VEZ no momento do chute. A cada frame, a bola
## segue a TANGENTE exata dessa curva no instante "t" — diferente de uma
## abordagem por "steering" (corrigir direção a cada frame perseguindo
## um ponto), que gera oscilação/zigue-zague quando bate de frente com a
## inércia da física. Seguir a tangente calculada é matematicamente
## estável: não há erro acumulado pra corrigir.

var _curva_ativa: bool = false
var _curva_p0: Vector2 = Vector2.ZERO  # origem
var _curva_p1: Vector2 = Vector2.ZERO  # ponto de controle (define o quanto/pra que lado curva)
var _curva_p2: Vector2 = Vector2.ZERO  # alvo final
var _curva_velocidade: float = 0.0
var _curva_tempo: float = 0.0
var _curva_duracao: float = 1.0
var _curva_parar_ao_chegar: bool = false  # true = "cruzamento" (freia ao chegar no alvo); false = "chute" (continua com a velocidade da curva, ex: pra dentro do gol)


func receber_chute_curvo(alvo: Vector2, forca: float, time_do_chutador: String, intensidade_curva: float = 90.0, duracao_curva: float = 1.1, parar_ao_chegar: bool = false) -> void:
	# Chute teleguiado (mesma base do Chute Direto), mas com duas
	# diferenças: (1) a trajetória é um arco que termina exatamente em
	# "alvo" (ex: o PontoMira do gol, ou um ponto qualquer do campo);
	# (2) ignora colisão com QUALQUER botão do mesmo time de quem
	# chutou — só oponentes interceptam.
	#
	# "parar_ao_chegar": chutes de gol (Curve Shot) devem MANTER a
	# velocidade ao terminar a curva, pra continuar entrando no gol.
	# Passes/cruzamentos pra um ponto qualquer do campo (Rabona Cross)
	# devem FREAR ao chegar, senão a bola "escorregaria" pra além do
	# ponto escolhido, contrariando a ideia de "a bola cai ali".
	var aliados_ignorados: Array[Botao] = []
	for nodo in get_tree().get_nodes_in_group("botoes"):
		var botao := nodo as Botao
		if botao and botao.time == time_do_chutador:
			add_collision_exception_with(botao)
			aliados_ignorados.append(botao)

	var origem := global_position
	var direcao_reta := (alvo - origem).normalized()
	var perpendicular := Vector2(-direcao_reta.y, direcao_reta.x)
	var lado := 1.0 if randf() < 0.5 else -1.0

	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

	# intensidade quase zero = nem ativa o sistema de curva, evita
	# qualquer processamento/oscilação à toa num chute que devia sair reto
	_curva_ativa = intensidade_curva > 1.0
	_curva_p0 = origem
	_curva_p2 = alvo
	_curva_p1 = origem.lerp(alvo, 0.5) + perpendicular * intensidade_curva * lado
	_curva_velocidade = forca / mass
	_curva_tempo = 0.0
	_curva_duracao = duracao_curva
	_curva_parar_ao_chegar = parar_ao_chegar

	if _curva_ativa:
		# já sai na direção da tangente da curva em t=0 (não na linha
		# reta) — assim o chute nasce curvando, em vez de "corrigir"
		# depois de já ter saído reto
		var tangente_inicial := (_curva_p1 - _curva_p0).normalized()
		apply_central_impulse(tangente_inicial * forca)
	else:
		apply_central_impulse(direcao_reta * forca)
		if parar_ao_chegar:
			# sem curva ativa, não existe _atualizar_curva() rodando pra
			# frear no fim — freia com um temporizador simples, baseado
			# no mesmo "duracao_curva" usado como referência de tempo
			var temporizador_parada := get_tree().create_timer(duracao_curva)
			temporizador_parada.timeout.connect(func() -> void:
				linear_velocity = Vector2.ZERO
			)

	var temporizador := get_tree().create_timer(duracao_curva)
	temporizador.timeout.connect(func() -> void:
		_curva_ativa = false
		for botao in aliados_ignorados:
			if is_instance_valid(botao):
				remove_collision_exception_with(botao)
	)


func _atualizar_curva(delta: float) -> void:
	if not _curva_ativa:
		return

	_curva_tempo += delta
	var t := clampf(_curva_tempo / _curva_duracao, 0.0, 1.0)

	# derivada da Bézier quadrática em t: a tangente exata da curva
	# nesse instante — é pra ONDE a bola deve estar indo agora
	var tangente := 2.0 * (1.0 - t) * (_curva_p1 - _curva_p0) + 2.0 * t * (_curva_p2 - _curva_p1)
	if tangente.length() > 0.01:
		linear_velocity = tangente.normalized() * _curva_velocidade

	if t >= 1.0:
		_curva_ativa = false
		if _curva_parar_ao_chegar:
			linear_velocity = Vector2.ZERO
