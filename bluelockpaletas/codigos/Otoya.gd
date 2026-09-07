extends Botao
class_name Otoya

## Otoya
##
## PASSIVA — Stealth: se Otoya passar 3 turnos SEGUIDOS sem realizar
## nenhuma ação (nem deslocamento, nem habilidade), fica com a
## opacidade reduzida em 70% (modulate.a = 0.3) até agir de novo — a
## qualquer ação, sai do Stealth imediatamente na próxima virada de
## turno dele. Sem custo, sem cooldown, sempre ligada.
##
## - Ninja Shot: chute comum e teleguiado no gol inimigo, igual ao
##   Chute Direto do Isagi — mas se Otoya estiver EM Stealth no momento
##   do chute, recebe um bônus de força (o "ataque surpresa"). Cooldown
##   de 5 turnos.
##
## - Shadow Step: escolhe um aliado e desliza até perto dele. Tem um
##   alcance bem maior que o normal, mas NÃO cobre o campo inteiro — se
##   o aliado escolhido estiver longe demais, a habilidade recusa.
##   Cooldown de 5 turnos.

@export_group("Passiva: Stealth")
@export var turnos_para_stealth: int = 2
@export var opacidade_em_stealth: float = 0.3  ## 0.3 = reduzida em 70%

@export_group("Ninja Shot")
@export var forca_ninja_shot: float = 90.0
@export var bonus_forca_stealth: float = 30.0  ## força extra recebida se o chute sair EM Stealth
@export var cooldown_ninja_shot: int = 6

@export_group("Shadow Step")
@export var alcance_shadow_step: float = 300.0  ## grande, mas não cobre o campo inteiro
@export var distancia_parada_do_aliado: float = 50.0
@export var duracao_shadow_step: float = 0.5
@export var cooldown_shadow_step: int = 5

const NOME_NINJA_SHOT := "Ninja Shot"
const NOME_SHADOW_STEP := "Shadow Step"

var _turnos_parado: int = 0
var _agiu_no_turno_atual: bool = false


func habilidades_proprias() -> Array[String]:
	return [NOME_NINJA_SHOT, NOME_SHADOW_STEP]


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_NINJA_SHOT and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func _habilidade_propria_consome_acao(nome: String) -> bool:
	if nome == NOME_SHADOW_STEP:
		# consumida manualmente em _on_alvo_shadow_step(), só quando o
		# deslocamento de fato acontece — escolher um alvo inválido ou
		# fora de alcance não desperdiça a ação nem o cooldown
		return false
	return true


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_NINJA_SHOT:
			_agiu_no_turno_atual = true  # qualquer habilidade usada conta como "ação" pra passiva
			_executar_ninja_shot()
			iniciar_cooldown(nome, cooldown_ninja_shot)
		NOME_SHADOW_STEP:
			_iniciar_shadow_step()


## --- Passiva: Stealth ---

func esta_em_stealth() -> bool:
	return _turnos_parado >= turnos_para_stealth


func _atualizar_opacidade_stealth() -> void:
	modulate.a = opacidade_em_stealth if esta_em_stealth() else 1.0


func _apos_chute(sucesso: bool) -> void:
	super._apos_chute(sucesso)
	if sucesso:
		_agiu_no_turno_atual = true  # deslocamento normal também conta como ação


func _on_turno_mudou(time_iniciado: String) -> void:
	super._on_turno_mudou(time_iniciado)
	if time_iniciado != time:
		return  # só avaliamos isso quando é a vez DELE começar de novo

	if _agiu_no_turno_atual:
		_turnos_parado = 0
	else:
		_turnos_parado += 1

	_agiu_no_turno_atual = false
	_atualizar_opacidade_stealth()


## --- Ninja Shot ---

func _executar_ninja_shot() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	var forca := forca_ninja_shot + (bonus_forca_stealth if esta_em_stealth() else 0.0)
	var direcao := (gol.ponto_para_mira() - bola.global_position).normalized()
	bola.receber_chute_teleguiado(direcao, forca)


## --- Shadow Step ---

func _iniciar_shadow_step() -> void:
	SelecaoAlvo.pedir_alvo(self, _on_alvo_shadow_step, "Escolha um aliado para o Shadow Step (alcance limitado)")


func _on_alvo_shadow_step(alvo: Botao) -> void:
	if alvo == self or alvo.time != time:
		Eventos.mensagem_solicitada.emit("Escolha um companheiro de time como alvo!")
		return

	var distancia := global_position.distance_to(alvo.global_position)
	if distancia > alcance_shadow_step:
		Eventos.mensagem_solicitada.emit("Esse aliado está fora do alcance do Shadow Step!")
		return

	var direcao := (global_position - alvo.global_position)
	direcao = direcao.normalized() if direcao.length() > 1.0 else Vector2.RIGHT
	var destino := alvo.global_position + direcao * distancia_parada_do_aliado
	MovimentoSuave.mover(self, destino, duracao_shadow_step)

	_agiu_no_turno_atual = true
	consumir_acao_habilidade()
	iniciar_cooldown(NOME_SHADOW_STEP, cooldown_shadow_step)
