extends Botao
class_name Onazi

## Onazi
##
## - Ego Unlock: chute direto e teleguiado no gol inimigo — igual ao
##   Chute Direto do Isagi, mas com uma diferença: a bola NÃO colide com
##   o PRÓPRIO Onazi (só ele — os outros botões continuam bloqueando
##   normalmente) durante o voo. Usa add_collision_exception_with() /
##   remove_collision_exception_with(), API nativa do PhysicsBody2D do
##   Godot pra ignorar colisão entre dois corpos físicos específicos
##   (tanto Botao quanto Bola são RigidBody2D, então herdam isso de
##   graça). Custa a ação de habilidade do turno. Cooldown de 6 turnos.
##
## - Since I'm here: concede mais uma ação de DESLOCAMENTO nesse turno,
##   só que com a força reduzida a 65% — reaproveita
##   conceder_acao_movimento_extra() (já existe em Botao.gd, mesmo
##   mecanismo do bônus de movimento do One Two do Kurona). Não custa a
##   própria ação de habilidade do turno (ela É a ação extra). Cooldown
##   de 8 turnos.

@export_group("Ego Unlock")
@export var forca_ego_unlock: float = 110.0
@export var ego_unlock_duracao_sem_colisao: float = 0.5  ## segundos (não turnos — é só o tempo do voo da bola), não a duração de um buff
@export var cooldown_ego_unlock: int = 6

@export_group("Since I'm here")
@export var since_im_here_multiplicador_forca: float = 0.65
@export var cooldown_since_im_here: int = 8

const NOME_EGO_UNLOCK := "Ego Unlock"
const NOME_SINCE_IM_HERE := "Since I'm here"

var _reduzir_forca_do_proximo_deslocamento: bool = false


## --- Ganchos do sistema de habilidades (ver Botao.gd) ---

func habilidades_proprias() -> Array[String]:
	return [NOME_EGO_UNLOCK, NOME_SINCE_IM_HERE]


func _habilidade_propria_consome_acao(nome: String) -> bool:
	return nome != NOME_SINCE_IM_HERE  # Since I'm here É a própria ação extra, não consome nenhuma outra


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_EGO_UNLOCK and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_EGO_UNLOCK:
			_executar_ego_unlock()
			iniciar_cooldown(nome, cooldown_ego_unlock)
		NOME_SINCE_IM_HERE:
			_executar_since_im_here()
			iniciar_cooldown(nome, cooldown_since_im_here)


## --- Ego Unlock ---

func _executar_ego_unlock() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	var direcao := (gol.ponto_para_mira() - bola.global_position).normalized()

	bola.add_collision_exception_with(self)
	bola.receber_chute_teleguiado(direcao, forca_ego_unlock)

	# a exceção é só pra bola conseguir ATRAVESSAR o Onazi no instante do
	# chute — depois do tempo de voo, removemos de novo, senão a bola
	# nunca mais colidiria com ele pro resto da partida
	var bola_ref := bola
	get_tree().create_timer(ego_unlock_duracao_sem_colisao).timeout.connect(
		func() -> void:
			if is_instance_valid(bola_ref) and is_instance_valid(self):
				bola_ref.remove_collision_exception_with(self)
	)

	Eventos.mensagem_solicitada.emit("Ego Unlock! Chute direto, atravessando o próprio Onazi.")


## --- Since I'm here ---

func _executar_since_im_here() -> void:
	conceder_acao_movimento_extra(1)
	_reduzir_forca_do_proximo_deslocamento = true
	Eventos.mensagem_solicitada.emit("Since I'm here! Mais uma ação de deslocamento disponível (com força reduzida).")


func multiplicador_forca_chute() -> float:
	# consumir_acao_movimento (dentro de _soltar_e_chutar, em Botao.gd)
	# sempre gasta a ação BÔNUS antes da ação normal do time quando ela
	# existe — então o PRÓXIMO arrasto depois do Since I'm here é
	# garantidamente o que usa a ação extra, e é exatamente esse que
	# precisa vir com força reduzida (não os arrastos seguintes).
	return since_im_here_multiplicador_forca if _reduzir_forca_do_proximo_deslocamento else 1.0


func _apos_chute(sucesso: bool) -> void:
	super._apos_chute(sucesso)
	if sucesso and _reduzir_forca_do_proximo_deslocamento:
		_reduzir_forca_do_proximo_deslocamento = false
