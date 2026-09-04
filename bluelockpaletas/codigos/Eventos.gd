extends Node

## AUTOLOAD (Singleton).
## Configure em: Project Settings > Autoload > adicione este script
## com o nome "Eventos".
##
## Serve de "quadro de avisos" global: qualquer parte do jogo pode emitir
## ou escutar esses sinais sem precisar ter referência direta umas às outras.

signal gol_marcado(lado: String)  # "esquerda" ou "direita"
signal botao_selecionado(botao: Botao)   # emitido quando o jogador clica em um personagem
signal mensagem_solicitada(texto: String)  # pede pra UI mostrar um aviso rápido na tela
signal botao_chutado(botao: Botao)  # emitido quando um botão completa um chute de VERDADE (ex: pro Stalker do Raichi saber quando perseguir de novo)
