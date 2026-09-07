extends Botao
class_name Zantetsu

## Zantetsu
##
## - Bullet Train: mesmo "sistema" de deslocamento do Opposite
##   Direction do Rin — só nas 4 direções fixas (cima, baixo, direita,
##   esquerda), sem deslizar, quase um teleporte. A diferença: isso é
##   uma HABILIDADE (gasta ação de habilidade, tem cooldown próprio) e
##   por isso NÃO consome a ação de movimento do time — concedemos uma
##   ação de movimento BÔNUS pessoal (conceder_acao_movimento_extra,
##   mesma base do "impulsionado duas vezes" do One Two do Kurona) bem
##   na hora de ativar, só pra cobrir esse arrasto específico. Cooldown
##   de 6 turnos.
##
##   Se o jogador ativar e não chegar a arrastar (ou arrastar curto
##   demais), a ativação expira sozinha — na troca de turno ou no
##   "chute" fracassado — e devolve a ação bônus não usada, pra nunca
##   deixar uma ação de movimento de graça sobrando pro time.
##
## - Left Footed Shot: chute comum (teleguiado, mirando automaticamente
##   no gol inimigo — mesma base do Chute Direto/Curve Shot). Fica mais
##   forte (multiplicador_bonus_bullet_train) se a ÚLTIMA AÇÃO de
##   Zantetsu tiver sido o Bullet Train — rastreado por uma flag simples
##   que vira true quando o dash executa e volta a false em qualquer
##   deslocamento normal ou ao usar este próprio chute. Cooldown de 6
##   turnos.

@export_group("Bullet Train")
@export var bullet_train_distancia: float = 130.0
@export var bullet_train_duracao_movimento: float = 0.15  ## bem rápido — "quase um teleporte", sem inércia
@export var cooldown_bullet_train: int = 6

@export_group("Left Footed Shot")
@export var forca_left_footed_shot: float = 450.0
@export var multiplicador_bonus_bullet_train: float = 1.5  ## aplicado à força se a última ação tiver sido o Bullet Train
@export var cooldown_left_footed_shot: int = 6

const NOME_BULLET_TRAIN := "Bullet Train"
const NOME_LEFT_FOOTED_SHOT := "Left Footed Shot"

var _bullet_train_ativo: bool = false  # true só entre "clicou no botão" e "soltou o arrasto"
var _ultima_acao_foi_bullet_train: bool = false  # true logo após um Bullet Train bem-sucedido; reseta em qualquer outra ação


func habilidades_proprias() -> Array[String]:
	return [NOME_BULLET_TRAIN, NOME_LEFT_FOOTED_SHOT]


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_LEFT_FOOTED_SHOT and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_BULLET_TRAIN:
			_bullet_train_ativo = true
			conceder_acao_movimento_extra(1)  # paga o arrasto seguinte, sem gastar a ação de movimento do time
			iniciar_cooldown(nome, cooldown_bullet_train)
			Eventos.mensagem_solicitada.emit("Bullet Train ativado! Arraste numa direção pra disparar (não gasta a ação de movimento).")
		NOME_LEFT_FOOTED_SHOT:
			_executar_left_footed_shot()
			iniciar_cooldown(nome, cooldown_left_footed_shot)


## --- Bullet Train ---

func _executar_deslocamento(vetor_arrasto: Vector2) -> void:
	if not _bullet_train_ativo:
		_ultima_acao_foi_bullet_train = false  # deslocamento normal — quebra a sequência
		super._executar_deslocamento(vetor_arrasto)
		return

	_bullet_train_ativo = false  # uso único por ativação

	var direcao_travada := _travar_direcao_cardinal(vetor_arrasto.normalized())
	var destino := global_position + direcao_travada * bullet_train_distancia
	MovimentoSuave.mover(self, destino, bullet_train_duracao_movimento)

	_ultima_acao_foi_bullet_train = true


func _travar_direcao_cardinal(direcao: Vector2) -> Vector2:
	# mesma lógica do Opposite Direction do Rin: arredonda pra uma das
	# 4 direções fixas, com base em qual eixo o jogador puxou mais forte
	if absf(direcao.x) > absf(direcao.y):
		return Vector2.RIGHT if direcao.x > 0 else Vector2.LEFT
	return Vector2.DOWN if direcao.y > 0 else Vector2.UP


func _apos_chute(sucesso: bool) -> void:
	super._apos_chute(sucesso)

	if not _bullet_train_ativo:
		return

	# só chega aqui se o Bullet Train foi ativado mas o arrasto saiu
	# curto demais pra contar (_executar_deslocamento nem rodou) — como
	# a ação bônus concedida na ativação nunca foi gasta, devolve ela
	if not sucesso:
		_bullet_train_ativo = false
		if acoes_movimento_bonus > 0:
			acoes_movimento_bonus -= 1


func _on_turno_mudou(time_iniciado: String) -> void:
	super._on_turno_mudou(time_iniciado)

	if _bullet_train_ativo:
		# o jogador ativou mas nunca chegou a arrastar antes do turno
		# acabar — cancela e devolve a ação bônus não usada, senão ela
		# ficaria "sobrando" livre pra um deslocamento normal depois, de graça
		_bullet_train_ativo = false
		if acoes_movimento_bonus > 0:
			acoes_movimento_bonus -= 1
		Eventos.mensagem_solicitada.emit("Bullet Train expirou sem ser usado.")


## --- Left Footed Shot ---

func _executar_left_footed_shot() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	var forca := forca_left_footed_shot
	var veio_do_bullet_train := _ultima_acao_foi_bullet_train
	if veio_do_bullet_train:
		forca *= multiplicador_bonus_bullet_train

	var direcao := gol.ponto_para_mira() - bola.global_position
	direcao = direcao.normalized() if direcao.length() > 1.0 else Vector2.RIGHT
	bola.receber_chute_teleguiado(direcao, forca)

	_ultima_acao_foi_bullet_train = false  # a "última ação" agora é este próprio chute

	if veio_do_bullet_train:
		Eventos.mensagem_solicitada.emit("Left Footed Shot! Embalado pelo Bullet Train — chute com força extra (%.0f)." % forca)
	else:
		Eventos.mensagem_solicitada.emit("Left Footed Shot! Chute de força %.0f." % forca)
