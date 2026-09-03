extends Botao
class_name Isagi

## Isagi Yoichi — habilidade: Chute Direto
## Um chute forte, reto e teleguiado direto na direção do gol inimigo,
## ignorando a velocidade atual da bola (por isso "teleguiado": não
## depende do ângulo de onde a bola veio, sempre mira reto no gol).
##
## Use esta cena assim:
## 1. Botão direito em Botao.tscn > Novo Herdeiro de Cena (Isagi.tscn)
## 2. Selecione o nó raiz > troque o script pra este (Isagi.gd)

@export var forca_chute_direto: float = 1400.0
@export var cooldown_chute_direto: int = 2  # em turnos


func nome_habilidade() -> String:
	return "Chute Direto"


func usar_habilidade() -> void:
	if not pode_usar_habilidade():
		return

	var bola := bola_no_alcance
	if not bola:
		return

	var gol := _encontrar_gol_inimigo()
	if not gol:
		return

	var direcao := (gol.ponto_para_mira() - bola.global_position).normalized()
	bola.receber_chute_teleguiado(direcao, forca_chute_direto)

	iniciar_cooldown(nome_habilidade(), cooldown_chute_direto)


func _encontrar_gol_inimigo() -> Gol:
	var lado_alvo := gol_inimigo_lado()
	for nodo in get_tree().get_nodes_in_group("gols"):
		var gol := nodo as Gol
		if gol and gol.lado == lado_alvo:
			return gol
	return null
