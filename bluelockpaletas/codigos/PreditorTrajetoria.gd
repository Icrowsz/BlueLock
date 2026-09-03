class_name PreditorTrajetoria
extends RefCounted

## Utilitário "sem estado" de previsão de trajetória: simula um raio
## saindo de um ponto, ricocheteando em superfícies reais do jogo
## (paredes, outros botões, a bola) usando o motor de física de verdade
## do Godot — não é uma curva desenhada "no olho", é raycast + reflexão.
##
## Não é um Node — é uma classe utilitária, reutilizável por qualquer
## habilidade futura que precise prever um caminho (não só a Metavisão).

## Lança um raio de "origem" na direção "direcao", ricocheteando (reflexão
## tipo espelho) até "max_ricochetes" vezes ou até percorrer
## "distancia_maxima" no total. Retorna um Dictionary com:
##   "pontos": PackedVector2Array — os vértices do caminho, pra desenhar
##             como uma linha (em coordenadas GLOBAIS/do mundo)
##   "corpo_atingido": o último corpo colidido (ou null, se o raio saiu
##             do campo sem bater em nada dentro da distância máxima)
static func prever(
	espaco: PhysicsDirectSpaceState2D,
	origem: Vector2,
	direcao: Vector2,
	distancia_maxima: float,
	max_ricochetes: int,
	corpos_a_ignorar: Array[RID] = []
) -> Dictionary:
	var pontos: PackedVector2Array = [origem]
	var pos_atual := origem
	var dir_atual := direcao.normalized()
	var distancia_restante := distancia_maxima
	var corpo_atingido: Object = null

	for i in range(max_ricochetes + 1):
		if distancia_restante <= 0.0:
			break

		var destino := pos_atual + dir_atual * distancia_restante
		var consulta := PhysicsRayQueryParameters2D.create(pos_atual, destino)
		consulta.exclude = corpos_a_ignorar

		var resultado := espaco.intersect_ray(consulta)
		if resultado.is_empty():
			pontos.append(destino)
			break

		var ponto_colisao: Vector2 = resultado["position"]
		var normal: Vector2 = resultado["normal"]
		pontos.append(ponto_colisao)

		distancia_restante -= pos_atual.distance_to(ponto_colisao)
		pos_atual = ponto_colisao
		dir_atual = dir_atual.bounce(normal)
		corpo_atingido = resultado["collider"]

		# se bateu na bola, para por aqui — quem chamou decide se quer
		# continuar prevendo o caminho da BOLA a partir daqui (fase 2)
		if corpo_atingido and corpo_atingido.is_in_group("bola"):
			break

	return {
		"pontos": pontos,
		"corpo_atingido": corpo_atingido,
	}
