extends Botao
class_name Bunny

## Bunny Iglesias
##
## - Bad Bunny: chute forte, semi-curvo, teleguiado no gol inimigo, que
##   NÃO PODE SER INTERCEPTADO POR NINGUÉM — nem aliados, nem
##   adversários. receber_chute_curvo() (em Bola.gd) só ignora colisão
##   com o TIME de quem chutou por padrão (ver comentário dela: "só
##   oponentes interceptam"); aqui abrimos exceção de colisão TAMBÉM
##   com o time adversário na mão, e desfazemos depois do mesmo
##   "duracao_bad_bunny" que a própria bola usa internamente pra
##   desfazer a exceção dos aliados — assim as duas limpezas terminam
##   juntas. Cooldown de 6 turnos.
##
## - Más Fotos: "salto" instantâneo — Bunny suma e reaparece exatamente
##   onde o jogador clicar, dentro de mas_fotos_alcance (600 por
##   padrão). Não é um deslocamento físico (sem arrasto, sem impulso):
##   só reposiciona global_position na hora e zera a velocidade, com
##   reset_physics_interpolation() pra não "escorregar" visualmente do
##   ponto antigo até o novo (mesmo cuidado que grudar_bola()/
##   soltar_bola_grudada() já tomam em Botao.gd). Cooldown de 8 turnos.
##
## - Fake Smile: escolhe um inimigo e trava ele (nem movimento, nem
##   habilidade) por fake_smile_duracao_turnos_inimigo turnos DO PONTO
##   DE VISTA DELE — mesma combinação aplicar_bloqueio_movimento() +
##   aplicar_bloqueio_habilidade() do Non-Rotating Gear do Hugo, e a
##   MESMA pegadinha do x2 (ver a nota grande no topo do Hugo.gd):
##   esses bloqueios decrementam a cada troca de turno GLOBAL, não só
##   do time do alvo, então o valor real passado é o dobro do número
##   "humano" configurado. Cooldown de 7 turnos.

@export_group("Bad Bunny")
@export var forca_bad_bunny: float = 230.0
@export var intensidade_curva_bad_bunny: float = 40.0  ## "semi" curvo — bem menor que os 70 do Rabona Cross do Charles
@export var duracao_bad_bunny: float = 1.0
@export var cooldown_bad_bunny: int = 6

@export_group("Más Fotos")
@export var mas_fotos_alcance: float = 500.0
@export var cooldown_mas_fotos: int = 8

@export_group("Fake Smile")
@export var fake_smile_duracao_turnos_inimigo: int = 2  ## "2 turnos" do PONTO DE VISTA DO INIMIGO — internamente vira 2x isso, ver nota no topo do arquivo
@export var cooldown_fake_smile: int = 7

const NOME_BAD_BUNNY := "Bad Bunny"
const NOME_MAS_FOTOS := "Más Fotos"
const NOME_FAKE_SMILE := "Fake Smile"


## --- Ganchos do sistema de habilidades (ver Botao.gd) ---

func habilidades_proprias() -> Array[String]:
	return [NOME_BAD_BUNNY, NOME_MAS_FOTOS, NOME_FAKE_SMILE]


func _habilidade_propria_consome_acao(nome: String) -> bool:
	if nome == NOME_BAD_BUNNY:
		return true  # chute direto, consome normalmente na hora do clique
	return false  # Más Fotos e Fake Smile consomem manualmente só quando o ponto/alvo é confirmado


func _requisito_extra_propria(nome: String) -> String:
	if nome == NOME_BAD_BUNNY and bola_no_alcance == null:
		return "A bola precisa estar por perto para usar %s!" % nome
	return ""


func executar_habilidade_propria(nome: String) -> void:
	match nome:
		NOME_BAD_BUNNY:
			_executar_bad_bunny()
			iniciar_cooldown(nome, cooldown_bad_bunny)
		NOME_MAS_FOTOS:
			_iniciar_mas_fotos()
		NOME_FAKE_SMILE:
			_iniciar_fake_smile()


## --- Bad Bunny ---

func _executar_bad_bunny() -> void:
	var bola := bola_no_alcance
	if not bola:
		return

	var gol := encontrar_gol_inimigo()
	if not gol:
		return

	# parar_ao_chegar = false: é um CHUTE DE GOL (igual ao Dragon Drive
	# do Shidou), então a bola deve manter velocidade ao terminar a
	# curva, não frear em cima do ponto de mira
	bola.receber_chute_curvo(gol.ponto_para_mira(), forca_bad_bunny, time, intensidade_curva_bad_bunny, duracao_bad_bunny, false)

	# a chamada acima já ignora colisão com o TIME da Bunny — falta só
	# abrir exceção com o time ADVERSÁRIO também, pro "não pode ser
	# interceptado" valer pra todo mundo, não só pros aliados
	var excecoes_inimigas: Array[Botao] = []
	for nodo in get_tree().get_nodes_in_group("botoes"):
		var botao := nodo as Botao
		if botao and botao.time != time:
			bola.add_collision_exception_with(botao)
			excecoes_inimigas.append(botao)

	get_tree().create_timer(duracao_bad_bunny).timeout.connect(
		func() -> void:
			if not is_instance_valid(bola):
				return
			for botao in excecoes_inimigas:
				if is_instance_valid(botao):
					bola.remove_collision_exception_with(botao)
	)

	Eventos.mensagem_solicitada.emit("Bad Bunny! Chute forte e semi-curvo — impossível de interceptar.")


## --- Más Fotos ---

func _iniciar_mas_fotos() -> void:
	SelecaoAlvo.pedir_ponto(self, _on_ponto_mas_fotos_escolhido, "Clique onde a Bunny deve reaparecer (Más Fotos)")


func _on_ponto_mas_fotos_escolhido(ponto: Vector2) -> void:
	var distancia := global_position.distance_to(ponto)
	if distancia > mas_fotos_alcance:
		Eventos.mensagem_solicitada.emit("Esse ponto está fora do alcance do Más Fotos!")
		return

	global_position = ponto
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	reset_physics_interpolation()  # sem isso, o sprite "desliza" visualmente do ponto antigo até o novo em vez de sumir/reaparecer

	consumir_acao_habilidade()
	iniciar_cooldown(NOME_MAS_FOTOS, cooldown_mas_fotos)
	Eventos.mensagem_solicitada.emit("Más Fotos! Bunny sumiu e reapareceu instantaneamente.")


## --- Fake Smile ---

func _iniciar_fake_smile() -> void:
	SelecaoAlvo.pedir_alvo(self, _on_alvo_fake_smile_escolhido, "Selecione um inimigo para o Fake Smile")


func _on_alvo_fake_smile_escolhido(alvo: Botao) -> void:
	if alvo.time == time:
		Eventos.mensagem_solicitada.emit("Escolha um jogador do time inimigo!")
		return

	# ver a nota grande no topo do arquivo sobre por que isso é x2
	var turnos_efetivos := fake_smile_duracao_turnos_inimigo * 2
	alvo.aplicar_bloqueio_movimento(turnos_efetivos)
	alvo.aplicar_bloqueio_habilidade(turnos_efetivos)

	consumir_acao_habilidade()
	iniciar_cooldown(NOME_FAKE_SMILE, cooldown_fake_smile)
	Eventos.mensagem_solicitada.emit("Fake Smile! O inimigo ficou impedido de agir por %d turnos." % fake_smile_duracao_turnos_inimigo)
