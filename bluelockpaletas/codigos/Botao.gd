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

## Cooldowns de habilidade: chave = nome da habilidade, valor = turnos restantes.
## Um dicionário (não uma variável fixa) porque cada habilidade pode ter
## seu próprio tempo de recarga, e personagens futuros terão nomes
## diferentes — isso funciona sem precisar de nenhum caso especial.
var cooldowns: Dictionary = {}

## Habilidades TEMPORÁRIAS concedidas por OUTRO personagem (ex: o One
## Two do Kurona empresta a habilidade pro alvo). Cada item é um
## Dictionary: {"nome", "executar" (Callable), "custa_acao" (bool),
## "disponivel" (bool)}. "disponivel" começa false e vira true na
## próxima troca de turno — é isso que garante que a habilidade
## concedida só pode ser usada "no próximo turno", nunca no mesmo turno
## em que foi concedida.
var habilidades_concedidas: Array = []

## Efeitos temporários genéricos (buffs/debuffs) que outras habilidades
## podem aplicar neste botão — funciona ao "contrário" dos cooldowns:
## aqui o efeito fica ATIVO por N turnos, em vez de bloqueado.
## Ex: a imunidade que o alvo do One Two do Kurona ganha, pra não poder
## receber outro One Two logo em seguida. Um Dictionary (nome -> turnos
## restantes) pelo mesmo motivo dos cooldowns: funciona pra qualquer
## efeito futuro, de qualquer personagem, sem precisar de caso especial.
var efeitos_temporarios: Dictionary = {}

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
			# se alguma habilidade está esperando um clique em um alvo
			# (ex: One Two do Kurona), esse clique é consumido como a
			# escolha do alvo — não abre o painel de habilidade normal
			# nem inicia arrasto
			if SelecaoAlvo.esta_selecionando():
				SelecaoAlvo.processar_clique(self)
				return

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


## --- Suporte a passes "automáticos" (tipo TP, sem física de verdade) ---
## Usado por habilidades como o One Two e o Shark Assault do Kurona.

func raio_area_alcance() -> float:
	# tenta descobrir o raio de verdade da AreaAlcance deste personagem
	# (funciona pra CircleShape2D, o formato mais comum pra esse tipo de
	# alcance). Se não achar, cai pra um valor de segurança baseado no
	# raio de clique.
	if area_alcance:
		for filho in area_alcance.get_children():
			if filho is CollisionShape2D and filho.shape is CircleShape2D:
				return filho.shape.radius
	return raio_clique * 1.5


func ponto_de_chegada_dominado(origem: Vector2, fracao_do_alcance: float = 0.6) -> Vector2:
	# calcula um ponto de chegada SEGURO pra um passe automático: fica
	# DENTRO do alcance deste botão (pra já contar como "recebido" na
	# hora, ativando bola_no_alcance), mas afastado o bastante do corpo
	# físico dele pra não gerar nenhum "empurrão" quando a bola aparecer
	# ali do nada. `origem` é só usado pra decidir de que LADO a bola
	# chega (efeito visual, ela "vem" da direção de quem chutou).
	var direcao := origem - global_position
	if direcao.length() < 0.001:
		direcao = Vector2.RIGHT  # fallback: origem bem em cima do alvo
	direcao = direcao.normalized()
	return global_position + direcao * (raio_area_alcance() * fracao_do_alcance)


## --- Sistema de habilidades: cada personagem pode ter VÁRIAS ---
## IMPORTANTE: personagens sobrescrevem os métodos com prefixo/sufixo
## "_propria" (habilidades_proprias, executar_habilidade_propria, etc.),
## NÃO os métodos públicos abaixo. Os públicos combinam automaticamente
## as habilidades do personagem com as que ele recebeu emprestadas de
## outros (ex: One Two do Kurona) — sobrescrever os públicos direto
## quebraria essa combinação pra qualquer personagem que receber uma
## habilidade concedida no futuro.

func lista_habilidades() -> Array[String]:
	var lista := habilidades_proprias().duplicate()
	for c in habilidades_concedidas:
		if c["disponivel"]:
			lista.append(c["nome"])
	return lista


func habilidade_consome_acao(nome: String) -> bool:
	var c := _achar_concedida(nome)
	if not c.is_empty():
		return c["custa_acao"]
	return _habilidade_propria_consome_acao(nome)


func requisito_extra_habilidade(nome: String) -> String:
	var c := _achar_concedida(nome)
	if not c.is_empty():
		return ""  # habilidades concedidas checam seus próprios requisitos na hora de executar
	return _requisito_extra_propria(nome)


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


func usar_habilidade(nome: String) -> void:
	var c := _achar_concedida(nome)
	if not c.is_empty():
		_remover_concedida(nome)
		c["executar"].call()
		return
	executar_habilidade_propria(nome)


func conceder_habilidade(nome: String, executar: Callable, custa_acao: bool = false) -> void:
	# empresta uma habilidade TEMPORÁRIA (uso único) a este botão, vinda
	# de outro personagem. Só fica disponível a partir da PRÓXIMA troca
	# de turno (nunca no mesmo turno em que foi concedida), e expira
	# sozinha se não for usada até o fim desse turno seguinte (ver
	# _on_turno_mudou) — pra nunca ficar acumulando cópias antigas.
	#
	# Se esse botão já tinha uma concessão pendente com o MESMO nome
	# (ex: ganhou um novo One Two antes de usar o anterior), a nova
	# substitui a antiga, nunca "empilha" em cima.
	_remover_concedida(nome)

	habilidades_concedidas.append({
		"nome": nome,
		"executar": executar,
		"custa_acao": custa_acao,
		"disponivel": false,
	})


func _achar_concedida(nome: String) -> Dictionary:
	for c in habilidades_concedidas:
		if c["nome"] == nome and c["disponivel"]:
			return c
	return {}


func _remover_concedida(nome: String) -> void:
	for i in range(habilidades_concedidas.size() - 1, -1, -1):
		if habilidades_concedidas[i]["nome"] == nome:
			habilidades_concedidas.remove_at(i)


## --- Ganchos que cada personagem sobrescreve ---

func habilidades_proprias() -> Array[String]:
	return []  # botão base não tem nenhuma


func _habilidade_propria_consome_acao(_nome: String) -> bool:
	return true  # a maioria consome; sobrescreva pra exceções (ex: Metavisão)


func _requisito_extra_propria(_nome: String) -> String:
	return ""


func executar_habilidade_propria(_nome: String) -> void:
	pass


func esta_em_cooldown(habilidade: String) -> bool:
	return cooldowns.get(habilidade, 0) > 0


func turnos_restantes_cooldown(habilidade: String) -> int:
	return cooldowns.get(habilidade, 0)


func iniciar_cooldown(habilidade: String, turnos: int) -> void:
	cooldowns[habilidade] = turnos


## --- Efeitos temporários (ver comentário na declaração da variável) ---

func tem_efeito(nome: String) -> bool:
	return efeitos_temporarios.get(nome, 0) > 0


func turnos_restantes_efeito(nome: String) -> int:
	return efeitos_temporarios.get(nome, 0)


func aplicar_efeito_temporario(nome: String, turnos: int) -> void:
	efeitos_temporarios[nome] = turnos


func _on_turno_mudou(time_iniciado: String) -> void:
	for chave in cooldowns.keys():
		if cooldowns[chave] > 0:
			cooldowns[chave] -= 1

	for chave in efeitos_temporarios.keys():
		if efeitos_temporarios[chave] > 0:
			efeitos_temporarios[chave] -= 1

	# habilidades CONCEDIDAS (emprestadas por outro personagem, ex: o
	# One Two do Kurona) só devem existir durante o PRÓXIMO turno de
	# verdade DESTE time — não em qualquer troca de turno global (que
	# também acontece quando é a vez do time ADVERSÁRIO). Por isso só
	# mexemos nelas quando é realmente a vez do MEU time:
	if time_iniciado == time:
		for i in range(habilidades_concedidas.size() - 1, -1, -1):
			var c = habilidades_concedidas[i]
			if c["disponivel"]:
				# já teve a chance de ser usada no meu turno anterior e
				# não foi: expira agora, pra nunca ficar acumulando
				# cópias antigas da mesma habilidade
				habilidades_concedidas.remove_at(i)
			else:
				c["disponivel"] = true


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
