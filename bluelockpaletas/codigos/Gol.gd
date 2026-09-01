extends Area2D
class_name Gol

## Anexe este script em cada gol do campo (nó Area2D).
## No Inspector, defina "lado" como "esquerda" ou "direita"
## conforme a posição do gol no campo.
##
## IMPORTANTE PRA MIRA DE HABILIDADES (ex: Chute Direto do Isagi):
## adicione um filho Marker2D chamado "PontoMira" e posicione ele
## manualmente bem no centro da boca do gol, arrastando no editor.
## Isso evita que habilidades mirem na origem "crua" do Area2D, que pode
## estar desalinhada dependendo de como o CollisionShape2D foi encaixado
## (causa comum de chutes saindo "torto"/pra cima).

@export_enum("esquerda", "direita") var lado: String = "esquerda"

@onready var ponto_mira: Marker2D = $PontoMira if has_node("PontoMira") else null


func _ready() -> void:
	add_to_group("gols")   # usado pelas habilidades (ex: Chute Direto) para mirar
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("bola"):
		Eventos.gol_marcado.emit(lado)


func ponto_para_mira() -> Vector2:
	# usa o PontoMira se existir; senão cai de volta pra origem do Area2D
	if ponto_mira:
		return ponto_mira.global_position
	return global_position
