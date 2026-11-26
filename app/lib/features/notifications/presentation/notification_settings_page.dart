import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wts/features/notifications/presentation/notification_providers.dart';
import 'package:wts/features/notifications/presentation/notification_style.dart';

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    _Row toggle(
      NotifSetting key,
      IconData icon,
      NotifTone tone,
      String title,
      String subtitle,
    ) {
      return _Row(
        icon: icon,
        tone: tone,
        title: title,
        subtitle: subtitle,
        value: s[key] ?? false,
        onChanged: (v) => notifier.set(key, v),
      );
    }

    return Scaffold(
      backgroundColor: NotifColors.pageBlue,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 3,
                    shadowColor: const Color(0x261F3FA0),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => context.pop(),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 30,
                          color: NotifColors.navy,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Pengaturan notifikasi',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: NotifColors.navy,
                    ),
                  ),
                ],
              ),
            ),
            const _Section('Umum'),
            _Card(
              rows: [
                toggle(
                  NotifSetting.allow,
                  Icons.notifications_none_rounded,
                  NotifTone.blue,
                  'Izinkan notifikasi',
                  'Push di layar kunci\ndan bilah notifikasi',
                ),
                toggle(
                  NotifSetting.badge,
                  Icons.notifications_none_rounded,
                  NotifTone.gray,
                  'Lencana angka di ikon',
                  'Jumlah notifikasi belum\ndibaca',
                ),
                toggle(
                  NotifSetting.sound,
                  Icons.flash_on_outlined,
                  NotifTone.yellow,
                  'Suara dan getar',
                  'Untuk notifikasi\npenting',
                ),
              ],
            ),
            const _Section('Transaksi'),
            _Card(
              rows: [
                toggle(
                  NotifSetting.offers,
                  Icons.shopping_bag_outlined,
                  NotifTone.blue,
                  'Kesepakatan dan tawaran',
                  'Baru, diubah, disetujui, ditolak',
                ),
                toggle(
                  NotifSetting.codReminder,
                  Icons.schedule_outlined,
                  NotifTone.orange,
                  'Pengingat jadwal COD',
                  'H-1 dan 1 jam sebelum\nbertemu',
                ),
                toggle(
                  NotifSetting.txStatus,
                  Icons.location_on_outlined,
                  NotifTone.green,
                  'Status transaksi',
                  'Berangkat, sampai,\nterjual',
                ),
                const _Row(
                  icon: Icons.event_busy_outlined,
                  tone: NotifTone.red,
                  title: 'Pembatalan dan perubahan jadwal',
                  subtitle: 'Penting, selalu aktif',
                  locked: true,
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Text(
                'Notifikasi penting transaksi tidak bisa dimatikan agar tidak '
                'ada janji yang terlewat.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: NotifColors.body,
                ),
              ),
            ),
            const _Section('Chat'),
            _Card(
              rows: [
                toggle(
                  NotifSetting.newMessage,
                  Icons.mark_chat_unread_outlined,
                  NotifTone.purple,
                  'Pesan baru',
                  'Pribadi dan\nMarket',
                ),
                toggle(
                  NotifSetting.lockPreview,
                  Icons.visibility_outlined,
                  NotifTone.blue,
                  'Pratinjau pesan di layar kunci',
                  'Tampilkan isi pesan',
                ),
              ],
            ),
            const _Section('Postingan'),
            _Card(
              rows: [
                toggle(
                  NotifSetting.comments,
                  Icons.textsms_outlined,
                  NotifTone.purple,
                  'Komentar dan balasan',
                  'Di postinganmu',
                ),
              ],
            ),
            const _Section('Sistem'),
            _Card(
              rows: [
                toggle(
                  NotifSetting.campus,
                  Icons.campaign_outlined,
                  NotifTone.green,
                  'Pengumuman kampus',
                  'Info penting dari admin',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: NotifColors.body,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.rows});

  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1F3FA0),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: 72,
                color: Color(0xFFF0F2F6),
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    this.value = false,
    this.onChanged,
    this.locked = false,
  });

  final IconData icon;
  final NotifTone tone;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          NotifIconTile(
            icon: icon,
            tone: tone,
            size: 42,
            radius: 13,
            iconSize: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: NotifColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    color: NotifColors.body,
                  ),
                ),
              ],
            ),
          ),
          if (locked)
            const Padding(
              padding: EdgeInsets.only(left: 8, right: 6),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 22,
                color: NotifColors.hint,
              ),
            )
          else
            Switch(
              value: value,
              onChanged: onChanged,
              thumbColor: const WidgetStatePropertyAll(Colors.white),
              trackColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? NotifColors.blue
                    : const Color(0xFFE5E7EB),
              ),
              trackOutlineColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
            ),
        ],
      ),
    );
  }
}