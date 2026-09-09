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
## - Awaken: gruda a bola no Nagi, mesmo mecanismo do Devil Contract do
##   Charles (bola vira filha dele + física congelada, ver Botao.gd:
##   grudar_bola()/soltar_bola_grudada()). Solta sozinha no PRÓXIMO
##   turno_iniciado — de QUALQUER time, nem precisa ser o turno do
##   Nagi ou do time dele — pra equilibrar com o Devil Contract (que
##   dura mais, mas só solta no turno do próprio Charles). Cooldown de
##   7 turnos.

@export_group("Genius Control")
@export var duracao_genius_control: float = 0.6  ## rápido — "desloca rapidamente"
@export var distancia_parada_da_bola: float = 30.0
@export var alcance_maximo_genius_control: float = 280.0  ## distância MÁXIMA até a bola pra poder ativar
@export var cooldown_genius_control: int = 6

@export_group("Death Volley (Follow Up)")
@export var forca_death_volley: float = 250.0

@export_group("Awaken")
@export var cooldown_awaken: int = 7

const NOME_GENIUS_CONTROL := "Genius Control"
const NOME_DEATH_VOLLEY := "Death Volley"
const NOME_AWAKEN := "Awaken"

var _death_volley_disponivel: bool = false
var _awaken_ativo: bool = false


func _ready() -> void:
	super._ready()
	Eventos.gol_marcado.connect(_on_gol_marcado)


func habilidades_proprias() -> Array[String]:
	var lista: Array[String] = [NOME_GENIUS_CONTROL, NOME_AWAKEN]
	if _death_volley_disponivel:
		lista.append(NOME_DEATH_VOLLEY)
	return lista


func _habilidade_propria_consome_acao(nome: String) -> bool:
	return nome != NOME_GENIUS_CONTROL  # só o Control é de graça


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_GENIUS_CONTROL:
		var bola := encontrar_bola()
		if not bola or global_position.distance_to(bola.global_position) > alcance_maximo_genius_control:
			return "A bola está fora do alcance do Genius Control!"

	if nome == NOME_DEATH_VOLLEY and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome

	if nome == NOME_AWAKEN and bola_no_alcance == null:
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

	var direcao := (gol.ponto_para_mira() - bola.global_position).normalized()
	bola.receber_chute_teleguiado(direcao, forca_death_volley)
	_death_volley_disponivel = false


## --- Awaken ---

func _executar_awaken() -> void:
	var bola := bola_no_alcance
	if not bola:
		return
	grudar_bola(bola)
	_awaken_ativo = true
	Eventos.mensagem_solicitada.emit("Awaken! A bola grudou no Nagi até o próximo turno (de qualquer time).")


func _on_gol_marcado(_lado: String) -> void:
	if _awaken_ativo:
		_awaken_ativo = false
		soltar_bola_grudada()  # segurança: nunca deixa a bola "presa" durante o reset pós-gol


func _on_turno_mudou(time_iniciado: String) -> void:
	super._on_turno_mudou(time_iniciado)
	if _awaken_ativo:
		# diferente do Devil Contract do Charles (que só conta turnos DO
		# TIME dele): aqui é o PRÓXIMO turno_iniciado que aparecer,
		# mesmo que seja do time adversário — de propósito, pra ser mais
		# curto e balancear com a duração maior do Devil Contract
		_awaken_ativo = false
		_soltar_awaken_apos_assentar()
		Eventos.mensagem_solicitada.emit("Awaken acabou — a bola não gruda mais no Nagi.")


func _soltar_awaken_apos_assentar() -> void:
	# ARMADILHA: quando a ÚLTIMA ação do turno é usada (ex: o próprio
	# arrasto que move o Nagi), Turnos.usar_acao() já troca de turno NA
	# HORA, na mesma chamada — ou seja, turno_iniciado() pode disparar
	# ANTES da física sequer ter movido o Nagi um pixel. Se soltássemos
	# a bola direto em _on_turno_mudou(), ela ficaria pra trás, ainda no
	# ponto de onde ele partiu. Por isso esperamos a velocidade do Nagi
	# cair perto de zero (ele realmente ter parado de deslizar) antes de
	# soltar de verdade.
	const VELOCIDADE_MINIMA_PARADO := 5.0

	await get_tree().physics_frame
	while is_inside_tree() and linear_velocity.length() > VELOCIDADE_MINIMA_PARADO:
		await get_tree().physics_frame

	if is_inside_tree():
		soltar_bola_grudada()
