extends Botao
class_name Reo

## Reo Mikage
##
## - Copy: abre um leque (MenuEscolha) com habilidades de outros
##   personagens — por enquanto: Bet (Raichi), Rabona Cross (Charles),
##   Dragon Drive (Shidou), Accelerate (Chigiri) e Metavisão (Isagi).
##   Ver _copiaveis abaixo pra crescer essa lista depois, sem precisar
##   mexer no resto do código.
##
##   Ao escolher uma opção, Reo "aprende" ela através do MESMO mecanismo
##   de habilidade CONCEDIDA que já existe em Botao.gd pros empréstimos
##   entre personagens (ex: One Two do Kurona) — só fica disponível a
##   partir do PRÓXIMO turno, e com turnos_para_expirar = -1 ela NÃO
##   expira sozinha, fica guardada até o jogador decidir usá-la (ou até
##   uma nova Copy substituir a escolha, já que só existe uma concessão
##   pendente por vez — regra de Botao.gd, não precisei duplicar aqui).
##
##   Abrir o leque (Copy em si) NÃO custa a ação de habilidade do turno
##   — só a habilidade ESCOLHIDA custa (ou não, ex: Metavisão), conforme
##   o "custa_acao" de cada entrada em _copiaveis. Já o COOLDOWN do Copy
##   é diferente: ele fica livre enquanto a cópia está só guardada, e só
##   entra em cooldown de "cooldown_copy" turnos no exato momento em que
##   a habilidade copiada é DE FATO gasta (não quando é escolhida) — ver
##   _iniciar_cooldowns_apos_uso(), chamada junto do cooldown próprio de
##   cada habilidade copiada. Os cooldowns copiados têm nome próprio
##   (cooldown_bet_copiado etc.): pra não empatar sem querer com o
##   cooldown de outro Reo que copiou a mesma coisa, ou com o do dono
##   original, se algum dia personagens compartilharem instância de
##   cooldowns (não é o caso hoje, mas evita a armadilha).
##
## - Lob Pass: mesma ideia do Shark Assault do Kurona (passe garantido,
##   sem física real, sem chance de interceptação — a bola "viaja" até
##   o destino e chega parada), mas em vez de escolher um aliado
##   ALEATÓRIO, o JOGADOR clica em qual aliado quer passar (reaproveita
##   SelecaoAlvo.pedir_alvo(), igual ao One Two do Kurona). Consumida
##   manualmente só quando o alvo é confirmado, pro cancelamento
##   (botão direito/Esc) não gastar a ação à toa.

@export_group("Copy - Bet (Raichi)")
@export var bet_alcance: float = 260.0
@export var bet_duracao_turnos: int = 3
@export var bet_multiplicador_forca_inimigo: float = 0.5
@export var bet_cor: Color = Color(0.753, 0.369, 1.0, 0.349)
@export var cooldown_bet_copiado: int = 5

@export_group("Copy - Rabona Cross (Charles)")
@export var forca_rabona_cross: float = 125.0
@export var intensidade_curva_rabona: float = 70.0
@export var duracao_curva_rabona: float = 1.0
@export var cooldown_rabona_copiado: int = 7

@export_group("Copy - Dragon Drive (Shidou)")
@export var forca_dragon_drive: float = 130.0
@export var duracao_dragon_drive: float = 1.0
@export var cooldown_dragon_drive_copiado: int = 7

@export_group("Copy - Accelerate (Chigiri)")
@export var accelerate_duracao: int = 4
@export var accelerate_multiplicador_distancia: float = 1.6
@export var accelerate_multiplicador_forca: float = 1.6
@export var cooldown_accelerate_copiado: int = 7

@export_group("Copy - Metavisão (Isagi)")
@export var cooldown_metavisao_copiada: int = 6

@export_group("Copy - cooldown próprio")
@export var cooldown_copy: int = 7  ## entra em cooldown só quando a cópia é DE FATO gasta, nunca ao ser escolhida/guardada

@export_group("Lob Pass")
@export var duracao_lob_pass: float = 2.5
@export var cooldown_lob_pass: int = 6

const NOME_COPY := "Copy"
const NOME_LOB_PASS := "Lob Pass"

## Fonte única de verdade pro leque: nome visível -> {"executar": Callable,
## "custa_acao": bool}. O leque mostrado (_abrir_leque_copy) e o
## "aprender" (_on_copy_escolhida) usam o MESMO dicionário, então
## adicionar uma habilidade nova ao Copy no futuro é só adicionar uma
## entrada aqui. "custa_acao" guarda o mesmo valor que o personagem
## original usa em _habilidade_propria_consome_acao() — é o que o
## conceder_habilidade() do Botao.gd espera pra habilidade concedida se
## comportar igual à original quando o jogador for usá-la (ex:
## Metavisão não deve gastar a ação de habilidade do turno).
var _copiaveis: Dictionary

var _zona_bet_atual: Area2D = null
var _bet_turnos_restantes: int = 0

var _accelerate_copiado_turnos_restantes: int = 0
var _metavisao_copiada_ativa: bool = false


func _ready() -> void:
	super._ready()
	_copiaveis = {
		"Bet": {"executar": Callable(self, "_executar_bet_copiado"), "custa_acao": true},
		"Rabona Cross": {"executar": Callable(self, "_iniciar_rabona_cross_copiado"), "custa_acao": true},
		"Dragon Drive": {"executar": Callable(self, "_executar_dragon_drive_copiado"), "custa_acao": true},
		"Accelerate": {"executar": Callable(self, "_executar_accelerate_copiado"), "custa_acao": true},
		"Metavisão": {"executar": Callable(self, "_executar_metavisao_copiada"), "custa_acao": false},
	}


## --- Ganchos do sistema de habilidades (ver Botao.gd) ---

func habilidades_proprias() -> Array[String]:
	return [NOME_COPY, NOME_LOB_PASS]


func _habilidade_propria_consome_acao(nome: String) -> bool:
	if nome == NOME_COPY:
		return false  # abrir o leque é de graça; quem custa é a habilidade escolhida, só quando USADA (não vem daqui, vem de _achar_concedida em Botao.gd)
	if nome == NOME_LOB_PASS:
		return false  # consumida manualmente em _on_alvo_lob_pass_escolhido(), só quando o passe de fato sai
	return true


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_LOB_PASS and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_COPY:
			_abrir_leque_copy()
		NOME_LOB_PASS:
			_iniciar_lob_pass()


## --- Copy ---

func _abrir_leque_copy() -> void:
	var opcoes: Array[String] = []
	opcoes.assign(_copiaveis.keys())
	MenuEscolha.pedir_opcao(opcoes, _on_copy_escolhida, "Copy: escolha uma habilidade")


func _on_copy_escolhida(nome_escolhido: String) -> void:
	var info: Dictionary = _copiaveis[nome_escolhido]
	conceder_habilidade(nome_escolhido, info["executar"], info["custa_acao"], -1)
	Eventos.mensagem_solicitada.emit("Copy! Reo guardou %s — disponível a partir do próximo turno." % nome_escolhido)


func _iniciar_cooldowns_apos_uso(nome_habilidade_copiada: String, cooldown_da_copia: int) -> void:
	# Chamado no exato momento em que uma habilidade copiada é DE FATO
	# gasta (não quando é escolhida no leque) — bota a habilidade
	# copiada E o Copy em si em cooldown juntos, como pedido: o Copy só
	# passa a ficar bloqueado depois que a cópia guardada é usada.
	iniciar_cooldown(nome_habilidade_copiada, cooldown_da_copia)
	iniciar_cooldown(NOME_COPY, cooldown_copy)


## --- Bet (copiado do Raichi.gd — mesma lógica, rodando com "self" =
## Reo e os stats exportados dele acima, não os do Raichi original) ---

func _executar_bet_copiado() -> void:
	var alvo := _encontrar_inimigo_mais_proximo()
	if not alvo:
		Eventos.mensagem_solicitada.emit("Não há inimigos em campo para o Bet copiado!")
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

	var visual := Polygon2D.new()
	visual.polygon = pontos
	visual.color = bet_cor
	area.add_child(visual)
	area.move_child(visual, 0)

	get_parent().add_child(area)

	_zona_bet_atual = area
	_bet_turnos_restantes = bet_duracao_turnos

	area.body_entered.connect(_on_corpo_entrou_bet)
	area.body_exited.connect(_on_corpo_saiu_bet)

	_iniciar_cooldowns_apos_uso("Bet", cooldown_bet_copiado)
	Eventos.mensagem_solicitada.emit("Bet (copiado)! Área bloqueando o inimigo mais próximo.")


func _gerar_poligono_semicirculo(raio: float, direcao: Vector2, segmentos: int = 24) -> PackedVector2Array:
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
		return
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


## --- Rabona Cross (copiado do Charles.gd) ---

func _iniciar_rabona_cross_copiado() -> void:
	if bola_no_alcance == null:
		Eventos.mensagem_solicitada.emit("A bola precisa estar por perto para usar Rabona Cross!")
		return
	SelecaoAlvo.pedir_ponto(self, _on_ponto_escolhido_rabona_copiado, "Clique no campo pra onde a bola deve cair (Rabona Cross)")


func _on_ponto_escolhido_rabona_copiado(ponto: Vector2) -> void:
	var bola := bola_no_alcance
	if not bola:
		Eventos.mensagem_solicitada.emit("A bola não está mais por perto — Rabona Cross cancelado.")
		return

	bola.receber_chute_curvo(ponto, forca_rabona_cross, time, intensidade_curva_rabona, duracao_curva_rabona, true)
	_iniciar_cooldowns_apos_uso("Rabona Cross", cooldown_rabona_copiado)
	Eventos.mensagem_solicitada.emit("Rabona Cross (copiado)! A bola foi cruzada em curva até o ponto escolhido.")


## --- Dragon Drive (copiado do Shidou.gd) ---

func _executar_dragon_drive_copiado() -> void:
	var bola := bola_no_alcance
	if not bola:
		Eventos.mensagem_solicitada.emit("A bola precisa estar por perto para usar Dragon Drive!")
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	bola.receber_chute_curvo(gol.ponto_para_mira(), forca_dragon_drive, time, 0.0, duracao_dragon_drive, false)
	_iniciar_cooldowns_apos_uso("Dragon Drive", cooldown_dragon_drive_copiado)
	Eventos.mensagem_solicitada.emit("Dragon Drive (copiado)!")


## --- Accelerate (copiado do Chigiri.gd) — buff de duração, então
## "gasto" acontece na hora de ativar, não depois (igual ao original) ---

func _executar_accelerate_copiado() -> void:
	_accelerate_copiado_turnos_restantes = accelerate_duracao
	_iniciar_cooldowns_apos_uso("Accelerate", cooldown_accelerate_copiado)
	Eventos.mensagem_solicitada.emit("Accelerate (copiado)! Mira e força de chute do Reo aumentadas.")


func multiplicador_distancia_arrasto() -> float:
	return accelerate_multiplicador_distancia if _accelerate_copiado_turnos_restantes > 0 else 1.0


func multiplicador_forca_chute() -> float:
	return accelerate_multiplicador_forca if _accelerate_copiado_turnos_restantes > 0 else 1.0


## --- Metavisão (copiada do Isagi.gd) — igual ao Accelerate, o "gasto"
## conta na ativação (mesmo comportamento do Isagi original) ---

func _executar_metavisao_copiada() -> void:
	_metavisao_copiada_ativa = true
	_iniciar_cooldowns_apos_uso("Metavisão", cooldown_metavisao_copiada)
	Eventos.mensagem_solicitada.emit("Metavisão (copiada)! Sua próxima mira mostra a trajetória completa.")


func _tem_visao_estendida_propria() -> bool:
	return _metavisao_copiada_ativa


func _apos_chute(sucesso: bool) -> void:
	super._apos_chute(sucesso)
	if sucesso:
		_metavisao_copiada_ativa = false
	if linha_trajetoria_bola:
		linha_trajetoria_bola.visible = false


## --- Lob Pass ---

func _iniciar_lob_pass() -> void:
	SelecaoAlvo.pedir_alvo(self, _on_alvo_lob_pass_escolhido, "Selecione um aliado para o Lob Pass")


func _on_alvo_lob_pass_escolhido(alvo: Botao) -> void:
	if alvo == self:
		Eventos.mensagem_solicitada.emit("Escolha outro jogador como alvo!")
		return

	if alvo.time != time:
		Eventos.mensagem_solicitada.emit("Escolha um companheiro de time como alvo!")
		return

	var bola := bola_no_alcance
	if not bola:
		Eventos.mensagem_solicitada.emit("A bola não está mais por perto — Lob Pass cancelado.")
		return

	bola.mover_para_com_trajetoria(alvo.global_position, duracao_lob_pass)

	consumir_acao_habilidade()
	iniciar_cooldown(NOME_LOB_PASS, cooldown_lob_pass)
	Eventos.mensagem_solicitada.emit("Lob Pass! A bola foi lançada até o aliado escolhido.")


## --- Turnos: decrementa a zona do Bet e a duração do Accelerate
## copiados junto com o resto (cooldowns e concessões já são
## decrementados pelo super._on_turno_mudou() em Botao.gd) ---

func _on_turno_mudou(time_da_vez: String) -> void:
	super._on_turno_mudou(time_da_vez)

	if _bet_turnos_restantes > 0:
		_bet_turnos_restantes -= 1
		if _bet_turnos_restantes <= 0:
			_remover_zona_bet()

	if _accelerate_copiado_turnos_restantes > 0:
		_accelerate_copiado_turnos_restantes -= 1
		if _accelerate_copiado_turnos_restantes <= 0:
			Eventos.mensagem_solicitada.emit("Accelerate (copiado) do Reo acabou!")
