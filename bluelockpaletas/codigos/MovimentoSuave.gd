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
