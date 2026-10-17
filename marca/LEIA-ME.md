# Marca da revenda

Tudo o que muda de uma revenda para outra fica nesta pasta. Para colocar a
marca do cliente, troque estes arquivos e envie para o `main`. A esteira gera
os três aplicativos (cliente, Super Central e Central) e os painéis web já
com a marca nova.

| Arquivo | O que é | Como deve ser |
|---|---|---|
| `marca.json` | Nomes, frase e cores | Veja a tabela abaixo |
| `icone.png` | Ícone dos apps na tela do celular | Quadrado, 1024 x 1024, sem texto pequeno |
| `icone_frente.png` | Só o símbolo do ícone (opcional) | Quadrado, fundo transparente; o Android põe a cor de fundo e recorta em círculo ou quadrado |
| `logo.png` | Logo das telas de entrada | Quadrado, fundo transparente, pelo menos 512 x 512 |

## marca.json

| Campo | Exemplo | Onde aparece |
|---|---|---|
| `NOME_APP` | `Gás e Água` | Nome do app do cliente e da revenda nas telas |
| `SLOGAN` | `Peça gás e água sem sair de casa.` | Tela de entrada do cliente |
| `NOME_SUPER_CENTRAL` | `Super Central` | Nome do app do dono |
| `NOME_CENTRAL` | `Central` | Nome do app das lojas |
| `COR_PRINCIPAL` | `#0B5C7A` | Botões e destaques dos apps, cor dos avisos |
| `COR_FUNDO_ICONE` | `#0B5C7A` | Fundo do ícone do celular |

As cores vão no formato `#RRGGBB`.

## Como aplicar

- **Automático:** a esteira roda `scripts/aplicar_marca.py` antes de gerar os
  APKs; basta enviar os arquivos novos.
- **À mão:** `python3 scripts/aplicar_marca.py` (precisa do Pillow). O script
  confere os arquivos e avisa em português se algo estiver errado.

A marca atual (gota com chama, azul petróleo) é **provisória**, desenhada por
`scripts/desenhar_marca_provisoria.py`, até a revenda mandar a dela.

O nome técnico dos apps (identificador na loja, por exemplo
`br.com.fortalezadigitalsecurity.gasagua.cliente`) **não** muda com a marca:
trocar esse identificador faria o celular tratar como outro aplicativo.
