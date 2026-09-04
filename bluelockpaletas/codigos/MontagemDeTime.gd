extends Node2D

## Anexe este script (ou incorpore essa lógica no script que já controla
## o seu campo/Jogo) na cena principal da partida.
##
## Estrutura de nós esperada no campo (monte no editor):
##
## Node2D (Jogo)
##   ├── PosicoesTimeA (Node2D)
##   │     ├── Atacante (Marker2D)     <- posicione manualmente no campo
##   │     ├── Meio (Marker2D)
##   │     └── Zagueiro (Marker2D)
##   ├── PosicoesTimeB (Node2D)
##   │     └── ... mesmos nomes de posição, do lado do Time B
##   └── (bola, gols, etc. já existentes)
##
## IMPORTANTE: o NOME de cada Marker2D precisa ser EXATAMENTE igual ao
## nome da posição usado em ConfiguracaoPartida (ex: "Atacante"), senão
## get_node_or_null() não acha e o personagem não é instanciado.
## Pro modo 5v5, é só adicionar os Marker2D das posições extras
## ("Ponta Esquerda", "Ponta Direita") nos dois grupos.

@onready var posicoes_time_a: Node2D = $PosicoesTimeA
@onready var posicoes_time_b: Node2D = $PosicoesTimeB


func _ready() -> void:
	_instanciar_time(ConfiguracaoPartida.escalacao_a, posicoes_time_a, "A")
	_instanciar_time(ConfiguracaoPartida.escalacao_b, posicoes_time_b, "B")


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
