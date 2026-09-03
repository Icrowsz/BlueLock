extends CanvasLayer

## Texto no canto superior direito indicando de quem é a vez, com um
## botão pra pular o turno caso o time não queira usar as ações.
##
## Estrutura de nós esperada (monte no editor):
##
## CanvasLayer (UITurno)  <- este script aqui
##   ├── LabelTurno (Label)
##   │     ancorado no canto superior direito (Anchor Preset: Top Right)
##   │     IMPORTANTE: marque como Nome Único (%)
##   └── BotaoPularTurno (Button)
##         texto "Pular Turno", logo abaixo do LabelTurno
##         IMPORTANTE: marque como Nome Único (%)

@onready var label_turno: Label = %LabelTurno
@onready var botao_pular: Button = %BotaoPularTurno


func _ready() -> void:
	if not label_turno or not botao_pular:
		push_error("UITurno: confira se 'LabelTurno' e 'BotaoPularTurno' existem e estão marcados como Nome Único (%).")
		return

	Turnos.turno_iniciado.connect(_on_turno_iniciado)
	botao_pular.pressed.connect(_on_pular_pressionado)
	_atualizar_texto(Turnos.time_da_vez)


func _on_turno_iniciado(time: String) -> void:
	_atualizar_texto(time)


func _atualizar_texto(time: String) -> void:
	label_turno.text = "Vez do Time %s" % time


func _on_pular_pressionado() -> void:
	Turnos.passar_turno_manual()
