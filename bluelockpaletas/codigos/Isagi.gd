extends Botao
class_name Isagi

## Isagi Yoichi
##
## - Chute Direto: chute médio (150), reto e teleguiado direto no gol inimigo.
##   Custa a ação de habilidade do turno. Cooldown de 5 turnos.
##
## - Metavisão: ativa uma prévia de trajetória bem mais longa e precisa
##   que a mira normal (com ricochete em paredes/outros botões, e
##   continua prevendo pra onde a BOLA vai depois de ser atingida). NÃO
##   custa a ação de habilidade — só entra em cooldown de 4 turnos.
##   O DESENHO em si (linha_mira, linha_trajetoria_bola,
##   alcance_metavisao, etc.) mora no Botao.gd base agora — generalizado
##   pra também servir a habilidades que CONCEDEM isso a outros (ex:
##   Metavisão do Niko, nos aliados). Aqui só ativamos a flag própria.

@export_group("Chute Direto")
@export var forca_chute_direto: float = 150.0
@export var cooldown_chute_direto: int = 5

@export_group("Metavisão")
@export var cooldown_metavisao: int = 5

var metavisao_ativa: bool = false


## --- Ganchos do sistema de habilidades (ver Botao.gd) ---

func habilidades_proprias() -> Array[String]:
	return ["Chute Direto", "Metavisão"]


func _habilidade_propria_consome_acao(nome: String) -> bool:
	return nome != "Metavisão"


func _requisito_extra_propria(nome: String) -> String:
	if nome == "Chute Direto" and bola_no_alcance == null:
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


func _tem_visao_estendida_propria() -> bool:
	return metavisao_ativa


func _apos_chute(sucesso: bool) -> void:
	super._apos_chute(sucesso)
	if sucesso:
		metavisao_ativa = false
	if linha_trajetoria_bola:
		linha_trajetoria_bola.visible = false
