extends CanvasLayer

## AUTOLOAD (Singleton) — mas com uma pegadinha: ver instruções de
## instalação no final deste comentário, porque este script espera um
## TextureRect como filho, então NÃO dá pra adicionar direto como
## autoload "solto" (Godot só faz isso automaticamente com uma .tscn).
##
## Overlay genérico de "splash de habilidade especial": mostra uma
## imagem em tela cheia, vibra por um tempo, esmaece e some — e só
## DEPOIS disso o chamador continua (por isso mostrar_habilidade() é uma
## função "async": quem chamar precisa usar "await"). Genérico de
## propósito: qualquer personagem futuro com uma habilidade "de impacto"
## (tipo a Strongest Guy do Isagi) pode reaproveitar isso passando só a
## própria imagem — sem duplicar nenhum código de animação.
##
## --- Como instalar ---
## 1. Crie uma cena nova: Nó raiz "CanvasLayer", renomeie pra
##    "EfeitoHabilidade". Layer alto (ex: 100), pra ficar por cima de
##    tudo, inclusive de outras UIs.
## 2. Dentro dela, adicione um "TextureRect" filho, nome "Imagem".
##    - Layout: Anchors Preset "Center" (ou "Full Rect" + Expand Mode
##      "Fit Width Proportional", como preferir).
##    - Stretch Mode: "Keep Aspect Centered".
##    - Visible: desmarcado (começa escondido).
## 3. Anexe ESTE script na raiz (CanvasLayer).
## 4. Salve como EfeitoHabilidade.tscn.
## 5. Project Settings > Autoload > adicione EfeitoHabilidade.tscn (a
##    CENA, não só o script) com o nome "EfeitoHabilidade".

@onready var imagem: TextureRect = $ImagemDesire



func _ready() -> void:
	visible = false


func mostrar_habilidade(textura: Texture2D, duracao_exibicao: float = 0.9, intensidade_vibracao: float = 8.0) -> void:
	# se já tiver uma animação rolando (ex: dois personagens acionando
	# reações quase juntos), corta a anterior na hora — evita duas
	# animações brigando pela mesma Imagem ao mesmo tempo
	var tween_anterior := get_meta("tween_ativo", null) as Tween
	if tween_anterior and tween_anterior.is_valid():
		tween_anterior.kill()

	imagem.texture = textura
	imagem.modulate.a = 0.0
	visible = true

	var posicao_central := imagem.position  # vibra EM VOLTA da posição de repouso, não a partir de (0,0)

	var tween := create_tween()
	set_meta("tween_ativo", tween)

	tween.tween_property(imagem, "modulate:a", 1.0, 0.15)  # fade in

	# vibração: uma sequência de pequenos deslocamentos aleatórios,
	# repetidos em passos curtos até completar "duracao_exibicao"
	const PASSO_VIBRACAO := 0.05
	var tempo_acumulado := 0.0
	while tempo_acumulado < duracao_exibicao:
		var deslocamento := Vector2(
			randf_range(-intensidade_vibracao, intensidade_vibracao),
			randf_range(-intensidade_vibracao, intensidade_vibracao)
		)
		tween.tween_property(imagem, "position", posicao_central + deslocamento, PASSO_VIBRACAO)
		tempo_acumulado += PASSO_VIBRACAO

	tween.tween_property(imagem, "position", posicao_central, PASSO_VIBRACAO)  # volta pro centro
	tween.tween_property(imagem, "modulate:a", 0.0, 0.15)  # fade out

	await tween.finished
	visible = false
	remove_meta("tween_ativo")
