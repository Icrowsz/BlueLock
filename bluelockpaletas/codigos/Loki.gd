extends Botao
class_name Loki

## Loki
##
## - Too Slow: uma ação de movimento com o DOBRO de força — forte o
##   bastante pra atravessar o mapa inteiro. Ao ativar, o jogador clica
##   em algum lugar do campo: se clicar perto da BOLA, Loki avança
##   direto até ela ignorando qualquer obstáculo no caminho (mesma
##   técnica de "física congelada" já usada em passes automáticos —
##   nada physically bloqueia o trajeto); se clicar em qualquer outro
##   lugar, isso só arma o PRÓXIMO arrasto normal pra sair com força
##   dobrada. Cooldown de 9 turnos.
##
## - Godspeed: escolhe um alvo inimigo e o alcança, não importa a
##   distância (deslocamento garantido, não uma física normal que
##   poderia "não chegar"); desabilita a ação de movimento do alvo por
##   alguns turnos. Cooldown de 7 turnos.
##
## - Tank: chute médio no gol inimigo, que DOBRA de força se Too Slow ou
##   Godspeed estiverem em cooldown (ou seja, "acabaram de ser usadas").
##   Cooldown de 7 turnos.

@export_group("Too Slow")
@export var multiplicador_forca_too_slow: float = 2.0
@export var raio_foco_bola_too_slow: float = 50.0
@export var duracao_dash_ate_bola: float = 0.4
@export var cooldown_too_slow: int = 9

@export_group("Godspeed")
@export var distancia_aproximacao_godspeed: float = 70.0
@export var duracao_dash_godspeed: float = 0.4
@export var duracao_bloqueio_godspeed: int = 2
@export var cooldown_godspeed: int = 7

@export_group("Tank")
@export var forca_base_tank: float = 300.0
@export var cooldown_tank: int = 7

const NOME_TOO_SLOW := "Too Slow"
const NOME_GODSPEED := "Godspeed"
const NOME_TANK := "Tank"

var _too_slow_forca_dobrada: bool = false


func habilidades_proprias() -> Array[String]:
	return [NOME_TOO_SLOW, NOME_GODSPEED, NOME_TANK]


func _habilidade_propria_consome_acao(nome: String) -> bool:
	# Too Slow e Godspeed dependem de um clique de seleção — a ação só é
	# consumida quando a escolha realmente acontece (ver cada fluxo
	# abaixo), pra cancelar (botão direito/Esc) não custar nada
	return nome == NOME_TANK


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_TANK and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_TOO_SLOW:
			SelecaoAlvo.pedir_ponto(self, _on_ponto_too_slow, "Clique na bola para focar nela, ou em qualquer lugar para um deslocamento com força dobrada")
		NOME_GODSPEED:
			SelecaoAlvo.pedir_alvo(self, _on_alvo_godspeed, "Selecione um inimigo para o Godspeed")
		NOME_TANK:
			_executar_tank()
			iniciar_cooldown(nome, cooldown_tank)


## --- Too Slow ---

func _on_ponto_too_slow(ponto: Vector2) -> void:
	var bola := _encontrar_bola()

	consumir_acao_habilidade()
	iniciar_cooldown(NOME_TOO_SLOW, cooldown_too_slow)

	if bola and ponto.distance_to(bola.global_position) <= raio_foco_bola_too_slow:
		# foco na bola: avança direto até ela, ignorando qualquer
		# obstáculo (física congelada durante o trajeto — mesma técnica
		# de passes automáticos como o Shark Assault do Kurona)
		MovimentoSuave.mover(self, bola.global_position, duracao_dash_ate_bola)
		_consumir_acao_movimento()
		Eventos.mensagem_solicitada.emit("Too Slow! Loki avança direto pra bola, ignorando tudo no caminho.")
	else:
		_too_slow_forca_dobrada = true
		Eventos.mensagem_solicitada.emit("Too Slow ativado! Seu próximo arrasto sai com o dobro de força.")


func _consumir_acao_movimento() -> void:
	# mesma prioridade de sempre: bônus pessoal antes da ação
	# compartilhada do time (ver _soltar_e_chutar no Botao.gd) — usado
	# aqui porque o dash até a bola não passa pelo arrasto normal
	if acoes_movimento_bonus > 0:
		acoes_movimento_bonus -= 1
	else:
		Turnos.usar_acao("movimento")


func _encontrar_bola() -> RigidBody2D:
	var bolas := get_tree().get_nodes_in_group("bola")
	return bolas[0] if not bolas.is_empty() else null


func _executar_deslocamento(vetor_arrasto: Vector2) -> void:
	if _too_slow_forca_dobrada:
		_too_slow_forca_dobrada = false
		var forca := (vetor_arrasto * multiplicador_forca * multiplicador_forca_chute_total() * multiplicador_forca_too_slow) \
			.limit_length(forca_maxima * multiplicador_forca_chute_total() * multiplicador_forca_too_slow)
		apply_central_impulse(forca)
		return

	super._executar_deslocamento(vetor_arrasto)


## --- Godspeed ---

func _on_alvo_godspeed(alvo: Botao) -> void:
	if alvo == self or alvo.time == time:
		Eventos.mensagem_solicitada.emit("Escolha um oponente como alvo!")
		return

	consumir_acao_habilidade()
	iniciar_cooldown(NOME_GODSPEED, cooldown_godspeed)

	var direcao_aproximacao := (global_position - alvo.global_position)
	direcao_aproximacao = direcao_aproximacao.normalized() if direcao_aproximacao.length() > 1.0 else Vector2.RIGHT
	var destino := alvo.global_position + direcao_aproximacao * distancia_aproximacao_godspeed

	MovimentoSuave.mover(self, destino, duracao_dash_godspeed)
	alvo.aplicar_bloqueio_movimento(duracao_bloqueio_godspeed)

	Eventos.mensagem_solicitada.emit("Godspeed! Loki alcançou %s e travou o movimento dele por %d turno(s)." % [alvo.name, duracao_bloqueio_godspeed])


## --- Tank ---

func _executar_tank() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	var forca := forca_base_tank
	if esta_em_cooldown(NOME_TOO_SLOW) or esta_em_cooldown(NOME_GODSPEED):
		forca *= 2.0

	var direcao := (gol.ponto_para_mira() - bola.global_position).normalized()
	bola.receber_chute_teleguiado(direcao, forca)
