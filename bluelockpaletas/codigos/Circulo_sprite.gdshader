shader_type canvas_item;

// Aplique este shader no material do Sprite2D de qualquer personagem
// para recortá-lo em círculo, sem precisar editar a imagem original.

uniform float raio : hint_range(0.0, 1.0) = 0.48;   // 0.5 = toca as bordas exatas
uniform float suavizar_borda : hint_range(0.0, 0.1) = 0.02;

void fragment() {
	vec4 cor = texture(TEXTURE, UV);
	float distancia_centro = distance(UV, vec2(0.5, 0.5));
	float mascara = 1.0 - smoothstep(raio - suavizar_borda, raio, distancia_centro);
	cor.a *= mascara;
	COLOR = cor;
}
