extends Control

## Anexe este script na cena de Escalação.
##
## Estrutura de nós esperada (monte no editor, marcados como Nome Único %):
##
## Control (Escalacao)  <- este script
##   ├── ContainerFormacoesTimeA (HBoxContainer)   <- cartões de formação do Time A
##   ├── ContainerTimeA (VBoxContainer)
##   ├── ContainerFormacoesTimeB (HBoxContainer)   <- cartões de formação do Time B
##   ├── ContainerTimeB (VBoxContainer)
##   ├── BotaoConfirmar (Button)
##   └── SeletorDePersonagem (instância de SeletorDePersonagem.tscn)
##
## Os dois times escolhem a formação de forma TOTALMENTE independente —
## podem repetir a mesma ou usar formações diferentes. Cada seletor tem
## seu próprio ButtonGroup, então clicar num cartão do Time A nunca
## desmarca o cartão selecionado do Time B (e vice-versa).
##
## FORMAÇÕES: preencha o array exportado "Formacoes Visuais" no
## Inspector, um item por formação (ver FormacaoVisual.gd) — nome EXATO
## igual ao usado em ConfiguracaoPartida.FORMACOES_3V3/FORMACOES_5V5,
## mais a imagem correspondente. O MESMO array alimenta os dois
## seletores (Time A e Time B); só as formações do MODO atual aparecem.
##
## Gera automaticamente uma linha (rótulo + Button) pra cada posição da
## formação ESCOLHIDA POR AQUELE TIME (ConfiguracaoPartida.
## posicoes_do_time()) — então cada time pode ter uma quantidade e/ou
## nomes de posição diferentes entre si. Clicar no Button de uma linha
## abre o SeletorDePersonagem (grid de cartas com retrato) — só uma
## instância do popup existe, reaproveitada por todas as linhas dos
## dois times.
##
## Trocar de formação (clicando num cartão) reconstrói a lista de
## posição DAQUELE TIME do zero — ConfiguracaoPartida.definir_formacao()
## já limpa a escalação anterior desse time sozinho (a do adversário não
## é afetada).

@onready var container_formacoes_a: HBoxContainer = %ContainerFormacoesTimeA
@onready var container_time_a: VBoxContainer = $ContainerTimeA
@onready var container_formacoes_b: HBoxContainer = %ContainerFormacoesTimeB
@onready var container_time_b: VBoxContainer = %ContainerTimeB
@onready var botao_confirmar: Button = %BotaoConfirmar
@onready var seletor: PopupPanel = %SeletorDePersonagem

const CENA_JOGO := "res://cenas/Campo.tscn"  # ajuste o caminho

## Um item por formação: nome exato + imagem. Preencha no Inspector —
## arraste as suas artes prontas aqui (ver FormacaoVisual.gd). O MESMO
## array é usado pros seletores dos dois times.
@export var formacoes_visuais: Array[FormacaoVisual] = []

@export_group("Aparência do cartão de formação")
@export var tamanho_imagem_formacao: Vector2 = Vector2(96, 96)
@export var cor_formacao_selecionada: Color = Color(1.0, 0.85, 0.2)
@export var cor_formacao_normal: Color = Color(1, 1, 1)

# Cada time tem seu PRÓPRIO ButtonGroup — assim escolher uma formação
# pro Time A nunca desmarca visualmente a seleção do Time B, mesmo que
# os dois estejam usando o mesmo nome de formação ao mesmo tempo.
var _grupo_formacoes_a := ButtonGroup.new()
var _grupo_formacoes_b := ButtonGroup.new()

# Só existe UM seletor de personagem compartilhado por todas as linhas
# — então precisamos guardar "pra qual linha/posição foi que a gente
# abriu o popup", pra saber onde aplicar a escolha quando
# personagem_escolhido disparar (ver _on_personagem_escolhido).
var _escalacao_ativa: Dictionary = {}
var _posicao_ativa: String = ""
var _botao_ativo: Button = null


func _ready() -> void:
	_montar_formacoes("A")
	_montar_formacoes("B")
	_montar_time("A")
	_montar_time("B")
	botao_confirmar.pressed.connect(_on_confirmar_pressionado)
	seletor.personagem_escolhido.connect(_on_personagem_escolhido)


## --- Helpers "por time" — trocam qual conjunto de nós/dados usar ---

func _container_formacoes(sigla_time: String) -> HBoxContainer:
	return container_formacoes_a if sigla_time == "A" else container_formacoes_b


func _grupo_formacoes(sigla_time: String) -> ButtonGroup:
	return _grupo_formacoes_a if sigla_time == "A" else _grupo_formacoes_b


func _container_time(sigla_time: String) -> VBoxContainer:
	return container_time_a if sigla_time == "A" else container_time_b


func _escalacao_do_time(sigla_time: String) -> Dictionary:
	return ConfiguracaoPartida.escalacao_a if sigla_time == "A" else ConfiguracaoPartida.escalacao_b


## --- Seleção de formação (uma por time, independentes) ---

func _montar_formacoes(sigla_time: String) -> void:
	var container := _container_formacoes(sigla_time)
	for filho in container.get_children():
		filho.queue_free()

	var disponiveis: Array = ConfiguracaoPartida.formacoes_disponiveis()

	for visual in formacoes_visuais:
		if visual.nome not in disponiveis:
			continue  # formação de outro modo — ignora silenciosamente
		container.add_child(_criar_cartao_formacao(visual, sigla_time))


func _criar_cartao_formacao(visual: FormacaoVisual, sigla_time: String) -> Control:
	var esta_selecionada := visual.nome == ConfiguracaoPartida.formacao_do_time(sigla_time)

	var cartao := VBoxContainer.new()
	cartao.alignment = BoxContainer.ALIGNMENT_CENTER

	var botao := Button.new()
	botao.custom_minimum_size = tamanho_imagem_formacao
	botao.toggle_mode = true
	botao.button_group = _grupo_formacoes(sigla_time)
	botao.button_pressed = esta_selecionada
	botao.modulate = cor_formacao_selecionada if esta_selecionada else cor_formacao_normal

	if visual.imagem:
		var textura_rect := TextureRect.new()
		textura_rect.texture = visual.imagem
		textura_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		textura_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		textura_rect.custom_minimum_size = tamanho_imagem_formacao
		textura_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # deixa o clique passar direto pro Button de baixo
		botao.add_child(textura_rect)

	botao.pressed.connect(func() -> void:
		_on_formacao_escolhida(sigla_time, visual.nome)
	)

	var rotulo := Label.new()
	rotulo.text = visual.nome
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	cartao.add_child(botao)
	cartao.add_child(rotulo)
	return cartao


func _on_formacao_escolhida(sigla_time: String, nome: String) -> void:
	if nome == ConfiguracaoPartida.formacao_do_time(sigla_time):
		return  # já é essa — evita limpar a escalação à toa

	ConfiguracaoPartida.definir_formacao(sigla_time, nome)

	# só o time que trocou precisa reconstruir — o adversário nem a
	# escalação dele foram afetados
	_montar_formacoes(sigla_time)
	_montar_time(sigla_time)


## --- Escalação por posição ---

func _montar_time(sigla_time: String) -> void:
	var container := _container_time(sigla_time)
	var escalacao := _escalacao_do_time(sigla_time)

	for filho in container.get_children():
		filho.queue_free()

	for posicao in ConfiguracaoPartida.posicoes_do_time(sigla_time):
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
