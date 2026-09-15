extends Button
class_name BotaoHabilidadeUI

## Só existe pra dar um tooltip customizado (caixa com largura fixa e
## quebra de linha) em vez da caixinha padrão do Godot, que vira uma
## linha gigante quando o texto é longo.

const LARGURA_TOOLTIP := 600.0

func _make_custom_tooltip(for_text: String) -> Object:
	var caixa := PanelContainer.new()
	caixa.custom_minimum_size = Vector2(LARGURA_TOOLTIP, 0)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	estilo.border_color = Color(1, 1, 1, 0.15)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(8)
	estilo.set_content_margin_all(10)
	caixa.add_theme_stylebox_override("panel", estilo)

	var label := Label.new()
	label.text = for_text
	label.custom_minimum_size = Vector2(LARGURA_TOOLTIP - 20, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color.WHITE)
	caixa.add_child(label)

	return caixa
