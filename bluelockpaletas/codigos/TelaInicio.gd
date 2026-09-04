extends Control

## Anexe este script na cena da Tela de Início.
##
## No editor: selecione cada botão (o "3 VS 3" e o "5 VS 5" da sua
## imagem) e marque o nome dele como Nome Único (%) na árvore de cenas
## (clique direito no nó > "Acessar Como Nome Único"), usando os nomes
## abaixo — ou ajuste os nomes aqui pros que você já tiver.

@onready var botao_3v3: Button = %Botao3v3
@onready var botao_5v5: Button = %Botao5v5

const CENA_ESCALACAO := "res://cenas/Escalacao.tscn"  # ajuste o caminho


func _ready() -> void:
	botao_3v3.pressed.connect(_on_3v3_pressionado)
	botao_5v5.pressed.connect(_on_5v5_pressionado)


func _on_3v3_pressionado() -> void:
	ConfiguracaoPartida.iniciar_modo("3v3")
	get_tree().change_scene_to_file(CENA_ESCALACAO)


func _on_5v5_pressionado() -> void:
	ConfiguracaoPartida.iniciar_modo("5v5")
	get_tree().change_scene_to_file(CENA_ESCALACAO)
