extends Botao
class_name Sendou

## Shuto Sendou
##
## - Star Talent: desloca o Sendou direto pro gol mais próximo em
##   campo — seja o do próprio time ou o inimigo, não importa, é só o
##   mais perto mesmo. Ao chegar, concede uma ação de habilidade extra
##   (só pra ele), permitindo usar o Sabrina Shot (ou outra habilidade)
##   no mesmo turno.
##
## - Sabrina Shot: chute reto e teleguiado no gol inimigo, igual ao
##   Chute Direto do Isagi, só que mais fraco.

@export_group("Star Talent")
@export var duracao_star_talent: float = 0.6
@export var cooldown_star_talent: int = 4  ## não especificado — ajuste como preferir

@export_group("Sabrina Shot")
@export var forca_sabrina_shot: float = 150.0  ## mais fraco que o Chute Direto (1400)
@export var cooldown_sabrina_shot: int = 3  ## não especificado — ajuste como preferir

const NOME_STAR_TALENT := "Star Talent"
const NOME_SABRINA_SHOT := "Sabrina Shot"


func habilidades_proprias() -> Array[String]:
	return [NOME_STAR_TALENT, NOME_SABRINA_SHOT]


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_SABRINA_SHOT and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_STAR_TALENT:
			_executar_star_talent()
			iniciar_cooldown(nome, cooldown_star_talent)
		NOME_SABRINA_SHOT:
			_executar_sabrina_shot()
			iniciar_cooldown(nome, cooldown_sabrina_shot)


## --- Star Talent ---

func _executar_star_talent() -> void:
	var gol := encontrar_gol_mais_proximo()
	if not gol:
		return

	MovimentoSuave.mover(self, gol.ponto_para_mira(), duracao_star_talent, func() -> void:
		conceder_acao_habilidade_extra(1)
		Eventos.mensagem_solicitada.emit("Star Talent! Sendou ganhou mais uma ação de habilidade.")
	)


## --- Sabrina Shot ---

func _executar_sabrina_shot() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	var direcao := (gol.ponto_para_mira() - bola.global_position).normalized()
	bola.receber_chute_teleguiado(direcao, forca_sabrina_shot)
