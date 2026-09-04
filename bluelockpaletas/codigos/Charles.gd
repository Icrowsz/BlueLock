extends Botao
class_name Charles

## Charles Chevalier
##
## PASSIVA (o primeiro personagem com uma passiva declarada — sem custo
## de ação, sem cooldown, sempre ligada): Charles desliza muito mais que
## os outros nas ações de movimento. Implementado reduzindo o
## linear_damp dele (o "atrito" que freia o deslize) bem abaixo do
## padrão da classe base (1.5).
##
## - Rabona Cross: igual ao Millimeter Precision do Hiori (o JOGADOR
##   escolhe o ponto exato do campo pra onde a bola vai), só que em vez
##   de um passe automático em linha reta e sem força, esse é um chute
##   DE VERDADE em curva (mesma base do Curve Shot do Rin) — ignora
##   colisão com aliados, mas um OPONENTE no caminho pode interceptar.
##   Freia sozinho ao chegar no ponto escolhido (não é um chute a gol,
##   é um cruzamento — não devia sair "voando" além do ponto). Cooldown
##   de 6 turnos.
##
## - Devil Contract: "gruda" a bola no Charles LITERALMENTE — a bola vira
##   filha dele na árvore de cena por este turno e o próximo turno DELE
##   (sobrevivendo a um turno inteiro do time adversário no meio), então
##   ela se move junto automaticamente (segue a transformação do Charles
##   pra sempre estar exatamente onde ele está, sem atraso nenhum,
##   mesmo durante o deslize). Congelamos a física da bola nesse período
##   (freeze = true), então ela também vira intransponível — ninguém
##   consegue roubar. Precisa da bola por perto pra ser ativado.
##   Cooldown de 6 turnos.

@export_group("Passiva: Deslize")
@export var linear_damp_charles: float = 1  ## padrão da classe base é 1.5 — quanto MENOR, mais ele desliza

@export_group("Rabona Cross")
@export var forca_rabona_cross: float = 150.0
@export var cooldown_rabona_cross: int = 6
@export var intensidade_curva_rabona: float = 70.0
@export var duracao_curva_rabona: float = 1.0

@export_group("Devil Contract")
@export var cooldown_devil_contract: int = 6

const NOME_RABONA_CROSS := "Rabona Cross"
const NOME_DEVIL_CONTRACT := "Devil Contract"

var _devil_contract_ativo: bool = false
var _devil_contract_ja_passou_um_turno_dele: bool = false
var _bola_grudada: RigidBody2D = null
var _pai_original_da_bola: Node = null


func _ready() -> void:
	super._ready()
	linear_damp = linear_damp_charles  # a passiva: menos atrito, mais deslize
	# segurança: se um gol acontecer com a bola ainda grudada, solta ela
	# ANTES do Placar tentar resetar posição/física — evita mexer numa
	# bola congelada e "filha" de outro nó no meio do reset
	Eventos.gol_marcado.connect(_on_gol_marcado)


func habilidades_proprias() -> Array[String]:
	return [NOME_RABONA_CROSS, NOME_DEVIL_CONTRACT]


func _habilidade_propria_consome_acao(nome: String) -> bool:
	if nome == NOME_RABONA_CROSS:
		# consumida manualmente em _on_ponto_escolhido_rabona(), só quando
		# o cruzamento de fato acontece — mesmo motivo do Millimeter
		# Precision do Hiori (cancelar a seleção não desperdiça a ação)
		return false
	return true  # Devil Contract consome normalmente, na hora do clique


func _requisito_extra_propria(nome: String) -> String:
	if bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_RABONA_CROSS:
			_iniciar_rabona_cross()
		NOME_DEVIL_CONTRACT:
			_executar_devil_contract()
			iniciar_cooldown(nome, cooldown_devil_contract)


## --- Rabona Cross ---

func _iniciar_rabona_cross() -> void:
	SelecaoAlvo.pedir_ponto(self, _on_ponto_escolhido_rabona, "Clique no campo pra onde a bola deve cair (Rabona Cross)")


func _on_ponto_escolhido_rabona(ponto: Vector2) -> void:
	var bola := bola_no_alcance
	if not bola:
		Eventos.mensagem_solicitada.emit("A bola não está mais por perto — Rabona Cross cancelado.")
		return

	bola.receber_chute_curvo(ponto, forca_rabona_cross, time, intensidade_curva_rabona, duracao_curva_rabona, true)

	consumir_acao_habilidade()
	iniciar_cooldown(NOME_RABONA_CROSS, cooldown_rabona_cross)
	Eventos.mensagem_solicitada.emit("Rabona Cross! A bola foi cruzada em curva até o ponto escolhido.")


## --- Devil Contract ---

func _executar_devil_contract() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	_devil_contract_ativo = true
	_devil_contract_ja_passou_um_turno_dele = false
	_grudar_bola(bola)
	Eventos.mensagem_solicitada.emit("Devil Contract! A bola grudou no Charles até o fim do próximo turno dele.")


func _grudar_bola(bola: RigidBody2D) -> void:
	_bola_grudada = bola
	_pai_original_da_bola = bola.get_parent()

	bola.linear_velocity = Vector2.ZERO
	bola.angular_velocity = 0.0
	bola.freeze = true  # congela a física dela: ninguém empurra, ninguém rouba

	# reparent(..., true) = MANTÉM a posição global atual no momento da
	# troca — a bola não teleporta pra cima do Charles, ela gruda
	# exatamente onde já estava (perto dele), só que agora como filha:
	# a partir daqui, toda vez que ele se mover, ela se move junto,
	# automaticamente, sem nenhum código rodando a cada frame.
	bola.reparent(self, true)


func _soltar_bola_grudada() -> void:
	if not _bola_grudada or not is_instance_valid(_bola_grudada):
		_bola_grudada = null
		return

	var pai_destino := _pai_original_da_bola if is_instance_valid(_pai_original_da_bola) else get_tree().current_scene
	_bola_grudada.reparent(pai_destino, true)  # true = mantém a posição global — não "pula" ao soltar
	_bola_grudada.freeze = false
	_bola_grudada.reset_physics_interpolation()
	_bola_grudada = null
	_pai_original_da_bola = null


func _on_gol_marcado(_lado: String) -> void:
	if _devil_contract_ativo:
		_soltar_bola_grudada()


func _on_turno_mudou(time_iniciado: String) -> void:
	super._on_turno_mudou(time_iniciado)

	if not _devil_contract_ativo or time_iniciado != time:
		return  # só contamos turnos DO TIME do Charles pra essa duração

	if _devil_contract_ja_passou_um_turno_dele:
		# esse turno_iniciado(self.time) é o turno DEPOIS do "próximo
		# turno" prometido — agora sim expira e solta a bola
		_devil_contract_ativo = false
		_soltar_bola_grudada()
		Eventos.mensagem_solicitada.emit("Devil Contract acabou — a bola não gruda mais no Charles.")
	else:
		# esse turno_iniciado(self.time) É o "próximo turno" — continua
		# ativo durante ele inteiro, só marca que já "usamos" esse turno extra
		_devil_contract_ja_passou_um_turno_dele = true
