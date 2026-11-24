# 08 · Seleção múltipla de imagens e ida para a listagem

**Entrega:** escolher **uma ou várias** imagens de uma vez na galeria do
aparelho. Cada uma vira um projeto no histórico, e o app mostra a
**listagem** em vez de abrir a tela de desenho. O usuário escolhe qual abrir.

Tudo continua 100% offline: o seletor é o do sistema, as cópias vão para o
armazenamento privado do app e nenhuma permissão nova foi pedida.

---

## 1. O fluxo

```
"Escolher imagem" (tela inicial)  ─┐
                                   ├─► galeria do sistema (marca 1 ou várias)
"Novo desenho" (listagem)         ─┘          │
                                              ▼
                       cancelou? ── sim ──► volta como estava, sem erro
                                              │ não
                                              ▼
                 para cada imagem, UMA POR VEZ: ler bytes → copiar → miniatura
                 (tela: "Salvando imagem 2 de 5…")
                                              │
                         ┌────────────────────┴────────────────────┐
                 nenhuma salva                              pelo menos uma salva
                         ▼                                          ▼
          tela de erro + "Tentar novamente"      limpa busca e filtro de categoria,
                                                 recarrega a LISTAGEM e mostra:
                                                 "3 imagens adicionadas ao histórico."
```

O mesmo método da Home (`_addImages`) atende os dois botões. A tela de
desenho só abre quando o usuário toca num card da listagem.

### Por que não abrir o desenho direto

- Com várias imagens não existe uma "certa" para abrir.
- Com uma só, o comportamento fica igual ao de várias. O usuário sempre cai
  no mesmo lugar e vê o que entrou no histórico.

### Por que limpar a busca e o filtro

As imagens novas ainda não têm nome customizado nem categoria. Com uma busca
("gato") ou um filtro ("Animais") ativos, elas ficariam escondidas logo
depois de adicionadas, e pareceria que nada aconteceu.

---

## 2. Memória: uma imagem por vez

O ponto mais sensível no Galaxy Tab A é a RAM. Uma foto de câmera tem uns
5 MB comprimida. Ler 20 de uma vez seriam ~100 MB só em bytes, antes de
qualquer decodificação: o bastante para o Android fechar o app.

Por isso:

| Peça | O que faz |
| --- | --- |
| `LocalImageSource.pickImages()` | Abre a galeria com `FilePicker.pickFiles(type: FileType.image)` e devolve **referências** (`PickedImage.lazy`). Nada é lido aqui. |
| `PickedImage.readBytes()` | Lê os bytes de UMA imagem, só quando chamado. Arquivo vazio vira `FormatException` com o nome. |
| `importPickedImages(...)` | Para cada imagem: lê, chama `ProjectRepository.create` (que copia para o armazenamento privado via `path_provider` e gera a miniatura pequena da Fase 3) e só então passa para a próxima. Os bytes são locais ao laço e podem ser liberados a cada volta. |

No pico, a memória guarda **uma** foto, e não a seleção inteira. A
listagem continua usando só as miniaturas (Fase 3), então 20 imagens novas
não pesam na rolagem.

---

## 3. Erros e cancelamento

| Situação | Resultado |
| --- | --- |
| Cancelou a galeria | Lista vazia: volta para a tela inicial ou para a listagem, sem mensagem. |
| A galeria falhou ao abrir | Tela de erro "Não foi possível abrir a galeria", com "Tentar novamente". |
| Uma imagem vazia, corrompida ou sem espaço | Ela fica de fora e as outras continuam. Mensagem: "2 imagens adicionadas ao histórico. 1 não pôde ser adicionada." |
| Todas falharam | Tela de erro com "Tentar novamente". |
| Toque duplo no botão | Ignorado enquanto a Home está ocupada (`_isBusy`). |

A cópia continua acontecendo ANTES de o projeto aparecer na listagem: se o
arquivo original for apagado da galeria depois, o projeto segue funcionando.

---

## 4. Código

| Arquivo | Papel |
| --- | --- |
| `lib/features/image_selection/data/local_image_source.dart` | `PickedImage` (leitura sob demanda), `LocalImageSource.pickImages()` e a implementação com `file_picker`. |
| `lib/features/image_selection/data/image_importer.dart` | `importPickedImages` (uma por vez, com progresso), `ImportResult` e `importSummary` (texto da mensagem). Lógica pura, sem widgets. |
| `lib/features/image_selection/presentation/home_page.dart` | `_addImages`: estados "Abrindo galeria…", "Salvando imagem N de T…", erro; limpa busca e filtro; recarrega a listagem. |

A importação saiu da Home porque a tela já é grande (o steering pede ~300
linhas) e porque, sem widgets, ela tem teste de unidade direto.

### Conceitos de Dart/Flutter praticados

- **Leitura preguiçosa** com uma função guardada (`Future<Uint8List>
  Function()`), em vez de carregar tudo antes.
- **Parâmetro nomeado privado** (`this._read`): quem chama escreve `read:`,
  e o campo continua privado.
- **Laço sequencial com `await`** para limitar o pico de memória.
- **Registros** (`(int, int)`) nos testes de progresso.

---

## 5. Testes

- `test/image_selection/image_importer_test.dart` (unidade):
  - `PickedImage.lazy` só lê quando `readBytes` é chamado; arquivo vazio vira
    `FormatException`;
  - cria um projeto por imagem, na ordem;
  - **uma por vez**: cada leitura só começa depois de a anterior ser salva;
  - uma falha (arquivo vazio, disco cheio) não para as outras;
  - progresso avisado antes de cada imagem; `allFailed`;
  - textos de `importSummary` (uma, várias, com falhas).
- `test/image_selection/multi_pick_flow_test.dart` (widget):
  - **tela inicial:** várias imagens criam todos os projetos e mostram a
    listagem sem `DrawingScreen`; uma imagem também vai para a listagem;
    "Salvando imagem 2 de 3…"; cancelar não cria nada; se todas falharem,
    erro e "Tentar novamente";
  - **listagem ("Novo desenho"):** as novas entram na lista junto com as
    antigas, sem abrir o desenho; a busca e o filtro de categoria são
    limpos; falha parcial avisa; cancelar mantém tudo; tocar numa imagem
    nova abre o desenho dela.
- `test/widget_test.dart`: os testes da Fase 1/2 que esperavam a tela de
  desenho logo depois de escolher agora esperam a listagem. O teste do
  "tela sempre acesa" abre o desenho pelo card.
- `test/fakes.dart`: `FakeImageSource.many(...)`, contador `calls`, e no
  `FakeProjectRepository` os campos `failCreate` e `createCalls`.

---

## 6. Como testar no aparelho

1. Sem desenhos, toque em "Escolher imagem", marque 3 fotos e confirme: a
   listagem aparece com as 3, e a tela de desenho não abre.
2. Na listagem, toque em "Novo desenho" e escolha mais 2: elas entram no
   topo da lista.
3. Cancele a galeria: nada muda.
4. No Galaxy Tab A, escolha umas 15 fotos grandes da câmera: o app mostra
   "Salvando imagem N de 15…" e não fecha.
5. Com uma busca ou um filtro de categoria ativo, adicione uma imagem: a
   busca e o filtro são limpos e a nova aparece.
6. Em modo avião, repita o passo 1: tudo funciona offline.
