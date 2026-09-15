extends Resource
class_name FormacaoVisual

## Um item da lista "formacoes_visuais" em Escalacao.gd: associa o NOME
## de uma formação (precisa bater EXATAMENTE com uma chave em
## ConfiguracaoPartida.FORMACOES_3V3 / FORMACOES_5V5 — ex: "1-2-2",
## "1-1-1") com a imagem que a representa na tela de Escalação.
##
## Pra criar um item novo: no Inspector do Escalacao.gd, no array
## "Formacoes Visuais", clique em "Add Element" > "New FormacaoVisual",
## preencha o campo "Nome" com o nome exato da formação, e arraste sua
## imagem pronta pro campo "Imagem".

@export var nome: String = ""
@export var imagem: Texture2D
