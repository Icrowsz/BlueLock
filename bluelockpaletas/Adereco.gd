extends Sprite2D
class_name Adereco

## Adereço visual "burro" de propósito: um Sprite2D comum, SEM
## CollisionShape2D, SEM física, e que não entra em nenhum grupo/layer
## de colisão do jogo. A "mágica" de acompanhar o Shidou (ou qualquer
## outro botão) durante o movimento não é mágica nenhuma: é só o
## comportamento padrão de QUALQUER nó filho no Godot — a posição e a
## rotação dele já são relativas ao pai automaticamente, sem nenhum
## código rodando por frame. Só por estar dentro da cena do
## personagem, como filho, ele "gruda" sozinho.
##
## Este script é OPCIONAL — só padroniza mostrar()/esconder() (e,
## opcionalmente, sumir sozinho depois de X segundos) pra não ficar
## repetindo "visible = true" / "visible = false" espalhado pelo código
## de cada personagem. Se preferir, dá pra usar um Sprite2D puro sem
## nenhum script e mexer em .visible direto — funciona igual.

@export var duracao_visivel: float = 4  ## 0 = fica visível até esconder() ser chamado manualmente; >0 = some sozinho depois desse tempo


func _ready() -> void:
	visible = false


func mostrar() -> void:
	visible = true
	if duracao_visivel > 0.0:
		get_tree().create_timer(duracao_visivel).timeout.connect(esconder)


func esconder() -> void:
	visible = false
