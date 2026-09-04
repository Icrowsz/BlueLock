extends Botao
class_name Bachira

## Meguru Bachira
##
## - Bee Shot: chute teleguiado no gol inimigo (igual ao Chute Direto do
##   Isagi), mas com metade da força-base padrão (75, vs. 150). Em
##   compensação, a bola fica intangível aos outros botões durante o
##   voo — nenhum oponente consegue entrar na frente pra interceptar.
##   Precisa da bola por perto.
##
## - Monster Trance: concede, só PRA ELE (não pro time), uma ação de
##   movimento extra (na METADE da distância normal) e uma ação de
##   habilidade extra, ambas válidas só até o fim deste turno. Precisa
##   da bola por perto pra ser ativada. Fluxo pretendido: deslocamento
##   padrão -> Monster Trance -> deslocamento extra (reduzido) -> Bee Shot,
##   tudo no mesmo turno.
##
## Nota: como as ações bônus (acoes_movimento_bonus/acoes_habilidade_bonus,
## ver Botao.gd) são sempre gastas ANTES da ação compartilhada do time,
## a ordem acima é a que garante que o deslocamento "comum" saia em
## distância cheia e só o "extra" saia reduzido — se o Monster Trance for
## ativado ANTES do deslocamento comum, é esse primeiro deslocamento que
## sai reduzido (a ação bônus é consumida primeiro). Vale avisar o
## jogador disso na hora de jogar.

@export_group("Bee Shot")
@export var forca_bee_shot: float = 75.0  ## metade da força-base padrão (150)
@export var cooldown_bee_shot: int = 6
@export var bee_shot_duracao_intangivel: float = 1.0  ## segundos que a bola ignora colisão com botões

@export_group("Monster Trance")
@export var monster_trance_multiplicador_distancia: float = 0.5
@export var cooldown_monster_trance: int = 5

var _monster_trance_ativo: bool = false

const NOME_BEE_SHOT := "Bee Shot"
const NOME_MONSTER_TRANCE := "Monster Trance"


func habilidades_proprias() -> Array[String]:
	return [NOME_BEE_SHOT, NOME_MONSTER_TRANCE]


func _requisito_extra_propria(nome: String) -> String:
	if (nome == NOME_BEE_SHOT or nome == NOME_MONSTER_TRANCE) and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_BEE_SHOT:
			_executar_bee_shot()
			iniciar_cooldown(nome, cooldown_bee_shot)
		NOME_MONSTER_TRANCE:
			_executar_monster_trance()
			iniciar_cooldown(nome, cooldown_monster_trance)


## --- Bee Shot ---

func _executar_bee_shot() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	var direcao := (gol.ponto_para_mira() - bola.global_position).normalized()
	bola.receber_chute_teleguiado(direcao, forca_bee_shot)
	bola.ativar_intangivel_para_botoes(bee_shot_duracao_intangivel)


## --- Monster Trance ---

func _executar_monster_trance() -> void:
	_monster_trance_ativo = true
	conceder_acao_movimento_extra(1)
	conceder_acao_habilidade_extra(1)
	Eventos.mensagem_solicitada.emit("Monster Trance! Bachira ganhou um deslocamento extra (reduzido) e mais uma ação de habilidade neste turno.")


func multiplicador_distancia_arrasto() -> float:
	# só reduz a distância quando o deslocamento que está prestes a
	# acontecer é o BÔNUS concedido pelo Monster Trance (acoes_movimento_bonus
	# > 0) — o deslocamento comum do time continua em distância cheia
	if _monster_trance_ativo and acoes_movimento_bonus > 0:
		return monster_trance_multiplicador_distancia
	return 1.0


func _on_turno_mudou(time_da_vez: String) -> void:
	super._on_turno_mudou(time_da_vez)

	# os bônus do Monster Trance valem só "neste turno" — se o time do
	# Bachira passar a vez (turno mudou pro time ADVERSÁRIO) e algum
	# bônus não foi usado a tempo, ele expira aqui, em vez de ficar
	# disponível pro turno seguinte por engano
	if _monster_trance_ativo and time_da_vez != time:
		_monster_trance_ativo = false
		acoes_movimento_bonus = 0
		acoes_habilidade_bonus = 0
