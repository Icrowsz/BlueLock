extends Botao
class_name Hugo

## Hugo Aiuchi (?)
##
## - Mechanic: passe AUTOMÁTICO (sem clicar em ninguém — escolhe sozinho
##   o aliado mais próximo dentro de um alcance bem maior que o normal)
##   e garantido. Concede mais uma ação de DESLOCAMENTO de brinde.
##   Cooldown de 7 turnos.
##
## - Non-Rotating Gear: escolhe DOIS jogadores do time inimigo (dois
##   cliques em sequência, via SelecaoAlvo.pedir_alvo() encadeado) e
##   trava os dois — nem movimento, nem habilidade — por
##   non_rotating_gear_duracao_turnos_inimigo turnos DO PONTO DE VISTA
##   DELES. Hugo ganha mais uma ação de habilidade. Cooldown de 7 turnos.
##
##   IMPORTANTE sobre a duração: aplicar_bloqueio_movimento()/
##   aplicar_bloqueio_habilidade() (em Botao.gd) decrementam a cada
##   troca de turno GLOBAL, de QUALQUER time — não só do time do alvo.
##   Isso significa que, pra travar o alvo durante N turnos DELE, o
##   valor real passado pra esses métodos precisa ser 2×N (metade das
##   trocas globais são o turno do PRÓPRIO Hugo, que não conta pro
##   alvo). Por isso a exportada é "turnos do inimigo" e a conversão
##   pra 2x acontece só na hora de aplicar — mesma pegadinha que já
##   apareceu no Glam Block do Aryu (lá, "só esse turno" virou passar
##   2 em vez de 1).
##
## - Second Place: só funciona com a bola no alcance. Escolhe UM
##   inimigo e anula as ações dele NO PRÓXIMO turno (mesma pegadinha de
##   +1 acima, aqui vale só 1 turno do inimigo → passa 2). Hugo ganha
##   mais uma ação de habilidade E libera o Follow Up "Greater than the
##   King" só NESTE turno (mesmo padrão do KaKaBoom do Shidou: some
##   sozinho se não for usado). Cooldown de 7 turnos.
##
## - Greater than the King (Follow Up): só aparece na lista depois que
##   o Second Place é usado no mesmo turno — sem cooldown próprio. Chute
##   reto e teleguiado, força acima da média.

@export_group("Mechanic")
@export var mechanic_alcance: float = 500.0  ## bem maior que o alcance normal de qualquer outro passe do jogo, de propósito
@export var duracao_mechanic: float = 0.4
@export var cooldown_mechanic: int = 7

@export_group("Non-Rotating Gear")
@export var non_rotating_gear_duracao_turnos_inimigo: int = 2  ## "3 turnos" do PONTO DE VISTA DO INIMIGO — ver nota grande no topo do arquivo
@export var cooldown_non_rotating_gear: int = 7

@export_group("Second Place")
@export var cooldown_second_place: int = 7

@export_group("Greater than the King (Follow Up)")
@export var forca_greater_than_king: float = 240.0  ## "acima da média" — comparar com forca_dragon_drive (220) do Shidou

const NOME_MECHANIC := "Mechanic"
const NOME_NON_ROTATING_GEAR := "Non-Rotating Gear"
const NOME_SECOND_PLACE := "Second Place"
const NOME_GREATER_THAN_KING := "Greater than the King"

var _greater_than_king_disponivel: bool = false


## --- Ganchos do sistema de habilidades (ver Botao.gd) ---

func habilidades_proprias() -> Array[String]:
	var lista: Array[String] = [NOME_MECHANIC, NOME_NON_ROTATING_GEAR, NOME_SECOND_PLACE]
	if _greater_than_king_disponivel:
		lista.append(NOME_GREATER_THAN_KING)
	return lista


func _habilidade_propria_consome_acao(nome: String) -> bool:
	if nome == NOME_MECHANIC:
		return false  # consumida manualmente só se achar um aliado — ver _executar_mechanic()
	if nome == NOME_NON_ROTATING_GEAR or nome == NOME_SECOND_PLACE:
		return false  # consumidas manualmente só quando o(s) alvo(s) são confirmados
	return true  # só o Greater than the King consome normalmente


func _requisito_extra_propria(nome: String) -> String:
	if (nome == NOME_MECHANIC or nome == NOME_SECOND_PLACE or nome == NOME_GREATER_THAN_KING) and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_MECHANIC:
			_executar_mechanic()
		NOME_NON_ROTATING_GEAR:
			_iniciar_non_rotating_gear()
		NOME_SECOND_PLACE:
			_iniciar_second_place()
		NOME_GREATER_THAN_KING:
			_executar_greater_than_king()


func _on_turno_mudou(time_iniciado: String) -> void:
	super._on_turno_mudou(time_iniciado)
	# o Follow Up liberado só vale NESTE turno — some se não for usado,
	# igual ao KaKaBoom do Shidou
	if _greater_than_king_disponivel and time_iniciado != time:
		_greater_than_king_disponivel = false


## --- Mechanic ---

func _executar_mechanic() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var aliado := _encontrar_aliado_mais_proximo(mechanic_alcance)
	if not aliado:
		# não achou ninguém pra passar: a habilidade não fez NADA de
		# verdade, então não consome ação nem entra em cooldown — só
		# avisa e para por aqui
		Eventos.mensagem_solicitada.emit("Mechanic! Nenhum aliado dentro do alcance pra receber o passe.")
		return

	bola.mover_para_com_trajetoria(aliado.global_position, duracao_mechanic)
	conceder_acao_movimento_extra(1)

	consumir_acao_habilidade()
	iniciar_cooldown(NOME_MECHANIC, cooldown_mechanic)
	Eventos.mensagem_solicitada.emit("Mechanic! Passe automático entregue a longa distância.")


func _encontrar_aliado_mais_proximo(alcance_maximo: float) -> Botao:
	var mais_proximo: Botao = null
	var menor_distancia := INF
	for nodo in get_tree().get_nodes_in_group("botoes"):
		var botao := nodo as Botao
		if not botao or botao == self or botao.time != time:
			continue
		var distancia := global_position.distance_to(botao.global_position)
		if distancia <= alcance_maximo and distancia < menor_distancia:
			menor_distancia = distancia
			mais_proximo = botao
	return mais_proximo


## --- Non-Rotating Gear ---

func _iniciar_non_rotating_gear() -> void:
	SelecaoAlvo.pedir_alvo(self, _on_primeiro_alvo_non_rotating_gear, "Selecione o 1º inimigo para o Non-Rotating Gear")


func _on_primeiro_alvo_non_rotating_gear(alvo1: Botao) -> void:
	if alvo1.time == time:
		Eventos.mensagem_solicitada.emit("Escolha um jogador do time inimigo!")
		return

	SelecaoAlvo.pedir_alvo(self, _on_segundo_alvo_non_rotating_gear.bind(alvo1), "Selecione o 2º inimigo para o Non-Rotating Gear")


func _on_segundo_alvo_non_rotating_gear(alvo2: Botao, alvo1: Botao) -> void:
	if alvo2.time == time:
		Eventos.mensagem_solicitada.emit("Escolha um jogador do time inimigo!")
		return
	if alvo2 == alvo1:
		Eventos.mensagem_solicitada.emit("Escolha um segundo inimigo diferente do primeiro!")
		return

	# ver a nota grande no topo do arquivo sobre por que isso é x2
	var turnos_efetivos := non_rotating_gear_duracao_turnos_inimigo * 2
	for alvo in [alvo1, alvo2]:
		alvo.aplicar_bloqueio_movimento(turnos_efetivos)
		alvo.aplicar_bloqueio_habilidade(turnos_efetivos)

	conceder_acao_habilidade_extra(1)

	consumir_acao_habilidade()
	iniciar_cooldown(NOME_NON_ROTATING_GEAR, cooldown_non_rotating_gear)
	Eventos.mensagem_solicitada.emit("Non-Rotating Gear! Dois inimigos travados por %d turnos — Hugo ganhou mais uma ação de habilidade." % non_rotating_gear_duracao_turnos_inimigo)


## --- Second Place / Greater than the King ---

func _iniciar_second_place() -> void:
	SelecaoAlvo.pedir_alvo(self, _on_alvo_second_place_escolhido, "Selecione um inimigo para anular no Second Place")


func _on_alvo_second_place_escolhido(alvo: Botao) -> void:
	if alvo.time == time:
		Eventos.mensagem_solicitada.emit("Escolha um jogador do time inimigo!")
		return

	if bola_no_alcance == null:
		Eventos.mensagem_solicitada.emit("A bola não está mais por perto — Second Place cancelado.")
		return

	# "anular as ações NO turno" = só o próximo turno dele — mesma
	# pegadinha do x2 explicada no Non-Rotating Gear acima, aqui só que
	# pra 1 turno mesmo (2 = 1 turno do inimigo, ver Glam Block do Aryu)
	alvo.aplicar_bloqueio_movimento(2)
	alvo.aplicar_bloqueio_habilidade(2)

	conceder_acao_habilidade_extra(1)
	_greater_than_king_disponivel = true

	consumir_acao_habilidade()
	iniciar_cooldown(NOME_SECOND_PLACE, cooldown_second_place)
	Eventos.mensagem_solicitada.emit("Second Place! Inimigo anulado no próximo turno — Hugo ganhou uma ação de habilidade e liberou o Follow Up Greater than the King.")


func _executar_greater_than_king() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	var direcao := (gol.ponto_para_mira() - bola.global_position).normalized()
	bola.receber_chute_teleguiado(direcao, forca_greater_than_king)
	_greater_than_king_disponivel = false
