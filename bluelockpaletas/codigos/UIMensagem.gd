extends CanvasLayer

## Mostra uma mensagem rápida na tela (fade in, espera, fade out).
## Disparada de QUALQUER lugar do jogo, sem precisar conhecer esse nó:
##
##     Eventos.mensagem_solicitada.emit("Texto do aviso aqui")
##
## Estrutura de nós esperada (monte no editor):
##
## CanvasLayer (UIMensagem)  <- este script aqui
##   └── LabelMensagem (Label)
##         posicione onde preferir (ex: centro da tela, ou embaixo do
##         placar), fonte de destaque, começa invisível
##         IMPORTANTE: marque como Nome Único (%) na árvore de cenas

@export var duracao: float = 1.5  # segundos que a mensagem fica visível

@onready var label_mensagem: Label = %LabelMensagem

var tween_ativo: Tween = null


func _ready() -> void:
	if not label_mensagem:
		push_error("UIMensagem: não encontrei o nó 'LabelMensagem'. Confira se ele existe e está marcado como Nome Único (%).")
		return

	Eventos.mensagem_solicitada.connect(_on_mensagem_solicitada)
	label_mensagem.visible = false
	label_mensagem.modulate.a = 0.0


func _on_mensagem_solicitada(texto: String) -> void:
	label_mensagem.text = texto

	# se já tinha uma mensagem em exibição, cancela a animação anterior
	# pra não sobrepor duas ao mesmo tempo
	if tween_ativo and tween_ativo.is_valid():
		tween_ativo.kill()

	label_mensagem.visible = true
	label_mensagem.modulate.a = 0.0

	var tempo_fade := 0.2
	var tempo_espera: float = max(duracao - tempo_fade * 2.0, 0.0)

	tween_ativo = create_tween()
	tween_ativo.tween_property(label_mensagem, "modulate:a", 1.0, tempo_fade)
	tween_ativo.tween_interval(tempo_espera)
	tween_ativo.tween_property(label_mensagem, "modulate:a", 0.0, tempo_fade)
	tween_ativo.finished.connect(func() -> void: label_mensagem.visible = false)
