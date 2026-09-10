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

## Emitido toda vez que QUALQUER botão termina de usar QUALQUER
## habilidade (própria ou concedida) — ver Botao.usar_habilidade().
## Gancho genérico pro sistema de Chemical Reaction (ReacoesQuimicas.gd)
## saber quando um "gatilho" (ex: Bee Shot do Bachira) acabou de acontecer,
## sem que o Bachira precise saber que a reação existe.
signal habilidade_executada(botao: Botao, nome: String)

## Emitido toda vez que a bola entra no AreaAlcance de QUALQUER botão —
## ver Botao._on_bola_entrou_alcance(). Junto com habilidade_executada
## acima, é a "condição" que o ReacoesQuimicas.gd espera pra saber se um
## gatilho pendente terminou de se completar (ex: a Bee Shot chegou perto
## do Isagi).
signal bola_entrou_alcance(botao: Botao)
