extends Botao
class_name Kuso

## Kuso
##
## - Best Move: passe REAL (chute teleguiado de verdade, pode ser
##   interceptado por um oponente no caminho) pro aliado que o jogador
##   escolher. Consumida manualmente só quando o alvo é confirmado, pro
##   cancelamento não gastar a ação à toa. Cooldown de 6 turnos.
##
## - Godwin Dribble: concede mais uma ação de DESLOCAMENTO (com alcance
##   de arrasto reduzido) E mais uma ação de HABILIDADE (essa sim
##   padrão, sem restrição nenhuma) nesse turno — reaproveita
##   conceder_acao_movimento_extra() e conceder_acao_habilidade_extra()
##   (já existem em Botao.gd). O multiplicador_distancia_arrasto() fica
##   reduzido só pro PRÓXIMO arrasto (mesma lógica do Since I'm here do
##   Onazi: a ação bônus é sempre consumida primeiro). Não custa a
##   própria ação de habilidade do turno (ela É uma das ações extras
##   concedidas). Cooldown de 7 turnos.

@export_group("Best Move")
@export var forca_best_move: float = 150.0
@export var cooldown_best_move: int = 8

@export_group("Godwin Dribble")
@export var godwin_dribble_multiplicador_distancia: float = 0.6
@export var cooldown_godwin_dribble: int = 7

const NOME_BEST_MOVE := "Best Move"
const NOME_GODWIN_DRIBBLE := "Godwin Dribble"

var _reduzir_distancia_do_proximo_deslocamento: bool = false


## --- Ganchos do sistema de habilidades (ver Botao.gd) ---

func habilidades_proprias() -> Array[String]:
	return [NOME_BEST_MOVE, NOME_GODWIN_DRIBBLE]


func _habilidade_propria_consome_acao(nome: String) -> bool:
	if nome == NOME_BEST_MOVE:
		return false  # consumida manualmente só quando o alvo é confirmado
	if nome == NOME_GODWIN_DRIBBLE:
		return false  # ela própria já É uma das ações extras concedidas
	return true


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_BEST_MOVE and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_BEST_MOVE:
			_iniciar_best_move()
		NOME_GODWIN_DRIBBLE:
			_executar_godwin_dribble()
			iniciar_cooldown(nome, cooldown_godwin_dribble)


## --- Best Move ---

func _iniciar_best_move() -> void:
	SelecaoAlvo.pedir_alvo(self, _on_alvo_best_move_escolhido, "Selecione um aliado para o Best Move")


func _on_alvo_best_move_escolhido(alvo: Botao) -> void:
	if alvo == self:
		Eventos.mensagem_solicitada.emit("Escolha outro jogador como alvo!")
		return

	if alvo.time != time:
		Eventos.mensagem_solicitada.emit("Escolha um companheiro de time como alvo!")
		return

	var bola := bola_no_alcance
	if not bola:
		Eventos.mensagem_solicitada.emit("A bola não está mais por perto — Best Move cancelado.")
		return

	var direcao := (alvo.global_position - bola.global_position).normalized()
	bola.receber_chute_teleguiado(direcao, forca_best_move)

	consumir_acao_habilidade()
	iniciar_cooldown(NOME_BEST_MOVE, cooldown_best_move)
	Eventos.mensagem_solicitada.emit("Best Move! Passe enviado pro aliado escolhido — pode ser interceptado.")


## --- Godwin Dribble ---

func _executar_godwin_dribble() -> void:
	conceder_acao_movimento_extra(1)
	conceder_acao_habilidade_extra(1)
	_reduzir_distancia_do_proximo_deslocamento = true
	Eventos.mensagem_solicitada.emit("Godwin Dribble! Mais uma ação de movimento (deslocamento menor) e mais uma ação de habilidade.")


func multiplicador_distancia_arrasto() -> float:
	# mesma lógica do Since I'm here do Onazi: a ação de movimento BÔNUS
	# é sempre consumida antes da normal (ver _soltar_e_chutar em
	# Botao.gd), então o PRÓXIMO arrasto é garantidamente o que usa a
	# ação extra concedida aqui — só esse precisa vir com alcance menor.
	return godwin_dribble_multiplicador_distancia if _reduzir_distancia_do_proximo_deslocamento else 1.0


func _apos_chute(sucesso: bool) -> void:
	super._apos_chute(sucesso)
	if sucesso and _reduzir_distancia_do_proximo_deslocamento:
		_reduzir_distancia_do_proximo_deslocamento = false
