extends CanvasLayer

## Painel de habilidades do personagem CLICADO. Gera um botão pra CADA
## habilidade que o personagem tiver (Botao.lista_habilidades()) — então
## funciona automaticamente com 0, 1, 2 ou mais habilidades, sem precisar
## mexer nessa UI quando um personagem novo for adicionado ao jogo.
##
## Estrutura de nós esperada (monte no editor):
##
## CanvasLayer (UIHabilidade)  <- este script aqui
##   └── ContainerHabilidades (HBoxContainer)
##         ancorado no canto inferior
##         IMPORTANTE: marque como Nome Único (%) na árvore de cenas

@onready var container: HBoxContainer = %ContainerHabilidades

var botao_selecionado: Botao = null  # último personagem clicado


func _ready() -> void:
	if not container:
		push_error("UIHabilidade: não encontrei 'ContainerHabilidades'. Confira se existe e está marcado como Nome Único (%).")
		return

	Eventos.botao_selecionado.connect(_on_botao_selecionado)
	Turnos.turno_iniciado.connect(_on_turno_iniciado)


func _on_botao_selecionado(botao: Botao) -> void:
	botao_selecionado = botao
	_reconstruir_botoes()


func _on_turno_iniciado(_time: String) -> void:
	# cada Botao decrementa seu próprio cooldown ao ouvir esse mesmo
	# sinal (ver Botao.gd, _on_turno_mudou) — call_deferred garante que
	# a UI só recalcula DEPOIS que todos já atualizaram nesse frame
	_reconstruir_botoes.call_deferred()


func _reconstruir_botoes() -> void:
	for filho in container.get_children():
		filho.queue_free()

	if not botao_selecionado:
		return

	for nome in botao_selecionado.lista_habilidades():
		var botao_ui := Button.new()
		botao_ui.custom_minimum_size = Vector2(150, 44)
		_atualizar_texto_botao(botao_ui, nome)
		botao_ui.pressed.connect(_on_habilidade_pressionada.bind(nome))
		container.add_child(botao_ui)


func _atualizar_texto_botao(botao_ui: Button, nome: String) -> void:
	if botao_selecionado.esta_em_cooldown(nome):
		botao_ui.text = "%s (Aguarde %d)" % [nome, botao_selecionado.turnos_restantes_cooldown(nome)]
	else:
		botao_ui.text = nome


func _on_habilidade_pressionada(nome: String) -> void:
	if not botao_selecionado:
		return

	var motivo := botao_selecionado.motivo_bloqueio_habilidade(nome)
	if motivo != "":
		Eventos.mensagem_solicitada.emit(motivo)
		return

	# executa ANTES de consumir a ação de turno: se essa for a última
	# ação disponível, Turnos.usar_acao() já passaria o turno na hora,
	# e a checagem de segurança dentro da habilidade acharia que não é
	# mais a vez do time, cancelando o efeito silenciosamente (mesmo bug
	# que já corrigimos antes pro Chute Direto — vale pra qualquer
	# habilidade nova também)
	botao_selecionado.usar_habilidade(nome)

	if botao_selecionado.habilidade_consome_acao(nome):
		botao_selecionado.consumir_acao_habilidade()

	_reconstruir_botoes()  # atualiza os textos (cooldown, etc.) na hora
