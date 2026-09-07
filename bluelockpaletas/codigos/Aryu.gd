extends Botao
class_name Aryu

## Aryu Ubaid
##
## - Glam Reach: por 3 turnos, aumenta a hitbox FÍSICA (a forma de
##   colisão real, não a AreaAlcance nem o raio_clique) em 30% —
##   deixando mais fácil interceptar/receber chutes que normalmente
##   passariam longe — mas reduz o deslocamento (alcance de arrasto) na
##   MESMA porcentagem enquanto durar. Cooldown de 8 turnos.
##
## - Glam Block: escolhe um inimigo DENTRO do alcance (glam_block_alcance),
##   Aryu se desloca até perto dele e o "encanta" — o alvo fica
##   impedido de gastar ações de habilidade durante o PRÓXIMO turno dele
##   (reaproveita aplicar_bloqueio_habilidade(), que já existe em
##   Botao.gd pra esse tipo de bloqueio com duração, ex: Expelliarmus do
##   Alexis Ness). Cooldown de 6 turnos.

@export_group("Glam Reach")
@export var glam_reach_duracao: int = 3
@export var glam_reach_multiplicador_hitbox: float = 1.5   ## +50% de hitbox física
@export var glam_reach_multiplicador_distancia: float = 0.7 ## -30% de alcance de arrasto (mesma % do hitbox)
@export var cooldown_glam_reach: int = 7

@export_group("Glam Block")
@export var glam_block_alcance: float = 250.0
@export var glam_block_distancia_parada: float = 40.0
@export var glam_block_duracao_movimento: float = 0.4
@export var cooldown_glam_block: int = 6

const NOME_GLAM_REACH := "Glam Reach"
const NOME_GLAM_BLOCK := "Glam Block"

var glam_reach_turnos_restantes: int = 0

## Nó da FORMA de colisão física (CollisionShape2D/CollisionPolygon2D) —
## é ele que decide se a bola/outro botão colide de verdade com o Aryu,
## diferente da AreaAlcance (só detecta "bola por perto" pra habilidades)
## e do raio_clique (só a hitbox de CLIQUE do mouse, no Botao.gd base).
##
## Escalamos o NÓ em si (a propriedade "scale" que todo Node2D tem), NÃO
## o "shape" (Resource) de dentro dele — mudar o Resource diretamente
## mudaria a hitbox de QUALQUER outro botão que esteja compartilhando o
## MESMO Resource (comportamento padrão do Godot: Resources não são
## duplicados automaticamente entre instâncias da mesma cena-base).
## Escalando o nó, cada Aryu em campo escala só a própria hitbox.
##
## Ajuste "CollisionShape2D" abaixo se sua cena usar outro nome pro nó
## de colisão.
@onready var _colisao: Node2D = $CollisionShape2D if has_node("CollisionShape2D") else null


func _ready() -> void:
	super._ready()
	if not _colisao:
		push_error("Aryu: não encontrei 'CollisionShape2D' pra aplicar o Glam Reach. Confira o nome do nó de colisão na cena.")


func habilidades_proprias() -> Array[String]:
	return [NOME_GLAM_REACH, NOME_GLAM_BLOCK]


func _habilidade_propria_consome_acao(nome: String) -> bool:
	if nome == NOME_GLAM_BLOCK:
		# consumida manualmente em _on_alvo_glam_block_escolhido(), só
		# quando o alvo é confirmado — cancelar a seleção não gasta nada
		return false
	return true  # Glam Reach consome normalmente, na hora do clique


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_GLAM_REACH:
			_executar_glam_reach()
			iniciar_cooldown(nome, cooldown_glam_reach)
		NOME_GLAM_BLOCK:
			_iniciar_glam_block()


## --- Glam Reach ---

func _executar_glam_reach() -> void:
	glam_reach_turnos_restantes = glam_reach_duracao
	if _colisao:
		_colisao.scale = Vector2.ONE * glam_reach_multiplicador_hitbox
	Eventos.mensagem_solicitada.emit("Glam Reach ativado! Hitbox maior, mas o deslocamento ficou mais curto.")


func multiplicador_distancia_arrasto() -> float:
	return glam_reach_multiplicador_distancia if glam_reach_turnos_restantes > 0 else 1.0


func _restaurar_hitbox() -> void:
	if _colisao:
		_colisao.scale = Vector2.ONE


## --- Glam Block ---

func _iniciar_glam_block() -> void:
	SelecaoAlvo.pedir_alvo(self, _on_alvo_glam_block_escolhido, "Selecione um inimigo ao alcance para o Glam Block")


func _on_alvo_glam_block_escolhido(alvo: Botao) -> void:
	if alvo.time == time:
		Eventos.mensagem_solicitada.emit("Escolha um oponente como alvo do Glam Block!")
		return

	var distancia := global_position.distance_to(alvo.global_position)
	if distancia > glam_block_alcance:
		Eventos.mensagem_solicitada.emit("Esse inimigo está fora do alcance do Glam Block!")
		return

	consumir_acao_habilidade()
	iniciar_cooldown(NOME_GLAM_BLOCK, cooldown_glam_block)

	var direcao := (alvo.global_position - global_position)
	direcao = direcao.normalized() if direcao.length() > 1.0 else Vector2.RIGHT
	var destino := alvo.global_position - direcao * glam_block_distancia_parada

	MovimentoSuave.mover(self, destino, glam_block_duracao_movimento, func() -> void:
		# +1 turno de "buffer" de propósito: bloqueado_de_usar_habilidade_
		# turnos_restantes decrementa em TODA troca de turno GLOBAL (ver
		# Botao.gd/_on_turno_mudou, ligado a Turnos.turno_iniciado — de
		# QUALQUER time, não só do alvo). Se déssemos só 1 aqui, o
		# bloqueio já cairia pra 0 bem na hora em que o turno do inimigo
		# começa, e ele nunca chegaria a ficar bloqueado DURANTE o
		# próprio turno dele. Com 2: sobra 1 ativo durante o turno
		# inimigo inteiro, e só zera na troca seguinte (quando volta a
		# ser turno do time do Aryu) — exatamente "esse turno" pedido.
		alvo.aplicar_bloqueio_habilidade(2)
		Eventos.mensagem_solicitada.emit("Glam Block! O inimigo foi encantado — sem habilidades no próximo turno dele.")
	)


## --- Turnos: decrementa o Glam Reach junto com o resto ---

func _on_turno_mudou(time_da_vez: String) -> void:
	super._on_turno_mudou(time_da_vez)

	if glam_reach_turnos_restantes > 0:
		glam_reach_turnos_restantes -= 1
		if glam_reach_turnos_restantes <= 0:
			_restaurar_hitbox()
			Eventos.mensagem_solicitada.emit("Glam Reach do Aryu acabou!")
