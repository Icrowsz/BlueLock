extends Botao
class_name Kurona

## Kurona
##
## - One Two: escolhe um alvo (outro botão do MESMO time); a bola é
##   chutada em direção a ele — mesmo chute teleguiado do Chute Direto
##   do Isagi, então É POSSÍVEL interceptar (a bola viaja pela física
##   normal; se um oponente estiver no caminho, esbarra nela normalmente,
##   sem código nenhum extra pra isso).
##
##   Se a bola chegar de verdade no alvo, ele GANHA o One Two emprestado
##   pro turno seguinte DO TIME dele (só uma concessão pendente por vez;
##   se não usar em até "cooldown_one_two" turnos, ela desaparece
##   sozinha). Se o alvo escolhido nessa devolução for o Kurona
##   ORIGINAL, é ELE (não quem devolveu) que ganha uma ação de
##   movimento EXTRA pessoal nesse turno.
##
## - Shark Assault: com a bola no alcance, toca automaticamente pra um
##   aliado ALEATÓRIO em campo. É um passe "garantido" (sem chute de
##   verdade physics-based, sem chance de interceptação) que chega sem
##   força nenhuma — como se o aliado tivesse dominado a bola parada.
##
## Custo de ação e cooldown do One Two só acontecem quando o passe de
## fato SAI (depois de escolher o alvo) — não no clique do botão de
## habilidade. Assim, cancelar a seleção (botão direito ou Esc) não
## desperdiça nada.

@export_group("One Two")
@export var forca_one_two: float = 1200.0
@export var cooldown_one_two: int = 5
@export var acoes_extra_ao_receber_de_volta: int = 1

@export_group("Shark Assault")
@export var cooldown_shark_assault: int = 3

const NOME_ONE_TWO := "One Two"
const NOME_SHARK_ASSAULT := "Shark Assault"


func habilidades_proprias() -> Array[String]:
	return [NOME_ONE_TWO, NOME_SHARK_ASSAULT]


func _habilidade_propria_consome_acao(nome: String) -> bool:
	if nome == NOME_ONE_TWO:
		# consumida manualmente dentro de _executar_passe(), só quando o
		# passe de fato acontece
		return false
	return true  # Shark Assault consome normalmente


func _requisito_extra_propria(nome: String) -> String:
	if bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_ONE_TWO:
			_pedir_alvo_para_passe(self, self, true)
		NOME_SHARK_ASSAULT:
			_executar_shark_assault()
			iniciar_cooldown(nome, cooldown_shark_assault)


## --- One Two ---

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
		iniciar_cooldown(NOME_ONE_TWO, cooldown_one_two)

	_aguardar_chegada_no_alvo(bola, alvo, quem_originou)


func _aguardar_chegada_no_alvo(bola: RigidBody2D, alvo: Botao, quem_originou: Kurona) -> void:
	# reaproveita a MESMA AreaAlcance que já existe pra chutar — se a
	# bola entrar no alcance do alvo, consideramos que "chegou". Se for
	# interceptada no caminho, ela nunca entra aqui.
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
		# a bola voltou pro Kurona que começou a jogada: SÓ ELE ganha o
		# bônus, mesmo que quem tenha devolvido seja outro personagem
		quem_originou.conceder_acao_movimento_extra(acoes_extra_ao_receber_de_volta)
		Eventos.mensagem_solicitada.emit("One Two completo! Kurona ganhou uma ação de movimento extra.")
		return

	# empresta o One Two pro alvo poder continuar/fechar a jogada (teto
	# de 1 concessão pendente e expiração são tratados pelo Botao.gd)
	alvo.conceder_habilidade(NOME_ONE_TWO, func() -> void:
		_pedir_alvo_para_passe(alvo, quem_originou, false)
	, false, cooldown_one_two)


## --- Shark Assault ---

func _executar_shark_assault() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var aliados := _aliados_disponiveis()
	if aliados.is_empty():
		Eventos.mensagem_solicitada.emit("Não há aliados em campo para o Shark Assault!")
		return

	var alvo: Botao = aliados[randi() % aliados.size()]
	bola.mover_para_com_trajetoria(alvo.global_position)


func _aliados_disponiveis() -> Array[Botao]:
	var lista: Array[Botao] = []
	for nodo in get_tree().get_nodes_in_group("botoes"):
		var botao := nodo as Botao
		if botao and botao != self and botao.time == time:
			lista.append(botao)
	return lista
