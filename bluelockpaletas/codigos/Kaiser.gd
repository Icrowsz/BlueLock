extends Botao
class_name Kaiser

## Kaiser
##
## Primeiro personagem com 3 habilidades ativas.
##
## - Kaiser Impact: chute muito forte, mirando automaticamente no gol
##   inimigo. A bola perde a colisão com QUALQUER botão (dos dois
##   times) por um instante logo no início da trajetória — reaproveita
##   ativar_intangivel_para_botoes(), a mesma base do Bee Shot do
##   Bachira. Cooldown de 6 turnos.
##
## - Beinschuss: chute mais fraco que o Impact, também mirando no gol,
##   mas que ignora colisão com TODO o time do Kaiser (reaproveita
##   receber_chute_curvo com intensidade de curva 0 — vira uma linha
##   reta, mas mantém o "ignora aliados"). Como o próprio Kaiser faz
##   parte desse time, ele entra automaticamente nessa exceção — é
##   isso que permite o chute "de costas" sem precisar de nenhuma
##   lógica extra pra ignorar a si mesmo. Cooldown de 7 turnos.
##
## - Emperor Route: avanço em formato de V esticado em direção da bola
##   — dois trechos de movimento suave encadeados (o "vértice" do V,
##   depois o ponto final), sem gastar ação de movimento nenhuma (é
##   scriptado, não usa o arrasto normal). NERF: tem um alcance máximo
##   (alcance_emperor_route) — se a bola estiver mais perto que isso, o
##   avanço vai exatamente até ela (adaptativo); se estiver mais longe,
##   Kaiser avança só até onde o alcance permite, na direção da bola,
##   sem necessariamente chegar nela. Ao terminar:
##     - se a bola ficou no alcance do PRÓPRIO Kaiser: ganha uma ação
##       de habilidade extra pra ele mesmo.
##     - senão, se algum ALIADO estiver com a bola no alcance: esse
##       aliado ganha uma ação de habilidade extra PRA ELE e a
##       habilidade concedida Knie Dich Hin (um passe padrão em direção
##       a Kaiser, pago pela própria ação extra que acabou de ganhar).
##     - senão, não acontece nada além do avanço em si.
##   Cooldown de 7 turnos.

@export_group("Kaiser Impact")
@export var forca_kaiser_impact: float = 260.0
@export var duracao_intangivel_kaiser_impact: float = 0.3  ## janela sem colisão nenhuma, só no início da trajetória
@export var cooldown_kaiser_impact: int = 6

@export_group("Beinschuss")
@export var forca_beinschuss: float = 225.0  ## mais fraco que o Impact, de propósito
@export var duracao_beinschuss: float = 1.0
@export var cooldown_beinschuss: int = 7

@export_group("Emperor Route")
@export var alcance_emperor_route: float = 500.0  ## distância MÁXIMA do avanço — se a bola estiver mais longe que isso, Kaiser para no meio do caminho, sem alcançá-la
@export var fracao_apex_emperor_route: float = 0.5  ## a que fração da distância PERCORRIDA (já limitada pelo alcance) fica o "vértice" do V
@export var largura_v_emperor_route: float = 90.0  ## o quanto o V se abre pro lado — "esticado" de propósito
@export var duracao_trecho_emperor_route: float = 0.22  ## duração de CADA um dos dois trechos do V
@export var cooldown_emperor_route: int = 7

@export_group("Knie Dich Hin (concedida)")
@export var forca_knie_dich_hin: float = 120.0  ## "passe padrão" — nem curto nem longo
@export var turnos_para_expirar_knie_dich_hin: int = 3

const NOME_KAISER_IMPACT := "Kaiser Impact"
const NOME_BEINSCHUSS := "Beinschuss"
const NOME_EMPEROR_ROUTE := "Emperor Route"
const NOME_KNIE_DICH_HIN := "Knie Dich Hin"


func habilidades_proprias() -> Array[String]:
	return [NOME_KAISER_IMPACT, NOME_BEINSCHUSS, NOME_EMPEROR_ROUTE]


func _requisito_extra_propria(nome: String) -> String:
	if nome in [NOME_KAISER_IMPACT, NOME_BEINSCHUSS] and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_KAISER_IMPACT:
			_executar_kaiser_impact()
			iniciar_cooldown(nome, cooldown_kaiser_impact)
		NOME_BEINSCHUSS:
			_executar_beinschuss()
			iniciar_cooldown(nome, cooldown_beinschuss)
		NOME_EMPEROR_ROUTE:
			_executar_emperor_route()
			iniciar_cooldown(nome, cooldown_emperor_route)


## --- Kaiser Impact ---

func _executar_kaiser_impact() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	bola.ativar_intangivel_para_botoes(duracao_intangivel_kaiser_impact)

	var direcao := gol.ponto_para_mira() - bola.global_position
	direcao = direcao.normalized() if direcao.length() > 1.0 else Vector2.RIGHT
	bola.receber_chute_teleguiado(direcao, forca_kaiser_impact)

	Eventos.mensagem_solicitada.emit("Kaiser Impact! A bola sai sem colisão nenhuma no início da trajetória.")


## --- Beinschuss ---

func _executar_beinschuss() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	# intensidade_curva = 0.0 -> sai reto, mas MANTÉM o "ignora colisão
	# com todo o time do chutador" do receber_chute_curvo — Kaiser
	# também é desse time, então já sai incluído sozinho na exceção
	bola.receber_chute_curvo(gol.ponto_para_mira(), forca_beinschuss, time, 0.0, duracao_beinschuss, false)
	Eventos.mensagem_solicitada.emit("Beinschuss! Kaiser acerta o chute mesmo de costas pra bola.")


## --- Emperor Route ---

func _executar_emperor_route() -> void:
	var bola := encontrar_bola()
	if not bola:
		return

	var origem := global_position
	var direcao := bola.global_position - origem
	direcao = direcao.normalized() if direcao.length() > 1.0 else Vector2.RIGHT
	var perpendicular := Vector2(-direcao.y, direcao.x)
	var lado := 1.0 if randf() < 0.5 else -1.0

	# NERF: o avanço tem alcance máximo. Se a bola estiver mais perto
	# que isso, percorre a distância exata até ela (adaptativo); se
	# estiver mais longe, percorre só até o limite do alcance, na
	# mesma direção — sem necessariamente alcançar a bola.
	var distancia_ate_bola := origem.distance_to(bola.global_position)
	var distancia_percorrida := minf(distancia_ate_bola, alcance_emperor_route)

	var ponto_apex := origem + direcao * (distancia_percorrida * fracao_apex_emperor_route) + perpendicular * largura_v_emperor_route * lado
	var ponto_final := origem + direcao * distancia_percorrida

	Eventos.mensagem_solicitada.emit("Emperor Route! Kaiser avança em V em direção à bola.")

	MovimentoSuave.mover(self, ponto_apex, duracao_trecho_emperor_route)

	var primeiro_trecho := get_tree().create_timer(duracao_trecho_emperor_route)
	primeiro_trecho.timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return

		MovimentoSuave.mover(self, ponto_final, duracao_trecho_emperor_route)

		var segundo_trecho := get_tree().create_timer(duracao_trecho_emperor_route)
		segundo_trecho.timeout.connect(_resolver_emperor_route)
	)


func _resolver_emperor_route() -> void:
	if bola_no_alcance != null:
		conceder_acao_habilidade_extra(1)
		Eventos.mensagem_solicitada.emit("Emperor Route encontrou a bola! Kaiser ganhou uma ação de habilidade extra.")
		return

	var aliado := _aliado_com_bola_no_alcance()
	if aliado:
		aliado.conceder_acao_habilidade_extra(1)
		# disponivel_imediatamente = true: senão a habilidade concedida só
		# valeria a partir do PRÓXIMO turno (comportamento padrão de
		# conceder_habilidade), e a ação bônus que acabamos de dar ficaria
		# sem nenhuma habilidade concedida pra usar até lá — a jogada
		# inteira do Emperor Route precisa se resolver NESTE turno
		aliado.conceder_habilidade(NOME_KNIE_DICH_HIN, func() -> void:
			_executar_knie_dich_hin(aliado)
		, true, turnos_para_expirar_knie_dich_hin, true)
		Eventos.mensagem_solicitada.emit("Emperor Route não achou a bola, mas %s está com ela — ganhou uma ação extra e o Knie Dich Hin!" % aliado.name)
		return

	Eventos.mensagem_solicitada.emit("Emperor Route terminou sem encontrar a bola nem um aliado com ela por perto.")


func _aliado_com_bola_no_alcance() -> Botao:
	for nodo in get_tree().get_nodes_in_group("botoes"):
		var botao := nodo as Botao
		if botao and botao != self and botao.time == time and botao.bola_no_alcance != null:
			return botao
	return null


func _executar_knie_dich_hin(aliado: Botao) -> void:
	var bola := aliado.bola_no_alcance
	if not bola:
		Eventos.mensagem_solicitada.emit("Knie Dich Hin! A bola não estava mais com %s." % aliado.name)
		return

	var direcao := global_position - bola.global_position
	direcao = direcao.normalized() if direcao.length() > 1.0 else Vector2.RIGHT
	bola.receber_chute_teleguiado(direcao, forca_knie_dich_hin)

	Eventos.mensagem_solicitada.emit("Knie Dich Hin! %s faz o passe padrão em direção a Kaiser." % aliado.name)
