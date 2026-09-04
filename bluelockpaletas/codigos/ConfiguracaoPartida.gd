extends Node

## AUTOLOAD (Singleton). Configure em: Project Settings > Autoload,
## nome "ConfiguracaoPartida".
##
## Guarda o modo (3v3/5v5) e a escalação de cada time ENTRE a Tela de
## Início, a Escalação e o Jogo. Precisa ser autoload porque trocar de
## cena com change_scene_to_file() destrói a cena anterior — sem isso,
## a escolha de personagens se perderia ao entrar no campo.

## Nomes das posições por modo. Ajuste como quiser — são só rótulos.
const POSICOES_3V3: Array[String] = ["Atacante", "Meio", "Zagueiro"]
const POSICOES_5V5: Array[String] = ["Atacante", "Ponta Esquerda", "Ponta Direita", "Meio", "Zagueiro"]

var modo: String = "3v3"

## posição (String) -> nome do personagem (String), um dicionário por time
var escalacao_a: Dictionary = {}
var escalacao_b: Dictionary = {}


func iniciar_modo(novo_modo: String) -> void:
	modo = novo_modo
	escalacao_a.clear()
	escalacao_b.clear()


func posicoes_do_modo() -> Array[String]:
	return POSICOES_5V5 if modo == "5v5" else POSICOES_3V3


func escalacao_completa() -> bool:
	for posicao in posicoes_do_modo():
		if not escalacao_a.has(posicao) or not escalacao_b.has(posicao):
			return false
	return true
