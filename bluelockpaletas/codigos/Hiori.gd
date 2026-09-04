extends Botao
class_name Hiori

## Hiori Yo
##
## - Millimeter Precision: passe onde o JOGADOR escolhe o ponto exato de
##   chegada da bola (clica em qualquer lugar do campo — não em um
##   aliado). A bola viaja até lá e chega SEM força nenhuma, como um
##   passe automático de verdade (reaproveita Bola.mover_para_com_trajetoria(),
##   a mesma base de outros passes "automáticos" do jogo). Cooldown de
##   6 turnos.
##
##   BALANCEAMENTO: o alcance é limitado (alcance_millimeter_precision)
##   e existe uma zona de segurança ao redor de qualquer gol
##   (raio_exclusao_gol) — cliques além do alcance ou muito perto de um
##   gol são "puxados" de volta automaticamente, pra essa habilidade não
##   virar um gol garantido de graça.
##
##   Como a jogada só termina quando o jogador clica no campo (depois
##   de já ter clicado no botão da habilidade), o custo da ação e o
##   cooldown só entram quando o passe REALMENTE acontece — cancelar a
##   seleção não desperdiça nada.
##
## - Fine-Tuning: um drible PADRÃO (Hiori se desloca com o mesmo arrasto
##   de sempre), só que com o alcance bem reduzido — um "toquezinho" pra
##   se ajustar. A ação de movimento desse toque é paga pela própria
##   habilidade (via conceder_acao_movimento_extra), não pela ação de
##   movimento do time. Assim que o toque termina, ele pode completar
##   com um passe CLÁSSICO de verdade — um chute físico normal (então
##   PODE ser interceptado), dessa vez escolhendo um ALIADO como alvo.

@export_group("Millimeter Precision")
@export var cooldown_millimeter_precision: int = 6
## Distância MÁXIMA (a partir da posição atual da bola) que o ponto
## escolhido pode ficar. Nível médio/baixo de propósito: é um passe
## garantido (sem interceptação), então não pode alcançar o campo
## inteiro — se o jogador clicar mais longe que isso, o ponto é
## "puxado" de volta pra essa distância, na mesma direção do clique.
@export var alcance_millimeter_precision: float = 350.0
## Raio de segurança ao redor de QUALQUER gol (o próprio e o inimigo).
## Se o ponto calculado cair mais perto de um gol do que isso, ele é
## empurrado pra fora dessa zona — é isso que fecha a brecha do "gol
## automático" (chutar direto pra dentro do gol inimigo sem risco).
@export var raio_exclusao_gol: float = 90.0

@export_group("Fine-Tuning")
@export var cooldown_fine_tuning: int = 4
## Quanto sobra do alcance normal de arrasto durante o toque reduzido
## (0.3 = 30% do alcance normal). Só vale enquanto o toque está rolando.
@export_range(0.05, 0.9) var fracao_alcance_drible: float = 0.3
## Força do chute em direção ao aliado escolhido, ao final do Fine-Tuning.
@export var forca_passe_classico: float = 500.0

const NOME_MILLIMETER := "Millimeter Precision"
const NOME_FINE_TUNING := "Fine-Tuning"

var _em_toque_fine_tuning: bool = false  # true só durante o arrasto reduzido do Fine-Tuning


func habilidades_proprias() -> Array[String]:
	return [NOME_MILLIMETER, NOME_FINE_TUNING]


func _habilidade_propria_consome_acao(nome: String) -> bool:
	if nome == NOME_MILLIMETER:
		# consome manualmente dentro de _on_ponto_escolhido_millimeter(),
		# só quando o passe de fato acontece — mesmo motivo de qualquer
		# habilidade que espera uma seleção depois do clique inicial
		return false
	return true  # Fine-Tuning consome normalmente, na hora do clique


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_MILLIMETER and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % NOME_MILLIMETER
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_MILLIMETER:
			_iniciar_millimeter_precision()
		NOME_FINE_TUNING:
			_iniciar_fine_tuning()


## --- Millimeter Precision ---

func _iniciar_millimeter_precision() -> void:
	SelecaoAlvo.pedir_ponto(self, _on_ponto_escolhido_millimeter, "Clique no campo pra onde a bola deve ir (Millimeter Precision)")


func _on_ponto_escolhido_millimeter(ponto: Vector2) -> void:
	var bola := bola_no_alcance
	if not bola:
		Eventos.mensagem_solicitada.emit("A bola não está mais por perto — Millimeter Precision cancelado.")
		return

	var ponto_final := _ajustar_ponto_millimeter(ponto, bola.global_position)
	bola.mover_para_com_trajetoria(ponto_final)

	consumir_acao_habilidade()
	iniciar_cooldown(NOME_MILLIMETER, cooldown_millimeter_precision)

	if ponto_final.distance_to(ponto) > 1.0:
		Eventos.mensagem_solicitada.emit("Millimeter Precision! (ajustado ao alcance) A bola foi cravada perto de onde Hiori mandou.")
	else:
		Eventos.mensagem_solicitada.emit("Millimeter Precision! A bola foi cravada exatamente onde Hiori mandou.")


func _ajustar_ponto_millimeter(ponto_clicado: Vector2, origem: Vector2) -> Vector2:
	# 1) limita a distância MÁXIMA a partir da bola — sem isso dava pra
	# mandar a bola pro campo inteiro, inclusive direto no gol inimigo
	var ponto := origem + (ponto_clicado - origem).limit_length(alcance_millimeter_precision)

	# 2) empurra o ponto pra fora de QUALQUER gol, se ele cair perto
	# demais — fecha de vez a brecha do "gol automático"
	for nodo in get_tree().get_nodes_in_group("gols"):
		var gol := nodo as Gol
		if not gol:
			continue

		var centro := gol.ponto_para_mira()
		var deslocamento := ponto - centro
		if deslocamento.length() < raio_exclusao_gol:
			var direcao := deslocamento.normalized() if deslocamento.length() > 0.001 else (origem - centro).normalized()
			ponto = centro + direcao * raio_exclusao_gol

	# 3) depois de afastar do gol, garante de novo o alcance máximo —
	# empurrar pra longe do gol pode, em casos raros, jogar o ponto pra
	# fora do alcance permitido
	return origem + (ponto - origem).limit_length(alcance_millimeter_precision)


## --- Fine-Tuning ---

func _iniciar_fine_tuning() -> void:
	_em_toque_fine_tuning = true

	# paga o toque com uma ação de movimento BÔNUS pessoal (a mesma
	# usada pelo "impulsionado duas vezes" do One Two do Kurona) — assim
	# não gasta a ação de movimento compartilhada do time, e o toque
	# continua "de graça" porque já foi pago pela ação de habilidade
	conceder_acao_movimento_extra(1)

	iniciar_cooldown(NOME_FINE_TUNING, cooldown_fine_tuning)
	Eventos.mensagem_solicitada.emit("Fine-Tuning! Arraste %s pra dar o toque." % name)


func multiplicador_distancia_arrasto() -> float:
	if _em_toque_fine_tuning:
		return fracao_alcance_drible
	return super.multiplicador_distancia_arrasto()


func _apos_chute(sucesso: bool) -> void:
	super._apos_chute(sucesso)

	if not _em_toque_fine_tuning:
		return
	_em_toque_fine_tuning = false

	if not sucesso:
		# arrasto curto demais pra contar como toque de verdade — devolve
		# a ação de movimento bônus, senão ela ficaria "sobrando" livre
		# pra usar num movimento de alcance normal depois, de graça
		if acoes_movimento_bonus > 0:
			acoes_movimento_bonus -= 1
		return

	_tentar_passe_classico()


func _tentar_passe_classico() -> void:
	var bola := bola_no_alcance
	if not bola:
		Eventos.mensagem_solicitada.emit("A bola não está por perto — Fine-Tuning terminou só no toque.")
		return

	SelecaoAlvo.pedir_alvo(self, _on_alvo_escolhido_passe_classico, "Escolha o aliado do passe clássico (Fine-Tuning)")


func _on_alvo_escolhido_passe_classico(alvo: Botao) -> void:
	if alvo == self or alvo.time != time:
		Eventos.mensagem_solicitada.emit("Escolha um companheiro de time como alvo!")
		return

	var bola := bola_no_alcance
	if not bola:
		Eventos.mensagem_solicitada.emit("A bola não está mais por perto pra completar o passe.")
		return

	var direcao := alvo.global_position - bola.global_position
	if direcao.length() < 0.001:
		return
	bola.receber_chute_teleguiado(direcao.normalized(), forca_passe_classico)

	Eventos.mensagem_solicitada.emit("Passe clássico enviado pra %s!" % alvo.name)


func _on_turno_mudou(time_iniciado: String) -> void:
	super._on_turno_mudou(time_iniciado)

	if _em_toque_fine_tuning:
		# o jogador não chegou a arrastar o toque a tempo — cancela pra
		# não vazar o alcance reduzido (nem a ação bônus não usada) pro
		# próximo turno
		_em_toque_fine_tuning = false
		if acoes_movimento_bonus > 0:
			acoes_movimento_bonus -= 1
		Eventos.mensagem_solicitada.emit("O toque do Fine-Tuning expirou sem ser usado.")
