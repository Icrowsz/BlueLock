extends Node

## AUTOLOAD (Singleton).
## Configure em: Project Settings > Autoload > adicione este script
## com o nome "SelecaoAlvo".
##
## Modo genérico de "selecione um alvo": qualquer habilidade futura que
## precise que o jogador clique em outro botão (não só o One Two do
## Kurona) pode reaproveitar isso, sem duplicar lógica de input.
##
## Enquanto uma seleção está pendente, os cliques em botões NÃO abrem o
## painel de habilidade normal (ver Botao.gd, _input) — são consumidos
## aqui como a escolha do alvo.

var _pedido_de: Botao = null
var _callback: Callable = Callable()


func pedir_alvo(quem_pediu: Botao, callback: Callable, mensagem: String = "Selecione um alvo") -> void:
	_pedido_de = quem_pediu
	_callback = callback
	Eventos.mensagem_solicitada.emit(mensagem)


func esta_selecionando() -> bool:
	return _pedido_de != null


func processar_clique(botao_clicado: Botao) -> void:
	# chamado pelo Botao.gd quando QUALQUER botão é clicado, enquanto
	# uma seleção está pendente.
	if not esta_selecionando():
		return

	var callback := _callback
	_pedido_de = null
	_callback = Callable()

	if callback.is_valid():
		callback.call(botao_clicado)


func cancelar() -> void:
	if not esta_selecionando():
		return
	_pedido_de = null
	_callback = Callable()
	Eventos.mensagem_solicitada.emit("Seleção cancelada.")
