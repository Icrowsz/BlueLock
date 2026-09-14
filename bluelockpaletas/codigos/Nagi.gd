extends Botao
class_name Nagi

## Seishiro Nagi
##
## - Genius Control: desloca o Nagi rapidamente até a bola, DESDE QUE
##   ela esteja dentro do alcance máximo. NÃO gasta a ação de habilidade
##   (só entra em cooldown). Se ele alcançar a bola (ela ficar dentro do
##   AreaAlcance ao terminar o movimento), libera o Follow Up — Death
##   Volley — só NESTE turno. Fluxo pretendido: usar Genius Control e,
##   em seguida, Death Volley. Cooldown de 6 turnos.
##
## - Death Volley (Follow Up): só aparece na lista de habilidades DEPOIS
##   que o Genius Control conecta com a bola no mesmo turno — não tem
##   cooldown próprio (é o Genius Control que tem os 6 turnos). Chute
##   teleguiado no gol inimigo com 200 de força.
##
## - Awaken: gruda a bola no Nagi (grudar_bola(), sistema PADRONIZADO em
##   Botao.gd — usado também pelo Devil Contract do Charles e pelo Royal
##   Heelflick do Sae). Dura 1 "turno do próprio Nagi" — mais curto que
##   o Devil Contract do Charles, de propósito, pra equilibrar — com
##   liberação e proteção contra gol automáticas (ver
##   manter_bola_grudada_por() em Botao.gd). Cooldown de 7 turnos.

@export_group("Genius Control")
@export var duracao_genius_control: float = 0.6  ## rápido — "desloca rapidamente"
@export var distancia_parada_da_bola: float = 30.0
@export var alcance_maximo_genius_control: float = 280.0  ## distância MÁXIMA até a bola pra poder ativar
@export var cooldown_genius_control: int = 6

@export_group("Death Volley (Follow Up)")
@export var forca_death_volley: float = 250.0

@export_group("Awaken")
@export var turnos_awaken: int = 1  ## mais curto que os 2 do Devil Contract do Charles, de propósito
@export var cooldown_awaken: int = 7

@export_group("Kill It (Chemical Reaction: Miracle)")
@export var forca_kill_it: float = 550.0
@export var cooldown_kill_it: int = 6
@export var textura_kill_it: Texture2D  ## imagem mostrada em tela cheia ao usar (ver EfeitoHabilidade.gd)

@export_group("Five Stage Volley (evolução do Kill It)")
@export var forca_five_stage_volley: float = 800.0
@export var duracao_intangivel_five_stage_volley: float = 0.3
@export var textura_five_stage_volley: Texture2D

const NOME_GENIUS_CONTROL := "Genius Control"
const NOME_DEATH_VOLLEY := "Death Volley"
const NOME_AWAKEN := "Awaken"
const NOME_KILL_IT := "Kill It"
const NOME_FIVE_STAGE_VOLLEY := "Five Stage Volley"

var _death_volley_disponivel: bool = false

## true a partir do momento em que a Chemical Reaction "Miracle" dispara
## (ver ReacoesQuimicas.gd) — habilidade PRÓPRIA de verdade (cooldown
## reutilizável), não um empréstimo de uso único.
var _tem_kill_it: bool = false

## true depois que o Chameleon Dream do Reo chega de verdade no Nagi
## (segunda instância da mesma Chemical Reaction) — upgrade PERMANENTE:
## Kill It nunca mais volta a aparecer, só Five Stage Volley, pelo resto
## da partida.
var _kill_it_evoluido: bool = false


func conceder_kill_it() -> void:
	_tem_kill_it = true


func evoluir_para_five_stage_volley() -> void:
	_kill_it_evoluido = true


func habilidades_proprias() -> Array[String]:
	var lista: Array[String] = [NOME_GENIUS_CONTROL, NOME_AWAKEN]
	if _death_volley_disponivel:
		lista.append(NOME_DEATH_VOLLEY)
	if _tem_kill_it:
		lista.append(NOME_FIVE_STAGE_VOLLEY if _kill_it_evoluido else NOME_KILL_IT)
	return lista


func _habilidade_propria_consome_acao(nome: String) -> bool:
	return nome != NOME_GENIUS_CONTROL  # só o Control é de graça


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_GENIUS_CONTROL:
		var bola := encontrar_bola()
		if not bola or global_position.distance_to(bola.global_position) > alcance_maximo_genius_control:
			return "A bola está fora do alcance do Genius Control!"

	if nome in [NOME_DEATH_VOLLEY, NOME_AWAKEN, NOME_KILL_IT, NOME_FIVE_STAGE_VOLLEY] and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome

	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_GENIUS_CONTROL:
			_executar_genius_control()
			iniciar_cooldown(nome, cooldown_genius_control)
		NOME_DEATH_VOLLEY:
			_executar_death_volley()
		NOME_AWAKEN:
			_executar_awaken()
			iniciar_cooldown(nome, cooldown_awaken)
		NOME_KILL_IT:
			_executar_kill_it()
			iniciar_cooldown(NOME_KILL_IT, cooldown_kill_it)
		NOME_FIVE_STAGE_VOLLEY:
			_executar_five_stage_volley()
			# mesmo cooldown do Kill It original — é a MESMA "vaga" de
			# habilidade evoluída, não uma separada, então usa a chave
			# de cooldown correspondente ao nome ATUAL (ver comentário
			# em habilidades_proprias())
			iniciar_cooldown(NOME_FIVE_STAGE_VOLLEY, cooldown_kill_it)


## --- Genius Control / Death Volley ---

func _executar_genius_control() -> void:
	var bola := encontrar_bola()
	if not bola:
		return

	var direcao := (global_position - bola.global_position)
	direcao = direcao.normalized() if direcao.length() > 1.0 else Vector2.RIGHT
	var destino := bola.global_position + direcao * distancia_parada_da_bola

	MovimentoSuave.mover(self, destino, duracao_genius_control, func() -> void:
		if bola_no_alcance:
			_death_volley_disponivel = true
			Eventos.mensagem_solicitada.emit("Genius Control! Death Volley liberado neste turno.")
		else:
			Eventos.mensagem_solicitada.emit("Genius Control! Nagi não alcançou a bola dessa vez.")
	)


func _executar_death_volley() -> void:
	var bola := bola_no_alcance
	if not bola:
		return
	var gol := encontrar_gol_inimigo()
	if not gol:
		return
		
	bola.definir_cor_trail(Color.GHOST_WHITE)

	var direcao := (gol.ponto_para_mira() - bola.global_position).normalized()
	bola.receber_chute_teleguiado(direcao, forca_death_volley)
	_death_volley_disponivel = false


## --- Awaken ---

func _executar_awaken() -> void:
	var bola := bola_no_alcance
	if not bola:
		return
	grudar_bola(bola)
	manter_bola_grudada_por(turnos_awaken)
	Eventos.mensagem_solicitada.emit("Awaken! A bola grudou no Nagi até o início do próximo turno dele.")


## --- Kill It / Five Stage Volley (Chemical Reaction: Miracle) ---

func _executar_kill_it() -> void:
	var bola := bola_no_alcance
	if not bola:
		return
	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	if textura_kill_it:
		await EfeitoHabilidade.mostrar_habilidade(textura_kill_it)

	# a bola pode ter saído do alcance ENQUANTO a animação rodava —
	# confere de novo antes de chutar (mesmo cuidado do Strongest Guy do Isagi)
	if not is_instance_valid(bola) or bola_no_alcance != bola:
		Eventos.mensagem_solicitada.emit("A bola saiu do alcance durante a animação do Kill It!")
		return

	bola.definir_cor_trail(Color.GHOST_WHITE)

	# intensidade 0 -> sai reto, mas MANTÉM o "ignora colisão com todo o
	# time do chutador" do receber_chute_curvo — Nagi e seus aliados
	# ficam de fora da colisão (mesma técnica do Beinschuss do Kaiser)
	bola.receber_chute_curvo(gol.ponto_para_mira(), forca_kill_it, time, 0.0, 1.0, false)
	Eventos.mensagem_solicitada.emit("Kill It! Nagi chuta forte, ignorando os próprios aliados.")


func _executar_five_stage_volley() -> void:
	var bola := bola_no_alcance
	if not bola:
		return
	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	if textura_five_stage_volley:
		await EfeitoHabilidade.mostrar_habilidade(textura_five_stage_volley)

	if not is_instance_valid(bola) or bola_no_alcance != bola:
		Eventos.mensagem_solicitada.emit("A bola saiu do alcance durante a animação do Five Stage Volley!")
		return

	bola.definir_cor_trail(Color.GHOST_WHITE)

	# ignora colisão com QUALQUER botão (dos dois times), só no início
	# da trajetória — mesma técnica do Kaiser Impact
	bola.ativar_intangivel_para_botoes(duracao_intangivel_five_stage_volley)

	var direcao := (gol.ponto_para_mira() - bola.global_position).normalized()
	bola.receber_chute_teleguiado(direcao, forca_five_stage_volley)
	Eventos.mensagem_solicitada.emit("Five Stage Volley! Um chute avassalador, sem colisão nenhuma no início.")
