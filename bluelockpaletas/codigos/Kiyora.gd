extends Botao
class_name Kiyora

## Kiyora
##
## - Injustice: diferente de um passe automático de alvo único (ex:
##   Shark Assault do Kurona, que sorteia sozinho), aqui a Kiyora
##   escolhe DOIS alvos manualmente (um de cada vez, clicando); depois
##   dos dois escolhidos, a bola vai automaticamente — passe garantido,
##   sem força, sem chance de interceptação (mesma técnica do Shark
##   Assault) — pra UM dos dois, sorteado na hora (50/50).
##
## - Break Dance: um "drible comum": em vez do deslocamento normal por
##   arrasto, aplica um impulso bem mais fraco (finta curta), e concede
##   de volta uma ação de HABILIDADE pessoal — ou seja, gasta a ação de
##   habilidade pra ativar, gasta a ação de movimento pra executar o
##   drible fraco, e devolve uma ação de habilidade no final. Na prática
##   ela "se paga" na economia de ações de habilidade.

@export_group("Injustice")
@export var cooldown_injustice: int = 5
@export var duracao_passe_injustice: float = 0.5

@export_group("Break Dance")
@export var multiplicador_forca_break_dance: float = 0.35
@export var cooldown_break_dance: int = 3

const NOME_INJUSTICE := "Injustice"
const NOME_BREAK_DANCE := "Break Dance"

var _break_dance_ativo: bool = false
var _injustice_primeiro_alvo: Botao = null


func habilidades_proprias() -> Array[String]:
	return [NOME_INJUSTICE, NOME_BREAK_DANCE]


func _habilidade_propria_consome_acao(nome: String) -> bool:
	if nome == NOME_INJUSTICE:
		# consumida manualmente só quando os DOIS alvos forem escolhidos
		# e o passe realmente sair — cancelar no meio da seleção (botão
		# direito/Esc) não desperdiça a ação à toa
		return false
	return true


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_INJUSTICE and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_INJUSTICE:
			_injustice_primeiro_alvo = null
			SelecaoAlvo.pedir_alvo(self, _on_primeiro_alvo_injustice, "Selecione o PRIMEIRO alvo do Injustice")
		NOME_BREAK_DANCE:
			_break_dance_ativo = true
			iniciar_cooldown(nome, cooldown_break_dance)
			Eventos.mensagem_solicitada.emit("Break Dance ativado! Arraste pra fazer um drible curto.")


## --- Injustice ---

func _on_primeiro_alvo_injustice(alvo: Botao) -> void:
	if alvo == self:
		Eventos.mensagem_solicitada.emit("Escolha outro jogador como primeiro alvo!")
		return
	if alvo.time != time:
		Eventos.mensagem_solicitada.emit("Escolha um companheiro de time como alvo!")
		return

	_injustice_primeiro_alvo = alvo
	SelecaoAlvo.pedir_alvo(self, _on_segundo_alvo_injustice, "Selecione o SEGUNDO alvo do Injustice")


func _on_segundo_alvo_injustice(alvo: Botao) -> void:
	var alvo1 := _injustice_primeiro_alvo
	_injustice_primeiro_alvo = null

	if alvo == self or alvo == alvo1:
		Eventos.mensagem_solicitada.emit("Escolha um segundo alvo diferente do primeiro!")
		return
	if alvo.time != time:
		Eventos.mensagem_solicitada.emit("Escolha um companheiro de time como alvo!")
		return

	var bola := bola_no_alcance
	if not bola:
		Eventos.mensagem_solicitada.emit("A bola não está mais por perto!")
		return

	consumir_acao_habilidade()
	iniciar_cooldown(NOME_INJUSTICE, cooldown_injustice)

	var escolhido: Botao = alvo1 if randf() < 0.5 else alvo
	bola.mover_para_com_trajetoria(escolhido.global_position, duracao_passe_injustice)
	Eventos.mensagem_solicitada.emit("Injustice! O passe saiu pra %s." % escolhido.name)


## --- Break Dance ---

func _executar_deslocamento(vetor_arrasto: Vector2) -> void:
	if not _break_dance_ativo:
		super._executar_deslocamento(vetor_arrasto)
		return

	_break_dance_ativo = false  # uso único por ativação

	var forca := (vetor_arrasto * multiplicador_forca * multiplicador_forca_chute_total() * multiplicador_forca_break_dance) \
		.limit_length(forca_maxima * multiplicador_forca_break_dance)
	apply_central_impulse(forca)

	conceder_acao_habilidade_extra(1)
