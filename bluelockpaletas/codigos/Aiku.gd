extends Botao
class_name Aiku

## Oliver Aiku
##
## - Serpent Sway: se a bola estiver dentro do alcance (não precisa
##   estar já grudada nele), Aiku desliza suavemente até perto dela.
##   Ao chegar, se a bola estiver ao alcance, ele PODE completar com um
##   passe de verdade pra um aliado (clicar em si mesmo, ou em qualquer
##   botão que não seja um aliado, cancela o passe sem desperdiçar
##   nada — o movimento já aconteceu de qualquer forma). Cooldown de 5
##   turnos.
##
## - Snake Hunt: Aiku escolhe um inimigo e desliza até perto dele. A
##   PARTIR desse turno, o alvo fica com o MOVIMENTO travado (não
##   consegue arrastar pra se deslocar) pelos próximos 4 turnos — mas o
##   próprio Aiku também sofre: seu alcance de deslocamento fica reduzido
##   em 40% enquanto esse efeito durar. Cooldown de 6 turnos.
##
## O travamento de movimento (aplicar_bloqueio_movimento) é genérico,
## definido no Botao.gd base — qualquer personagem futuro pode causar o
## mesmo efeito em outro.

@export_group("Serpent Sway")
@export var alcance_serpent_sway: float = 300.0  ## distância MÁXIMA até a bola pra poder ativar
@export var duracao_movimento_serpent_sway: float = 0.5
@export var distancia_parada_da_bola: float = 40.0  ## não termina EM CIMA da bola, para a uma distância curta dela
@export var forca_passe_serpent_sway: float = 500.0
@export var cooldown_serpent_sway: int = 5

@export_group("Snake Hunt")
@export var distancia_parada_do_alvo: float = 50.0
@export var duracao_movimento_snake_hunt: float = 0.5
@export var duracao_bloqueio_alvo: int = 4  ## turnos que o ALVO fica sem poder se mover
@export var fracao_deslocamento_reduzido_aiku: float = 0.6  ## 0.6 = Aiku fica com 60% do alcance (reduzido em 40%)
@export var cooldown_snake_hunt: int = 6

const NOME_SERPENT_SWAY := "Serpent Sway"
const NOME_SNAKE_HUNT := "Snake Hunt"

var _snake_hunt_turnos_restantes: int = 0  # >0 enquanto O PRÓPRIO Aiku sofre o penalty de deslocamento


func habilidades_proprias() -> Array[String]:
	return [NOME_SERPENT_SWAY, NOME_SNAKE_HUNT]


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_SERPENT_SWAY:
		var bola := _encontrar_bola()
		if not bola or global_position.distance_to(bola.global_position) > alcance_serpent_sway:
			return "A bola precisa estar dentro do alcance do Serpent Sway!"
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_SERPENT_SWAY:
			_executar_serpent_sway()
			iniciar_cooldown(nome, cooldown_serpent_sway)
		NOME_SNAKE_HUNT:
			_iniciar_snake_hunt()
			iniciar_cooldown(nome, cooldown_snake_hunt)


func _encontrar_bola() -> RigidBody2D:
	var bolas := get_tree().get_nodes_in_group("bola")
	return bolas[0] as RigidBody2D if not bolas.is_empty() else null


## --- Serpent Sway ---

func _executar_serpent_sway() -> void:
	var bola := _encontrar_bola()
	if not bola:
		return

	var destino := _ponto_de_aproximacao(bola.global_position)
	MovimentoSuave.mover(self, destino, duracao_movimento_serpent_sway, func() -> void:
		_oferecer_passe_serpent_sway()
	)


func _oferecer_passe_serpent_sway() -> void:
	if not bola_no_alcance:
		Eventos.mensagem_solicitada.emit("Serpent Sway! Aiku chegou perto da bola.")
		return
	SelecaoAlvo.pedir_alvo(self, _on_alvo_escolhido_serpent_sway, "Escolha um aliado pro passe (ou clique no próprio Aiku pra não passar)")


func _on_alvo_escolhido_serpent_sway(alvo: Botao) -> void:
	if alvo == self or alvo.time != time:
		Eventos.mensagem_solicitada.emit("Serpent Sway! Sem passe dessa vez.")
		return

	var bola := bola_no_alcance
	if not bola:
		Eventos.mensagem_solicitada.emit("A bola não está mais por perto pra completar o passe.")
		return

	var direcao := alvo.global_position - bola.global_position
	if direcao.length() < 0.001:
		return
	bola.receber_chute_teleguiado(direcao.normalized(), forca_passe_serpent_sway)
	Eventos.mensagem_solicitada.emit("Serpent Sway! Passe enviado pra %s." % alvo.name)


## --- Snake Hunt ---

func _iniciar_snake_hunt() -> void:
	SelecaoAlvo.pedir_alvo(self, _on_alvo_escolhido_snake_hunt, "Escolha o inimigo alvo do Snake Hunt")


func _on_alvo_escolhido_snake_hunt(alvo: Botao) -> void:
	if alvo == self or alvo.time == time:
		Eventos.mensagem_solicitada.emit("Escolha um INIMIGO como alvo do Snake Hunt!")
		return

	alvo.aplicar_bloqueio_movimento(duracao_bloqueio_alvo)
	_snake_hunt_turnos_restantes = duracao_bloqueio_alvo  # Aiku sofre pelo MESMO tanto de turnos

	var destino := _ponto_de_aproximacao(alvo.global_position, distancia_parada_do_alvo)
	MovimentoSuave.mover(self, destino, duracao_movimento_snake_hunt)

	Eventos.mensagem_solicitada.emit("Snake Hunt! %s não pode se mover pelos próximos %d turnos — mas Aiku também fica mais lento até lá." % [alvo.name, duracao_bloqueio_alvo])


func _ponto_de_aproximacao(alvo_pos: Vector2, distancia: float = -1.0) -> Vector2:
	# fica a uma distância curta do alvo, na direção de onde Aiku já
	# estava vindo — evita terminar exatamente EM CIMA da bola/do
	# inimigo (visualmente estranho, e essa distância vira a folga que o
	# AreaAlcance dele precisa pra detectar a bola logo em seguida)
	var dist := distancia_parada_da_bola if distancia < 0.0 else distancia
	var direcao := (global_position - alvo_pos)
	direcao = direcao.normalized() if direcao.length() > 1.0 else Vector2.RIGHT
	return alvo_pos + direcao * dist


func multiplicador_distancia_arrasto() -> float:
	if _snake_hunt_turnos_restantes > 0:
		return fracao_deslocamento_reduzido_aiku
	return super.multiplicador_distancia_arrasto()


func _on_turno_mudou(time_iniciado: String) -> void:
	super._on_turno_mudou(time_iniciado)
	if _snake_hunt_turnos_restantes > 0:
		_snake_hunt_turnos_restantes -= 1
