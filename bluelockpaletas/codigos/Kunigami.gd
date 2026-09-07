extends Botao
class_name Kunigami

## Kunigami
##
## - Lefty Shot: chute forte no gol inimigo (base 300). Se houver algum
##   inimigo dentro do alcance do Kunigami (mesma AreaAlcance usada pra
##   detectar a bola), esse inimigo é empurrado pra longe E o chute sai
##   ainda mais forte (bônus de força). Cooldown de 7 turnos.
##
## - Joker Shove: empurra pra longe os DOIS inimigos mais próximos em
##   campo (não precisa da bola por perto — é controle de área, não um
##   chute). Cooldown de 6 turnos.
##
## Depende de Botao.receber_empurrao(direcao, forca), que precisa
## existir no Botao.gd base (ver instruções no chat).

@export_group("Lefty Shot")
@export var forca_lefty_shot: float = 140.0
@export var bonus_forca_com_inimigo_perto: float = 30.0
@export var forca_empurrao_lefty_shot: float = 250.0
@export var cooldown_lefty_shot: int = 7

@export_group("Joker Shove")
@export var forca_joker_shove: float = 250.0
@export var cooldown_joker_shove: int = 6

const NOME_LEFTY_SHOT := "Lefty Shot"
const NOME_JOKER_SHOVE := "Joker Shove"


func habilidades_proprias() -> Array[String]:
	return [NOME_LEFTY_SHOT, NOME_JOKER_SHOVE]


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_LEFTY_SHOT and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_LEFTY_SHOT:
			_executar_lefty_shot()
			iniciar_cooldown(nome, cooldown_lefty_shot)
		NOME_JOKER_SHOVE:
			_executar_joker_shove()
			iniciar_cooldown(nome, cooldown_joker_shove)


## --- Lefty Shot ---

func _executar_lefty_shot() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	var forca := forca_lefty_shot
	var inimigo := _encontrar_inimigo_no_alcance()
	if inimigo:
		var direcao_empurrao := (inimigo.global_position - global_position).normalized()
		if direcao_empurrao == Vector2.ZERO:
			direcao_empurrao = Vector2.RIGHT
		inimigo.receber_empurrao(direcao_empurrao, forca_empurrao_lefty_shot)
		forca += bonus_forca_com_inimigo_perto

	var direcao_chute := (gol.ponto_para_mira() - bola.global_position).normalized()
	bola.receber_chute_teleguiado(direcao_chute, forca)


func _encontrar_inimigo_no_alcance() -> Botao:
	if not area_alcance:
		return null
	for corpo in area_alcance.get_overlapping_bodies():
		var botao := corpo as Botao
		if botao and botao.time != time:
			return botao
	return null


## --- Joker Shove ---

func _executar_joker_shove() -> void:
	var inimigos := _encontrar_inimigos_mais_proximos(2)
	if inimigos.is_empty():
		Eventos.mensagem_solicitada.emit("Não há inimigos por perto para o Joker Shove!")
		return

	for inimigo in inimigos:
		var direcao := (inimigo.global_position - global_position).normalized()
		if direcao == Vector2.ZERO:
			direcao = Vector2.RIGHT
		inimigo.receber_empurrao(direcao, forca_joker_shove)


func _encontrar_inimigos_mais_proximos(quantidade: int) -> Array[Botao]:
	var inimigos: Array[Botao] = []
	for nodo in get_tree().get_nodes_in_group("botoes"):
		var botao := nodo as Botao
		if botao and botao.time != time:
			inimigos.append(botao)

	inimigos.sort_custom(func(a: Botao, b: Botao) -> bool:
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)

	return inimigos.slice(0, quantidade)
