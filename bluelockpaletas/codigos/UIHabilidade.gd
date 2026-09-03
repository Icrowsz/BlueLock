extends CanvasLayer

## Botão de habilidade especial (ex: "Chute Direto") que aparece no canto
## inferior da tela quando o jogador tem uma habilidade disponível, e some
## quando deixa de estar no alcance.
##
## Estrutura de nós esperada (monte no editor):
##
## CanvasLayer (UIHabilidade)  <- este script aqui
##   └── BotaoHabilidade (Button)
##         ancorado no canto inferior (ex: bottom-right ou bottom-center)
##         começa com "visible" desmarcado no editor
##         IMPORTANTE: clique direito no Button na árvore de cenas >
##         "Acessar como Nome Único" (ícone %) — assim o script encontra
##         ele mesmo que você aninhe dentro de containers depois pra estilizar

@onready var botao_habilidade: Button = %BotaoHabilidade

var botao_ativo: Botao = null  # qual personagem está com a habilidade pronta


func _ready() -> void:
	if not botao_habilidade:
		push_error("UIHabilidade: não encontrei o nó 'BotaoHabilidade'. Confira se ele existe e está marcado como Nome Único (%) na árvore de cenas.")
		return

	Eventos.habilidade_disponivel.connect(_on_habilidade_disponivel)
	Eventos.habilidade_indisponivel.connect(_on_habilidade_indisponivel)
	Turnos.turno_iniciado.connect(_on_turno_iniciado)
	botao_habilidade.pressed.connect(_on_botao_pressionado)
	botao_habilidade.visible = false


func _on_habilidade_disponivel(botao: Botao) -> void:
	if not botao.tem_habilidade_no_alcance():
		return  # não é o turno desse time
	botao_ativo = botao
	_atualizar_botao(botao)
	botao_habilidade.visible = true


func _on_habilidade_indisponivel(botao: Botao) -> void:
	# só esconde se for o mesmo botão que estava ativo (evita que um
	# segundo personagem saindo do alcance esconda a habilidade de outro)
	if botao_ativo == botao:
		botao_ativo = null
		botao_habilidade.visible = false


func _on_turno_iniciado(time: String) -> void:
	# usamos call_deferred aqui de propósito: cada Botao também está
	# escutando esse mesmo sinal pra decrementar seu próprio cooldown
	# (ver Botao.gd, _on_turno_mudou). Precisamos garantir que TODOS os
	# cooldowns já foram atualizados antes de recalcular o que a UI
	# mostra — call_deferred adia essa checagem pro fim do frame atual,
	# depois que os outros handlers já rodaram.
	_revalidar_apos_turno.call_deferred(time)


func _revalidar_apos_turno(_time: String) -> void:
	# ao trocar de turno, verifica se algum personagem do NOVO time já
	# está com a bola no alcance (o sinal habilidade_disponivel só
	# dispara quando a bola ENTRA na área — se ela já estava lá antes
	# da troca de turno, precisamos revalidar manualmente aqui)
	botao_ativo = null
	botao_habilidade.visible = false

	for nodo in get_tree().get_nodes_in_group("botoes"):
		var botao := nodo as Botao
		if botao and botao.tem_habilidade_no_alcance():
			botao_ativo = botao
			_atualizar_botao(botao)
			botao_habilidade.visible = true
			break


func _atualizar_botao(botao: Botao) -> void:
	var habilidade := botao.nome_habilidade()
	if botao.esta_em_cooldown(habilidade):
		botao_habilidade.text = "Aguarde (%d)" % botao.turnos_restantes_cooldown(habilidade)
		botao_habilidade.disabled = true
	else:
		botao_habilidade.text = habilidade
		botao_habilidade.disabled = not Turnos.tem_acao_disponivel("habilidade")


func _on_botao_pressionado() -> void:
	if botao_ativo and botao_ativo.pode_usar_habilidade():
		# IMPORTANTE: executa a habilidade ANTES de consumir a ação.
		# Se fizéssemos o contrário, e essa fosse a última ação do turno,
		# Turnos.usar_acao() já teria trocado o turno pro time adversário
		# antes de usar_habilidade() rodar — e a checagem de segurança
		# dentro dela (pode_usar_habilidade -> pode_agir) cancelaria o
		# efeito silenciosamente, achando que não era mais a vez do time.
		botao_ativo.usar_habilidade()
		Turnos.usar_acao("habilidade")
	botao_habilidade.visible = false
	botao_ativo = null
