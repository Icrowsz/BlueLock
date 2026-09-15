extends Node

## AUTOLOAD (Singleton). Configure em: Project Settings > Autoload,
## nome "ConfiguracaoPartida".
##
## Guarda o modo (3v3/5v5), a FORMAÇÃO escolhida por CADA time (podem
## repetir a mesma formação, ou usar formações diferentes — são
## completamente independentes) e a escalação de cada time ENTRE a Tela
## de Início, a Escalação e o Jogo. Precisa ser autoload porque trocar
## de cena com change_scene_to_file() destrói a cena anterior — sem
## isso, a escolha se perderia ao entrar no campo.
##
## FORMAÇÕES: cada modo pode ter mais de uma disposição espacial
## possível (ex: 5v5 pode jogar num "1-2-2" ou num "1-1-2"). Cada
## formação é só uma LISTA de nomes de posição. Cada time escolhe a sua
## própria (ver definir_formacao()) antes de montar o time — isso decide
## tanto quais posições aparecem na tela de Escalação PRA AQUELE TIME
## quanto qual grupo de Marker2D é usado em campo pra ele (ver
## MontagemDeTime.gd).
##
## Pra adicionar uma formação nova: só acrescente uma entrada no
## Dictionary correspondente abaixo (FORMACOES_3V3 ou FORMACOES_5V5) com
## os nomes de posição que quiser, e crie o grupo de Marker2D
## correspondente na cena do jogo (ver o comentário em
## MontagemDeTime.gd pra saber a estrutura esperada).

const FORMACOES_3V3: Dictionary = {
	"1-1-1": ["Atacante", "Meio", "Zagueiro"],
	"1-2": ["Atacante Direito", "Atacante Esquerdo", "Zagueiro"],
	"2-1": ["Atacante", "Zagueiro Direito", "Zagueiro Esquerdo"],
}

const FORMACOES_5V5: Dictionary = {
	"1-2-2": ["Atacante Direito", "Atacante Esquerdo", "Ala Direito", "Ala Esquerdo", "Zagueiro"],
	"2-1-2": ["Atacante Direito", "Atacante Esquerdo", "Meio", "Zagueiro Direito", "Zagueiro Esquerdo"],
	"2-2-1": ["Atacante", "Ala Direito", "Ala Esquerdo", "Zagueiro Direito", "Zagueiro Esquerdo"],
	"3-1-1": ["Atacante", "Meio", "Lateral Direito", "Lateral Esquerdo", "Zagueiro"],
	"1-1-3": ["Atacante", "Lateral Direito", "Lateral Esquerdo", "Meio", "Zagueiro"],
}

var modo: String = "3v3"

## Formação ATUAL de cada time — independentes uma da outra. Sempre uma
## chave dentro de formacoes_do_modo().
var formacao_a: String = "1-1-1"
var formacao_b: String = "1-1-1"

## posição (String) -> nome do personagem (String), um dicionário por time
var escalacao_a: Dictionary = {}
var escalacao_b: Dictionary = {}


func iniciar_modo(novo_modo: String) -> void:
	modo = novo_modo

	# os dois times começam na PRIMEIRA formação cadastrada pro modo —
	# cada um pode trocar depois, de forma independente, via
	# definir_formacao(), na tela de Escalação
	var chaves := formacoes_do_modo().keys()
	var padrao: String = chaves[0] if not chaves.is_empty() else ""
	formacao_a = padrao
	formacao_b = padrao

	escalacao_a.clear()
	escalacao_b.clear()


func formacoes_do_modo() -> Dictionary:
	return FORMACOES_5V5 if modo == "5v5" else FORMACOES_3V3


func formacoes_disponiveis() -> Array:
	# pra popular os seletores de formação na tela de Escalação (um por
	# time — ambos leem a mesma lista, já que o modo é único pra partida)
	return formacoes_do_modo().keys()


func formacao_do_time(sigla_time: String) -> String:
	return formacao_a if sigla_time == "A" else formacao_b


func definir_formacao(sigla_time: String, nova_formacao: String) -> void:
	if not formacoes_do_modo().has(nova_formacao):
		push_warning("Formação '%s' não existe pro modo '%s'." % [nova_formacao, modo])
		return

	if sigla_time == "A":
		formacao_a = nova_formacao
		# a formação muda os nomes (e a quantidade) de posições — a
		# escalação anterior DESSE TIME não faz mais sentido; a do
		# adversário não é afetada
		escalacao_a.clear()
	elif sigla_time == "B":
		formacao_b = nova_formacao
		escalacao_b.clear()
	else:
		push_warning("Time '%s' inválido — use 'A' ou 'B'." % sigla_time)


func posicoes_do_time(sigla_time: String) -> Array[String]:
	var lista: Array[String] = []
	for posicao in formacoes_do_modo().get(formacao_do_time(sigla_time), []):
		lista.append(posicao)
	return lista


func escalacao_completa() -> bool:
	for posicao in posicoes_do_time("A"):
		if not escalacao_a.has(posicao):
			return false
	for posicao in posicoes_do_time("B"):
		if not escalacao_b.has(posicao):
			return false
	return true
