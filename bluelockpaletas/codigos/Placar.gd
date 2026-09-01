extends CanvasLayer

## Anexe este script na CanvasLayer da UI do placar.
##
## Estrutura de nós esperada (monte no editor):
##
## CanvasLayer (Placar)  <- este script aqui
##   ├── PainelPlacar (PanelContainer)   [ancorado no topo-centro]
##   │     └── HBoxContainer
##   │           ├── LabelEsquerda (Label)   texto inicial "0"
##   │           ├── LabelSeparador (Label)  texto "x"
##   │           └── LabelDireita (Label)    texto inicial "0"
##   └── LabelGol (Label)   texto "GOL!", ancorado no CENTRO da tela,
##                          fonte bem grande (ex: 96px), começa invisível
##
## Dica de estilo pro PainelPlacar (Inspector > Theme Overrides > Styles > Panel):
## crie um novo StyleBoxFlat com bg_color meio transparente (ex: preto com
## alpha 0.5), corner_radius uns 12px em cada canto, e content_margin de
## uns 16px nas laterais. Nos Labels, aumente o "Font Size" pra uns 32-40
## e dê uma cor diferente pra cada time (ex: azul e vermelho).

@export var posicao_reinicio_bola: Vector2 = Vector2.ZERO  # ajuste pro centro do seu campo
@export var duracao_comemoracao: float = 1.5  # segundos que o "GOL!" fica na tela

@onready var label_esquerda: Label = $PainelPlacar/HBoxContainer/LabelEsquerda
@onready var label_direita: Label = $PainelPlacar/HBoxContainer/LabelDireita
@onready var label_gol: Label = $LabelGol

var placar_esquerda: int = 0
var placar_direita: int = 0
var processando_gol: bool = false  # evita dois gols dispararem a comemoração ao mesmo tempo


func _ready() -> void:
	Eventos.gol_marcado.connect(_on_gol_marcado)
	_atualizar_labels()
	if label_gol:
		label_gol.visible = false
		label_gol.modulate.a = 0.0


func _on_gol_marcado(lado: String) -> void:
	if processando_gol:
		return  # já tem uma comemoração rolando, ignora gols repetidos
	processando_gol = true

	if lado == "esquerda":
		placar_esquerda += 1
	else:
		placar_direita += 1
	_atualizar_labels()

	await _mostrar_comemoracao()
	_resetar_jogo()

	processando_gol = false


func _mostrar_comemoracao() -> void:
	if not label_gol:
		return

	label_gol.visible = true
	label_gol.modulate.a = 0.0

	var tempo_fade := 0.2
	var tempo_espera: float = max(duracao_comemoracao - tempo_fade * 2.0, 0.0)

	var tween := create_tween()
	tween.tween_property(label_gol, "modulate:a", 1.0, tempo_fade)
	tween.tween_interval(tempo_espera)
	tween.tween_property(label_gol, "modulate:a", 0.0, tempo_fade)
	await tween.finished

	label_gol.visible = false


func _resetar_jogo() -> void:
	# busca a bola e os botões no momento do reset (não guardamos referência
	# antecipada — ver explicação no histórico do projeto sobre esse bug)
	var bolas := get_tree().get_nodes_in_group("bola")
	if bolas.size() > 0:
		bolas[0].resetar(posicao_reinicio_bola)

	get_tree().call_group("botoes", "resetar")


func _atualizar_labels() -> void:
	label_esquerda.text = str(placar_esquerda)
	label_direita.text = str(placar_direita)
