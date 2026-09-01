extends Node

## AUTOLOAD (Singleton).
## Configure em: Project Settings > Autoload > adicione este script
## com o nome "Eventos".
##
## Serve de "quadro de avisos" global: qualquer parte do jogo pode emitir
## ou escutar esses sinais sem precisar ter referência direta umas às outras.

signal gol_marcado(lado: String)  # "esquerda" ou "direita"
