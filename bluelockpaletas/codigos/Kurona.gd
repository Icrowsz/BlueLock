extends Botao
class_name Kurona

## Kurona
##
## - One Two: escolhe um alvo (outro botão do MESMO time). O passe é
##   AUTOMÁTICO/garantido — igual ao Shark Assault: a bola faz um "TP"
##   direto até perto do alvo, já dominada (sem força nenhuma), então
##   NÃO existe mais chance de interceptação no meio do caminho. A
##   diferença é só quem escolhe o destino: aqui é o jogador, no Shark
##   Assault é sorteado.
##
##   Quando o passe chega, o alvo GANHA o One Two emprestado — mas só
##   pode usá-lo durante o PRÓXIMO turno de verdade do time dele. Se
##   não usar até lá, a habilidade emprestada expira sozinha (isso é o
##   que evita ficar acumulando "cópias" antigas — ver Botao.gd,
##   conceder_habilidade() e _on_turno_mudou()). Se o alvo escolhido
##   nessa devolução for o Kurona ORIGINAL, ele ganha uma ação de
##   movimento EXTRA nesse turno (o "impulsionado duas vezes").
##
## Cooldown e custo de ação: como a jogada só se completa quando o
## jogador escolhe o alvo (depois de clicar no botão da habilidade), o
## custo da ação e o início do cooldown só acontecem quando o passe
## REALMENTE sai — não no clique do botão. Assim, cancelar a seleção
## (botão direito ou Esc) não desperdiça nada.
##
## Imunidade: quem RECEBE de verdade o One Two fica imune por algumas
## rodadas — não pode ser escolhido como alvo de um novo One Two nesse
## período. Evita o "ping-pong infinito" entre os mesmos 2 jogadores.
##
## - Shark Assault: se a bola estiver no alcance do Kurona, ele toca
##   pra um ALIADO ALEATÓRIO em campo, com o mesmo passe automático e
##   garantido do One Two (ver ponto_de_chegada_dominado() em Botao.gd).

@export_group("One Two")
@export var cooldown_one_two: int = 5
@export var acoes_extra_ao_receber_de_volta: int = 1
@export var duracao_imunidade_one_two: int = 5

@export_group("Shark Assault")
@export var cooldown_shark_assault: int = 4

@export_group("Passe Automático")
## Em que fração do alcance do ALVO a bola aparece ao chegar (0 = bem
## em cima dele, 1 = na borda do alcance). Um valor médio evita tanto
## sobrepor o corpo dele quanto cair fora do alcance.
@export_range(0.1, 0.95) var fracao_alcance_dominio: float = 0.6

const NOME_HABILIDADE := "One Two"
const NOME_SHARK_ASSAULT := "Shark Assault"
const EFEITO_IMUNE_ONE_TWO := "Imunidade One Two"


func habilidades_proprias() -> Array[String]:
	return [NOME_HABILIDADE, NOME_SHARK_ASSAULT]


func _habilidade_propria_consome_acao(nome: String) -> bool:
	if nome == NOME_HABILIDADE:
		# consome manualmente dentro de _executar_passe(), só quando o
		# passe de fato acontece — por isso aqui é false
		return false
	return true  # Shark Assault consome a ação normalmente, na hora do clique


func _requisito_extra_propria(nome: String) -> String:
	if bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	if nome == NOME_SHARK_ASSAULT and _aliados_disponiveis().is_empty():
		return "Não há nenhum aliado em campo para o %s!" % NOME_SHARK_ASSAULT
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_HABILIDADE:
			_pedir_alvo_para_passe(self, self, true)
		NOME_SHARK_ASSAULT:
			_executar_shark_assault()
			iniciar_cooldown(NOME_SHARK_ASSAULT, cooldown_shark_assault)


## --- Shark Assault ---

func _executar_shark_assault() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var aliados := _aliados_disponiveis()
	if aliados.is_empty():
		return

	var alvo: Botao = aliados[randi() % aliados.size()]
	_mandar_bola_dominada(bola, alvo)

	Eventos.mensagem_solicitada.emit("Shark Assault! %s dominou a bola." % alvo.name)


func _aliados_disponiveis() -> Array[Botao]:
	# qualquer botão do MESMO time, em campo, que não seja este Kurona
	var aliados: Array[Botao] = []
	for nodo in get_tree().get_nodes_in_group("botoes"):
		var botao := nodo as Botao
		if botao and botao != self and botao.time == time:
			aliados.append(botao)
	return aliados


## --- Fluxo do One Two (reaproveitado tanto pelo Kurona quanto por
## quem receber a habilidade emprestada) ---

func _pedir_alvo_para_passe(ator: Botao, quem_originou: Kurona, eh_lance_original: bool) -> void:
	SelecaoAlvo.pedir_alvo(ator, func(alvo: Botao) -> void:
		_executar_passe(ator, alvo, quem_originou, eh_lance_original)
	, "Selecione um alvo para o One Two")


func _executar_passe(ator: Botao, alvo: Botao, quem_originou: Kurona, eh_lance_original: bool) -> void:
	if alvo == ator:
		Eventos.mensagem_solicitada.emit("Escolha outro jogador como alvo!")
		return

	if alvo.time != ator.time:
		Eventos.mensagem_solicitada.emit("Escolha um companheiro de time como alvo!")
		return

	if alvo.tem_efeito(EFEITO_IMUNE_ONE_TWO):
		Eventos.mensagem_solicitada.emit(
			"%s ainda está imune ao One Two (mais %d turno(s))!" % [alvo.name, alvo.turnos_restantes_efeito(EFEITO_IMUNE_ONE_TWO)]
		)
		return

	var bola := ator.bola_no_alcance
	if not bola:
		Eventos.mensagem_solicitada.emit("A bola não está mais por perto!")
		return

	# passe AUTOMÁTICO/garantido (mesmo mecanismo do Shark Assault): sem
	# física de verdade, então não existe chance de interceptação
	_mandar_bola_dominada(bola, alvo)

	Turnos.usar_acao("habilidade")
	if eh_lance_original:
		iniciar_cooldown(NOME_HABILIDADE, cooldown_one_two)

	# como o passe é garantido, já sabemos NA HORA que "chegou" — não
	# precisa mais esperar nenhum sinal de física pra confirmar
	_completar_one_two(alvo, quem_originou)


func _mandar_bola_dominada(bola: RigidBody2D, alvo: Botao) -> void:
	var ponto := alvo.ponto_de_chegada_dominado(bola.global_position, fracao_alcance_dominio)
	bola.receber_dominio_instantaneo(ponto)


func _completar_one_two(alvo: Botao, quem_originou: Kurona) -> void:
	if alvo == quem_originou:
		# a bola voltou pro Kurona que começou a jogada: bônus!
		Turnos.adicionar_acoes("movimento", acoes_extra_ao_receber_de_volta)
		Eventos.mensagem_solicitada.emit("One Two completo! Ação de movimento extra concedida.")
		return

	# o alvo recebeu de verdade o One Two: fica imune por algumas
	# rodadas, pra não poder ser escolhido de novo enquanto isso (evita
	# ping-pong infinito entre os mesmos 2 jogadores)
	alvo.aplicar_efeito_temporario(EFEITO_IMUNE_ONE_TWO, duracao_imunidade_one_two)

	# empresta o One Two pro alvo poder continuar/fechar a jogada —
	# funciona em QUALQUER personagem que receber, não só outro Kurona,
	# porque toda a lógica continua rodando aqui (esse Kurona.gd), só
	# muda quem está "segurando" a bola. Só vale pro PRÓXIMO turno de
	# verdade do time do alvo (ver Botao.conceder_habilidade).
	alvo.conceder_habilidade(NOME_HABILIDADE, func() -> void:
		_pedir_alvo_para_passe(alvo, quem_originou, false)
	)
