extends PopupPanel

## SeletorDePersonagem — versão auto-contida.
##
## Diferença da versão anterior: NENHUM nó precisa ser montado à mão na
## cena. O script cria a própria árvore (margem, título, grid de
## cartas) inteira por código, dentro de _ready() — então não existe
## Nome Único pra configurar errado, nem estrutura de nós pra bater com
## um comentário. A ÚNICA coisa que a cena .tscn precisa ter é um
## PopupPanel vazio com este script anexado.
##
## A lista de personagens vem direto de Personagens.nomes_disponiveis()
## — é a única "conexão" que existe, e é automática: qualquer
## personagem novo que você adicionar em Personagens.gd já aparece
## aqui, sem precisar tocar neste arquivo.

## As linhas @export abaixo são o que faz esses valores aparecerem no
## painel INSPECTOR do Godot quando você seleciona o nó
## SeletorDePersonagem na árvore da cena — dá pra digitar um número
## novo ali e testar na hora (Play), sem precisar abrir o script.
## "const" (mais abaixo) NÃO aparece no Inspector, só @export aparece.
@export var tamanho_popup: Vector2i = Vector2i(720, 520)
@export var colunas: int = 6
@export var tamanho_carta: Vector2 = Vector2(96, 120)
@export var tamanho_retrato: Vector2 = Vector2(72, 72)
@export var cor_selecionada: Color = Color(0.55, 1.0, 0.85)  ## destaque de quem já era a escolha atual

signal personagem_escolhido(nome: String)

var _label_titulo: Label
var _grid: GridContainer


func _ready() -> void:
	visible = false
	_montar_esqueleto()


## Cria margem > VBox > (título + ScrollContainer > grid) — a MESMA
## estrutura que antes você tinha que montar manualmente no editor,
## só que garantida por código: não tem como "esquecer" um nó ou
## nomear errado, porque não existe nó nenhum pra configurar.
func _montar_esqueleto() -> void:
	var margem := MarginContainer.new()
	margem.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margem.add_theme_constant_override(lado, 20)
	add_child(margem)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margem.add_child(vbox)

	_label_titulo = Label.new()
	_label_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_label_titulo)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # sem isso, ele não cresce pra acompanhar o popup maior — fica do tamanho mínimo dos filhos
	vbox.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = colunas
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)


func abrir(titulo: String, nome_atual: String = "") -> void:
	_label_titulo.text = titulo
	_montar_cartas(nome_atual)
	popup_centered(tamanho_popup)


func _montar_cartas(nome_atual: String) -> void:
	for filho in _grid.get_children():
		filho.queue_free()

	# única "conexão" real com o resto do jogo: a lista vem inteira
	# daqui, então adicionar um personagem novo em Personagens.gd já
	# basta pra ele aparecer no seletor, sem tocar neste arquivo
	for nome in Personagens.nomes_disponiveis():
		_grid.add_child(_criar_carta(nome, nome == nome_atual))


func _criar_carta(nome: String, selecionada: bool) -> Control:
	var botao := Button.new()
	botao.custom_minimum_size = tamanho_carta
	botao.text = ""  # o texto vai no Label de dentro, não no próprio botão
	if selecionada:
		botao.modulate = cor_selecionada

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE  # deixa o clique passar pro Button por trás
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	botao.add_child(vbox)

	var retrato := TextureRect.new()
	retrato.texture = _retrato_do_personagem(nome)
	retrato.custom_minimum_size = tamanho_retrato
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(retrato)

	var rotulo := Label.new()
	rotulo.text = nome
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(rotulo)

	botao.pressed.connect(func() -> void:
		hide()
		personagem_escolhido.emit(nome)
	)

	return botao


## Extensões de imagem aceitas pro retrato, na ORDEM em que são
## testadas — se você tiver o mesmo personagem em mais de um formato
## por engano, o primeiro da lista que existir "ganha". Ajuste a
## ordem/lista aqui se quiser priorizar outro formato.
@export var extensoes_retrato: Array[String] = ["png", "jpg", "jpeg", "webp", "svg"]

func _retrato_do_personagem(nome: String) -> Texture2D:
	# AJUSTE esse caminho/convenção pro padrão real dos seus retratos.
	var nome_arquivo := nome.replace("💫", "").strip_edges()

	for extensao in extensoes_retrato:
		var caminho := "res://imagens/retratos/%s.%s" % [nome_arquivo, extensao]
		if ResourceLoader.exists(caminho):
			return load(caminho)

	return null  # sem retrato cadastrado ainda (em nenhum formato aceito): mostra só o nome, sem quebrar nada
