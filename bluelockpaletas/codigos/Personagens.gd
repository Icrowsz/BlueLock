extends Node

## AUTOLOAD (Singleton). Configure em: Project Settings > Autoload,
## nome "Personagens".
##
## Registro central: nome exibido -> cena do personagem. A tela de
## Escalação lê ISSO pra montar a lista de opções, e o Jogo lê ISSO pra
## saber qual cena instanciar — assim, adicionar um personagem novo no
## jogo é só acrescentar uma linha aqui, sem mexer em mais nada.
##
## AJUSTE OS CAMINHOS abaixo pra onde suas cenas .tscn realmente estão.
const PERSONAGENS: Dictionary = {
	"Isagi": preload("res://personagens/Isagi.tscn"),
	"Bachira": preload("res://personagens/Bachira.tscn"),
	"Chigiri": preload("res://personagens/Chigiri.tscn"),
	"Kurona": preload("res://personagens/Kurona.tscn"),
	"Raichi": preload("res://personagens/Raichi.tscn"),
	"Sendou": preload("res://personagens/Sendou.tscn"),
}


func nomes_disponiveis() -> Array:
	return PERSONAGENS.keys()


func cena_do_personagem(nome: String) -> PackedScene:
	return PERSONAGENS.get(nome)
