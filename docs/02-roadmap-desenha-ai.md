# 02 · Roadmap do desenha_ai

**Objetivo do app:** ajudar a desenhar à mão no papel. O usuário escolhe uma
imagem de referência e a vê sobreposta, semitransparente, à imagem ao vivo da
câmera traseira, como um "papel vegetal digital".

**Restrições do projeto:**

- 100% offline: nenhuma permissão de internet, nenhuma chamada de rede.
- Aparelhos-alvo: **Samsung Galaxy Tab A** (tablet, hardware modesto, pouca
  RAM) e **RedMagic Pro 11** (celular potente, tela de alta resolução).
  Decisões de desempenho miram o Tab A; decisões de layout cobrem os dois.
- Projeto de estudo: cada fase deve ensinar conceitos novos de Flutter.

Status: ✅ concluída · 🚧 em andamento · ⏳ aguardando

---

## Fase 1 · Seletor de imagem local ✅

> Na Fase 3, a prévia da imagem na Home foi substituída pelo histórico
> "Continuar desenhando".

**Entrega:** tela inicial onde o usuário escolhe uma imagem salva no aparelho
e vê uma prévia.

### Funcionalidades

- Botão "Escolher imagem" abre o seletor **nativo** do Android, filtrado para
  imagens (galeria, pasta Downloads, cartão SD).
- Prévia da imagem com nome e tamanho do arquivo.
- "Trocar imagem" e "Remover imagem".
- Estados tratados: vazio, carregando, imagem carregada, erro.
- Cancelar o seletor não é tratado como erro e mantém a imagem anterior.
- Layout responsivo: detalhes na lateral em telas largas (tablet deitado) e
  embaixo em telas estreitas (celular em pé).

### Decisões técnicas

| Decisão | Motivo |
| --- | --- |
| Pacote `file_picker` com `FileType.image` | Usa o Photo Picker / seletor de documentos do sistema. **Não exige permissão de armazenamento** e lê só arquivos locais. |
| Guardar **bytes** em vez de caminho | No Android o seletor costuma devolver `content://`, que não é um caminho de arquivo comum. Bytes funcionam sempre. |
| Decodificar a prévia no tamanho da tela (`ResizeImage`) | Uma foto de 50 MP decodificada inteira usa ~200 MB de RAM. O Tab A não aguenta isso com folga. |
| Estados com `sealed class` | Impede combinações inválidas (ex.: "carregando" e "erro" ao mesmo tempo) e o compilador força tratar todos. |
| Interface `LocalImageSource` | Permite testar a tela com uma fonte falsa e trocar o pacote sem mexer na UI. |
| `setState` (sem pacote de estado) | Uma tela, um estado local: é a ferramenta mais simples que resolve. |

### Conceitos de Flutter praticados

`StatelessWidget`, `StatefulWidget`, `setState`, `mounted`, `async/await`,
`LayoutBuilder`, `Image` com `frameBuilder`/`errorBuilder`, tema Material 3,
widget tests com dependência falsa.

### Como testar no aparelho

1. Conecte o aparelho por USB com a depuração USB ativada.
2. `flutter run`.
3. Ative o **modo avião** para confirmar que tudo funciona offline.
4. Casos a verificar:
   - escolher uma foto da câmera (arquivo grande);
   - escolher uma imagem pequena (ícone, print);
   - abrir o seletor e cancelar (com e sem imagem já escolhida);
   - girar o aparelho com uma imagem carregada;
   - escolher um arquivo corrompido (ex.: renomeie um `.txt` para `.jpg`),
     que deve mostrar a mensagem de erro da prévia.

---

## Fase 2 · AR Drawing / sobreposição ✅

> Detalhes da implementação: `docs/03-fase2-camera-e-gestos.md`.

**Entrega:** tela de desenho com a câmera traseira ao vivo em tela cheia e a
imagem de referência por cima, ajustável.

### Funcionalidades planejadas

- **Câmera traseira ao vivo** em tela cheia (pacote oficial `camera`).
- **Imagem de referência sobreposta** com:
  - **Opacidade**: slider (0–100%), sempre visível e fácil de alcançar com o
    polegar.
  - **Posição**: arrastar com um dedo.
  - **Zoom**: pinça com dois dedos.
  - **Rotação**: girar com dois dedos, mais botões de ajuste fino (±1°, ±90°).
  - **Espelhar** horizontalmente (útil para desenhos simétricos).
  - **Resetar** transformações.
- **Trava de tela** (o ponto mais importante para uso real):
  - um botão de cadeado congela todas as transformações da imagem;
  - com a trava ativa, toques na imagem são ignorados (a mão apoiada no papel
    não move nada);
  - para destravar, é preciso **segurar** o cadeado por ~1 s, para não
    destravar sem querer.
- **Tela sempre acesa** enquanto desenha (pacote `wakelock_plus`).
- **Lanterna** liga/desliga, para desenhar em ambiente escuro.
- **Modo imersivo**: esconde as barras do sistema e auto-oculta os controles
  depois de alguns segundos.

### Decisões técnicas previstas

| Tema | Plano |
| --- | --- |
| Câmera | `camera`: `CameraController` criado em `initState`, liberado em `dispose`, e pausado/retomado com `WidgetsBindingObserver` quando o app vai para segundo plano. |
| Permissão | `CAMERA` no `AndroidManifest.xml`; tratar a recusa com uma tela explicativa e um botão para abrir as configurações. |
| Gestos | `GestureDetector` com `onScaleStart/Update` (cobre arrastar, pinça e rotação num só reconhecedor), aplicando uma `Matrix4` via `Transform`. |
| Estado das transformações | Classe imutável `OverlayTransform` (posição, escala, rotação, opacidade, espelhado, travado), gerenciada por um `ValueNotifier`/`ChangeNotifier`, para reconstruir só a camada da imagem a cada quadro de gesto. |
| Desempenho | Reaproveitar a imagem já decodificada no tamanho da tela; `RepaintBoundary` separando câmera, imagem e controles; testar com o *performance overlay* no Tab A. |
| Orientação | Avaliar travar em paisagem no tablet (`SystemChrome.setPreferredOrientations`), porque girar a câmera no meio do desenho desalinha tudo. |

### Novos conceitos de Flutter

Plugins com código nativo, permissões em tempo de execução, ciclo de vida
(`initState`/`dispose`/`AppLifecycleState`), gestos multitoque, `Matrix4`,
`Stack`/`Positioned`, `Navigator` (ir da Fase 1 para a 2), `ChangeNotifier`.

---

## Fase 3 · Persistência local ✅

> Concluída: cópia da imagem para o armazenamento interno, salvamento
> automático dos ajustes, histórico "Continuar desenhando" e exclusão.
> Detalhes: `docs/04-fase3-persistencia-offline.md`.
>
> ❌ **Cancelado:** salvar o progresso do traçado ("até onde o traçado foi
> feito"). O item continua listado abaixo só como registro do plano
> original; ele **não será implementado**. O que a Fase 3 entregou não foi
> alterado.

**Entrega:** o app lembra do que o usuário estava fazendo, mesmo depois de
fechado.

### Funcionalidades planejadas

- **Projetos recentes** na tela inicial (miniatura, nome, data), para
  reabrir com um toque.
- **Salvar as transformações** de cada projeto (posição, zoom, rotação,
  opacidade), para continuar exatamente onde parou.
- **Cópia da imagem para o armazenamento do app**: se o original for
  apagado ou movido na galeria, o projeto continua funcionando.
- ~~**Progresso do traçado (se possível):**~~ ❌ **CANCELADO** (decisão
  tomada antes da Fase 4; não será feito). Opções que tinham sido
  consideradas, mantidas só como registro:
  - ~~*Viável:* o usuário marca manualmente regiões já desenhadas (pinta
    áreas por cima, como um marca-texto) e isso é salvo como uma camada.~~
  - ~~*Viável:* foto de progresso tirada pela própria câmera, salva no
    projeto para comparar com a referência.~~
  - ~~*Experimental:* detectar automaticamente o que já foi desenhado no
    papel comparando a câmera com a referência (OpenCV/TFLite offline).~~
- Excluir projetos e liberar espaço.

### Decisões técnicas previstas

| Tema | Plano |
| --- | --- |
| Onde salvar arquivos | `path_provider` → `getApplicationDocumentsDirectory()`: pasta privada do app, sem permissão extra, apagada só ao desinstalar. |
| Metadados dos projetos | Começar com um JSON por projeto (simples de entender e depurar). Migrar para banco (`sqflite` ou `drift`) só se a lista crescer ou precisar de buscas. |
| Preferências simples | `shared_preferences` (último projeto aberto, opacidade padrão). |
| Miniaturas | Gerar uma versão pequena da imagem ao salvar, para a lista de recentes não decodificar imagens grandes. |
| Salvamento | Automático e com *debounce* (ex.: 500 ms depois do último gesto), para não gravar a cada quadro. |
| Versão do formato | Campo `schemaVersion` no JSON, para migrar dados quando o formato mudar. |

### Novos conceitos de Flutter

I/O de arquivos com `dart:io`, serialização JSON (`toJson`/`fromJson`),
`FutureBuilder`/`StreamBuilder`, listas com `ListView.builder`, testes de
unidade da camada de dados.

---

## Fase 4 · Renomeação e busca no histórico 🚧 (aguardando testes no aparelho)

**Entrega:** melhorias sobre a base da Fase 3, sem descartar nada do que já
existia. Detalhes: `docs/05-fase4-renomeacao-e-busca.md`.

### Funcionalidades

- **Renomear só dentro do app:** botão Editar (lápis) à esquerda do botão
  Remover em cada item do histórico. Abre um diálogo; o nome fica salvo no
  `project.json`. O arquivo original na galeria e os arquivos copiados na
  Fase 3 não mudam. Campo vazio ou só com espaços volta ao nome original;
  Cancelar mantém o nome anterior.
- **Barra de pesquisa** no topo da seção "Continuar desenhando": filtra em
  tempo real, sem diferenciar maiúsculas e acentos, com botão de limpar.
- **Prioridade de nomes** (exibição e busca):
  1. nome customizado no app;
  2. nome original do arquivo;
  3. nome padrão "Imagem" (o mesmo fallback que a Fase 3 já usava).

### Decisões técnicas

| Decisão | Motivo |
| --- | --- |
| Campo opcional `customName` no JSON, sem mudar `schemaVersion` | Arquivos da Fase 3 continuam válidos sem migração. |
| `displayName` no modelo | Lista, busca e diálogo de exclusão usam a mesma regra de prioridade. |
| `rename` no repositório relê o JSON do disco | Não sobrescreve ajustes salvos pelo salvamento automático depois de a lista ser lida. |
| Renomear não muda o "último acesso" | Renomear não é continuar desenhando; o item não pula para o topo. |
| Busca como função pura, sem debounce | Filtrar dezenas de itens leva microssegundos; dá para testar sem tela. |
| `TextEditingController` + `FocusNode` na Home, descartados no `dispose` | O texto pesquisado sobrevive às trocas de estado da Home. |

### Novos conceitos de Flutter

`TextEditingController` e `FocusNode` (ciclo de vida), `TextEditingController`
como `ValueListenable`, `showDialog` devolvendo um valor, compatibilidade de
formato de arquivo entre versões.

---

## Fase 5 · Categorias e filtros 🚧

Organizar o histórico por categorias do usuário, em etapas, sem descartar
nada das fases anteriores. Detalhes: `docs/06-fase5-categorias-e-filtros.md`.

### Etapa 5A · Base de categorias, vínculo no Editar e badge 🚧 (aguardando testes no aparelho)

- **Categorias offline** em `categories.json`, no armazenamento interno:
  criar com nome (sem vazio nem duplicado, ignorando maiúsculas e acentos) e
  uma cor de uma paleta fixa de 12; remover com confirmação.
- **Remover categoria é seguro:** os desenhos não são apagados, só ficam sem
  categoria (`clearCategory`). Um id de categoria que não existe mais é
  tratado como "sem categoria" em toda a UI.
- **Botão Editar** (Fase 4) ganhou a escolha de categoria ("Sem categoria" +
  chips coloridos). Nome e categoria são gravados juntos.
- **Badge** com a cor e o nome da categoria no card. Sem categoria, o card
  fica igual ao da Fase 4.

| Decisão | Motivo |
| --- | --- |
| Projeto guarda só o `categoryId` | Excluir/editar a categoria não exige reescrever nome e cor em cada desenho. |
| Um arquivo só para categorias | São poucas e pequenas; mais simples que uma pasta por item. |
| Remove a categoria antes de limpar os vínculos | Se o app morrer no meio, sobra um id órfão, que a UI já trata como "sem categoria". |
| Paleta fixa, sem seletor livre | Leve, fácil de tocar, cores bem distintas. |
| `rename` virou `updateDetails` | Uma única gravação para nome + categoria. |

### Etapa 5B · Faixa de categorias, seletor e filtro combinado 🚧 (aguardando testes no aparelho)

- **Faixa abaixo da busca:** etiqueta neutra "Sem categoria" (marca/desmarca
  o filtro), etiquetas coloridas das categorias marcadas (com "×") e, ao
  lado, o botão "Categorias".
- **Seletor em tela cheia:** pesquisar categorias, marcar uma ou várias
  (incluindo "Sem categoria"), criar (inclusive "Criar categoria “x”" a
  partir da pesquisa) e remover, com o mesmo código seguro da 5A.
- **Filtro combinado:** categorias primeiro, depois a busca do topo, que
  passa a procurar só dentro das categorias marcadas, com a mesma
  prioridade de nomes da Fase 4.
- **Sem nada marcado, todos os desenhos aparecem** (o comportamento das
  Fases 3 e 4 continua igual).

| Decisão | Motivo |
| --- | --- |
| `ValueNotifier<CategoryFilter>` na Home | Marcar/desmarcar reconstrói só a faixa e a lista. |
| `CategoryFilter` imutável com `==` | O notifier só avisa quando o filtro muda de verdade. |
| Seletor em tela cheia, e não `BottomSheet` | Teclado e SnackBars funcionam bem também no celular. |
| Marcações como rascunho até "Aplicar" | Dá para explorar e desistir no "X" sem mexer no histórico. |
| `retainOnly` ao recarregar | Categoria removida sai do filtro e não esconde desenhos. |

### Próximas etapas

A definir nos próximos pedidos.

---

## Fase 6 · Redesign visual 🚧

Nova identidade visual, em etapas, sem mudar nenhuma funcionalidade.
Detalhes: `docs/07-fase6-tema-e-layout.md`.

### Etapa 6A · Tema claro/escuro, detecção inicial e botão de sol/lua 🚧 (aguardando testes no aparelho)

- **Paleta própria** inspirada na estética de apps de design (Canva):
  violeta + turquesa, fundo limpo, cantos arredondados, bordas finas no
  lugar de sombras. Modos claro e escuro, com contraste testado.
- **Primeira execução:** segue o tema do sistema.
- **Escolha manual** salva em `preferences.json` (offline, sem permissão);
  nas próximas aberturas vale a escolha, até um novo toque.
- **Botão único de sol/lua** no canto superior direito da Home, com
  animação leve (transições na pintura, sem rebuild).

| Decisão | Motivo |
| --- | --- |
| Arquivo JSON, sem `shared_preferences` | Um valor só; mesmas proteções do resto do app, sem dependência nova. |
| Ler a preferência antes do `runApp` | O app abre no tema certo, sem piscar. |
| `ThemeData` criados uma vez | Trocar o tema não recalcula estilos. |
| Botão segue o modo escolhido, e não o `Theme` | Animação imediata; o `Theme` só muda de brilho no meio da transição. |
| Mesa de Luz e controles do desenho fora do tema | Fazem parte da função de desenhar, não da aparência. |

### Etapa 6B · Home sem header e marca desenhada 🚧 (aguardando testes no aparelho)

- **Header (`AppBar`) removido** da Home: sem título `desenha_ai` e sem o
  ícone de etiqueta. Tudo abaixo da busca continua igual.
- **Sol/lua flutuando** no canto superior direito (`Stack` + `SafeArea`),
  em todos os estados da Home.
- **Sem imagem:** "Escolher imagem" e "Categorias" (com ícone de etiqueta)
  lado a lado, no mesmo estilo.
- **Marca "Desenha A.I"** em letras desenhadas (`CustomPainter`, sem fonte
  nem imagem): no centro da tela inicial e no topo da listagem.
- Ícones da barra de status ajustados ao tema (antes era papel da AppBar).

### Etapa 6C · Ajustes finos de espaçamento e tamanho 🚧 (aguardando testes no aparelho)

- Título da listagem (marca) **30 dp mais baixo** (topo em 42 dp) e com
  margem lateral maior (72 dp).
- Botão de sol/lua **maior** (56 dp de área de toque, ícone de 30 dp) e
  **20 dp mais baixo** (topo em 28 dp).
- O botão virou um `Positioned` no canto: descer ou aumentar o botão não
  mexe no layout central da tela inicial.

### Etapa 6F · Seta + título centralizado e sol/lua em todas as telas 🚧 (aguardando testes no aparelho)

Detalhes: `docs/07-fase6-tema-e-layout.md`, seção 9. `PageHeader` sem
faixa (seta de voltar no lugar do "X", título centralizado bem abaixo do
topo); sol/lua no canto superior direito de todas as telas, inclusive a de
desenho; "Limpar" e "Adicionar categoria" à direita, abaixo da pesquisa do
seletor; na listagem da Home, a marca fica 30 dp abaixo do sol/lua.

### Etapa 6E · Sem `AppBar` em nenhuma tela e sol/lua maior 🚧 (aguardando testes no aparelho)

Detalhes: `docs/07-fase6-tema-e-layout.md`, seção 8. Categorias e Filtrar por
categoria passam a usar o `PageHeader` (`lib/core/widgets/page_header.dart`)
no corpo; botão sol/lua em 64 dp (ícone de 36 dp).

### Etapa 6D · Editar categorias e paleta de 30 cores 🚧 (aguardando testes no aparelho)

Detalhes: `docs/06-fase5-categorias-e-filtros.md`, seção 10.

- **Lápis "Editar categoria"** à esquerda da lixeira, na tela "Categorias" e
  no seletor da faixa: muda o nome (sem vazio nem duplicado de outra
  categoria) e a cor, gravando em `categories.json`.
- Os cards vinculados mostram o nome e a cor novos sem regravar nenhum
  desenho, porque eles guardam só o id da categoria.
- **Paleta de 30 cores** (as 12 originais preservadas + 18 novas), com
  contraste e distinção garantidos por teste, em grade compacta.

### Próximas etapas

A definir nos próximos pedidos.

---

## Fora do escopo (por enquanto)

- Qualquer recurso que precise de internet (nuvem, contas, compartilhamento
  online).
- iOS, web e desktop. O código Flutter é portável, mas só testaremos Android.
- Edição da imagem (filtros, recorte).
- ❌ Salvar o progresso do traçado: **cancelado** (ver Fase 3).

---

## Seleção múltipla de imagens 🚧 (aguardando testes no aparelho)

Detalhes: `docs/08-selecao-multipla-de-imagens.md`.

- "Escolher imagem" (tela inicial) e "Novo desenho" (listagem) abrem a
  galeria permitindo marcar **uma ou várias** imagens
  (`FilePicker.pickFiles`).
- Cada imagem é copiada para o armazenamento privado e vira um projeto,
  **uma por vez**, para a memória guardar uma foto de cada vez (Galaxy
  Tab A).
- Depois de confirmar, o app mostra a **listagem**, sem abrir a tela de
  desenho, tanto para uma quanto para várias imagens. A busca e o filtro de
  categoria são limpos para as novas aparecerem.
- Cancelar não é erro; uma imagem ruim não impede as outras; se todas
  falharem, tela de erro com "Tentar novamente".

---

## Etapa final · Gerenciador manual de status 🚧 (aguardando testes no aparelho)

Detalhes: `docs/09-status-dos-desenhos.md`.

- 4 status: **Não iniciado** (padrão de toda imagem nova), **Em andamento**,
  **Concluído** e **Arquivado**, com ícone e cor próprios, em tons
  diferentes para o modo claro e o escuro (contraste ≥ 4,5:1 testado).
- Controle 100% manual: só o botão de status do card muda o status. Abrir,
  desenhar e fechar a tela de desenho não mexem nele.
- Gravado no `project.json` (`"status"`). Projetos antigos, sem o campo,
  abrem como "Não iniciado"; o `schemaVersion` continua 1.
- Card: botão de status (bandeira) à esquerda do Editar, diálogo com os 4
  status (um toque salva) e badge de status à esquerda da categoria.
- Filtro de status com "Todos" + os 4 chips direto na tela, entre a busca
  e as categorias, sob o título "Status dos desenhos"; a faixa de
  categorias ganhou o título "Categorias". Abre com "Todos" marcado (todos
  os desenhos à vista); marcar um status desmarca "Todos", desmarcar o
  último o marca de novo; combina com a busca e as categorias.
