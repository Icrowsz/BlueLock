extends Botao
class_name AlexisNess

## Alexis Ness
##
## - Alohomora: escolhe um aliado; a bola viaja até ele em zigue-zague,
##   igual ao Shark Assault do Kurona (passe "garantido", sem chute
##   físico, sem chance de interceptação — só que aqui o ALVO é
##   escolhido, não aleatório). Cooldown de 5 turnos.
##
## - Expelliarmus: escolhe um inimigo DENTRO DO ALCANCE, desliza até
##   perto dele, e desativa as habilidades dele por 4 turnos
##   (aplicar_bloqueio_habilidade, na base) — além de reduzir a força
##   de deslocamento desse alvo pelo mesmo período
##   (aplicar_reducao_forca, também na base). Cooldown de 6 turnos.

@export_group("Alohomora")
@export var duracao_alohomora: float = 0.6
@export var zigues_alohomora: int = 3
@export var amplitude_zigzag_alohomora: float = 40.0
@export var cooldown_alohomora: int = 5

@export_group("Expelliarmus")
@export var alcance_expelliarmus: float = 250.0  ## distância MÁXIMA até o inimigo pra poder ativar
@export var distancia_parada_do_alvo: float = 50.0
@export var duracao_movimento_expelliarmus: float = 0.5
@export var duracao_bloqueio_habilidade_alvo: int = 4
@export var fracao_reducao_forca_alvo: float = 0.5  ## 0.5 = alvo fica com metade da força de deslocamento
@export var cooldown_expelliarmus: int = 6

const NOME_ALOHOMORA := "Alohomora"
const NOME_EXPELLIARMUS := "Expelliarmus"


func habilidades_proprias() -> Array[String]:
	return [NOME_ALOHOMORA, NOME_EXPELLIARMUS]


func _habilidade_propria_consome_acao(nome: String) -> bool:
	if nome == NOME_ALOHOMORA:
		# consumida manualmente em _completar_alohomora(), só quando o
		# passe de fato sai — cancelar a seleção não desperdiça nada
		return false
	return true  # Expelliarmus consome normalmente


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_ALOHOMORA and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome

	if nome == NOME_EXPELLIARMUS and _inimigo_mais_proximo_no_alcance() == null:
		return "Nenhum inimigo dentro do alcance do Expelliarmus!"

	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_ALOHOMORA:
			SelecaoAlvo.pedir_alvo(self, _completar_alohomora, "Escolha um aliado para o Alohomora")
		NOME_EXPELLIARMUS:
			_executar_expelliarmus()
			iniciar_cooldown(nome, cooldown_expelliarmus)


## --- Alohomora ---

func _completar_alohomora(alvo: Botao) -> void:
	if alvo == self or alvo.time != time:
		Eventos.mensagem_solicitada.emit("Escolha um companheiro de time como alvo!")
		return

	var bola := bola_no_alcance
	if not bola:
		Eventos.mensagem_solicitada.emit("A bola não está mais por perto!")
		return

	bola.mover_para_com_trajetoria_zigzag(alvo.global_position, duracao_alohomora, zigues_alohomora, amplitude_zigzag_alohomora)

	consumir_acao_habilidade()
	iniciar_cooldown(NOME_ALOHOMORA, cooldown_alohomora)
	Eventos.mensagem_solicitada.emit("Alohomora! Passe em zigue-zague enviado pra %s." % alvo.name)


## --- Expelliarmus ---

func _inimigos_em_campo() -> Array[Botao]:
	var lista: Array[Botao] = []
	for nodo in get_tree().get_nodes_in_group("botoes"):
		var botao := nodo as Botao
		if botao and botao.time != time:
			lista.append(botao)
	return lista


func _inimigo_mais_proximo_no_alcance() -> Botao:
	var mais_proximo: Botao = null
	var menor_distancia := alcance_expelliarmus
	for inimigo in _inimigos_em_campo():
		var distancia := global_position.distance_to(inimigo.global_position)
		if distancia <= menor_distancia:
			menor_distancia = distancia
			mais_proximo = inimigo
	return mais_proximo


func _executar_expelliarmus() -> void:
	var alvo := _inimigo_mais_proximo_no_alcance()
	if not alvo:
		return

	alvo.aplicar_bloqueio_habilidade(duracao_bloqueio_habilidade_alvo)
	alvo.aplicar_reducao_forca(fracao_reducao_forca_alvo, duracao_bloqueio_habilidade_alvo)

	var direcao := (global_position - alvo.global_position)
	direcao = direcao.normalized() if direcao.length() > 1.0 else Vector2.RIGHT
	var destino := alvo.global_position + direcao * distancia_parada_do_alvo
	MovimentoSuave.mover(self, destino, duracao_movimento_expelliarmus)

	Eventos.mensagem_solicitada.emit("Expelliarmus! %s ficou sem habilidades e mais lento por %d turnos." % [alvo.name, duracao_bloqueio_habilidade_alvo])
