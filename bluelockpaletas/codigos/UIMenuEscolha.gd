extends CanvasLayer

## Painel do "leque de opções" (ex: Copy do Reo escolhendo qual
## habilidade copiar). Mesmo padrão de UIHabilidade.gd: gera um botão
## pra cada opção recebida, então funciona com qualquer lista, sem
## precisar mexer nessa UI quando o leque crescer.
##
## Estrutura de nós esperada (monte no editor, como uma cena separada
## na raiz, irmã da UIHabilidade):
##
## CanvasLayer (UIMenuEscolha)  <- este script aqui
##   └── PainelOpcoes (PanelContainer, ou só um Control mesmo)
##         ancorado no centro da tela
##         └── VBoxContainer
##               ├── LabelTitulo (Label)              <- Nome Único (%)
##               └── ContainerOpcoes (VBoxContainer)   <- Nome Único (%)
##
## Começa invisible; só aparece enquanto uma escolha está pendente.

@onready var label_titulo: Label = %LabelTitulo
@onready var container: VBoxContainer = %ContainerOpcoes


func _ready() -> void:
	if not container or not label_titulo:
		push_error("UIMenuEscolha: não encontrei 'LabelTitulo'/'ContainerOpcoes'. Confira os Nomes Únicos (%).")
		return

	visible = false
	MenuEscolha.opcoes_solicitadas.connect(_on_opcoes_solicitadas)
	MenuEscolha.escolha_cancelada.connect(_on_escolha_cancelada)


func _on_opcoes_solicitadas(titulo: String, opcoes: Array[String]) -> void:
	label_titulo.text = titulo

	for filho in container.get_children():
		filho.queue_free()

	for opcao in opcoes:
		var botao_ui := Button.new()
		botao_ui.text = opcao
		botao_ui.custom_minimum_size = Vector2(200, 44)
		botao_ui.pressed.connect(_on_opcao_pressionada.bind(opcao))
		container.add_child(botao_ui)

	visible = true


func _on_opcao_pressionada(opcao: String) -> void:
	visible = false
	MenuEscolha.escolher(opcao)


func _on_escolha_cancelada() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	# ESC ou botão direito cancela o leque sem gastar nada — mesma
	# convenção de cancelamento já usada em SelecaoAlvo pros outros
	# tipos de seleção.
	if not visible:
		return

	# Cast explícito (em vez de só "is"): o analisador estático do Godot
	# não estreita o tipo de "event" dentro da mesma expressão, então
	# acessar .button_index/.pressed direto em InputEvent genérico vira
	# Variant e o ":=" logo abaixo não consegue inferir tipo nenhum.
	var evento_mouse := event as InputEventMouseButton
	var cancelou_com_botao_direito: bool = evento_mouse != null \
		and evento_mouse.button_index == MOUSE_BUTTON_RIGHT and evento_mouse.pressed
	var cancelou_com_esc: bool = event.is_action_pressed("ui_cancel")

	if cancelou_com_botao_direito or cancelou_com_esc:
		MenuEscolha.cancelar()
		get_viewport().set_input_as_handled()
