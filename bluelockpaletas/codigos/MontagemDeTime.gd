extends Node2D

## Anexe este script (ou incorpore essa lógica no script que já controla
## o seu campo/Jogo) na cena principal da partida.
##
## Estrutura de nós esperada no campo (monte no editor) — UM grupo de
## marcadores POR FORMAÇÃO cadastrada em ConfiguracaoPartida, cada um
## com os DOIS conjuntos de posição (TimeA e TimeB) dentro:
##
## Node2D (Jogo)
##   ├── Formacoes (Node2D)
##   │     ├── 1-1-1 (Node2D)                <- nome EXATO da formação
##   │     │     ├── PosicoesTimeA (Node2D)
##   │     │     │     ├── Atacante (Marker2D)   <- posicione manualmente
##   │     │     │     ├── Meio (Marker2D)
##   │     │     │     └── Zagueiro (Marker2D)
##   │     │     └── PosicoesTimeB (Node2D)
##   │     │           └── ... mesmos nomes de posição, do lado do Time B
##   │     ├── 2-1 (Node2D)
##   │     │     └── ... (PosicoesTimeA e PosicoesTimeB também)
##   │     ├── 1-2-2 (Node2D)                 <- formação do modo 5v5
##   │     └── 1-1-2 (Node2D)
##   └── (bola, gols, etc. já existentes)
##
## IMPORTANTE — cada time agora pode estar numa formação DIFERENTE
## (ConfiguracaoPartida.formacao_a / formacao_b): o Time A usa só o
## "PosicoesTimeA" de dentro da formação QUE ELE escolheu, e o Time B
## usa só o "PosicoesTimeB" de dentro da formação QUE ELE escolheu —
## mesmo que sejam duas pastas de formação diferentes. Por isso toda
## formação cadastrada precisa ter os DOIS grupos (PosicoesTimeA e
## PosicoesTimeB) montados, mesmo que só um deles acabe sendo usado numa
## partida específica.
##
## - O nome de cada Node2D dentro de "Formacoes" precisa ser EXATAMENTE
##   igual ao nome da formação em ConfiguracaoPartida.FORMACOES_3V3 /
##   FORMACOES_5V5 (ex: "1-1-1", "2-1", "1-2-2", "1-1-2").
## - Dentro de cada formação, o NOME de cada Marker2D precisa ser
##   EXATAMENTE igual ao nome da posição naquela formação.

@onready var container_formacoes: Node2D = $Formacoes


func _ready() -> void:
	var posicoes_time_a := _achar_grupo_de_posicoes(ConfiguracaoPartida.formacao_a, "PosicoesTimeA")
	var posicoes_time_b := _achar_grupo_de_posicoes(ConfiguracaoPartida.formacao_b, "PosicoesTimeB")

	if not posicoes_time_a or not posicoes_time_b:
		return  # erro específico já foi reportado dentro de _achar_grupo_de_posicoes()

	_instanciar_time(ConfiguracaoPartida.escalacao_a, posicoes_time_a, "A")
	_instanciar_time(ConfiguracaoPartida.escalacao_b, posicoes_time_b, "B")


func _achar_grupo_de_posicoes(nome_formacao: String, nome_grupo_do_time: String) -> Node2D:
	var grupo_formacao := container_formacoes.get_node_or_null(nome_formacao) as Node2D
	if not grupo_formacao:
		push_error("Não encontrei os marcadores da formação '%s' dentro de 'Formacoes'. Confira se existe um Node2D com esse NOME EXATO lá." % nome_formacao)
		return null

	var posicoes := grupo_formacao.get_node_or_null(nome_grupo_do_time) as Node2D
	if not posicoes:
		push_error("A formação '%s' precisa ter '%s' como filho direto." % [nome_formacao, nome_grupo_do_time])
		return null

	return posicoes


func _instanciar_time(escalacao: Dictionary, posicoes: Node2D, sigla_time: String) -> void:
	for posicao in escalacao:
		var nome_personagem: String = escalacao[posicao]
		var cena := Personagens.cena_do_personagem(nome_personagem)
		if not cena:
			push_warning("Personagem '%s' não encontrado no registro." % nome_personagem)
			continue

		var marcador := posicoes.get_node_or_null(posicao) as Marker2D
		if not marcador:
			push_warning("Sem Marker2D pra posição '%s' em %s." % [posicao, posicoes.name])
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
