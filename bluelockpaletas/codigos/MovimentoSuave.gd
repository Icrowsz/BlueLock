class_name MovimentoSuave
extends RefCounted

## Utilitário "sem estado" pra mover qualquer RigidBody2D suavemente até
## um destino, sem aplicar força nele nem em quem estiver no caminho.
## Usado tanto pela bola (Shark Assault do Kurona) quanto por botões que
## se deslocam sozinhos (Stalker do Raichi) — mesma técnica dos dois
## casos, então centralizada aqui em vez de duplicada.
##
## "Congela" a física (freeze) durante o trajeto: evita que o motor de
## física brigue com a posição sendo animada quadro a quadro (mesmo
## problema de fundo do bug de reset que já foi corrigido antes com
## _integrate_forces), e evita empurrar qualquer coisa no caminho.
##
## IMPORTANTE: guardamos o tween ATIVO de cada corpo (por instance_id).
## Sem isso, chamar mover() de novo no MESMO corpo antes do trajeto
## anterior terminar cria um SEGUNDO tween — os dois brigam pela mesma
## global_position, e o "finished" do tween antigo chega a dar
## freeze = false NO MEIO do trajeto novo, quebrando o congelamento que
## a animação em andamento ainda precisa. Era exatamente isso que
## fazia o Stalker do Raichi "não grudar": cada chute do alvo disparava
## uma nova perseguição por cima da anterior, ainda em andamento.
static var _tweens_ativos: Dictionary = {}  # instance_id (int) -> Tween

static func mover(corpo: RigidBody2D, destino: Vector2, duracao: float = 0.4, ao_terminar: Callable = Callable()) -> void:
	var id := corpo.get_instance_id()

	# cancela qualquer trajeto anterior AINDA em andamento nesse mesmo
	# corpo, senão os dois tweens ficam escrevendo na mesma propriedade
	if _tweens_ativos.has(id):
		var tween_antigo: Tween = _tweens_ativos[id]
		if is_instance_valid(tween_antigo):
			tween_antigo.kill()  # kill() NÃO dispara "finished" — não desfaz o freeze à toa
		_tweens_ativos.erase(id)

	corpo.linear_velocity = Vector2.ZERO
	corpo.angular_velocity = 0.0
	corpo.freeze = true

	var tween := corpo.create_tween()
	_tweens_ativos[id] = tween
	tween.tween_property(corpo, "global_position", destino, duracao)
	tween.finished.connect(func() -> void:
		_tweens_ativos.erase(id)
		corpo.freeze = false
		corpo.linear_velocity = Vector2.ZERO
		corpo.angular_velocity = 0.0
		# necessário pra evitar um "salto" visual quando o projeto usa
		# Physics Interpolation: sem isso, o quadro renderizado pode
		# interpolar a partir da última posição física conhecida ANTES
		# do teleporte do tween, fazendo o corpo parecer "puxar de
		# volta" por um instante.
		corpo.reset_physics_interpolation()
		if ao_terminar.is_valid():
			ao_terminar.call()
	)


static func mover_zigzag(corpo: RigidBody2D, destino: Vector2, duracao: float = 0.6, zigues: int = 3, amplitude: float = 40.0, ao_terminar: Callable = Callable()) -> void:
	# mesma ideia do mover() acima (freeze + tween + kill do tween
	# anterior), só que em vez de um trajeto reto, monta uma sequência de
	# pontos alternando de lado perpendicular à linha reta — usado pelo
	# Alohomora do Alexis Ness (passe "garantido" em zigue-zague).
	var id := corpo.get_instance_id()

	if _tweens_ativos.has(id):
		var tween_antigo: Tween = _tweens_ativos[id]
		if is_instance_valid(tween_antigo):
			tween_antigo.kill()
		_tweens_ativos.erase(id)

	corpo.linear_velocity = Vector2.ZERO
	corpo.angular_velocity = 0.0
	corpo.freeze = true

	var origem := corpo.global_position
	var reta := destino - origem
	if reta.length() < 1.0:
		corpo.freeze = false
		if ao_terminar.is_valid():
			ao_terminar.call()
		return

	var direcao := reta.normalized()
	var perpendicular := Vector2(-direcao.y, direcao.x)
	var passos := maxi(zigues, 1) * 2  # cada "zigue" = ida pra um lado + volta pro centro da reta

	var pontos: Array[Vector2] = []
	for i in range(1, passos + 1):
		var t := float(i) / float(passos + 1)
		var lado := 1.0 if i % 2 == 1 else -1.0
		pontos.append(origem.lerp(destino, t) + perpendicular * amplitude * lado)
	pontos.append(destino)  # último trecho sempre termina exatamente no alvo

	var tween := corpo.create_tween()
	_tweens_ativos[id] = tween
	var duracao_por_trecho := duracao / float(pontos.size())
	for ponto in pontos:
		tween.tween_property(corpo, "global_position", ponto, duracao_por_trecho)

	tween.finished.connect(func() -> void:
		_tweens_ativos.erase(id)
		corpo.freeze = false
		corpo.linear_velocity = Vector2.ZERO
		corpo.angular_velocity = 0.0
		corpo.reset_physics_interpolation()
		if ao_terminar.is_valid():
			ao_terminar.call()
	)
