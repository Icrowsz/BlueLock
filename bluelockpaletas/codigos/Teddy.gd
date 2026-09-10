extends Botao
class_name Teddy

## Teddy Knight
##
## - Rainbow Knight: chute forte com curva média, no gol inimigo.
##   Reaproveita receber_chute_curvo(), que já ignora colisão com
##   ALIADOS por padrão (só oponente intercepta) — exatamente o pedido.
##   Cooldown de 6 turnos.
##
## - Puppet: MESMO padrão do Scissors Dribble do Yukimiya — concede
##   várias ações de movimento extras (4, aqui) só que cada uma sai com
##   deslocamento reduzido enquanto durarem (a força do chute NÃO é
##   afetada, só a distância — diferente do Scissors Dribble, que reduz
##   os dois). Sobras somem no fim do turno se não forem usadas.
##   Cooldown de 7 turnos.
##
## - England Cavalry: escolhe QUALQUER jogador (aliado OU inimigo) e se
##   desloca até perto dele (mesmo esquema de movimento do Glam Block do
##   Aryu). Se for aliado, ele ganha mais um turno de ações — um
##   deslocamento extra E uma habilidade extra
##   (conceder_acao_movimento_extra/conceder_acao_habilidade_extra
##   chamados NO ALVO, não no Teddy). Se for inimigo, as habilidades
##   dele ficam canceladas no próximo turno — aplicar_bloqueio_habilidade
##   com a mesma pegadinha do x2 já usada no Glam Block do Aryu/Second
##   Place do Hugo (bloqueio decrementa em toda troca de turno global,
##   então "cancelado nesse turno" = passar 2, não 1). O resultado só é
##   decidido DEPOIS que Teddy termina de chegar perto do alvo. Cooldown
##   de 8 turnos.

@export_group("Rainbow Knight")
@export var forca_rainbow_knight: float = 220.0
@export var intensidade_curva_rainbow_knight: float = 55.0  ## "média" — entre o Gyro Shot do Yukimiya (30, fraca) e o Rabona Cross do Charles (70)
@export var duracao_curva_rainbow_knight: float = 1.0
@export var cooldown_rainbow_knight: int = 6

@export_group("Puppet")
@export var quantidade_acoes_puppet: int = 4
@export var multiplicador_distancia_puppet: float = 0.5
@export var cooldown_puppet: int = 7

@export_group("England Cavalry")
@export var england_cavalry_distancia_parada: float = 40.0
@export var england_cavalry_duracao_movimento: float = 0.4
@export var cooldown_england_cavalry: int = 8

const NOME_RAINBOW_KNIGHT := "Rainbow Knight"
const NOME_PUPPET := "Puppet"
const NOME_ENGLAND_CAVALRY := "England Cavalry"

var _puppet_ativo: bool = false


## --- Ganchos do sistema de habilidades (ver Botao.gd) ---

func habilidades_proprias() -> Array[String]:
	return [NOME_RAINBOW_KNIGHT, NOME_PUPPET, NOME_ENGLAND_CAVALRY]


func _habilidade_propria_consome_acao(nome: String) -> bool:
	if nome == NOME_ENGLAND_CAVALRY:
		return false  # consumida manualmente só quando o alvo é confirmado
	return true  # Rainbow Knight e Puppet consomem normalmente, na hora do clique


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_RAINBOW_KNIGHT and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_RAINBOW_KNIGHT:
			_executar_rainbow_knight()
			iniciar_cooldown(nome, cooldown_rainbow_knight)
		NOME_PUPPET:
			_executar_puppet()
			iniciar_cooldown(nome, cooldown_puppet)
		NOME_ENGLAND_CAVALRY:
			_iniciar_england_cavalry()


func _on_turno_mudou(time_iniciado: String) -> void:
	super._on_turno_mudou(time_iniciado)
	# os toques do Puppet valem só "neste turno" — igual ao Scissors
	# Dribble do Yukimiya, se sobrar algum sem usar quando o time do
	# Teddy passa a vez, expira aqui
	if _puppet_ativo and time_iniciado != time:
		_puppet_ativo = false
		acoes_movimento_bonus = 0


## --- Rainbow Knight ---

func _executar_rainbow_knight() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	# parar_ao_chegar = false: é um chute a gol, precisa manter a
	# velocidade da curva pra continuar entrando
	bola.receber_chute_curvo(gol.ponto_para_mira(), forca_rainbow_knight, time, intensidade_curva_rainbow_knight, duracao_curva_rainbow_knight, false)


## --- Puppet ---

func _executar_puppet() -> void:
	_puppet_ativo = true
	conceder_acao_movimento_extra(quantidade_acoes_puppet)
	Eventos.mensagem_solicitada.emit("Puppet! Teddy ganhou %d dribles com deslocamento reduzido neste turno." % quantidade_acoes_puppet)


func multiplicador_distancia_arrasto() -> float:
	if _puppet_ativo and acoes_movimento_bonus > 0:
		return multiplicador_distancia_puppet
	return 1.0


## --- England Cavalry ---

func _iniciar_england_cavalry() -> void:
	SelecaoAlvo.pedir_alvo(self, _on_alvo_england_cavalry_escolhido, "Selecione um aliado ou inimigo para o England Cavalry")


func _on_alvo_england_cavalry_escolhido(alvo: Botao) -> void:
	if alvo == self:
		Eventos.mensagem_solicitada.emit("Escolha outro jogador como alvo!")
		return

	consumir_acao_habilidade()
	iniciar_cooldown(NOME_ENGLAND_CAVALRY, cooldown_england_cavalry)

	var direcao := (alvo.global_position - global_position)
	direcao = direcao.normalized() if direcao.length() > 1.0 else Vector2.RIGHT
	var destino := alvo.global_position - direcao * england_cavalry_distancia_parada

	MovimentoSuave.mover(self, destino, england_cavalry_duracao_movimento, func() -> void:
		if not is_instance_valid(alvo):
			return

		if alvo.time == time:
			alvo.conceder_acao_movimento_extra(1)
			alvo.conceder_acao_habilidade_extra(1)
			Eventos.mensagem_solicitada.emit("England Cavalry! Teddy chegou perto do aliado — mais um turno de ações pra ele.")
		else:
			# +1 de "buffer": mesma pegadinha do Glam Block do Aryu/Second
			# Place do Hugo — bloqueio decrementa em toda troca de turno
			# GLOBAL, então "canceladas nesse turno" precisa de 2, não 1
			alvo.aplicar_bloqueio_habilidade(2)
			Eventos.mensagem_solicitada.emit("England Cavalry! Teddy encurralou o inimigo — habilidades dele canceladas no próximo turno.")
	)
