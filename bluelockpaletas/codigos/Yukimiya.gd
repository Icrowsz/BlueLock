extends Botao
class_name Yukimiya

## Yukimiya Kyosuke
##
## - Gyro Shot: chute com efeito (curva fraca, mesma base do Curve Shot
##   do Rin, só que com intensidade de curva bem menor) no gol inimigo.
##   Como reaproveita receber_chute_curvo(), já ignora colisão com
##   ALIADOS automaticamente (só oponente intercepta). Cooldown de 5
##   turnos.
##
## - Scissors Dribble: concede 3 ações de movimento extras, só PRA ELE
##   (acoes_movimento_bonus, na base), mas cada uma sai mais curta E
##   mais fraca que o normal enquanto durarem — um "drible" de toques
##   rápidos e curtos, não um deslize forte. Some no fim do turno se
##   sobrar alguma sem usar. Cooldown de 5 turnos.

@export_group("Gyro Shot")
@export var forca_gyro_shot: float = 200.0
@export var intensidade_curva_gyro_shot: float = 30.0  ## bem menor que o Curve Shot do Rin (padrão 90)
@export var duracao_curva_gyro_shot: float = 1.0
@export var cooldown_gyro_shot: int = 7

@export_group("Scissors Dribble")
@export var quantidade_acoes_scissors_dribble: int = 3
@export var multiplicador_distancia_scissors_dribble: float = 0.5  ## "curtas"
@export var multiplicador_forca_scissors_dribble: float = 0.6  ## "fracas"
@export var cooldown_scissors_dribble: int = 6

const NOME_GYRO_SHOT := "Gyro Shot"
const NOME_SCISSORS_DRIBBLE := "Scissors Dribble"

var _scissors_dribble_ativo: bool = false


func habilidades_proprias() -> Array[String]:
	return [NOME_GYRO_SHOT, NOME_SCISSORS_DRIBBLE]


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_GYRO_SHOT and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_GYRO_SHOT:
			_executar_gyro_shot()
			iniciar_cooldown(nome, cooldown_gyro_shot)
		NOME_SCISSORS_DRIBBLE:
			_executar_scissors_dribble()
			iniciar_cooldown(nome, cooldown_scissors_dribble)


## --- Gyro Shot ---

func _executar_gyro_shot() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	# parar_ao_chegar = false: é um CHUTE a gol, não um passe — precisa
	# manter a velocidade da curva pra continuar entrando no gol
	bola.receber_chute_curvo(gol.ponto_para_mira(), forca_gyro_shot, time, intensidade_curva_gyro_shot, duracao_curva_gyro_shot, false)


## --- Scissors Dribble ---

func _executar_scissors_dribble() -> void:
	_scissors_dribble_ativo = true
	conceder_acao_movimento_extra(quantidade_acoes_scissors_dribble)
	conceder_acao_habilidade_extra(1)
	Eventos.mensagem_solicitada.emit("Scissors Dribble! Yukimiya ganhou %d deslocamentos curtos e fracos neste turno." % quantidade_acoes_scissors_dribble)


func multiplicador_distancia_arrasto() -> float:
	if _scissors_dribble_ativo and acoes_movimento_bonus > 0:
		return multiplicador_distancia_scissors_dribble
	return 1.0


func multiplicador_forca_chute() -> float:
	if _scissors_dribble_ativo and acoes_movimento_bonus > 0:
		return multiplicador_forca_scissors_dribble
	return 1.0


func _on_turno_mudou(time_iniciado: String) -> void:
	super._on_turno_mudou(time_iniciado)
	# os toques do Scissors Dribble valem só "neste turno" — se sobrar
	# algum sem usar quando o time do Yukimiya passa a vez, expira aqui
	if _scissors_dribble_ativo and time_iniciado != time:
		_scissors_dribble_ativo = false
		acoes_movimento_bonus = 0
