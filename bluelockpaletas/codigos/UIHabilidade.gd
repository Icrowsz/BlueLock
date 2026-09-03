extends CanvasLayer

## Painel de habilidade que mostra a habilidade do personagem CLICADO
## (nome + estado de cooldown, se houver). Some se o personagem clicado
## não tiver nenhuma habilidade.
##
## Estrutura de nós esperada (monte no editor):
##
## CanvasLayer (UIHabilidade)  <- este script aqui
##   └── BotaoHabilidade (Button)
##         ancorado no canto inferior
##         começa com "visible" desmarcado no editor
##         IMPORTANTE: marque como Nome Único (%) na árvore de cenas

@onready var botao_habilidade: Button = %BotaoHabilidade

var botao_selecionado: Botao = null  # último personagem clicado


func _ready() -> void:
	if not botao_habilidade:
		push_error("UIHabilidade: não encontrei o nó 'BotaoHabilidade'. Confira se ele existe e está marcado como Nome Único (%) na árvore de cenas.")
		return

	Eventos.botao_selecionado.connect(_on_botao_selecionado)
	Turnos.turno_iniciado.connect(_on_turno_iniciado)
	botao_habilidade.pressed.connect(_on_botao_pressionado)
	botao_habilidade.visible = false


func _on_botao_selecionado(botao: Botao) -> void:
	if botao.nome_habilidade() == "":
		# personagem sem nenhuma habilidade (ex: Botao base): não mostra nada
		botao_selecionado = null
		botao_habilidade.visible = false
		return

	botao_selecionado = botao
	_atualizar_texto()
	botao_habilidade.visible = true


func _on_turno_iniciado(_time: String) -> void:
	# os cooldowns são decrementados por cada Botao ao ouvir o mesmo sinal
	# (ver Botao.gd, _on_turno_mudou). Usamos call_deferred pra garantir
	# que essa atualização de texto rode DEPOIS que todos os cooldowns já
	# foram decrementados nesse frame.
	_atualizar_texto.call_deferred()


func _atualizar_texto() -> void:
	if not botao_selecionado:
		return
	var habilidade := botao_selecionado.nome_habilidade()
	if botao_selecionado.esta_em_cooldown(habilidade):
		botao_habilidade.text = "Aguarde (%d)" % botao_selecionado.turnos_restantes_cooldown(habilidade)
	else:
		botao_habilidade.text = habilidade


func _on_botao_pressionado() -> void:
	if not botao_selecionado:
		return

	var motivo := botao_selecionado.motivo_bloqueio_habilidade()
	if motivo != "":
		Eventos.mensagem_solicitada.emit(motivo)
		return

	botao_selecionado.usar_habilidade()
	Turnos.usar_acao("habilidade")
	_atualizar_texto()  # reflete o cooldown recém-iniciado na hora
