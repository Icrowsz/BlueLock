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
	"Aiku": preload("res://personagens/Aiku.tscn"),
	"Aryu": preload("res://personagens/Aryu.tscn"),
	"Bachira": preload("res://personagens/Bachira.tscn"),
	"Barou": preload("res://personagens/Barou.tscn"),
	"Charles": preload("res://personagens/Charles.tscn"),
	"Chigiri": preload("res://personagens/Chigiri.tscn"),
	"Hiori": preload("res://personagens/Hiori.tscn"),
	"Isagi": preload("res://personagens/Isagi.tscn"),
	"Karasu": preload("res://personagens/Karasu.tscn"),
	"Kiyora": preload("res://personagens/Kiyora.tscn"),
	"Kunigami": preload("res://personagens/Kunigami.tscn"),
	"Kurona": preload("res://personagens/Kurona.tscn"),
	"Nagi": preload("res://personagens/Nagi.tscn"),
	"Ness": preload("res://personagens/Ness.tscn"),
	"Niko": preload("res://personagens/Niko.tscn"),
	"Otoya": preload("res://personagens/Otoya.tscn"),
	"Raichi": preload("res://personagens/Raichi.tscn"),
	"Reo": preload("res://personagens/Reo.tscn"),
	"Rin": preload("res://personagens/Rin.tscn"),
	"Sendou": preload("res://personagens/Sendou.tscn"),
	"Shidou": preload("res://personagens/Shidou.tscn"),
	"Yukimiya": preload("res://personagens/Yukimiya.tscn"),
	"Zantetsu": preload("res://personagens/Zantetsu.tscn"),
}


func nomes_disponiveis() -> Array:
	return PERSONAGENS.keys()


func cena_do_personagem(nome: String) -> PackedScene:
	return PERSONAGENS.get(nome)
