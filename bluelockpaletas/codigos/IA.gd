extends Node

## AUTOLOAD (Singleton).
## Configure em: Project Settings > Autoload > adicione este script
## com o nome "IA".
##
## NÃO decide "como" executar uma jogada — só decide QUAL jogada fazer,
## e chama os mesmos pontos de entrada que o jogador usa
## (Botao.realizar_jogada_de_movimento, Botao.usar_habilidade). Assim o
## resto do jogo (turnos, cooldowns, física) nem sabe que quem jogou foi
## um algoritmo.
##
## Essa é uma IA BÁSICA (heurística gulosa, sem planejamento): quem
## estiver mais perto da bola tenta levá-la em direção ao gol; se
## ninguém estiver perto o bastante, o botão mais próximo da bola avança
## até ela. Dá pra evoluir depois (ver comentário no fim do arquivo).

@export var atraso_antes_de_jogar: float = 1.0  # segurinha visual antes da primeira jogada do turno
@export var atraso_entre_jogadas: float = 0.6   # respiro entre uma jogada e outra no mesmo turno


func _ready() -> void:
	Turnos.turno_iniciado.connect(_on_turno_iniciado)


func _on_turno_iniciado(time: String) -> void:
	if not Turnos.eh_controlado_por_ia(time):
		return
	_jogar_turno.call_deferred(time)


func _jogar_turno(time: String) -> void:
	await get_tree().create_timer(atraso_antes_de_jogar).timeout

	while Turnos.time_da_vez == time and _tem_alguma_acao_disponivel():
		var conseguiu := _tentar_jogada(time)
		if not conseguiu:
			break  # não achou nenhuma jogada útil, encerra o turno (ou usa Turnos.passar_turno_manual() se preferir explícito)
		await get_tree().create_timer(atraso_entre_jogadas).timeout


func _tem_alguma_acao_disponivel() -> bool:
	return Turnos.tem_acao_disponivel("movimento") or Turnos.tem_acao_disponivel("habilidade")


func _tentar_jogada(time: String) -> bool:
	var bola := _encontrar_bola()
	if not bola:
		return false

	var botoes := _botoes_do_time(time)
	if botoes.is_empty():
		return false

	var mais_proximo := _mais_proximo_de(botoes, bola.global_position)
	if not mais_proximo:
		return false

	# prioridade simples: se tiver ação de habilidade E o mais próximo já
	# estiver com a bola no alcance, tenta usar a primeira habilidade
	# disponível dele antes de gastar o movimento
	if Turnos.tem_acao_disponivel("habilidade") and mais_proximo.bola_no_alcance != null:
		for nome in mais_proximo.lista_habilidades():
			if mais_proximo.motivo_bloqueio_habilidade(nome) == "":
				mais_proximo.usar_habilidade(nome)
				return true

	if Turnos.tem_acao_disponivel("movimento"):
		var direcao := (bola.global_position - mais_proximo.global_position)
		if direcao.length() < 1.0:
			var gol := mais_proximo.encontrar_gol_inimigo()
			direcao = (gol.ponto_para_mira() - mais_proximo.global_position) if gol else Vector2.RIGHT
		direcao = direcao.normalized()

		var vetor := direcao * mais_proximo.distancia_maxima_arrasto
		mais_proximo.realizar_jogada_de_movimento(vetor)
		return true

	return false


func _botoes_do_time(time: String) -> Array[Botao]:
	var lista: Array[Botao] = []
	for nodo in get_tree().get_nodes_in_group("botoes"):
		var botao := nodo as Botao
		if botao and botao.time == time:
			lista.append(botao)
	return lista


func _mais_proximo_de(botoes: Array[Botao], posicao: Vector2) -> Botao:
	var melhor: Botao = null
	var menor_distancia := INF
	for botao in botoes:
		var distancia := botao.global_position.distance_to(posicao)
		if distancia < menor_distancia:
			menor_distancia = distancia
			melhor = botao
	return melhor


func _encontrar_bola() -> RigidBody2D:
	var bolas := get_tree().get_nodes_in_group("bola")
	return bolas[0] if not bolas.is_empty() else null


## --- Próximos passos, se quiser evoluir a IA depois ---
## 1. Dificuldade: adicione "ruído" no vetor de mira (ex:
##    direcao.rotated(randf_range(-0.2, 0.2)) numa dificuldade fácil) e
##    reduza pra 0 numa dificuldade difícil.
## 2. Habilidades com alvo (SelecaoAlvo): em vez de simular cliques, a
##    IA pode chamar o mesmo fluxo por trás — ex: para o One Two do
##    Kurona, ao invés de esperar um clique, chame diretamente o
##    callback que SelecaoAlvo guardaria, escolhendo o alvo por
##    heurística (aliado mais avançado em campo, por exemplo).
## 3. Defesa: se a bola estiver mais perto do time adversário, mova um
##    botão pra uma posição defensiva em vez de sempre correr pra bola.
## 4. Pontuação de jogadas: em vez de "primeira jogada válida", gere
##    uma lista de jogadas candidatas com uma nota cada (distância ao
##    gol, chance de interceptação, etc.) e escolha a de maior nota.
