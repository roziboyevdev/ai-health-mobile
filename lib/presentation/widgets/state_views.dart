import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({required this.icon, required this.title, required this.message, super.key});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight.isFinite && constraints.maxHeight < 240;
        return Center(
          child: Padding(
            padding: EdgeInsets.all(compact ? 8 : 28),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: compact ? 32 : 46,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(height: compact ? 8 : 14),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: compact ? 4 : 8),
                    Text(message, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({required this.value, required this.builder, super.key});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: error.toString(),
      ),
    );
  }
}
