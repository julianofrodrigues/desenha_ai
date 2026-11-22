// Testes do debounce. Usamos `testWidgets` só pelo relógio FALSO do
// flutter_test: `tester.pump(duração)` avança o tempo instantaneamente.
import 'dart:async';

import 'package:desenha_ai/features/drawing/services/debounced_saver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int value;
  late List<int> writes;
  late DebouncedSaver<int> saver;

  // O saver é criado DENTRO de cada teste (e não no `setUp`). O `setUp` roda
  // fora do relógio falso do `testWidgets`; Futures criados lá ficam presos à
  // zona real e suas continuações nunca rodam durante o `tester.pump`.
  void createSaver() {
    value = 0;
    writes = [];
    saver = DebouncedSaver(
      delay: const Duration(milliseconds: 500),
      snapshot: () => value,
      write: (v) async => writes.add(v),
    );
  }

  testWidgets('várias mudanças rápidas geram UMA gravação com o último valor',
      (tester) async {
    createSaver();
    for (var i = 1; i <= 10; i++) {
      value = i;
      saver.schedule();
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(writes, isEmpty); // nunca passou 500 ms sem mudança

    await tester.pump(const Duration(milliseconds: 500));
    expect(writes, [10]);
    await saver.dispose();
  });

  testWidgets('flush grava na hora e cancela o timer', (tester) async {
    createSaver();
    value = 7;
    saver.schedule();
    await saver.flush();
    expect(writes, [7]);

    await tester.pump(const Duration(seconds: 1));
    expect(writes, [7]); // o timer não gravou de novo
  });

  testWidgets('flush sem mudança pendente não grava', (tester) async {
    createSaver();
    await saver.flush();
    expect(writes, isEmpty);
  });

  testWidgets('dispose grava o pendente e ignora agendamentos depois',
      (tester) async {
    createSaver();
    value = 3;
    saver.schedule();
    await saver.dispose();
    expect(writes, [3]);

    value = 4;
    saver.schedule();
    await tester.pump(const Duration(seconds: 1));
    expect(writes, [3]);
  });

  testWidgets('gravações não se sobrepõem e erros não travam a fila',
      (tester) async {
    final order = <String>[];
    final firstWrite = Completer<void>();
    // Cada snapshot devolve um número novo (0, depois 1), tirado na hora
    // do `flush`, antes de qualquer gravação começar.
    var nextSnapshot = 0;
    final s = DebouncedSaver<int>(
      delay: const Duration(milliseconds: 10),
      snapshot: () => nextSnapshot++,
      write: (v) async {
        order.add('início $v');
        if (v == 0) {
          await firstWrite.future;
          throw StateError('disco cheio');
        }
        order.add('fim $v');
      },
    );

    s.schedule();
    final first = s.flush(); // começa a 1ª gravação (fica "presa")
    s.schedule();
    final second = s.flush(); // entra na fila

    await tester.pump();
    expect(order, ['início 0']); // a 2ª ainda não começou

    firstWrite.complete();
    await first;
    await second;
    expect(order, ['início 0', 'início 1', 'fim 1']);
  });
}
