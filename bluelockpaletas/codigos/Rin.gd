extends Botao
class_name Rin

## Rin Itoshi
##
## - Curve Shot: chute teleguiado no gol inimigo (mesma base do Chute
##   Direto), mas com trajetória bem curva, e que IGNORA colisão com
##   aliados — só um oponente consegue interceptar. Força 150 (padrão),
##   cooldown de 6 turnos.
##
## - Opposite Direction: em vez do deslocamento normal (arrasto livre +
##   impulso físico), Rin se desloca só nas 4 direções fixas (cima,
##   baixo, direita, esquerda), sem deslizar — um teleporte curto e sem
##   inércia. Mais fraco (percorre bem menos distância) que o
##   deslocamento normal.

@export_group("Curve Shot")
@export var forca_curve_shot: float = 150.0
@export var cooldown_curve_shot: int = 6
@export var intensidade_curva: float = 90.0  ## desvio lateral MÁXIMO em pixels (só atinge isso num chute 100% lateral; de frente, escala pra perto de zero)
@export var duracao_curva: float = 1.1

@export_group("Opposite Direction")
@export var opposite_direction_distancia: float = 90.0
@export var cooldown_opposite_direction: int = 4

const NOME_CURVE_SHOT := "Curve Shot"
const NOME_OPPOSITE_DIRECTION := "Opposite Direction"

var _opposite_direction_ativo: bool = false


func habilidades_proprias() -> Array[String]:
	return [NOME_CURVE_SHOT, NOME_OPPOSITE_DIRECTION]


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_CURVE_SHOT and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_CURVE_SHOT:
			_executar_curve_shot()
			iniciar_cooldown(nome, cooldown_curve_shot)
		NOME_OPPOSITE_DIRECTION:
			_opposite_direction_ativo = true
			iniciar_cooldown(nome, cooldown_opposite_direction)
			Eventos.mensagem_solicitada.emit("Opposite Direction ativado! Arraste em uma direção pra teleportar.")


## --- Curve Shot ---

func _executar_curve_shot() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	var alvo := gol.ponto_para_mira()
	var intensidade_efetiva := _calcular_intensidade_curva(bola.global_position, alvo)
	bola.receber_chute_curvo(alvo, forca_curve_shot, time, intensidade_efetiva, duracao_curva)


func _calcular_intensidade_curva(origem: Vector2, alvo: Vector2) -> float:
	# quanto mais alinhado com o eixo de ataque (de frente pro gol),
	# menos curva — é o caminho mais fácil, sai reto. Quanto mais
	# lateral (perpendicular ao eixo de ataque), mais curva, pra
	# contornar até fechar no gol.
	var eixo_ataque := Vector2.RIGHT if gol_inimigo_lado() == "direita" else Vector2.LEFT
	var direcao_reta := (alvo - origem).normalized()
	var alinhamento := absf(direcao_reta.dot(eixo_ataque))  # 1.0 = de frente, 0.0 = 90° lateral
	var fator_lateral := 1.0 - alinhamento
	return intensidade_curva * fator_lateral


## --- Opposite Direction ---

func _executar_deslocamento(vetor_arrasto: Vector2) -> void:
	if not _opposite_direction_ativo:
		super._executar_deslocamento(vetor_arrasto)
		return

	_opposite_direction_ativo = false  # uso único por ativação

	var direcao_travada := _travar_direcao_cardinal(vetor_arrasto.normalized())
	var destino := global_position + direcao_travada * opposite_direction_distancia
	MovimentoSuave.mover(self, destino, 0.2)  # rápido — é um "teleporte", não um deslize


func _travar_direcao_cardinal(direcao: Vector2) -> Vector2:
	# arredonda pra uma das 4 direções fixas, com base em qual eixo o
	# jogador puxou mais forte
	if absf(direcao.x) > absf(direcao.y):
		return Vector2.RIGHT if direcao.x > 0 else Vector2.LEFT
	return Vector2.DOWN if direcao.y > 0 else Vector2.UP
