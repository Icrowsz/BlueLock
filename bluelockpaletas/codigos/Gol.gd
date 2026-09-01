extends Area2D

## Anexe este script em cada gol do campo (nó Area2D).
## No Inspector, defina "lado" como "esquerda" ou "direita"
## conforme a posição do gol no campo.

@export_enum("esquerda", "direita") var lado: String = "esquerda"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("bola"):
		Eventos.gol_marcado.emit(lado)
