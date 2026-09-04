extends Botao
class_name Chigiri

## Hyoma Chigiri
##
## - Accelerate: por 4 turnos, aumenta o alcance da mira e a força do
##   chute normal (por arrasto). Cooldown de 5 turnos.
##
## - 44 Panther Shot: chute teleguiado no gol inimigo (igual ao Chute
##   Direto do Isagi), só que mais fraco na base — ganha um bônus de
##   força por turno que o Accelerate estiver ativo no momento do chute
##   (turno 1 de Accelerate = +200; turno 4 = +800, no padrão default).
##   Cooldown de 3 turnos.
##
## Nota de temporização: assim como os cooldowns, a duração do
## Accelerate é contada em trocas de turno GLOBAIS (de qualquer time),
## seguindo o mesmo padrão já usado no resto do jogo — não só nos
## turnos do próprio time do Chigiri.

@export_group("Accelerate")
@export var accelerate_duracao: int = 4
@export var accelerate_multiplicador_distancia: float = 1.6
@export var accelerate_multiplicador_forca: float = 1.6
@export var cooldown_accelerate: int = 5

@export_group("44 Panther Shot")
@export var forca_base_panther_shot: float = 900.0  # mais fraco que o Chute Direto padrão (1400)
@export var bonus_forca_por_turno_accelerate: float = 200.0
@export var cooldown_panther_shot: int = 3

var accelerate_turnos_restantes: int = 0
var accelerate_turnos_ativos: int = 0

const NOME_ACCELERATE := "Accelerate"
const NOME_PANTHER_SHOT := "44 Panther Shot"


func habilidades_proprias() -> Array[String]:
	return [NOME_ACCELERATE, NOME_PANTHER_SHOT]


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_PANTHER_SHOT and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_ACCELERATE:
			_executar_accelerate()
			iniciar_cooldown(nome, cooldown_accelerate)
		NOME_PANTHER_SHOT:
			_executar_panther_shot()
			iniciar_cooldown(nome, cooldown_panther_shot)


## --- Accelerate ---

func _executar_accelerate() -> void:
	accelerate_turnos_restantes = accelerate_duracao
	accelerate_turnos_ativos = 1
	Eventos.mensagem_solicitada.emit("Accelerate ativado! Mira e força de chute aumentadas.")


func multiplicador_distancia_arrasto() -> float:
	return accelerate_multiplicador_distancia if accelerate_turnos_restantes > 0 else 1.0


func multiplicador_forca_chute() -> float:
	return accelerate_multiplicador_forca if accelerate_turnos_restantes > 0 else 1.0


func _on_turno_mudou(time: String) -> void:
	super._on_turno_mudou(time)  # mantém cooldowns e concessões funcionando normalmente

	if accelerate_turnos_restantes <= 0:
		return

	accelerate_turnos_restantes -= 1
	if accelerate_turnos_restantes > 0:
		accelerate_turnos_ativos = mini(accelerate_turnos_ativos + 1, accelerate_duracao)
	else:
		accelerate_turnos_ativos = 0
		Eventos.mensagem_solicitada.emit("Accelerate do Chigiri acabou!")


## --- 44 Panther Shot ---

func _executar_panther_shot() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	var bonus := accelerate_turnos_ativos * bonus_forca_por_turno_accelerate
	var forca_final := forca_base_panther_shot + bonus

	var direcao := (gol.ponto_para_mira() - bola.global_position).normalized()
	bola.receber_chute_teleguiado(direcao, forca_final)
