---
inclusion: always
---

# Boas práticas Flutter do desenha_ai

Regras permanentes para todo código deste projeto. O app roda 100% offline em
Android, com foco no **Samsung Galaxy Tab A** (pouca RAM, GPU modesta) e no
**RedMagic Pro 11**. O projeto também é material de estudo: o código precisa
ser legível por quem está aprendendo Flutter.

## 1. Organização de pastas

- Organize por funcionalidade em `lib/features/<feature>/`. Dentro de cada
  feature, separe por responsabilidade:
  - `models/`: classes de dados imutáveis, sem dependência de Flutter UI
    quando possível (fáceis de testar).
  - `services/`: acesso a plugins, hardware, arquivos (câmera, seletor de
    arquivos, storage). A UI depende de uma **interface**, não do plugin.
  - `widgets/`: peças de UI reutilizáveis e pequenas.
  - `screens/`: telas que montam widgets e coordenam o estado.
  - A feature `image_selection` (Fase 1) usa `data/` + `presentation/`, que
    são equivalentes a `services/` + `screens/widgets/`. Não misture os dois
    estilos dentro da mesma feature.
- Código compartilhado entre features vai em `lib/core/` (só quando houver
  um segundo uso real).
- **Evite telas gigantes**: se um arquivo de tela passar de ~300 linhas ou um
  `build` passar de ~80 linhas, extraia widgets. Prefira classes de widget
  (`class _Toolbar extends StatelessWidget`) a métodos `Widget _buildX()`,
  porque classes podem ser `const` e reconstruídas isoladamente.
- Injete dependências (serviços) pelo construtor, para que os testes usem
  implementações falsas.

## 2. Ciclo de vida e memória (crítico no Galaxy Tab A)

- Todo recurso criado num `State` precisa ser liberado no `dispose()` do
  mesmo `State`: `CameraController`, `AnimationController`,
  `TextEditingController`, `ScrollController`, `ValueNotifier`,
  `StreamSubscription`, `Timer`, observers (`WidgetsBinding.removeObserver`)
  e listeners (`removeListener`).
- Quem cria, descarta. Não descarte objetos recebidos por parâmetro.
- A câmera deve ser **liberada** quando o app sai da tela
  (`AppLifecycleState.hidden`/`paused`) e **reaberta** ao voltar
  (`resumed`). Nunca deixe a câmera ligada em segundo plano.
- O "tela sempre acesa" (`ScreenWakeLock`) só fica ligado enquanto a tela
  que precisa dele estiver visível: ligue no `initState`/`resumed` e desligue
  no `dispose`/`hidden`. A flag vale para a janela do app inteiro.
- Depois de qualquer `await` dentro de um `State`, confira `mounted` antes de
  usar `setState` ou `context`.
- Operações assíncronas que podem se sobrepor (ex.: iniciar/parar câmera
  rapidamente) precisam de proteção contra corrida (contador de geração ou
  flag), descartando resultados obsoletos.
- Imagens: decodifique no tamanho necessário (`ResizeImage`, `cacheWidth`).
  Nunca decodifique fotos de câmera em resolução total sem necessidade.
- Use a menor configuração de hardware que atende ao caso (ex.:
  `ResolutionPreset.high` em vez de `max`, `enableAudio: false` quando não
  grava áudio).

## 3. Desempenho e rebuilds

- Use `const` em todo construtor e widget que permitir.
- Para valores que mudam com frequência (slider de opacidade, gestos de
  arrastar/zoom/rotação, a 60+ eventos por segundo), use `ValueNotifier` +
  `ValueListenableBuilder` (ou `ListenableBuilder`) envolvendo **só** o widget
  que depende do valor. Não chame `setState` na tela inteira para isso.
- Passe subárvores que não mudam pelo parâmetro `child` do builder, para não
  reconstruí-las.
- Use `RepaintBoundary` para isolar camadas que repintam em ritmos diferentes
  (câmera, imagem de referência, controles).
- Modelos de estado devem ser imutáveis, com `copyWith`, `==` e `hashCode`,
  para que notifiers só avisem quando algo mudou de fato.

## 4. Permissões e privacidade (offline)

- Nunca adicione a permissão `INTERNET` nem dependências que façam chamadas
  de rede.
- Peça só as permissões estritamente necessárias e remova (com
  `tools:node="remove"`) as que plugins declaram e o app não usa.
- Recursos de hardware opcionais (câmera, flash) devem ser declarados com
  `android:required="false"`, e o app deve funcionar sem eles.
- Negar uma permissão nunca pode travar o app: sempre ofereça um caminho
  alternativo.

## 5. Comentários e documentação

- Comente em **português**, explicando o **porquê** das decisões técnicas e de
  UI, não o que a linha já diz.
- Toda classe pública tem um comentário `///` dizendo para que serve.
- Cada fase tem um documento em `docs/` explicando os conceitos novos de
  Flutter que ela introduz.

## 6. Qualidade

- `dart analyze` deve passar sem nenhum problema antes de concluir qualquer
  tarefa.
- Toda lógica pura (modelos, cálculos) tem teste de unidade; todo
  comportamento de tela importante tem widget test com serviços falsos.
- Em widget tests, evite `pumpAndSettle` quando houver animações infinitas
  (indicadores de progresso, decodificação de imagem); avance o tempo com
  `pump(Duration)`.
