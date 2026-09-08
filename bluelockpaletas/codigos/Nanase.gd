extends Botao
class_name Nanase

## Nanase
##
## - Ambidexterity: chute comum (reto, mirando automaticamente no gol
##   inimigo — mesma base do Chute Direto), mas que ignora colisão só
##   com o PRÓPRIO Nanase durante um instante depois do chute — não com
##   o resto do time, diferente do Curve Shot do Rin (que ignora TODOS
##   os aliados). É uma exceção de colisão bem mais cirúrgica: evita só
##   que o corpo dele mesmo esbarre/desvie a própria bola logo depois de
##   chutar. Cooldown de 6 turnos.
##
## - Lynchpin: passe comum e CURTO (força bem menor que o normal) pra
##   um aliado escolhido — chute físico de verdade (receber_chute_teleguiado),
##   então totalmente interceptável, sem nenhuma proteção especial.
##   Cooldown de 6 turnos.

@export_group("Ambidexterity")
@export var forca_ambidexterity: float = 200.0
@export var duracao_ignorar_proprio_ambidexterity: float = 0.6  ## por quanto tempo a bola ignora colisão com o próprio Nanase depois do chute
@export var cooldown_ambidexterity: int = 6

@export_group("Lynchpin")
@export var forca_lynchpin: float = 90.0  ## bem menor que um passe longo — é um passe CURTO de propósito
@export var cooldown_lynchpin: int = 6

const NOME_AMBIDEXTERITY := "Ambidexterity"
const NOME_LYNCHPIN := "Lynchpin"


func habilidades_proprias() -> Array[String]:
	return [NOME_AMBIDEXTERITY, NOME_LYNCHPIN]


func _requisito_extra_propria(nome: String) -> String:
	if nome in [NOME_AMBIDEXTERITY, NOME_LYNCHPIN] and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_AMBIDEXTERITY:
			_executar_ambidexterity()
			iniciar_cooldown(nome, cooldown_ambidexterity)
		NOME_LYNCHPIN:
			_iniciar_lynchpin()
			iniciar_cooldown(nome, cooldown_lynchpin)


## --- Ambidexterity ---

func _executar_ambidexterity() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	# exceção de colisão só com ELE MESMO (não com o time todo, ver
	# comentário no topo do arquivo) — removida sozinha depois de
	# duracao_ignorar_proprio_ambidexterity segundos
	bola.add_collision_exception_with(self)
	var temporizador := get_tree().create_timer(duracao_ignorar_proprio_ambidexterity)
	temporizador.timeout.connect(func() -> void:
		if is_instance_valid(bola):
			bola.remove_collision_exception_with(self)
	)

	var direcao := gol.ponto_para_mira() - bola.global_position
	direcao = direcao.normalized() if direcao.length() > 1.0 else Vector2.RIGHT
	bola.receber_chute_teleguiado(direcao, forca_ambidexterity)

	Eventos.mensagem_solicitada.emit("Ambidexterity! Nanase chuta sem risco de esbarrar na própria bola.")


## --- Lynchpin ---

func _iniciar_lynchpin() -> void:
	SelecaoAlvo.pedir_alvo(self, func(alvo: Botao) -> void:
		_confirmar_lynchpin(alvo)
	, "Escolha o aliado do Lynchpin")


func _confirmar_lynchpin(alvo: Botao) -> void:
	if alvo == self or alvo.time != time:
		Eventos.mensagem_solicitada.emit("Escolha um companheiro de time como alvo!")
		return

	var bola := bola_no_alcance
	if not bola:
		Eventos.mensagem_solicitada.emit("A bola não está mais por perto — Lynchpin cancelado.")
		return

	var direcao := alvo.global_position - bola.global_position
	direcao = direcao.normalized() if direcao.length() > 1.0 else Vector2.RIGHT
	bola.receber_chute_teleguiado(direcao, forca_lynchpin)

	Eventos.mensagem_solicitada.emit("Lynchpin! Passe curto enviado pra %s — pode ser interceptado." % alvo.name)
