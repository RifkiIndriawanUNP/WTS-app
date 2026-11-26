import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wts/core/utils/guard.dart';
import 'package:wts/features/market/domain/market_transaction.dart';
import 'package:wts/features/market/domain/product.dart';
import 'package:wts/features/market/presentation/market_providers.dart';
import 'package:wts/features/market/presentation/market_style.dart';
import 'package:wts/shared/widgets/common_widgets.dart';
import 'package:wts/shared/widgets/dialogs.dart';

/// Halaman "Transaksi Saya" (ikon tas di beranda Market).
class MyTransactionsPage extends ConsumerStatefulWidget {
  const MyTransactionsPage({super.key});

  @override
  ConsumerState<MyTransactionsPage> createState() => _MyTransactionsPageState();
}

class _MyTransactionsPageState extends ConsumerState<MyTransactionsPage> {
  int _tab = 0;

  static const _phases = [
    TransactionPhase.ongoing,
    TransactionPhase.done,
    TransactionPhase.cancelled,
  ];
  static const _labels = ['Berlangsung', 'Selesai', 'Dibatalkan'];

  Future<void> _cancel(MarketTransaction t) async {
    final ok = await confirmDialog(
      context,
      title: 'Batalkan kesepakatan?',
      message: 'Tawaran untuk "${t.title}" akan dibatalkan.',
      confirmLabel: 'Batalkan',
      destructive: true,
    );
    if (ok && mounted) ref.read(marketTransactionsProvider.notifier).cancel(t.id);
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(marketTransactionsProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;
    int count(TransactionPhase p) => all.where((t) => t.phase == p).length;
    final list = all.where((t) => t.phase == _phases[_tab]).toList();

    return Scaffold(
      backgroundColor: MC.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            MarketTitleBar(title: 'Transaksi Saya', onBack: () => context.pop()),
            const SizedBox(height: 56),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: softShadow(.05, 10),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < _phases.length; i++)
                    Expanded(
                      child: _TabItem(
                        label: _labels[i],
                        count: count(_phases[i]),
                        selected: _tab == i,
                        onTap: () => setState(() => _tab = i),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Belum ada transaksi',
                      message: 'Transaksi di kategori ini akan muncul di sini.',
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottom),
                      children: [
                        for (final t in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _TransactionCard(
                              tx: t,
                              onChat: () => showSnack(
                                context,
                                'Membuka chat dengan ${t.firstName} (simulasi).',
                              ),
                              onUpdate: () => ref
                                  .read(marketTransactionsProvider.notifier)
                                  .advance(t.id),
                              onOffer: () {
                                final id = t.productId;
                                if (id != null) {
                                  context.push('/market/product/$id');
                                }
                              },
                              onCancel: () => _cancel(t),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: mt(
                      size: 14,
                      weight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? MC.ink : MC.slateLight,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFDDE8FC)
                          : const Color(0xFFEEF1F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: mt(
                        size: 12,
                        weight: FontWeight.w700,
                        color: selected ? MC.blue : MC.slate,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Positioned(
                left: 6,
                right: 6,
                bottom: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: MC.blue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.tx,
    required this.onChat,
    required this.onUpdate,
    required this.onOffer,
    required this.onCancel,
  });

  final MarketTransaction tx;
  final VoidCallback onChat;
  final VoidCallback onUpdate;
  final VoidCallback onOffer;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final awaiting = tx.awaitingReply;
    final ongoing = tx.phase == TransactionPhase.ongoing;

    final Color chipBg;
    final Color chipFg;
    switch (tx.phase) {
      case TransactionPhase.done:
        chipBg = MC.greenBg;
        chipFg = MC.green;
      case TransactionPhase.cancelled:
        chipBg = const Color(0xFFFEE2E2);
        chipFg = MC.red;
      case TransactionPhase.ongoing:
        chipBg = awaiting ? const Color(0xFFFDEFD8) : const Color(0xFFE3EDFC);
        chipFg = awaiting ? const Color(0xFFD97706) : MC.blue;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEF0F4)),
        boxShadow: softShadow(.05, 14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: const SizedBox(
                  width: 64,
                  height: 64,
                  child: PeachPlaceholder(circle: 30, iconSize: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: mt(
                        size: 16,
                        weight: FontWeight.w800,
                        color: MC.ink,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tx.roleLabel} · ${tx.counterpart}',
                      style: mt(
                        size: 13,
                        weight: FontWeight.w500,
                        color: MC.slate,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            rp(tx.price),
                            style: mt(
                              size: 17,
                              weight: FontWeight.w800,
                              color: MC.orange,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: chipBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            tx.badge,
                            style: mt(
                              size: 12,
                              weight: FontWeight.w700,
                              color: chipFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: MC.line.withValues(alpha: .7)),
          const SizedBox(height: 14),
          _Stepper(
            stage: tx.stage,
            amber: awaiting,
            cancelled: tx.phase == TransactionPhase.cancelled,
          ),
          const SizedBox(height: 14),
          _InfoBar(tx: tx),
          if (ongoing) ...[
            const SizedBox(height: 12),
            if (awaiting)
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _SoftButton(
                      label: 'Lihat Tawaran',
                      background: const Color(0xFFEFF6FF),
                      color: MC.blue,
                      onTap: onOffer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SoftButton(
                      label: 'Batalkan',
                      background: Colors.white,
                      color: MC.red,
                      border: const Color(0xFFF5B5B5),
                      onTap: onCancel,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _SoftButton(
                      label: 'Chat ${tx.firstName}',
                      background: const Color(0xFFF1F5F9),
                      color: MC.ink,
                      onTap: onChat,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SoftButton(
                      label: 'Update Status COD',
                      background: const Color(0xFF2563EB),
                      color: Colors.white,
                      onTap: onUpdate,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({
    required this.label,
    required this.background,
    required this.color,
    required this.onTap,
    this.border,
  });

  final String label;
  final Color background;
  final Color color;
  final Color? border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: border == null ? BorderSide.none : BorderSide(color: border!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mt(size: 13.5, weight: FontWeight.w700, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBar extends StatelessWidget {
  const _InfoBar({required this.tx});

  final MarketTransaction tx;

  @override
  Widget build(BuildContext context) {
    final deadline = tx.infoKind == TransactionInfoKind.deadline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF3FE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (deadline)
            const Icon(Icons.schedule_rounded, size: 20, color: MC.blue)
          else
            const Icon(Icons.calendar_today_outlined, size: 19, color: MC.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tx.infoText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mt(size: 13.5, weight: FontWeight.w600, color: MC.text),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20, color: MC.slate),
        ],
      ),
    );
  }
}

/// Stepper 4 tahap: Sepakat -> Berangkat -> Sampai -> Terjual.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.stage,
    required this.amber,
    required this.cancelled,
  });

  final int stage;
  final bool amber;
  final bool cancelled;

  static const _amber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final active = amber ? _amber : MC.blue;
    return Column(
      children: [
        SizedBox(
          height: 24,
          child: Row(
            children: [
              for (var i = 0; i < kTransactionStages.length; i++) ...[
                _node(i, active),
                if (i < kTransactionStages.length - 1)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i < stage && !cancelled
                            ? MC.blue
                            : const Color(0xFFE2E8F5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < kTransactionStages.length; i++)
              Text(
                kTransactionStages[i],
                style: mt(
                  size: 11,
                  weight: i == stage && !cancelled
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: cancelled
                      ? MC.slateLight
                      : (i <= stage ? active : MC.slateLight),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _node(int i, Color active) {
    const size = 24.0;
    if (cancelled) {
      return _ring(size, const Color(0xFFCBD5E1), null);
    }
    if (i < stage) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: MC.blue, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
      );
    }
    if (i == stage) {
      final last = i == kTransactionStages.length - 1;
      if (last) {
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: MC.blue,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
        );
      }
      return _ring(
        size,
        active,
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: active, shape: BoxShape.circle),
        ),
      );
    }
    return _ring(
      size,
      MC.blue,
      i == kTransactionStages.length - 1
          ? const Icon(Icons.shopping_bag_outlined, size: 12, color: MC.blue)
          : null,
    );
  }

  Widget _ring(double size, Color color, Widget? inner) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2.4),
      ),
      child: inner,
    );
  }
}