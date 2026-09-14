extends Node2D

## Anexe este script (ou incorpore essa lógica no script que já controla
## o seu campo/Jogo) na cena principal da partida.
##
## Estrutura de nós esperada no campo (monte no editor) — agora com UM
## GRUPO DE MARKER2D POR FORMAÇÃO dentro de cada time, porque cada
## formação tem posições (e portanto Marker2D) diferentes:
##
## Node2D (Jogo)
##   ├── PosicoesTimeA (Node2D)
##   │     ├── "1-1-1" (Node2D)              <- nome EXATO da formação (ver ConfiguracaoPartida.FORMACOES)
##   │     │     ├── Atacante (Marker2D)      <- posicione manualmente no campo
##   │     │     ├── Meio (Marker2D)
##   │     │     └── Zagueiro (Marker2D)
##   │     └── "2-1" (Node2D)
##   │           ├── Atacante Esquerdo (Marker2D)
##   │           ├── Atacante Direito (Marker2D)
##   │           └── Zagueiro (Marker2D)
##   ├── PosicoesTimeB (Node2D)
##   │     └── ... mesma estrutura (um Node2D por formação), do lado do Time B
##   └── (bola, gols, etc. já existentes)
##
## IMPORTANTE: o nome de cada subgrupo de formação precisa bater
## EXATAMENTE com a chave usada em ConfiguracaoPartida.FORMACOES (ex:
## "1-1-1", "2-1"), e o nome de cada Marker2D dentro dele precisa bater
## EXATAMENTE com a posição correspondente NAQUELA formação — senão
## get_node_or_null() não acha e o personagem não é instanciado.
## Repita essa estrutura (um subgrupo por formação) pros dois modos:
## PosicoesTimeA/B do 3v3 tem "2-1" e "1-1-1"; do 5v5 tem "1-2-2" e "1-1-2".

@onready var posicoes_time_a: Node2D = $PosicoesTimeA
@onready var posicoes_time_b: Node2D = $PosicoesTimeB


func _ready() -> void:
	var marcadores_a := _marcadores_da_formacao(posicoes_time_a)
	var marcadores_b := _marcadores_da_formacao(posicoes_time_b)
	if not marcadores_a or not marcadores_b:
		return  # o aviso já foi dado dentro de _marcadores_da_formacao()

	_instanciar_time(ConfiguracaoPartida.escalacao_a, marcadores_a, "A")
	_instanciar_time(ConfiguracaoPartida.escalacao_b, marcadores_b, "B")


func _marcadores_da_formacao(posicoes: Node2D) -> Node2D:
	var grupo := posicoes.get_node_or_null(ConfiguracaoPartida.formacao) as Node2D
	if not grupo:
		push_error("Sem grupo de Marker2D pra formação '%s' em %s. Confira se existe um Node2D com esse NOME EXATO dentro dele." % [ConfiguracaoPartida.formacao, posicoes.name])
	return grupo


func _instanciar_time(escalacao: Dictionary, posicoes: Node2D, sigla_time: String) -> void:
	for posicao in escalacao:
		var nome_personagem: String = escalacao[posicao]
		var cena := Personagens.cena_do_personagem(nome_personagem)
		if not cena:
			push_warning("Personagem '%s' não encontrado no registro." % nome_personagem)
			continue

		var marcador := posicoes.get_node_or_null(posicao) as Marker2D
		if not marcador:
			push_warning("Sem Marker2D pra posição '%s' em %s (formação '%s')." % [posicao, posicoes.name, ConfiguracaoPartida.formacao])
			continue

		var instancia := cena.instantiate()
		if not instancia:
			push_error("Não consegui instanciar a cena de '%s' — normalmente é um ERRO DE SCRIPT dentro dessa cena. Olha o painel Debugger/Saída do Godot: deve ter uma mensagem de erro logo ANTES desta, apontando o script e a linha exatos." % nome_personagem)
			continue

		var personagem := instancia as Botao
		if not personagem:
			push_error("A cena de '%s' não é (nem herda de) Botao — confira se o script Botao.gd está no nó RAIZ dessa cena." % nome_personagem)
			instancia.queue_free()
			continue

		personagem.time = sigla_time
		personagem.global_position = marcador.global_position
		add_child(personagem)
