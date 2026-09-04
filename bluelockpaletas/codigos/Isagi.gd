extends Botao
class_name Isagi

## Isagi Yoichi
##
## - Chute Direto: chute forte, reto e teleguiado direto no gol inimigo.
##   Custa a ação de habilidade do turno. Cooldown de 2 turnos.
##
## - Metavisão: ativa uma prévia de trajetória bem mais longa e precisa
##   que a mira normal (com ricochete em paredes/outros botões, e
##   continua prevendo pra onde a BOLA vai depois de ser atingida). NÃO
##   custa a ação de habilidade — só entra em cooldown de 4 turnos.

@export_group("Chute Direto")
@export var forca_chute_direto: float = 1400.0
@export var cooldown_chute_direto: int = 2

@export_group("Metavisão")
@export var cooldown_metavisao: int = 4
@export var alcance_metavisao: float = 900.0
@export var max_ricochetes_metavisao: int = 4
@export var cor_trajetoria_chute: Color = Color(1.0, 0.85, 0.15)
@export var cor_trajetoria_bola: Color = Color(1.0, 1.0, 1.0, 0.65)

var metavisao_ativa: bool = false

@onready var linha_trajetoria_bola: Line2D = $LinhaTrajetoriaBola if has_node("LinhaTrajetoriaBola") else null


func _ready() -> void:
	super._ready()
	if linha_trajetoria_bola:
		linha_trajetoria_bola.top_level = true
		linha_trajetoria_bola.visible = false
		linha_trajetoria_bola.default_color = cor_trajetoria_bola


## --- Ganchos do sistema de habilidades (ver Botao.gd) ---

func habilidades_proprias() -> Array[String]:
	return ["Chute Direto", "Metavisão"]


func _habilidade_propria_consome_acao(nome: String) -> bool:
	return nome != "Metavisão"


func _requisito_extra_propria(nome: String) -> String:
	if bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		"Chute Direto":
			_executar_chute_direto()
			iniciar_cooldown(nome, cooldown_chute_direto)
		"Metavisão":
			_executar_metavisao()
			iniciar_cooldown(nome, cooldown_metavisao)


## --- Chute Direto ---

func _executar_chute_direto() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	var direcao := (gol.ponto_para_mira() - bola.global_position).normalized()
	bola.receber_chute_teleguiado(direcao, forca_chute_direto)


## --- Metavisão ---

func _executar_metavisao() -> void:
	metavisao_ativa = true
	Eventos.mensagem_solicitada.emit("Metavisão ativada! Sua próxima mira mostra a trajetória completa.")


func _desenhar_mira(vetor: Vector2) -> void:
	if not metavisao_ativa:
		super._desenhar_mira(vetor)
		if linha_trajetoria_bola:
			linha_trajetoria_bola.visible = false
		return

	_desenhar_trajetoria_prevista(vetor.normalized())


func _desenhar_trajetoria_prevista(direcao: Vector2) -> void:
	var espaco := get_world_2d().direct_space_state

	var previsao := PreditorTrajetoria.prever(
		espaco, global_position, direcao, alcance_metavisao, max_ricochetes_metavisao, [get_rid()]
	)

	linha_mira.global_position = Vector2.ZERO
	linha_mira.default_color = cor_trajetoria_chute
	linha_mira.points = previsao["pontos"]
	linha_mira.visible = true

	var corpo_atingido = previsao["corpo_atingido"]

	if linha_trajetoria_bola and corpo_atingido and corpo_atingido.is_in_group("bola"):
		var pontos_fase1: PackedVector2Array = previsao["pontos"]
		var ponto_impacto: Vector2 = pontos_fase1[pontos_fase1.size() - 1]

		var previsao_bola := PreditorTrajetoria.prever(
			espaco, ponto_impacto, direcao, alcance_metavisao * 0.6, max_ricochetes_metavisao,
			[get_rid(), corpo_atingido.get_rid()]
		)

		linha_trajetoria_bola.global_position = Vector2.ZERO
		linha_trajetoria_bola.points = previsao_bola["pontos"]
		linha_trajetoria_bola.visible = true
	elif linha_trajetoria_bola:
		linha_trajetoria_bola.visible = false


func _apos_chute(sucesso: bool) -> void:
	super._apos_chute(sucesso)
	if sucesso:
		metavisao_ativa = false
	if linha_trajetoria_bola:
		linha_trajetoria_bola.visible = false
