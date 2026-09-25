import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sync_flusher.dart';
import '../l10n/app_localizations.dart';

/// How many sales are still waiting to reach the server.
///
/// Renders NOTHING while the queue is empty, which is almost always: the till app bar is already
/// within ~14dp of overflowing at 407dp, and a permanent "all synced" tick would buy nothing. It
/// appears only when there is something to worry about — a queue that stops draining is otherwise
/// invisible until somebody reconciles the day and finds sales missing.
class SyncPendingBadge extends ConsumerWidget {
  const SyncPendingBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final flusher = ref.watch(syncFlusherProvider);
    return ValueListenableBuilder<int>(
      valueListenable: flusher.pending,
      builder: (context, count, _) {
        if (count <= 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Tooltip(
            message: t.syncPending(count),
            child: InkWell(
              // Tapping asks for a drain now rather than waiting for the next trigger.
              onTap: flusher.flush,
              borderRadius: BorderRadius.circular(100),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_upload_outlined, size: 18, color: Colors.white),
                const SizedBox(width: 3),
                Text('$count',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ),
          ),
        );
      },
    );
  }
}
