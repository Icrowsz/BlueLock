extends Control

## Anexe este script na cena de Escalação.
##
## Estrutura de nós esperada (monte no editor, marcados como Nome Único %):
##
## Control (Escalacao)  <- este script
##   ├── ContainerTimeA (VBoxContainer)
##   ├── ContainerTimeB (VBoxContainer)
##   ├── BotaoConfirmar (Button)
##   └── SeletorDePersonagem (instância de SeletorDePersonagem.tscn)
##
## Gera automaticamente uma linha (rótulo + Button) pra cada posição de
## ConfiguracaoPartida.posicoes_do_modo(), em cada time — então funciona
## igual pro 3v3 e pro 5v5 sem precisar de tela separada. Clicar no
## Button de uma linha abre o SeletorDePersonagem (grid de cartas com
## retrato) EM VEZ do OptionButton antigo — só uma instância do popup
## existe, reaproveitada por todas as linhas dos dois times.

@onready var container_time_a: VBoxContainer = $ContainerTimeA
@onready var container_time_b: VBoxContainer = %ContainerTimeB
@onready var botao_confirmar: Button = %BotaoConfirmar
@onready var seletor: PopupPanel = %SeletorDePersonagem

const CENA_JOGO := "res://cenas/Campo.tscn"  # ajuste o caminho

# Só existe UM seletor compartilhado por todas as linhas — então
# precisamos guardar "pra qual linha/posição foi que a gente abriu o
# popup", pra saber onde aplicar a escolha quando personagem_escolhido
# disparar (ver _on_personagem_escolhido).
var _escalacao_ativa: Dictionary = {}
var _posicao_ativa: String = ""
var _botao_ativo: Button = null


func _ready() -> void:
	_montar_time(container_time_a, ConfiguracaoPartida.escalacao_a)
	_montar_time(container_time_b, ConfiguracaoPartida.escalacao_b)
	botao_confirmar.pressed.connect(_on_confirmar_pressionado)
	seletor.personagem_escolhido.connect(_on_personagem_escolhido)


func _montar_time(container: VBoxContainer, escalacao: Dictionary) -> void:
	for filho in container.get_children():
		filho.queue_free()

	for posicao in ConfiguracaoPartida.posicoes_do_modo():
		container.add_child(_criar_linha_posicao(posicao, escalacao))


func _criar_linha_posicao(posicao: String, escalacao: Dictionary) -> HBoxContainer:
	var linha := HBoxContainer.new()

	var rotulo := Label.new()
	rotulo.text = posicao
	rotulo.custom_minimum_size = Vector2(160, 0)
	linha.add_child(rotulo)

	var botao := Button.new()
	botao.text = escalacao.get(posicao, "- escolha -")
	botao.custom_minimum_size = Vector2(160, 0)
	botao.pressed.connect(func() -> void:
		# guarda ONDE aplicar a escolha antes de abrir — o seletor é
		# compartilhado, então isso é o que liga o clique de agora à
		# linha certa quando personagem_escolhido chegar
		_escalacao_ativa = escalacao
		_posicao_ativa = posicao
		_botao_ativo = botao
		seletor.abrir("Escolha o %s" % posicao, escalacao.get(posicao, ""))
	)

	linha.add_child(botao)
	return linha


func _on_personagem_escolhido(nome: String) -> void:
	_escalacao_ativa[_posicao_ativa] = nome
	_botao_ativo.text = nome


func _on_confirmar_pressionado() -> void:
	if not ConfiguracaoPartida.escalacao_completa():
		Eventos.mensagem_solicitada.emit("Escolha um personagem pra cada posição, nos dois times!")
		return
	get_tree().change_scene_to_file(CENA_JOGO)
