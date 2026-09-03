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

@export_group("One Two")
@export var forca_one_two: float = 200.0
@export var cooldown_one_two: int = 3
@export var acoes_extra_ao_receber_de_volta: int = 1

const NOME_HABILIDADE := "One Two"


func habilidades_proprias() -> Array[String]:
	return [NOME_HABILIDADE]


func _habilidade_propria_consome_acao(_nome: String) -> bool:
	# consome manualmente dentro de _executar_passe(), só quando o passe
	# de fato acontece — por isso aqui é sempre false
	return false


func _requisito_extra_propria(_nome: String) -> String:
	if bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % NOME_HABILIDADE
	return ""


func executar_habilidade_propria(nome: String) -> void:
	if nome == NOME_HABILIDADE:
		_pedir_alvo_para_passe(self, self, true)


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

	# empresta o One Two pro alvo poder continuar/fechar a jogada —
	# funciona em QUALQUER personagem que receber, não só outro Kurona,
	# porque toda a lógica continua rodando aqui (esse Kurona.gd), só
	# muda quem está "segurando" a bola
	alvo.conceder_habilidade(NOME_HABILIDADE, func() -> void:
		_pedir_alvo_para_passe(alvo, quem_originou, false)
	)
