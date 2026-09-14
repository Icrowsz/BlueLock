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
	"Igaguri": preload("res://personagens/Igaguri.tscn"),
	"Isagi": preload("res://personagens/Isagi.tscn"),
	"Karasu": preload("res://personagens/Karasu.tscn"),
	"Kiyora": preload("res://personagens/Kiyora.tscn"),
	"Kunigami": preload("res://personagens/Kunigami.tscn"),
	"Kurona": preload("res://personagens/Kurona.tscn"),
	"Kuso": preload("res://personagens/Kuso.tscn"),
	"Nagi": preload("res://personagens/Nagi.tscn"),
	"Nanase": preload("res://personagens/Nanase.tscn"),
	"Ness": preload("res://personagens/Ness.tscn"),
	"Niko": preload("res://personagens/Niko.tscn"),
	"Onazi": preload("res://personagens/Onazi.tscn"),
	"Otoya": preload("res://personagens/Otoya.tscn"),
	"Raichi": preload("res://personagens/Raichi.tscn"),
	"Reo": preload("res://personagens/Reo.tscn"),
	"Rin": preload("res://personagens/Rin.tscn"),
	"Sendou": preload("res://personagens/Sendou.tscn"),
	"Shidou": preload("res://personagens/Shidou.tscn"),
	"Yukimiya": preload("res://personagens/Yukimiya.tscn"),
	"Zantetsu": preload("res://personagens/Zantetsu.tscn"),
	"Sae": preload("res://personagens/Sae.tscn"),
	"Kaiser": preload("res://personagens/Kaiser.tscn"),
	"Bunny": preload("res://personagens/Bunny.tscn"),
	"Loki": preload("res://personagens/Loki.tscn"),
	"Hugo": preload("res://personagens/Hugo.tscn"),
	"Lorenzo": preload("res://personagens/Lorenzo.tscn"),
	"Teddy": preload("res://personagens/Teddy.tscn"),
}


## "Random" NÃO entra no dicionário PERSONAGENS acima — ele é `const`,
## então o valor de cada chave é fixado uma única vez (na inicialização
## do jogo), e não tem como um preload "sortear sozinho" toda vez que
## for lido. Em vez disso, "Random" é tratado como um caso especial:
## aparece na lista de nomes disponíveis, mas só vira uma cena de
## verdade dentro de cena_do_personagem(), sorteada NA HORA.
const NOME_ALEATORIO := "Random"


func nomes_disponiveis() -> Array:
	var nomes := PERSONAGENS.keys()
	nomes.append(NOME_ALEATORIO)
	return nomes


func cena_do_personagem(nome: String) -> PackedScene:
	if nome == NOME_ALEATORIO:
		return _cena_aleatoria()
	return PERSONAGENS.get(nome)


func _cena_aleatoria() -> PackedScene:
	var chaves := PERSONAGENS.keys()
	var nome_sorteado: String = chaves[randi() % chaves.size()]
	return PERSONAGENS[nome_sorteado]


## Sorteia um TIME inteiro de uma vez, sem repetir personagem (usa
## shuffle() + fatia, em vez de chamar _cena_aleatoria() várias vezes —
## se fosse por chamadas repetidas, o MESMO personagem poderia sair
## sorteado mais de uma vez pro mesmo time). Se "quantidade" for maior
## que o total de personagens cadastrados, devolve todos embaralhados
## (sem duplicar ninguém, só com menos jogadores que o pedido).
func sortear_time(quantidade: int) -> Array[PackedScene]:
	var chaves := PERSONAGENS.keys()
	chaves.shuffle()

	var cenas: Array[PackedScene] = []
	for i in range(mini(quantidade, chaves.size())):
		cenas.append(PERSONAGENS[chaves[i]])
	return cenas
