# Trilhas Ativas — Metodologias Ativas para Biologia e Ciências

Aplicativo web estático (sem dependências, sem build) com um banco de
metodologias ativas voltado ao ensino de Biologia e Ciências, um gerador de
trilhas de aprendizagem e uma biblioteca pesquisável de dinâmicas com
referências bibliográficas.

## Como usar

Abra `app/index.html` diretamente no navegador, ou sirva a pasta com
qualquer servidor estático:

```bash
cd app
python3 -m http.server 8080
# depois acesse http://localhost:8080
```

Também pode ser publicado como página estática (ex.: GitHub Pages) apontando
para a pasta `app/`.

## Funcionalidades

- **Biblioteca de metodologias**: 18 metodologias ativas (sala de aula
  invertida, PBL, PjBL, POGIL, Peer Instruction, Jigsaw, ensino por
  investigação, rotação por estações, gamificação, debate científico, júri
  simulado, entre outras), cada uma com resumo, passo a passo de aplicação,
  matérias/temas relacionados, nível de ensino, duração, tamanho de grupo,
  materiais necessários e referências bibliográficas.
- **Filtros e busca**: por matéria/tema, nível de ensino, etapa da aula e
  busca textual livre.
- **Gerador de trilha de aprendizagem**: a partir de um tema e nível de
  ensino escolhidos, monta uma sequência didática cobrindo as cinco etapas —
  sensibilização, exploração, sistematização, aplicação e avaliação — com
  metodologias adequadas ao contexto selecionado.
- **Exportação simples**: botão para imprimir/exportar a trilha gerada em
  PDF via o diálogo de impressão do navegador.

## Estrutura

```
app/
├── index.html          # marcação da página
├── css/styles.css       # estilos (responsivo, com suporte a modo escuro)
├── js/data.js            # banco de dados das metodologias, matérias, níveis e etapas
├── js/app.js             # filtros, busca, modal de detalhes e gerador de trilha
└── README.md
```

## Ampliando o banco de dados

Para adicionar uma nova metodologia, inclua um novo objeto no array
`METODOLOGIAS` em `js/data.js`, seguindo os mesmos campos das entradas
existentes (`id`, `nome`, `etapa`, `resumo`, `comoAplicar`, `materias`,
`niveis`, `duracao`, `tamanhoGrupo`, `materiais`, `referencias`). Novas
matérias ou níveis podem ser adicionados às listas `MATERIAS` e `NIVEIS` no
topo do mesmo arquivo.

Esta primeira versão usa um banco de dados estático em JavaScript (sem
backend), o que é suficiente para uso individual ou publicação como site
estático. Uma evolução natural seria migrar `js/data.js` para uma API/banco
de dados real caso o conteúdo passe a ser editado por várias pessoas.
