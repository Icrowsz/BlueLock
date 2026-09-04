extends Botao
class_name Raichi

## Jingo Raichi
##
## - Stalker: escolhe um inimigo como alvo; Raichi se desloca até perto
##   dele imediatamente. Pelos próximos "stalker_duracao" turnos, a
##   força e o alcance dos chutes dele ficam reduzidos (fica lento), mas
##   ele "acompanha" o alvo — toda vez que o alvo completa um chute de
##   verdade, o Raichi se reposiciona perto dele de novo. O cooldown (3
##   turnos, por padrão) só começa a contar quando a habilidade
##   TERMINA, não quando é ativada.
##
## - Bet: cria uma área em forma de meio-círculo (180°) apontando pro
##   inimigo mais próximo. Qualquer inimigo que ENTRAR nela fica
##   impedido de usar habilidades e com a força de chute pela metade,
##   enquanto estiver dentro. A área dura alguns turnos e depois some
##   sozinha. Cooldown de 4 turnos.

@export_group("Stalker")
@export var stalker_duracao: int = 4
@export var stalker_multiplicador_forca: float = 0.5
@export var stalker_multiplicador_distancia: float = 0.5
@export var stalker_distancia_perseguicao: float = 70.0
@export var cooldown_stalker: int = 6

@export_group("Bet")
@export var bet_alcance: float = 260.0
@export var bet_duracao_turnos: int = 3
@export var bet_multiplicador_forca_inimigo: float = 0.5
@export var cooldown_bet: int = 6
@export var bet_textura: Texture2D  ## opcional: arraste uma imagem aqui pra preencher o "transferidor"
@export var bet_cor: Color = Color(1, 0.2, 0.2, 0.35)  ## usada se bet_textura estiver vazio, ou como tint por cima da textura

const NOME_STALKER := "Stalker"
const NOME_BET := "Bet"

var stalker_alvo: Botao = null
var stalker_turnos_restantes: int = 0

var _zona_bet_atual: Area2D = null
var _bet_turnos_restantes: int = 0


func habilidades_proprias() -> Array[String]:
	return [NOME_STALKER, NOME_BET]


func _habilidade_propria_consome_acao(nome: String) -> bool:
	if nome == NOME_STALKER:
		# consumida manualmente só quando o alvo é confirmado — ver
		# _on_alvo_stalker_escolhido(). Assim, cancelar a seleção (botão
		# direito/Esc) não desperdiça a ação à toa.
		return false
	return true


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_STALKER and stalker_turnos_restantes > 0:
		return "Stalker já está ativo!"
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_STALKER:
			SelecaoAlvo.pedir_alvo(self, _on_alvo_stalker_escolhido, "Selecione um inimigo para o Stalker")
		NOME_BET:
			_executar_bet()
			iniciar_cooldown(nome, cooldown_bet)


## --- Stalker ---

func _on_alvo_stalker_escolhido(alvo: Botao) -> void:
	if alvo.time == time:
		Eventos.mensagem_solicitada.emit("Escolha um oponente como alvo do Stalker!")
		return

	Turnos.usar_acao("habilidade")

	stalker_alvo = alvo
	stalker_turnos_restantes = stalker_duracao

	if not Eventos.botao_chutado.is_connected(_on_algum_botao_chutado):
		Eventos.botao_chutado.connect(_on_algum_botao_chutado)

	_perseguir_alvo()
	Eventos.mensagem_solicitada.emit("Stalker ativado! Raichi está grudado no alvo.")


func _perseguir_alvo() -> void:
	if not stalker_alvo or not is_instance_valid(stalker_alvo):
		_encerrar_stalker()
		return

	var direcao_aproximacao := (global_position - stalker_alvo.global_position)
	if direcao_aproximacao.length() < 1.0:
		direcao_aproximacao = Vector2.RIGHT
	else:
		direcao_aproximacao = direcao_aproximacao.normalized()

	var destino := stalker_alvo.global_position + direcao_aproximacao * stalker_distancia_perseguicao
	MovimentoSuave.mover(self, destino)


func _on_algum_botao_chutado(botao: Botao) -> void:
	if stalker_turnos_restantes > 0 and botao == stalker_alvo:
		_perseguir_alvo()


func multiplicador_distancia_arrasto() -> float:
	return stalker_multiplicador_distancia if stalker_turnos_restantes > 0 else 1.0


func multiplicador_forca_chute() -> float:
	return stalker_multiplicador_forca if stalker_turnos_restantes > 0 else 1.0


func _encerrar_stalker() -> void:
	stalker_alvo = null
	stalker_turnos_restantes = 0
	if Eventos.botao_chutado.is_connected(_on_algum_botao_chutado):
		Eventos.botao_chutado.disconnect(_on_algum_botao_chutado)
	iniciar_cooldown(NOME_STALKER, cooldown_stalker)
	Eventos.mensagem_solicitada.emit("Stalker do Raichi terminou.")


## --- Bet ---

func _executar_bet() -> void:
	var alvo := _encontrar_inimigo_mais_proximo()
	if not alvo:
		Eventos.mensagem_solicitada.emit("Não há inimigos em campo para o Bet!")
		return

	_remover_zona_bet()

	var direcao := (alvo.global_position - global_position).normalized()

	var area := Area2D.new()
	area.global_position = global_position
	area.collision_layer = 0
	area.collision_mask = 1

	var pontos := _gerar_poligono_semicirculo(bet_alcance, direcao)

	var forma := CollisionPolygon2D.new()
	forma.polygon = pontos
	area.add_child(forma)

	# visual: um Polygon2D IRMÃO da CollisionPolygon2D, com o MESMO
	# array de pontos — assim o desenho bate exatamente com a área de
	# colisão, sem duplicar a lógica do formato de transferidor.
	var visual := Polygon2D.new()
	visual.polygon = pontos
	visual.color = bet_cor
	if bet_textura:
		visual.texture = bet_textura
		# sem um array de "uv" próprio, o Godot mapeia a textura usando
		# as posições dos vértices direto — funciona bem pra imagens
		# pensadas pra esse formato de leque; se a sua textura ficar
		# esticada/deslocada, ajuste "texture_offset"/"texture_scale"
		# no Inspector do Polygon2D depois de instanciado, ou gere um
		# "uv" próprio (mesmo tamanho de "pontos") normalizado 0..1.
	area.add_child(visual)
	area.move_child(visual, 0)  # desenha atrás da CollisionPolygon2D (que é invisível de qualquer forma)

	get_parent().add_child(area)

	_zona_bet_atual = area
	_bet_turnos_restantes = bet_duracao_turnos

	area.body_entered.connect(_on_corpo_entrou_bet)
	area.body_exited.connect(_on_corpo_saiu_bet)

	Eventos.mensagem_solicitada.emit("Bet ativado! Área bloqueando o inimigo mais próximo.")


func _gerar_poligono_semicirculo(raio: float, direcao: Vector2, segmentos: int = 24) -> PackedVector2Array:
	# gera um "leque" de 180°, com o ápice na origem (posição do Raichi)
	# e a curva voltada pra "direcao" — o formato de transferidor pedido.
	var angulo_base := direcao.angle()
	var pontos := PackedVector2Array()
	pontos.append(Vector2.ZERO)
	for i in range(segmentos + 1):
		var t := float(i) / float(segmentos)
		var angulo := angulo_base - PI / 2.0 + t * PI
		pontos.append(Vector2(cos(angulo), sin(angulo)) * raio)
	return pontos


func _encontrar_inimigo_mais_proximo() -> Botao:
	var mais_proximo: Botao = null
	var menor_distancia := INF
	for nodo in get_tree().get_nodes_in_group("botoes"):
		var botao := nodo as Botao
		if not botao or botao.time == time:
			continue
		var distancia := global_position.distance_to(botao.global_position)
		if distancia < menor_distancia:
			menor_distancia = distancia
			mais_proximo = botao
	return mais_proximo


func _on_corpo_entrou_bet(body: Node) -> void:
	var botao := body as Botao
	if not botao or botao.time == time:
		return  # só afeta inimigos
	botao.bloqueado_de_usar_habilidade_por_zona = true
	botao.multiplicador_forca_externo = bet_multiplicador_forca_inimigo


func _on_corpo_saiu_bet(body: Node) -> void:
	var botao := body as Botao
	if not botao or botao.time == time:
		return
	botao.bloqueado_de_usar_habilidade_por_zona = false
	botao.multiplicador_forca_externo = 1.0


func _remover_zona_bet() -> void:
	if _zona_bet_atual and is_instance_valid(_zona_bet_atual):
		for corpo in _zona_bet_atual.get_overlapping_bodies():
			_on_corpo_saiu_bet(corpo)
		_zona_bet_atual.queue_free()
	_zona_bet_atual = null


## --- Turnos: decrementa Stalker e Bet junto com cooldowns/concessões ---

func _on_turno_mudou(time_da_vez: String) -> void:
	super._on_turno_mudou(time_da_vez)

	if stalker_turnos_restantes > 0:
		stalker_turnos_restantes -= 1
		if stalker_turnos_restantes <= 0:
			_encerrar_stalker()

	if _bet_turnos_restantes > 0:
		_bet_turnos_restantes -= 1
		if _bet_turnos_restantes <= 0:
			_remover_zona_bet()
