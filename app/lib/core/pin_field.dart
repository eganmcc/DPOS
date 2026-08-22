import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Boxed PIN input (Direction A): N cells, filled cells show a solid primary dot,
/// the active/next cell gets a primary border. Tap anywhere to focus.
class PinField extends StatefulWidget {
  const PinField({
    super.key,
    required this.controller,
    this.length = 6,
    this.onSubmit,
  });

  final TextEditingController controller;
  final int length;
  final VoidCallback? onSubmit;

  @override
  State<PinField> createState() => _PinFieldState();
}

class _PinFieldState extends State<PinField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = widget.controller.text;
    return SizedBox(
      height: 52,
      child: Stack(
        children: [
          IgnorePointer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.length, (i) {
                final filled = i < text.length;
                final active = i == text.length && _focus.hasFocus;
                return Container(
                  width: 44,
                  height: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active ? cs.primary : cs.outline,
                      width: active ? 2 : 1.5,
                    ),
                  ),
                  child: filled
                      ? Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                        )
                      : null,
                );
              }),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: false,
                keyboardType: TextInputType.number,
                maxLength: widget.length,
                obscureText: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                onTap: () => setState(() {}),
                onSubmitted: (_) => widget.onSubmit?.call(),
                decoration: const InputDecoration(counterText: '', border: InputBorder.none),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
