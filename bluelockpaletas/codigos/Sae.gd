extends Botao
class_name Sae

## Sae Itoshi
##
## - Perfect Pass: passe garantido (sem força real, sem chance de
##   interceptação — mesma técnica do Shark Assault/mover_para_com_
##   trajetoria) até um PONTO escolhido pelo jogador. Usa só
##   SelecaoAlvo.pedir_ponto() — clicar em cima de um jogador já
##   funciona sozinho pra "passar pra ele", porque o clique captura a
##   posição do mouse mesmo quando cai em cima de um Botao (Botao._input
##   não chama set_input_as_handled() nesse caso, então o clique
##   propaga até o _input() do SelecaoAlvo). Tem um ALCANCE MÁXIMO
##   (medido a partir da posição atual da bola): cliques mais longe são
##   "puxados" de volta pra essa distância, na mesma direção — não fica
##   ilimitado. Cooldown de 7 turnos.
##
## - Royal Heelflick: concede uma ação de movimento EXTRA (pessoal,
##   acoes_movimento_bonus) pra ele. Quando essa ação bônus específica é
##   usada, a colisão do Sae com outros BOTÕES fica desativada durante
##   todo o trajeto (ele atravessa todo mundo, mas continua colidindo
##   com paredes normalmente). Se a bola estiver no AreaAlcance no
##   momento em que a habilidade é ATIVADA, ela gruda nele
##   (grudar_bola(), sistema PADRONIZADO em Botao.gd) e o segue durante
##   esse deslocamento, soltando naturalmente quando ele parar — e ele
##   também ganha uma ação de HABILIDADE extra.
##
##   REDE DE SEGURANÇA: se o deslocamento bônus nunca acontecer de
##   verdade (ex: arrasto cancelado com botão direito, ou o jogador
##   simplesmente termina o turno sem arrastar), tanto a bola grudada
##   quanto a colisão desativada são desfeitas SOZINHAS no início do
##   próximo turno de Sae — a bola via manter_bola_grudada_por()
##   (Botao.gd), e a colisão/ação bônus não usada por um contador
##   equivalente aqui. Antes, nenhum dos dois tinha esse prazo, e a
##   habilidade podia deixar o Sae travado (intangível e/ou com a bola
##   grudada) pelo resto da partida. Cooldown de 8 turnos.
##
## - Genius: avanço curto até a bola. Se alcançar (ela ficar dentro do
##   AreaAlcance ao terminar o movimento), chuta automaticamente com
##   força média no gol inimigo. Cooldown de 6 turnos.

@export_group("Perfect Pass")
@export var duracao_perfect_pass: float = 0.6
@export var alcance_maximo_perfect_pass: float = 350.0  ## distância MÁXIMA a partir da bola — cliques mais longe são "puxados" de volta pra essa distância
@export var cooldown_perfect_pass: int = 7

@export_group("Royal Heelflick")
  ## mesma convenção do Bola.gd — ajuste se seus botões usam outra camada de física
@export var turnos_bola_grudada_heelflick: int = 1  ## rede de segurança (ver Botao.gd) — a liberação "natural" abaixo costuma acontecer bem antes disso
@export var cooldown_royal_heelflick: int = 8

@export_group("Genius")
@export var duracao_genius: float = 0.3  ## avanço "curto"
@export var distancia_parada_da_bola_genius: float = 30.0
@export var forca_genius: float = 175.0  ## "força média" — entre o Bee Shot (75) e o Chute Direto (150)
@export var cooldown_genius: int = 6

const NOME_PERFECT_PASS := "Perfect Pass"
const NOME_ROYAL_HEELFLICK := "Royal Heelflick"
const NOME_GENIUS := "Genius"



func habilidades_proprias() -> Array[String]:
	return [NOME_PERFECT_PASS, NOME_ROYAL_HEELFLICK, NOME_GENIUS]


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_PERFECT_PASS and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func _habilidade_propria_consome_acao(nome: String) -> bool:
	if nome == NOME_PERFECT_PASS:
		# consumida manualmente em _on_ponto_perfect_pass(), só quando o
		# passe de fato sai — cancelar a seleção não desperdiça nada
		return false
	return true


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_PERFECT_PASS:
			SelecaoAlvo.pedir_ponto(self, _on_ponto_perfect_pass, "Clique num jogador ou em qualquer ponto do campo (Perfect Pass)")
		NOME_ROYAL_HEELFLICK:
			_executar_royal_heelflick()
			iniciar_cooldown(nome, cooldown_royal_heelflick)
		NOME_GENIUS:
			_executar_genius()
			iniciar_cooldown(nome, cooldown_genius)


## --- Perfect Pass ---

func _on_ponto_perfect_pass(ponto: Vector2) -> void:
	var bola := bola_no_alcance
	if not bola:
		Eventos.mensagem_solicitada.emit("A bola não está mais por perto — Perfect Pass cancelado.")
		return

	var origem := bola.global_position
	var ponto_final := origem + (ponto - origem).limit_length(alcance_maximo_perfect_pass)

	bola.mover_para_com_trajetoria(ponto_final, duracao_perfect_pass)

	consumir_acao_habilidade()
	iniciar_cooldown(NOME_PERFECT_PASS, cooldown_perfect_pass)

	if ponto_final.distance_to(ponto) > 1.0:
		Eventos.mensagem_solicitada.emit("Perfect Pass! (ajustado ao alcance máximo) A bola chegou perto de onde você mandou.")
	else:
		Eventos.mensagem_solicitada.emit("Perfect Pass! A bola chegou exatamente onde você mandou.")


## --- Royal Heelflick ---

func _executar_royal_heelflick() -> void:
	conceder_acao_movimento_extra(1)
 # se a ação bônus não for usada até o início do próximo turno do Sae, tudo é desfeito sozinho

	if bola_no_alcance:
		grudar_bola(bola_no_alcance)
		manter_bola_grudada_por(turnos_bola_grudada_heelflick)  # rede de segurança PADRONIZADA — a liberação natural abaixo ainda acontece mais cedo, quando ele realmente parar
		conceder_acao_habilidade_extra(1)
		Eventos.mensagem_solicitada.emit("Royal Heelflick! Deslocamento extra sem colisão, bola grudada, e mais uma ação de habilidade.")
	else:
		Eventos.mensagem_solicitada.emit("Royal Heelflick! Deslocamento extra sem colisão.")


func _executar_deslocamento(vetor_arrasto: Vector2) -> void:
	# só o deslocamento que efetivamente vai gastar a ação BÔNUS do
	# Heelflick sai sem colisão — o deslocamento comum do time continua
	# normal (mesma lógica de "a ação bônus é sempre consumida primeiro"
	super._executar_deslocamento(vetor_arrasto)





func _restaurar_colisao_apos_parar() -> void:
	# mesma técnica de "esperar assentar" usada no grude padronizado
	# (Botao.gd, _soltar_bola_grudada_com_seguranca): como o deslize
	# continua por vários frames depois do impulso, só restauramos a
	# colisão (e soltamos a bola, se estiver grudada) quando ele
	# realmente para, não no instante do clique.
	const VELOCIDADE_MINIMA_PARADO := 5.0

	await get_tree().physics_frame
	while is_inside_tree() and linear_velocity.length() > VELOCIDADE_MINIMA_PARADO:
		await get_tree().physics_frame

	if is_inside_tree():
		if bola_esta_grudada_em_mim():
			soltar_bola_grudada()




func _on_turno_mudou(time_iniciado: String) -> void:
	super._on_turno_mudou(time_iniciado)

	


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
