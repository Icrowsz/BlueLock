extends Botao
class_name Barou

## Barou
##
## - Devour: concede um deslocamento CURTO extra (não substitui o
##   movimento normal do turno, soma um a mais) e aumenta temporariamente
##   sua própria hitbox de alcance. Se, depois desse dash curto, a bola
##   estiver ao alcance, libera o Follow Up "Lion Kingdom" — um chute
##   que fica mais forte quanto mais botões (aliados OU inimigos)
##   estiverem por perto. Cooldown de 7 turnos.
##
## - King Path: mesma ideia, um drible extra com alcance um pouco maior
##   que o do Devour (mas ainda curto), sem aumento de hitbox. Se
##   encontrar a bola, libera o Follow Up "Nero" — um chute forte e
##   direto. Cooldown de 6 turnos.
##
## O Follow Up NÃO tem cooldown/custo de ação próprio — é a recompensa
## por ter fechado a distância até a bola, não uma habilidade separada.
## Se não for usado, ele expira na próxima troca de turno (não fica
## disponível pra sempre).

@export_group("Devour")
@export var alcance_dash_devour: float = 70.0
@export var multiplicador_hitbox_devour: float = 1.8
@export var cooldown_devour: int = 7

@export_group("King Path")
@export var alcance_dash_king_path: float = 100.0
@export var cooldown_king_path: int = 6

@export_group("Lion Kingdom (Follow Up do Devour)")
@export var forca_base_lion_kingdom: float = 140.0
@export var bonus_forca_por_botao_proximo: float = 30.0
@export var raio_contagem_lion_kingdom: float = 150.0

@export_group("Nero (Follow Up do King Path)")
@export var forca_nero: float = 150.0

const NOME_DEVOUR := "Devour"
const NOME_KING_PATH := "King Path"
const NOME_LION_KINGDOM := "Lion Kingdom"
const NOME_NERO := "Nero"

var _devour_ativo: bool = false
var _king_path_ativo: bool = false
var _follow_up_disponivel: String = ""  # "" = nenhum liberado agora


func habilidades_proprias() -> Array[String]:
	var lista: Array[String] = [NOME_DEVOUR, NOME_KING_PATH]
	if _follow_up_disponivel != "":
		lista.append(_follow_up_disponivel)
	return lista


func _habilidade_propria_consome_acao(nome: String) -> bool:
	# o Follow Up é a RECOMPENSA de ter fechado a distância — não custa
	# uma segunda ação de habilidade em cima da que já foi gasta pra
	# ativar o Devour/King Path
	return nome != NOME_LION_KINGDOM and nome != NOME_NERO


func _requisito_extra_propria(nome: String) -> String:
	if (nome == NOME_LION_KINGDOM or nome == NOME_NERO) and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_DEVOUR:
			_devour_ativo = true
			conceder_acao_movimento_extra(1)
			if area_alcance:
				area_alcance.scale = Vector2.ONE * multiplicador_hitbox_devour
			iniciar_cooldown(nome, cooldown_devour)
			Eventos.mensagem_solicitada.emit("Devour ativado! Arraste pra fazer o dash — se pegar a bola, libera o Lion Kingdom.")
		NOME_KING_PATH:
			_king_path_ativo = true
			conceder_acao_movimento_extra(1)
			iniciar_cooldown(nome, cooldown_king_path)
			Eventos.mensagem_solicitada.emit("King Path ativado! Arraste pra driblar — se pegar a bola, libera o Nero.")
		NOME_LION_KINGDOM:
			_executar_lion_kingdom()
			_follow_up_disponivel = ""
		NOME_NERO:
			_executar_nero()
			_follow_up_disponivel = ""


## --- Dash curto (compartilhado pelas duas ativações) ---

func _executar_deslocamento(vetor_arrasto: Vector2) -> void:
	if _devour_ativo:
		_devour_ativo = false
		_dash_curto(vetor_arrasto, alcance_dash_devour)
		_verificar_follow_up_apos_dash(NOME_LION_KINGDOM, true)
		return

	if _king_path_ativo:
		_king_path_ativo = false
		_dash_curto(vetor_arrasto, alcance_dash_king_path)
		_verificar_follow_up_apos_dash(NOME_NERO, false)
		return

	super._executar_deslocamento(vetor_arrasto)


func _dash_curto(vetor_arrasto: Vector2, alcance_maximo: float) -> void:
	var vetor_curto := vetor_arrasto.limit_length(alcance_maximo)
	var forca := (vetor_curto * multiplicador_forca * multiplicador_forca_chute_total()).limit_length(forca_maxima * multiplicador_forca_chute_total())
	apply_central_impulse(forca)


func _verificar_follow_up_apos_dash(nome_follow_up: String, restaurar_hitbox: bool) -> void:
	# espera a física do dash se acomodar antes de checar o alcance —
	# checar no mesmo frame do impulso pegaria a bola/alcance como
	# estavam ANTES do dash terminar de valer (mesmo motivo do ajuste
	# que já fizemos no Stalker do Raichi)
	await get_tree().create_timer(0.4).timeout

	if restaurar_hitbox and area_alcance:
		area_alcance.scale = Vector2.ONE

	if bola_no_alcance != null:
		_follow_up_disponivel = nome_follow_up
		Eventos.mensagem_solicitada.emit("%s liberado! A bola está ao seu alcance." % nome_follow_up)


func _on_turno_mudou(time_da_vez: String) -> void:
	super._on_turno_mudou(time_da_vez)
	# Follow Up não usado até a próxima troca de turno? Some — não é
	# uma habilidade permanente, é a janela de oportunidade do dash.
	_follow_up_disponivel = ""


## --- Lion Kingdom ---

func _executar_lion_kingdom() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	var quantidade := _contar_botoes_proximos(raio_contagem_lion_kingdom)
	var forca := forca_base_lion_kingdom + quantidade * bonus_forca_por_botao_proximo

	var direcao := (gol.ponto_para_mira() - bola.global_position).normalized()
	bola.receber_chute_teleguiado(direcao, forca)


func _contar_botoes_proximos(raio: float) -> int:
	var contagem := 0
	for nodo in get_tree().get_nodes_in_group("botoes"):
		var botao := nodo as Botao
		if botao and botao != self and global_position.distance_to(botao.global_position) <= raio:
			contagem += 1
	return contagem


## --- Nero ---

func _executar_nero() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	var direcao := (gol.ponto_para_mira() - bola.global_position).normalized()
	bola.receber_chute_teleguiado(direcao, forca_nero)
