extends Control

## Anexe este script na cena de Escalação.
##
## Estrutura de nós esperada (monte no editor, marcados como Nome Único %):
##
## Control (Escalacao)  <- este script
##   ├── ContainerTimeA (VBoxContainer)
##   ├── ContainerTimeB (VBoxContainer)
##   └── BotaoConfirmar (Button)
##
## Gera automaticamente uma linha (rótulo + OptionButton) pra cada
## posição de ConfiguracaoPartida.posicoes_do_modo(), em cada time —
## então funciona igual pro 3v3 e pro 5v5 sem precisar de tela separada.

@onready var container_time_a: VBoxContainer = $ContainerTimeA
@onready var container_time_b: VBoxContainer = %ContainerTimeB
@onready var botao_confirmar: Button = %BotaoConfirmar

const CENA_JOGO := "res://cenas/Campo.tscn"  # ajuste o caminho


func _ready() -> void:
	_montar_time(container_time_a, ConfiguracaoPartida.escalacao_a)
	_montar_time(container_time_b, ConfiguracaoPartida.escalacao_b)
	botao_confirmar.pressed.connect(_on_confirmar_pressionado)


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

	var opcoes := OptionButton.new()
	opcoes.add_item("- escolha -")
	for nome_personagem in Personagens.nomes_disponiveis():
		opcoes.add_item(nome_personagem)

	# se o jogador voltar pra essa tela, reabre já com a escolha anterior
	if escalacao.has(posicao):
		var indice_atual := opcoes.get_item_count()
		for i in range(opcoes.get_item_count()):
			if opcoes.get_item_text(i) == escalacao[posicao]:
				indice_atual = i
				break
		opcoes.selected = indice_atual

	opcoes.item_selected.connect(func(indice: int) -> void:
		if indice <= 0:
			escalacao.erase(posicao)
		else:
			escalacao[posicao] = opcoes.get_item_text(indice)
	)

	linha.add_child(opcoes)
	return linha


func _on_confirmar_pressionado() -> void:
	if not ConfiguracaoPartida.escalacao_completa():
		Eventos.mensagem_solicitada.emit("Escolha um personagem pra cada posição, nos dois times!")
		return
	get_tree().change_scene_to_file(CENA_JOGO)
