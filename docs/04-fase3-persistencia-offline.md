# 04 · Fase 3: histórico de projetos offline

Esta fase faz o app **lembrar** de cada desenho: a imagem, a posição, o zoom,
a rotação, a opacidade, o espelho e o fundo. Tudo fica no armazenamento
interno do aparelho, sem internet.

Arquivos da fase:

```
lib/features/
├─ drawing/
│  ├─ models/drawing_settings.dart    ← o que é salvo da tela de desenho
│  ├─ models/overlay_transform.dart   ← ganhou toJson/fromJson
│  └─ services/debounced_saver.dart   ← salvamento automático com debounce
└─ projects/
   ├─ models/drawing_project.dart          ← um item do histórico
   ├─ services/project_repository.dart     ← contrato (interface)
   ├─ services/file_project_repository.dart← implementação em arquivos
   ├─ services/thumbnail_generator.dart    ← miniatura de até 256 px
   └─ widgets/project_history_tile.dart    ← item da lista na Home
```

O fluxo:

```
Home ── escolher imagem ──► repository.create()  (copia + miniatura + JSON)
  │                               │
  │                               ▼
  │                         DrawingScreen ── mudanças ──► DebouncedSaver ──► repository.save()
  │                               │
  └── tocar no histórico ──► repository.readImage() + save() (último acesso)
  └── excluir ─────────────► repository.delete()  (apaga a pasta inteira)
```

---

## 1. Onde guardar: Scoped Storage vs. armazenamento privado

### 1.1 Os dois mundos do Android

| | Armazenamento **compartilhado** | Armazenamento **privado do app** |
| --- | --- | --- |
| Exemplos | Galeria (`DCIM/`, `Pictures/`), `Download/` | `/data/user/0/<pacote>/...` |
| Quem vê | o usuário e outros apps | **só este app** |
| Permissão | regras do *Scoped Storage* (Android 10+): `MediaStore`, seletor do sistema, `READ_MEDIA_IMAGES`... | **nenhuma** |
| Ao desinstalar | os arquivos ficam | **é apagado junto** |
| Pode sumir sem o app saber? | sim: o usuário apaga ou move a foto | não (exceto se o usuário "limpar dados") |

O **Scoped Storage** (Android 10+) é o conjunto de regras que limita o
acesso dos apps à área compartilhada. Um app não pode mais ler qualquer
arquivo do cartão: ele recebe só o que o usuário escolheu num seletor
(como fizemos na Fase 1) ou o que o próprio app criou. Mesmo com acesso
concedido, o arquivo continua sendo **do usuário**, e ele pode apagá-lo ou
movê-lo a qualquer momento.

### 1.2 Por que copiamos a imagem

Se o histórico guardasse só "o endereço da foto na galeria":

- a foto poderia ser apagada ou movida, e o projeto quebraria;
- o endereço `content://` que o seletor devolve pode perder a permissão de
  leitura depois que o app é fechado.

Por isso, ao criar o projeto, **copiamos os bytes** para a pasta privada do
app. A partir daí o projeto é autossuficiente.

### 1.3 `getApplicationDocumentsDirectory()`

O pacote `path_provider` traduz para cada plataforma onde ficam as pastas
"padrão" do app:

| Função | No Android | Uso |
| --- | --- | --- |
| `getApplicationDocumentsDirectory()` | `/data/user/0/<pacote>/app_flutter` | **dados do usuário que devem durar** (nosso caso) |
| `getApplicationSupportDirectory()` | `/data/user/0/<pacote>/files` | arquivos internos do app |
| `getTemporaryDirectory()` | `/data/user/0/<pacote>/cache` | cache: **o Android pode apagar** quando faltar espaço |

Usamos a pasta de documentos, e não o cache, porque um desenho em
andamento não pode sumir sozinho. Ela é resolvida **uma vez** no `main.dart`,
antes do `runApp`, para o repositório conhecer os caminhos de forma
síncrona (o que permite usar `Image.file` direto na lista).

### 1.4 Uma pasta por projeto

```
app_flutter/projects/
  lq3k9x2a7f/
    project.json   ← metadados + ajustes
    image.jpg      ← cópia da imagem escolhida
    thumb.png      ← miniatura
```

- **Excluir = apagar a pasta.** Registro, imagem e miniatura somem juntos,
  sem sobrar arquivo órfão ocupando espaço.
- **Falha isolada:** um `project.json` corrompido afeta só aquele projeto; a
  lista ignora o item e mostra os outros.
- **Por que não um banco de dados?** Para dezenas de projetos, ler alguns
  JSONs de 1 KB é instantâneo e fácil de depurar. `sqflite`/`drift` só
  compensariam com milhares de itens ou buscas complexas.
- **Segurança:** o `id` vira nome de pasta, então só aceitamos `[a-z0-9]`. Os
  nomes de arquivo lidos do JSON também são validados. Assim, um JSON
  adulterado não consegue apontar para fora da pasta do projeto
  (`../../outra_coisa`).

### 1.5 Gravação atômica

```dart
// file_project_repository.dart
await temp.writeAsString(jsonEncode(project.toJson()), flush: true);
await temp.rename(projectJsonPath); // troca o arquivo de uma vez
```

Se o app morrer **no meio** de uma gravação direta, o JSON fica pela metade
e o projeto se perde. Gravando num `.tmp` e depois **renomeando** (operação
atômica no mesmo sistema de arquivos), o arquivo final é sempre o antigo
inteiro ou o novo inteiro.

Todas as escritas também passam por uma **fila** (`_serialized`), uma de
cada vez, para que um salvamento e uma exclusão nunca se intercalem.

---

## 2. Serialização em JSON

### 2.1 `toJson` / `fromJson` escritos à mão

```dart
// overlay_transform.dart
Map<String, Object?> toJson() => {
  'dx': offset.dx, 'dy': offset.dy,
  'scale': scale, 'rotation': rotation, 'flipped': flipped,
};
```

Um `project.json` real:

```json
{
  "schemaVersion": 1,
  "id": "lq3k9x2a7f",
  "originalName": "gato.jpg",
  "imageFile": "image.jpg",
  "thumbnailFile": "thumb.png",
  "createdAt": "2025-03-05T17:02:11.123456Z",
  "updatedAt": "2025-03-05T17:40:52.654321Z",
  "settings": {
    "transform": {"dx": 25.0, "dy": -10.5, "scale": 1.8, "rotation": 0.31, "flipped": true},
    "opacity": 0.65,
    "mode": "lightTable",
    "lightTableColor": "white"
  }
}
```

Escrevemos a serialização à mão, em vez de usar geradores de código
(`json_serializable`, `freezed`), porque são poucos campos e assim fica
visível exatamente o que acontece. Para modelos grandes, os geradores
compensam.

### 2.2 Como serializar uma matriz

A tela usa uma `Matrix4` (16 números) para posicionar a imagem. **Não
salvamos a matriz**: salvamos os componentes que a geram (`dx`, `dy`,
`scale`, `rotation`, `flipped`) e a recalculamos com `toMatrix()` ao abrir.

- **Sem perda:** a matriz é sempre derivada dos componentes, então a imagem
  volta exatamente igual. O teste "a matriz reconstruída é idêntica à
  original" (`test/projects/serialization_test.dart`) garante isso.
- **Validável:** ao ler, dá para limitar o zoom e normalizar o ângulo. Uma
  matriz corrompida poderia distorcer a imagem de forma que nenhum gesto
  desfaz.
- **Reversível:** extrair zoom e rotação de volta de uma matriz
  (decomposição) é sujeito a erro de arredondamento e fica ambíguo com o
  espelhamento.
- **Legível:** dá para abrir o arquivo e entender o que está salvo.

### 2.3 Detalhes que evitam bugs

- **Enums por nome** (`"lightTable"`), não por índice (`1`): se a ordem do
  enum mudar, arquivos antigos continuam corretos. Nome desconhecido →
  valor padrão (`enumByName`).
- **Números:** `jsonDecode("2")` devolve `int` e `jsonDecode("2.5")`
  devolve `double`. Por isso lemos como `num` e convertemos com
  `toDouble()`.
- **Datas** em ISO 8601 **UTC** (`...Z`): texto ordenável e sem ambiguidade
  de fuso. Convertemos para o horário local só ao exibir.
- **`schemaVersion`:** se o formato mudar numa versão futura, o app sabe qual
  formato está lendo e pode migrar. Um arquivo de versão **mais nova** é
  recusado em vez de lido errado.
- **Tolerância em camadas:** sem `id`, imagem ou datas, o projeto não pode
  ser aberto (`FormatException`, e a lista o ignora). Já os **ajustes**
  inválidos voltam ao padrão: é melhor abrir com opacidade 50% do que perder
  o desenho.

---

## 3. Salvamento automático com debounce

### 3.1 O problema

Durante um gesto, a transformação muda ~60 vezes por segundo. Gravar em
disco a cada mudança:

- **trava a UI** no Galaxy Tab A: cada gravação codifica JSON, grava e força
  `flush` na memória flash;
- **desgasta** a memória flash com milhares de gravações inúteis;
- **pode gravar fora de ordem** se as escritas se sobrepuserem.

### 3.2 A solução: `DebouncedSaver`

```
mudanças:   x x x x x x x x                x
gravações:                   ·····[grava]    ·····[grava]
                             600 ms          600 ms
```

Cada mudança **reinicia** um timer de 600 ms. Só gravamos quando o usuário
fica 600 ms sem mexer. Um gesto inteiro (ou uma arrastada do slider) vira
**uma** gravação.

```dart
// drawing_screen.dart
_autosaver = DebouncedSaver(
  delay: DrawingScreen.autosaveDelay,       // 600 ms
  snapshot: _currentSettings,               // lê os notifiers (síncrono)
  write: _persist,                          // repository.save (assíncrono)
);
Listenable.merge([_transform, _opacity, _mode, _lightTableColor])
  .addListener(_autosaver.schedule);
```

Detalhes importantes:

- **Ouvimos os mesmos `ValueNotifier`s da Fase 2.** Salvar não adiciona
  nenhum `setState` nem rebuild: o `schedule()` só reinicia um `Timer`.
- **O snapshot é síncrono**, tirado no momento em que a gravação dispara.
  Assim o valor salvo é sempre o último que o usuário viu, mesmo que a tela
  feche logo depois.
- **Fila:** uma gravação só começa quando a anterior termina.
- **`flush()` imediato** em dois momentos:
  - no `dispose()` da tela (voltou para a Home com uma mudança pendente);
  - no estado `hidden` (app minimizado). Em segundo plano o Android pode
    matar o processo **sem aviso**, o que é comum no Tab A, com pouca RAM.
    Não dá para contar com o timer.
- **A trava não é salva:** ao reabrir, a pessoa precisa conseguir mexer na
  tela sem lembrar que a deixou travada.
- **Abrir conta como acesso:** a Home chama `save()` ao abrir um projeto, o
  que atualiza `updatedAt` e o coloca no topo de "Continuar desenhando".

---

## 4. Miniaturas e memória no Galaxy Tab A

### 4.1 Quanto custa uma imagem na RAM

Uma imagem decodificada ocupa **largura × altura × 4 bytes**, não importa o
tamanho do arquivo JPEG:

| Imagem | Na RAM |
| --- | --- |
| Foto de 12 MP (4000×3000) | ~48 MB |
| Foto de 50 MP (8160×6120) | ~200 MB |
| Miniatura de 256×192 | ~0,2 MB |
| A mesma miniatura exibida a 64 dp em tela 2x (128×96) | ~0,05 MB |

Uma lista com 10 fotos originais "reduzidas na tela" decodificaria
**centenas de MB**. O Tab A fecharia o app.

### 4.2 O que fazemos

1. **Miniatura gerada uma vez, na criação** (`UiThumbnailGenerator`):
   - lê só o **cabeçalho** da imagem para saber largura e altura;
   - pede ao decodificador o tamanho-alvo (maior lado = 256 px). Em JPEG ele
     pode decodificar direto em 1/2, 1/4 ou 1/8 do tamanho, sem montar a
     foto inteira primeiro;
   - grava um PNG de poucas dezenas de KB;
   - chama `dispose()` em `ui.Image`, `Codec`, `ImageDescriptor` e
     `ImmutableBuffer`. Esses objetos seguram memória **nativa**, que o
     coletor de lixo do Dart não enxerga.
2. **`Image.file(..., cacheWidth: 64 × densidade)`** na lista: mesmo a
   miniatura de 256 px é decodificada só no tamanho em que aparece. O cache
   de imagens do Flutter guarda essa versão pequena.
3. **`SliverList.builder`** (lista preguiçosa): só os itens visíveis (mais
   uma pequena margem) são construídos e decodificados. Com 50 projetos, só
   uns 8 existem na memória de cada vez.
4. **`Image.file` em vez de ler os bytes no Dart:** o Flutter lê e
   decodifica o arquivo fora da thread da UI, e a rolagem continua suave.
5. **`ValueKey(project.id)`** em cada item: ao excluir um projeto, os outros
   itens não "herdam" a miniatura errada durante a reconstrução.
6. **Sem miniatura?** (formato que o decodificador não entende) O projeto é
   criado mesmo assim e a lista mostra um ícone no lugar.

A imagem **grande** só é lida do disco quando o usuário abre um projeto. Lá
ela é decodificada no tamanho da tela (Fase 2, `ReferenceOverlay`).

---

## 5. O que mudou na Home

- A seção **"Continuar desenhando"** substituiu a prévia da Fase 1. A imagem
  escolhida vira um projeto do histórico, que mostra miniatura, data/hora
  do último acesso e modo usado ("Câmera AR" / "Mesa de luz").
- **Escolher imagem** → a imagem é copiada (tela "Preparando desenho…") e a
  tela de desenho abre direto.
- **Tocar num item** → reabre a tela de desenho com tudo como estava.
- **Lixeira** → diálogo de confirmação → apaga a pasta do projeto. O diálogo
  avisa que a foto original da galeria **não** é afetada.
- **Sem projetos** → a tela de boas-vindas da Fase 1 continua aparecendo.

---

## 6. Testes

| Arquivo | O que cobre |
| --- | --- |
| `test/projects/file_project_repository_test.dart` | repositório **real** numa pasta temporária: cópia da imagem, miniatura, ida e volta dos ajustes, ordem por último acesso, JSON corrompido, fila de gravações, exclusão da pasta, não recriar projeto excluído |
| `test/projects/serialization_test.dart` | JSON sem perda (inclusive a matriz), valores inválidos, `schemaVersion`, nomes de arquivo maliciosos |
| `test/projects/thumbnail_generator_test.dart` | miniatura real: proporção, sem ampliar, erro com bytes inválidos |
| `test/drawing/debounced_saver_test.dart` | uma gravação por rajada, `flush`, `dispose`, fila e erros |
| `test/drawing/drawing_screen_test.dart` | restaurar ajustes, salvar com debounce, salvar ao sair e ao minimizar |
| `test/widget_test.dart` | Home: criar projeto, listar em ordem, retomar exatamente, excluir com confirmação |

## 7. Como testar no aparelho

1. Modo avião ligado. Escolha uma imagem, ajuste posição, zoom, rotação,
   opacidade e espelho, e mude para Mesa de Luz preta.
2. Volte para a Home: o desenho aparece em "Continuar desenhando", com o
   modo "Mesa de luz".
3. Feche o app pela lista de apps recentes e abra de novo. Toque no item:
   tudo deve estar exatamente como você deixou.
4. Ajuste algo e, **sem esperar**, aperte o botão Home do Android. Mate o app
   pelos recentes e reabra: o último ajuste deve ter sido salvo.
5. Apague a foto original da galeria e reabra o projeto: ele deve continuar
   funcionando.
6. Exclua um projeto. Em Configurações › Apps › desenha_ai › Armazenamento,
   o espaço usado deve diminuir.
