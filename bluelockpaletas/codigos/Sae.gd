extends Botao
class_name Sae

## Sae Itoshi
##
## - Perfect Pass: [PENDENTE]
##
## - Royal Heelflick: [PENDENTE] concede uma ação de movimento EXTRA (pessoal,
##   acoes_movimento_bonus) pra ele. Quando essa ação bônus específica é
##   usada, a colisão do Sae com outros BOTÕES fica desativada durante
##   todo o trajeto (ele atravessa todo mundo, mas continua colidindo
##   com paredes normalmente). Se a bola estiver no AreaAlcance no
##   momento em que a habilidade é ATIVADA, ela gruda nele
##   (grudar_bola(), mesma base do Devil Contract do Charles) e o segue
##   durante esse deslocamento, soltando sozinha quando ele parar — e
##   ele também ganha uma ação de HABILIDADE extra. Cooldown de 8
##   turnos.
##
## - Genius: avanço curto até a bola. Se alcançar (ela ficar dentro do
##   AreaAlcance ao terminar o movimento), chuta automaticamente com
##   força média no gol inimigo. Cooldown de 6 turnos.

@export_group("Royal Heelflick")
@export_flags_2d_physics var camada_botoes: int = 2  ## mesma convenção do Bola.gd — ajuste se seus botões usam outra camada de física
@export var cooldown_royal_heelflick: int = 8

@export_group("Genius")
@export var duracao_genius: float = 0.3  ## avanço "curto"
@export var distancia_parada_da_bola_genius: float = 30.0
@export var forca_genius: float = 250.0  ## "força média" — entre o Bee Shot (75) e o Chute Direto (150)
@export var cooldown_genius: int = 6

const NOME_PERFECT_PASS := "Perfect Pass"
const NOME_ROYAL_HEELFLICK := "Royal Heelflick"
const NOME_GENIUS := "Genius"

var _heelflick_sem_colisao_pendente: bool = false  # true = a PRÓXIMA ação de movimento vem sem colisão


func habilidades_proprias() -> Array[String]:
	return [NOME_PERFECT_PASS, NOME_ROYAL_HEELFLICK, NOME_GENIUS]


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_ROYAL_HEELFLICK:
			_executar_royal_heelflick()
			iniciar_cooldown(nome, cooldown_royal_heelflick)
		NOME_GENIUS:
			_executar_genius()
			iniciar_cooldown(nome, cooldown_genius)
		NOME_PERFECT_PASS:
			pass  # PENDENTE


## --- Royal Heelflick ---

func _executar_royal_heelflick() -> void:
	conceder_acao_movimento_extra(1)
	_heelflick_sem_colisao_pendente = true

	if bola_no_alcance:
		grudar_bola(bola_no_alcance)
		conceder_acao_habilidade_extra(1)
		Eventos.mensagem_solicitada.emit("Royal Heelflick! Deslocamento extra sem colisão, bola grudada, e mais uma ação de habilidade.")
	else:
		Eventos.mensagem_solicitada.emit("Royal Heelflick! Deslocamento extra sem colisão.")


func _executar_deslocamento(vetor_arrasto: Vector2) -> void:
	# só o deslocamento que efetivamente vai gastar a ação BÔNUS do
	# Heelflick sai sem colisão — o deslocamento comum do time continua
	# normal (mesma lógica de "a ação bônus é sempre consumida primeiro"
	# usada pelo Monster Trance do Bachira e outros)
	if _heelflick_sem_colisao_pendente and acoes_movimento_bonus > 0:
		_heelflick_sem_colisao_pendente = false
		_desativar_colisao_temporariamente()
	super._executar_deslocamento(vetor_arrasto)


func _desativar_colisao_temporariamente() -> void:
	var camada_original := collision_layer
	var mascara_original := collision_mask
	collision_layer = collision_layer & ~camada_botoes
	collision_mask = collision_mask & ~camada_botoes

	_restaurar_colisao_apos_parar(camada_original, mascara_original)


func _restaurar_colisao_apos_parar(camada_original: int, mascara_original: int) -> void:
	# mesma técnica de "esperar assentar" usada no Awaken do Nagi: como o
	# deslize continua por vários frames depois do impulso, restauramos a
	# colisão (e soltamos a bola, se estiver grudada) só quando ele
	# realmente para, não no instante do clique.
	const VELOCIDADE_MINIMA_PARADO := 5.0

	await get_tree().physics_frame
	while is_inside_tree() and linear_velocity.length() > VELOCIDADE_MINIMA_PARADO:
		await get_tree().physics_frame

	if is_inside_tree():
		collision_layer = camada_original
		collision_mask = mascara_original
		if bola_esta_grudada_em_mim():
			soltar_bola_grudada()


## --- Genius ---

func _executar_genius() -> void:
	var bola := encontrar_bola()
	if not bola:
		return

	var direcao := (global_position - bola.global_position)
	direcao = direcao.normalized() if direcao.length() > 1.0 else Vector2.RIGHT
	var destino := bola.global_position + direcao * distancia_parada_da_bola_genius

	MovimentoSuave.mover(self, destino, duracao_genius, func() -> void:
		if not bola_no_alcance:
			Eventos.mensagem_solicitada.emit("Genius! Sae não alcançou a bola dessa vez.")
			return

		var gol := encontrar_gol_inimigo()
		if not gol:
			return

		var direcao_chute := (gol.ponto_para_mira() - bola_no_alcance.global_position).normalized()
		bola_no_alcance.receber_chute_teleguiado(direcao_chute, forca_genius)
		Eventos.mensagem_solicitada.emit("Genius! Sae alcançou a bola e chutou.")
	)
