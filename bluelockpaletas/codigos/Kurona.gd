extends Botao
class_name Kurona

## Kurona
##
## - One Two: escolhe um alvo (outro botão do MESMO time); a bola é
##   chutada em direção a ele — é o mesmo chute teleguiado do Chute
##   Direto do Isagi, então É POSSÍVEL interceptar (a bola viaja pela
##   física normal do jogo; se um oponente estiver no caminho, ele
##   esbarra nela normalmente, sem código nenhum extra pra isso).
##
##   Se a bola chegar de verdade no alvo (ninguém interceptou), o alvo
##   GANHA o One Two emprestado pro turno seguinte DO TIME dele —
##   podendo repassar a jogada adiante. Se o alvo escolhido nessa
##   devolução for o Kurona ORIGINAL, ele ganha uma ação de movimento
##   EXTRA nesse turno (o "impulsionado duas vezes").
##
## Cooldown e custo de ação: como a jogada só se completa quando o
## jogador escolhe o alvo (depois de clicar no botão da habilidade), o
## custo da ação e o início do cooldown só acontecem quando o passe
## REALMENTE sai — não no clique do botão. Assim, cancelar a seleção
## (botão direito ou Esc) não desperdiça nada.
##
## Imunidade: quem RECEBE de verdade o One Two (a bola chegou e ele
## ganhou a habilidade emprestada) fica imune por algumas rodadas —
## não pode ser escolhido como alvo de um novo One Two nesse período.
## Isso evita o "ping-pong infinito" de ficar passando o One Two pra
## frente e pra trás entre os 2 mesmos jogadores turno após turno.
##
## - Shark Assault: se a bola estiver no alcance do Kurona, ele toca
##   pra um ALIADO ALEATÓRIO em campo. Diferente do One Two, esse passe
##   é automático/garantido — a bola faz um "TP" direto até perto do
##   aliado, já "dominada" (velocidade zero), sem viajar de verdade
##   pelo campo. Por isso NÃO pode ser interceptado no caminho.

@export_group("One Two")
@export var forca_one_two: float = 200.0
@export var cooldown_one_two: int = 5
@export var acoes_extra_ao_receber_de_volta: int = 1
@export var duracao_imunidade_one_two: int = 5

@export_group("Shark Assault")
@export var cooldown_shark_assault: int = 4
@export var margem_chegada_shark_assault: float = 20.0  ## distância da bola até o aliado ao "chegar" (ajuste conforme o tamanho do seu botão/alcance)

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

	# a bola "chega" já dominada bem perto do aliado — não em cima dele
	# (senão o físico dos dois corpos sobrepostos causaria um empurrão
	# estranho no frame seguinte). Usamos a direção de onde a bola veio
	# como referência de onde ela "encosta" no aliado.
	var direcao := bola.global_position - alvo.global_position
	if direcao.length() < 0.001:
		direcao = Vector2.RIGHT  # fallback: bola já estava bem em cima do alvo
	direcao = direcao.normalized()

	var distancia_chegada := alvo.raio_clique + margem_chegada_shark_assault
	bola.receber_dominio_instantaneo(alvo.global_position + direcao * distancia_chegada)

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

	var direcao := (alvo.global_position - bola.global_position).normalized()
	bola.receber_chute_teleguiado(direcao, forca_one_two)

	Turnos.usar_acao("habilidade")
	if eh_lance_original:
		iniciar_cooldown(NOME_HABILIDADE, cooldown_one_two)

	_aguardar_chegada_no_alvo(bola, alvo, quem_originou)


func _aguardar_chegada_no_alvo(bola: RigidBody2D, alvo: Botao, quem_originou: Kurona) -> void:
	# reaproveita a MESMA AreaAlcance que já existe pra chutar — se a
	# bola entrar no alcance do alvo, consideramos que "chegou" (o passe
	# deu certo). Se for interceptada no caminho, ela nunca entra aqui.
	if not alvo.area_alcance:
		return

	var callback: Callable
	callback = func(body: Node) -> void:
		if body != bola:
			return
		alvo.area_alcance.body_entered.disconnect(callback)
		_completar_one_two(alvo, quem_originou)

	alvo.area_alcance.body_entered.connect(callback)


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
	# muda quem está "segurando" a bola
	alvo.conceder_habilidade(NOME_HABILIDADE, func() -> void:
		_pedir_alvo_para_passe(alvo, quem_originou, false)
	)
