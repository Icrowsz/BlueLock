extends Node

## AUTOLOAD (Singleton).
## Configure em: Project Settings > Autoload > adicione este script
## com o nome "Turnos".
##
## Gerencia de quem é a vez (time A ou B) e quantas ações de cada TIPO
## restam nesse turno. Usamos um Dicionário (não um número fixo) de
## propósito: assim, quando um personagem futuro tiver uma habilidade
## que concede uma ação extra (ex: "joga de novo"), basta chamar
## adicionar_acoes() — não precisamos mexer na estrutura nem em nenhum
## outro script que já existe.

signal turno_iniciado(time: String)
signal turno_finalizado(time: String)
signal acoes_atualizadas(acoes_restantes: Dictionary)

## Ações que cada time recebe no início do turno. Pode adicionar novos
## tipos aqui no futuro (ex: "passe") sem quebrar nada que já existe.
@export var acoes_padrao: Dictionary = {
	"movimento": 1,
	"habilidade": 1,
}

var time_da_vez: String = "A"
var acoes_restantes: Dictionary = {}


func _ready() -> void:
	_iniciar_turno("A")


func eh_turno_do_time(time: String) -> bool:
	return time == time_da_vez


func tem_acao_disponivel(tipo: String) -> bool:
	return acoes_restantes.get(tipo, 0) > 0


func usar_acao(tipo: String) -> bool:
	# tenta gastar uma ação do tipo informado. Retorna false sem fazer
	# nada se não houver nenhuma disponível — sempre confira o retorno
	# antes de considerar a ação como "realizada".
	if not tem_acao_disponivel(tipo):
		return false

	acoes_restantes[tipo] -= 1
	acoes_atualizadas.emit(acoes_restantes)

	if _sem_acoes_restantes():
		_passar_turno()

	return true


func adicionar_acoes(tipo: String, quantidade: int) -> void:
	# GANCHO PRO FUTURO: chame isso de dentro da habilidade de um
	# personagem que concede ações extras nesse turno.
	# Ex: Turnos.adicionar_acoes("movimento", 1)
	acoes_restantes[tipo] = acoes_restantes.get(tipo, 0) + quantidade
	acoes_atualizadas.emit(acoes_restantes)


func passar_turno_manual() -> void:
	# use isso num botão de "Passar Turno" na UI, caso o jogador não
	# queira gastar todas as ações disponíveis
	_passar_turno()


func _sem_acoes_restantes() -> bool:
	for tipo in acoes_restantes:
		if acoes_restantes[tipo] > 0:
			return false
	return true


func _passar_turno() -> void:
	turno_finalizado.emit(time_da_vez)
	var proximo_time := "B" if time_da_vez == "A" else "A"
	_iniciar_turno(proximo_time)


func _iniciar_turno(time: String) -> void:
	time_da_vez = time
	acoes_restantes = acoes_padrao.duplicate()
	turno_iniciado.emit(time_da_vez)
	acoes_atualizadas.emit(acoes_restantes)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("passar_turno"):
		passar_turno_manual()
