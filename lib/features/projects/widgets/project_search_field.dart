import 'package:material_ui/material_ui.dart';

/// Barra de pesquisa do histórico (Fase 4).
///
/// Não guarda estado: recebe o [controller] e o [focusNode] de quem a usa
/// (a Home), que é quem os cria e descarta. Assim o texto pesquisado não se
/// perde quando a Home troca de estado (ex.: volta da tela de desenho).
///
/// Só este campo é reconstruído a cada tecla (para mostrar/esconder o botão
/// de limpar). O resto da Home não é reconstruído.
class ProjectSearchField extends StatelessWidget {
  const ProjectSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  void _clear() {
    controller.clear();
    // Mantém o foco: quem limpou provavelmente vai digitar outra busca.
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    // `TextEditingController` É um `ValueNotifier<TextEditingValue>`, então
    // pode alimentar um `ValueListenableBuilder` diretamente.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        // Tocar fora do campo fecha o teclado, que no celular cobre metade
        // da lista.
        onTapOutside: (_) => focusNode.unfocus(),
        decoration: InputDecoration(
          hintText: 'Pesquisar desenhos',
          prefixIcon: const Icon(Icons.search),
          // O botão só existe quando há o que limpar.
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar pesquisa',
                  onPressed: _clear,
                  icon: const Icon(Icons.clear),
                ),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
