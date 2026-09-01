extends Node

## AUTOLOAD (Singleton).
## Configure em: Project Settings > Autoload > adicione este script
## com o nome "Eventos".
##
## Serve de "quadro de avisos" global: qualquer parte do jogo pode emitir
## ou escutar esses sinais sem precisar ter referência direta umas às outras.

signal gol_marcado(lado: String)  # "esquerda" ou "direita"
signal habilidade_disponivel(botao: Botao)    # emitido quando dá pra usar uma habilidade
signal habilidade_indisponivel(botao: Botao)  # emitido quando deixa de dar
