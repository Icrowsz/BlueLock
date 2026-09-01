extends CanvasLayer

## Botão de habilidade especial (ex: "Chute Direto") que aparece no canto
## inferior da tela quando o jogador tem uma habilidade disponível, e some
## quando deixa de estar no alcance.
##
## Estrutura de nós esperada (monte no editor):
##
## CanvasLayer (UIHabilidade)  <- este script aqui
##   └── BotaoHabilidade (Button)
##         ancorado no canto inferior (ex: bottom-right ou bottom-center)
##         começa com "visible" desmarcado no editor
##         IMPORTANTE: clique direito no Button na árvore de cenas >
##         "Acessar como Nome Único" (ícone %) — assim o script encontra
##         ele mesmo que você aninhe dentro de containers depois pra estilizar

@onready var botao_habilidade: Button = %BotaoHabilidade

var botao_ativo: Botao = null  # qual personagem está com a habilidade pronta


func _ready() -> void:
	if not botao_habilidade:
		push_error("UIHabilidade: não encontrei o nó 'BotaoHabilidade'. Confira se ele existe e está marcado como Nome Único (%) na árvore de cenas.")
		return

	Eventos.habilidade_disponivel.connect(_on_habilidade_disponivel)
	Eventos.habilidade_indisponivel.connect(_on_habilidade_indisponivel)
	botao_habilidade.pressed.connect(_on_botao_pressionado)
	botao_habilidade.visible = false


func _on_habilidade_disponivel(botao: Botao) -> void:
	botao_ativo = botao
	botao_habilidade.text = botao.nome_habilidade()
	botao_habilidade.visible = true


func _on_habilidade_indisponivel(botao: Botao) -> void:
	# só esconde se for o mesmo botão que estava ativo (evita que um
	# segundo personagem saindo do alcance esconda a habilidade de outro)
	if botao_ativo == botao:
		botao_ativo = null
		botao_habilidade.visible = false


func _on_botao_pressionado() -> void:
	if botao_ativo and botao_ativo.pode_usar_habilidade():
		botao_ativo.usar_habilidade()
	botao_habilidade.visible = false
	botao_ativo = null
