extends Botao
class_name Shidou

## Ryusei Shidou
##
## - Dragon Drive: chute forte, reto, no gol inimigo. Reaproveita
##   receber_chute_curvo() só pelo efeito colateral dela de ignorar
##   colisão com QUALQUER botão do MESMO time de quem chuta — inclusive
##   o próprio atirador, já que ele também conta como "botão do time".
##   Passamos intensidade de curva 0 pra desativar a curva em si (fica
##   reto), mas mantemos essa parte. Na prática: a bola atravessa o
##   próprio Shidou e os aliados, então dá pra chutar "de costas" pro
##   gol sem se atrapalhar. Cooldown de 6 turnos.
##
## - Demon Rush: avanço médio até a bola. Se alcançar (ela ficar dentro
##   do AreaAlcance ao terminar o movimento), ganha uma ação de
##   habilidade extra e libera o Follow Up — KaKaBoom — só NESTE turno.
##   Cooldown de 6 turnos.
##
## - KaKaBoom (Follow Up): só aparece na lista de habilidades depois que
##   o Demon Rush conecta com a bola no mesmo turno — não tem cooldown
##   próprio. Chute forte e reto no gol inimigo, mas SEM nenhuma
##   proteção contra colisão — um oponente no caminho intercepta
##   normalmente.

@export_group("Dragon Drive")
@export var forca_dragon_drive: float = 140.0
@export var duracao_dragon_drive: float = 1.0  ## usado só como referência de tempo (sem curva, não afeta trajetória)
@export var cooldown_dragon_drive: int = 7

@export_group("Demon Rush")
@export var duracao_demon_rush: float = 0.4  ## avanço "médio" — nem tão rápido quanto o Genius Control, nem lento
@export var distancia_parada_da_bola: float = 30.0
@export var cooldown_demon_rush: int = 6

@export_group("KaKaBoom (Follow Up)")
@export var forca_kakaboom: float = 220.0

const NOME_DRAGON_DRIVE := "Dragon Drive"
const NOME_DEMON_RUSH := "Demon Rush"
const NOME_KAKABOOM := "KaKaBoom"

var _kakaboom_disponivel: bool = false


func habilidades_proprias() -> Array[String]:
	var lista: Array[String] = [NOME_DRAGON_DRIVE, NOME_DEMON_RUSH]
	if _kakaboom_disponivel:
		lista.append(NOME_KAKABOOM)
	return lista


func _requisito_extra_propria(nome: String) -> String:
	if (nome == NOME_DRAGON_DRIVE or nome == NOME_KAKABOOM) and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_DRAGON_DRIVE:
			_executar_dragon_drive()
			iniciar_cooldown(nome, cooldown_dragon_drive)
		NOME_DEMON_RUSH:
			_executar_demon_rush()
			iniciar_cooldown(nome, cooldown_demon_rush)
		NOME_KAKABOOM:
			_executar_kakaboom()


func _on_turno_mudou(time_iniciado: String) -> void:
	super._on_turno_mudou(time_iniciado)
	# o KaKaBoom liberado só vale NESTE turno — some se não for usado
	if _kakaboom_disponivel and time_iniciado != time:
		_kakaboom_disponivel = false


## --- Dragon Drive ---

func _executar_dragon_drive() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	# intensidade de curva 0 = sai reto; o motivo de usar essa função e
	# não receber_chute_teleguiado() é o efeito colateral dela de
	# ignorar colisão com o time inteiro de quem chuta (Shidou incluso)
	bola.receber_chute_curvo(gol.ponto_para_mira(), forca_dragon_drive, time, 0.0, duracao_dragon_drive, false)


## --- Demon Rush / KaKaBoom ---

func _executar_demon_rush() -> void:
	var bola := encontrar_bola()
	if not bola:
		return

	var direcao := (global_position - bola.global_position)
	direcao = direcao.normalized() if direcao.length() > 1.0 else Vector2.RIGHT
	var destino := bola.global_position + direcao * distancia_parada_da_bola

	MovimentoSuave.mover(self, destino, duracao_demon_rush, func() -> void:
		if bola_no_alcance:
			conceder_acao_habilidade_extra(1)
			_kakaboom_disponivel = true
			Eventos.mensagem_solicitada.emit("Demon Rush! Shidou alcançou a bola — KaKaBoom liberado e ganhou uma ação de habilidade extra.")
		else:
			Eventos.mensagem_solicitada.emit("Demon Rush! Shidou não alcançou a bola dessa vez.")
	)


func _executar_kakaboom() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	var direcao := (gol.ponto_para_mira() - bola.global_position).normalized()
	bola.receber_chute_teleguiado(direcao, forca_kakaboom)
	_kakaboom_disponivel = false
