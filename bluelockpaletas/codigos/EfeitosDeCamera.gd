extends Node

## AUTOLOAD (Singleton). Sacode a câmera ATIVA da cena atual
## (get_viewport().get_camera_2d()) sem precisar de referência manual —
## funciona com qualquer Camera2D, em qualquer cena.

var _forca: float = 0.0
var _duracao_total: float = 0.0
var _tempo_restante: float = 0.0
var _camera_atual: Camera2D = null
var _offset_original: Vector2 = Vector2.ZERO


func sacudir(forca: float = 12.0, duracao: float = 0.3) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return

	if _camera_atual != cam:
		if _camera_atual and is_instance_valid(_camera_atual):
			_camera_atual.offset = _offset_original
		_camera_atual = cam
		_offset_original = cam.offset

	# um shake mais forte "vence" um mais fraco já rolando, em vez de somar
	_forca = max(_forca, forca)
	_duracao_total = max(_duracao_total, duracao)
	_tempo_restante = _duracao_total


func _process(delta: float) -> void:
	if _tempo_restante <= 0.0 or not _camera_atual or not is_instance_valid(_camera_atual):
		return

	_tempo_restante -= delta
	if _tempo_restante <= 0.0:
		_camera_atual.offset = _offset_original
		_forca = 0.0
		return

	var intensidade := _forca * (_tempo_restante / _duracao_total)  # decai até zero
	_camera_atual.offset = _offset_original + Vector2(
		randf_range(-intensidade, intensidade),
		randf_range(-intensidade, intensidade)
	)
