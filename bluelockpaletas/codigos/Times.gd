extends Node

## AUTOLOAD (Singleton).
## Configure em: Project Settings > Autoload > adicione este script
## com o nome "Times".
##
## Define, num lugar só, pra qual lado cada time ataca. Assim, se um dia
## você quiser trocar de lado no intervalo (como no futebol de verdade),
## muda só aqui — não precisa mexer em cada botão.

const GOL_INIMIGO := {
	"A": "direita",   # time A defende a esquerda, ataca o gol da direita
	"B": "esquerda",  # time B defende a direita, ataca o gol da esquerda
}

const COR_TIME := {
	"A": Color(0.9, 0.15, 0.15),  # vermelho
	"B": Color(0.15, 0.45, 0.95), # azul
}


func gol_inimigo_do_time(time: String) -> String:
	return GOL_INIMIGO.get(time, "direita")


func cor_do_time(time: String) -> Color:
	return COR_TIME.get(time, Color.WHITE)
