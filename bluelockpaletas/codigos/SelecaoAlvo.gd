extends Node

## AUTOLOAD (Singleton).
## Configure em: Project Settings > Autoload > adicione este script
## com o nome "SelecaoAlvo".
##
## Modo genérico de "selecione algo pra continuar a jogada": qualquer
## habilidade que precise de um clique do jogador pode reaproveitar
## isso, sem duplicar lógica de input. Dois tipos de seleção:
##
## - pedir_alvo(): espera um clique em OUTRO BOTÃO (ex: escolher o
##   aliado do passe clássico do Fine-Tuning do Hiori).
## - pedir_ponto(): espera um clique em QUALQUER LUGAR do campo, mesmo
##   onde não existe nenhum botão (ex: Millimeter Precision do Hiori,
##   que escolhe um PONTO exato de chegada, não um aliado).
##
## Enquanto qualquer uma das duas está pendente, os cliques em botões
## NÃO abrem o painel de habilidade normal nem iniciam arrasto (ver
## Botao.gd, _input) — são consumidos aqui como parte da seleção.

enum Modo { NENHUM, ALVO, PONTO }

var _modo: Modo = Modo.NENHUM
var _pedido_de: Botao = null
var _callback: Callable = Callable()


func pedir_alvo(quem_pediu: Botao, callback: Callable, mensagem: String = "Selecione um alvo") -> void:
	_modo = Modo.ALVO
	_pedido_de = quem_pediu
	_callback = callback
	Eventos.mensagem_solicitada.emit(mensagem)


func pedir_ponto(quem_pediu: Botao, callback: Callable, mensagem: String = "Selecione um ponto no campo") -> void:
	_modo = Modo.PONTO
	_pedido_de = quem_pediu
	_callback = callback
	Eventos.mensagem_solicitada.emit(mensagem)


func esta_selecionando() -> bool:
	return _modo != Modo.NENHUM


func esta_selecionando_ponto() -> bool:
	return _modo == Modo.PONTO


func processar_clique(botao_clicado: Botao) -> void:
	# chamado pelo Botao.gd quando QUALQUER botão é clicado, enquanto
	# uma seleção de ALVO (não de ponto) está pendente. Se o modo atual
	# for PONTO, isso é um no-op de propósito: o clique segue adiante
	# pelo pipeline de input até chegar em _unhandled_input() aqui
	# embaixo, que trata como escolha de ponto.
	if _modo != Modo.ALVO:
		return
	_concluir(botao_clicado)


func processar_clique_no_campo(posicao_global: Vector2) -> void:
	if _modo != Modo.PONTO:
		return
	_concluir(posicao_global)


func _concluir(valor) -> void:
	var callback := _callback
	_modo = Modo.NENHUM
	_pedido_de = null
	_callback = Callable()

	if callback.is_valid():
		callback.call(valor)


func cancelar() -> void:
	if _modo == Modo.NENHUM:
		return
	_modo = Modo.NENHUM
	_pedido_de = null
	_callback = Callable()
	Eventos.mensagem_solicitada.emit("Seleção cancelada.")


func _input(event: InputEvent) -> void:
	# IMPORTANTE: usamos _input() (não _unhandled_input()) de propósito.
	# _unhandled_input() só recebe o evento se NENHUM Control da UI (ex:
	# o painel de botões de habilidade) já tiver "consumido" o clique
	# antes — e é muito fácil algum Control (mesmo invisível, cobrindo a
	# tela) engolir o clique sem querer, fazendo o campo nunca receber
	# nada. _input() roda ANTES da UI, então o clique no campo é
	# capturado garantidamente.
	if not esta_selecionando_ponto():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var camera := get_viewport().get_camera_2d()
		var posicao_global := camera.get_global_mouse_position() if camera else get_viewport().get_mouse_position()
		processar_clique_no_campo(posicao_global)
		get_viewport().set_input_as_handled()
