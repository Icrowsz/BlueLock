extends Botao
class_name Igaguri

## Igaguri
##
## Personagem simples: as duas habilidades só escolhem um inimigo BEM
## PRÓXIMO (distância simples a partir do próprio Igaguri — não o
## AreaAlcance, que é só pra detectar a bola) e aplicam um bloqueio já
## pronto na classe base, sem nenhuma lógica nova:
##
## - Malicia: aplicar_bloqueio_habilidade() no alvo por 3 turnos —
##   ele fica sem poder usar NENHUMA habilidade própria ou concedida
##   nesse período. Cooldown de 5 turnos a partir do uso.
##
## - Dharma Chains: aplicar_bloqueio_movimento() no alvo por 3 turnos —
##   ele fica sem poder se deslocar (arrastar) nesse período. Cooldown
##   de 5 turnos a partir do uso.

@export_group("Malicia")
@export var alcance_malicia: float = 150.0
@export var duracao_bloqueio_malicia: int = 3
@export var cooldown_malicia: int = 6

@export_group("Dharma Chains")
@export var alcance_dharma_chains: float = 150.0
@export var duracao_bloqueio_dharma_chains: int = 3
@export var cooldown_dharma_chains: int = 6

const NOME_MALICIA := "Malicia"
const NOME_DHARMA_CHAINS := "Dharma Chains"


func habilidades_proprias() -> Array[String]:
	return [NOME_MALICIA, NOME_DHARMA_CHAINS]


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_MALICIA and not _existe_inimigo_no_alcance(alcance_malicia):
		return "Nenhum inimigo próximo o bastante para usar %s!" % NOME_MALICIA
	if nome == NOME_DHARMA_CHAINS and not _existe_inimigo_no_alcance(alcance_dharma_chains):
		return "Nenhum inimigo próximo o bastante para usar %s!" % NOME_DHARMA_CHAINS
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_MALICIA:
			_iniciar_malicia()
			iniciar_cooldown(nome, cooldown_malicia)
		NOME_DHARMA_CHAINS:
			_iniciar_dharma_chains()
			iniciar_cooldown(nome, cooldown_dharma_chains)


## --- Malicia ---

func _iniciar_malicia() -> void:
	SelecaoAlvo.pedir_alvo(self, func(alvo: Botao) -> void:
		_confirmar_malicia(alvo)
	, "Escolha o inimigo alvo da Malicia")


func _confirmar_malicia(alvo: Botao) -> void:
	if not _eh_inimigo_valido(alvo, alcance_malicia):
		return

	alvo.aplicar_bloqueio_habilidade(duracao_bloqueio_malicia)
	Eventos.mensagem_solicitada.emit("Malicia! As habilidades de %s ficaram bloqueadas por %d turno(s)." % [alvo.name, duracao_bloqueio_malicia])


## --- Dharma Chains ---

func _iniciar_dharma_chains() -> void:
	SelecaoAlvo.pedir_alvo(self, func(alvo: Botao) -> void:
		_confirmar_dharma_chains(alvo)
	, "Escolha o inimigo alvo do Dharma Chains")


func _confirmar_dharma_chains(alvo: Botao) -> void:
	if not _eh_inimigo_valido(alvo, alcance_dharma_chains):
		return

	alvo.aplicar_bloqueio_movimento(duracao_bloqueio_dharma_chains)
	Eventos.mensagem_solicitada.emit("Dharma Chains! O deslocamento de %s ficou bloqueado por %d turno(s)." % [alvo.name, duracao_bloqueio_dharma_chains])


## --- Compartilhado ---

func _existe_inimigo_no_alcance(alcance: float) -> bool:
	for nodo in get_tree().get_nodes_in_group("botoes"):
		var botao := nodo as Botao
		if botao and botao != self and botao.time != time and global_position.distance_to(botao.global_position) <= alcance:
			return true
	return false


func _eh_inimigo_valido(alvo: Botao, alcance: float) -> bool:
	if alvo == self or alvo.time == time:
		Eventos.mensagem_solicitada.emit("Escolha um INIMIGO, não um aliado!")
		return false
	if global_position.distance_to(alvo.global_position) > alcance:
		Eventos.mensagem_solicitada.emit("Esse alvo não está próximo o bastante!")
		return false
	return true
