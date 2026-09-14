extends Node

## AUTOLOAD (Singleton). Configure em: Project Settings > Autoload,
## nome "ConfiguracaoPartida".
##
## Guarda o modo (3v3/5v5), a FORMAÇÃO escolhida e a escalação de cada
## time ENTRE a Tela de Início, a Escalação e o Jogo. Precisa ser autoload
## porque trocar de cena com change_scene_to_file() destrói a cena
## anterior — sem isso, a escolha se perderia ao entrar no campo.

## Cada modo tem uma ou mais FORMAÇÕES — cada formação é um Array de
## nomes de posição (rótulos livres: servem tanto pra UI de escalação
## quanto pro nome do Marker2D no campo, ver MontagemDeTime.gd). A
## quantidade de posições listada numa formação PRECISA bater com o
## número de jogadores do modo (3 pro 3v3, 5 pro 5v5) — senão a
## escalação nunca fica "completa" (ver escalacao_completa()).
##
## Pra adicionar uma formação nova: só acrescente uma entrada aqui, e
## crie o grupo de Marker2D correspondente no campo (ver
## MontagemDeTime.gd) — nenhum outro sistema precisa mudar.
const FORMACOES: Dictionary = {
	"3v3": {
		"2-1": ["Atacante Esquerdo", "Atacante Direito", "Zagueiro"],
		"1-1-1": ["Atacante", "Meio", "Zagueiro"],
	},
	"5v5": {
		"1-2-2": ["Zagueiro", "Meio Esquerdo", "Meio Direito", "Atacante Esquerdo", "Atacante Direito"],
		# ATENÇÃO: "1-1-2" como você descreveu soma só 4 posições
		# (1+1+2 = 4), e o 5v5 precisa de 5. Deixei 4 rótulos abaixo pra
		# ficar fiel ao nome que você deu — ajuste este Array (acrescente
		# a posição que faltar) antes de usar essa formação de verdade,
		# senão escalacao_completa() nunca vai bater no modo 5v5 com ela
		# selecionada.
		"1-1-2": ["Zagueiro", "Meio", "Atacante Esquerdo", "Atacante Direito"],
	},
}

var modo: String = "3v3"
var formacao: String = "1-1-1"

## posição (String) -> nome do personagem (String), um dicionário por time
var escalacao_a: Dictionary = {}
var escalacao_b: Dictionary = {}


func iniciar_modo(novo_modo: String) -> void:
	modo = novo_modo
	formacao = FORMACOES[modo].keys()[0]  # primeira formação cadastrada pro modo, como padrão
	escalacao_a.clear()
	escalacao_b.clear()


## Formações disponíveis pro modo ATUAL — use isso pra popular o
## seletor de formação na tela de escalação (ex: um OptionButton).
func formacoes_do_modo() -> Array[String]:
	var lista: Array[String] = []
	lista.assign(FORMACOES[modo].keys())
	return lista


func escolher_formacao(nova_formacao: String) -> void:
	if not FORMACOES[modo].has(nova_formacao):
		push_warning("Formação '%s' não existe pro modo '%s'." % [nova_formacao, modo])
		return
	formacao = nova_formacao
	# as posições de uma formação diferente têm rótulos diferentes — uma
	# escalação feita em cima de "1-1-1" (Atacante/Meio/Zagueiro) não faz
	# sentido nenhum em cima de "2-1" (Atacante Esquerdo/Direito/Zagueiro),
	# então zera as duas escalações ao trocar de formação
	escalacao_a.clear()
	escalacao_b.clear()


func posicoes_do_modo() -> Array[String]:
	var lista: Array[String] = []
	lista.assign(FORMACOES[modo][formacao])
	return lista


func escalacao_completa() -> bool:
	for posicao in posicoes_do_modo():
		if not escalacao_a.has(posicao) or not escalacao_b.has(posicao):
			return false
	return true
