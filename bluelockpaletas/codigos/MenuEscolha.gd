extends Node

## AUTOLOAD (Singleton).
## Configure em: Project Settings > Autoload > adicione este script
## com o nome "MenuEscolha".
##
## Terceiro modo de "peça uma entrada do jogador pra continuar a
## jogada", irmão do SelecaoAlvo.gd (que cobre ALVO e PONTO no campo).
## Este aqui cobre ESCOLHA ENTRE OPÇÕES NOMEADAS — não é um clique no
## campo/num botão, é escolher um item de uma lista curta (ex: a Copy
## do Reo perguntando qual habilidade copiar). Qualquer habilidade
## futura que precise de um "menu de opções" pode reaproveitar isso.
##
## Não mexe em input nenhum diretamente — quem desenha o menu e
## devolve a escolha é a UI (ver UIMenuEscolha.gd). Este singleton só
## guarda o callback pendente e emite os sinais que a UI escuta.

signal opcoes_solicitadas(titulo: String, opcoes: Array[String])
signal escolha_cancelada

var _callback: Callable = Callable()
var _ativo: bool = false


func pedir_opcao(opcoes: Array[String], callback: Callable, titulo: String = "Escolha uma opção") -> void:
	# Só uma escolha pendente por vez: pedir de novo enquanto já tem uma
	# ativa substitui a anterior (mesma regra de "só a mais recente
	# importa" usada no resto do jogo, ex: SelecaoAlvo).
	_callback = callback
	_ativo = true
	opcoes_solicitadas.emit(titulo, opcoes)


func esta_pedindo() -> bool:
	return _ativo


func escolher(opcao: String) -> void:
	# Chamado pela UI quando o jogador clica numa das opções do leque.
	if not _ativo:
		return

	var callback := _callback
	_ativo = false
	_callback = Callable()

	if callback.is_valid():
		callback.call(opcao)


func cancelar() -> void:
	if not _ativo:
		return
	_ativo = false
	_callback = Callable()
	escolha_cancelada.emit()
