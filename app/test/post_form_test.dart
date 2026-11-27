import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wts/features/auth/domain/user_profile.dart';
import 'package:wts/features/timeline/data/fake_post_repository.dart';
import 'package:wts/features/timeline/data/post_draft_store.dart';
import 'package:wts/features/timeline/data/post_repository.dart';
import 'package:wts/features/timeline/domain/post.dart';
import 'package:wts/features/timeline/presentation/providers/feed_providers.dart';
import 'package:wts/features/timeline/presentation/screens/post_form_screen.dart';
import 'package:wts/shared/widgets/widgets.dart';

UserProfile _user() => UserProfile(
  id: 'u1',
  email: 'u1@nusaputra.ac.id',
  username: 'preview_user',
  prodiName: 'Teknik Informatika',
  createdAt: DateTime(2026),
);

FakePostRepository _repo({Duration minGap = Duration.zero}) =>
    FakePostRepository(
      currentUser: _user,
      latency: Duration.zero,
      minGap: minGap,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PostRules', () {
    test('compose menggabungkan judul dan isi', () {
      expect(PostRules.compose('Judul', 'Isi'), 'Judul\nIsi');
      expect(PostRules.compose('', 'Isi saja'), 'Isi saja');
      expect(PostRules.compose('Judul saja', ''), 'Judul saja');
      expect(PostRules.compose('  ', '  '), '');
    });

    test('validateCaption: 1 sampai 2000 karakter', () {
      expect(PostRules.validateCaption(''), isNotNull);
      expect(PostRules.validateCaption('a'), isNull);
      expect(PostRules.validateCaption('a' * 2000), isNull);
      expect(PostRules.validateCaption('a' * 2001), isNotNull);
    });
  });

  group('createPost (repo palsu)', () {
    test('berhasil: tampil di atas feed, milik sendiri, anonim menyembunyikan nama', () async {
      final repo = _repo();
      final created = await repo.createPost(
        const PostDraft(caption: 'Judul\nIsi', tagIds: [10], isAnonymous: true),
      );
      expect(created.isMine, isTrue);
      expect(created.authorLabel, 'Anonim');
      expect(created.parts.title, 'Judul');

      final feed = await repo.fetchFeed(sort: PostSort.newest);
      // setelah pengumuman resmi
      expect(feed.items[1].id, created.id);
    });

    test('tidak anonim memakai profil pengguna', () async {
      final created = await _repo().createPost(
        const PostDraft(caption: 'Halo', tagIds: [2]),
      );
      expect(created.authorLabel, '@preview_user');
      expect(created.authorProdi, 'Teknik Informatika');
    });

    test('validasi sesuai RPC create_post', () async {
      final repo = _repo();
      Future<void> expectCode(PostDraft d, String code) => expectLater(
        repo.createPost(d),
        throwsA(isA<PostException>().having((e) => e.code, 'code', code)),
      );

      await expectCode(
        const PostDraft(caption: '', tagIds: [1]),
        'invalid_caption',
      );
      await expectCode(
        const PostDraft(caption: 'x', tagIds: []),
        'tags_required',
      );
      await expectCode(
        const PostDraft(caption: 'x', tagIds: [1, 2, 3]),
        'tags_required',
      );
      await expectCode(
        const PostDraft(caption: 'x', tagIds: [99]),
        'invalid_tag',
      );
      await expectCode(
        const PostDraft(caption: 'x', tagIds: [1], lifetimeDays: 2),
        'invalid_duration',
      );
      await expectCode(
        PostDraft(
          caption: 'x',
          tagIds: const [1],
          images: List.generate(6, (i) => PostImage(seed: i)),
        ),
        'too_many_images',
      );
      await expectCode(
        const PostDraft(
          caption: 'x',
          tagIds: [1],
          questionnaire: QuestionnaireInfo(link: 'ftp://salah'),
        ),
        'invalid_link',
      );
    });

    test('durasi menentukan masa tayang', () async {
      final created = await _repo().createPost(
        const PostDraft(caption: 'x', tagIds: [2], lifetimeDays: 3),
      );
      final days = created.expiresAt.difference(created.createdAt).inHours / 24;
      expect(days, closeTo(3, 0.01));
    });

    test('kuesioner tersimpan', () async {
      final created = await _repo().createPost(
        const PostDraft(
          caption: 'Isi kuesioner ya',
          tagIds: [1],
          questionnaire: QuestionnaireInfo(
            link: 'https://forms.gle/abc',
            durationMin: 5,
          ),
        ),
      );
      expect(created.questionnaire?.link, 'https://forms.gle/abc');
      expect(created.questionnaire?.durationMin, 5);
    });

    test('jeda antar posting (rate limit)', () async {
      final repo = _repo(minGap: const Duration(seconds: 30));
      await repo.createPost(const PostDraft(caption: 'a', tagIds: [2]));
      await expectLater(
        repo.createPost(const PostDraft(caption: 'b', tagIds: [2])),
        throwsA(
          isA<PostException>().having(
            (e) => e.code,
            'code',
            'rate_limit_exceeded',
          ),
        ),
      );
    });
  });

  group('updateCaption (repo palsu)', () {
    test('berhasil dalam 24 jam dan menandai diedit', () async {
      final updated = await _repo().updateCaption('p15', 'Caption baru');
      expect(updated.caption, 'Caption baru');
      expect(updated.isEdited, isTrue);
    });

    test(
      'ditolak di luar 24 jam, bukan pemilik, atau caption kosong',
      () async {
        final repo = _repo();
        Future<void> expectCode(String id, String caption, String code) =>
            expectLater(
              repo.updateCaption(id, caption),
              throwsA(isA<PostException>().having((e) => e.code, 'code', code)),
            );
        await expectCode('p11', 'x', 'edit_window'); // 4 hari lalu
        await expectCode('p4', 'x', 'forbidden'); // milik orang lain
        await expectCode('p15', '   ', 'invalid_caption');
      },
    );
  });

  group('Draf', () {
    test('simpan, muat, dan hapus', () async {
      await PostDraftStore.save(
        const PostFormDraft(
          title: 'J',
          body: 'B',
          tagIds: [1, 2],
          anonymous: true,
          days: 7,
        ),
      );
      final loaded = await PostDraftStore.load();
      expect(loaded?.title, 'J');
      expect(loaded?.tagIds, [1, 2]);
      expect(loaded?.anonymous, isTrue);
      expect(loaded?.days, 7);

      await PostDraftStore.clear();
      expect(await PostDraftStore.load(), isNull);
    });

    test('draf kosong tidak disimpan', () async {
      await PostDraftStore.save(const PostFormDraft());
      expect(await PostDraftStore.load(), isNull);
    });
  });

  group('PostFormScreen', () {
    Widget host(FakePostRepository repo, {Post? editing}) => ProviderScope(
      overrides: [postRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: PostFormScreen(editing: editing)),
    );

    void bigScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('tombol Posting aktif setelah ada isi dan kategori', (
      tester,
    ) async {
      bigScreen(tester);
      await tester.pumpWidget(host(_repo()));
      await tester.pumpAndSettle();

      FilledButton button() =>
          tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button().onPressed, isNull);

      await tester.enterText(
        find.byType(TextField).at(1),
        'Cari teman belajar kalkulus',
      );
      await tester.pump();
      expect(button().onPressed, isNull); // belum ada kategori

      await tester.tap(find.widgetWithText(GlassChip, 'Akademik'));
      await tester.pump();
      expect(button().onPressed, isNotNull);
    });

    testWidgets('maksimal 2 kategori', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(host(_repo()));
      await tester.pumpAndSettle();

      for (final name in ['Akademik', 'Tugas', 'Diskusi']) {
        await tester.tap(find.widgetWithText(GlassChip, name));
        await tester.pump();
      }
      bool selected(String name) => tester
          .widget<GlassChip>(find.widgetWithText(GlassChip, name))
          .selected;
      expect(['Akademik', 'Tugas', 'Diskusi'].where(selected).length, 2);
      expect(find.text('Maksimal 2 tag'), findsOneWidget);
    });

    testWidgets('kategori Kuesioner memunculkan isian tautan', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(host(_repo()));
      await tester.pumpAndSettle();

      expect(find.text('Detail kuesioner (opsional)'), findsNothing);
      await tester.tap(find.widgetWithText(GlassChip, 'Kuesioner'));
      await tester.pump();
      expect(find.text('Detail kuesioner (opsional)'), findsOneWidget);
    });

    testWidgets('posting berhasil menyimpan ke repo dan menutup layar', (
      tester,
    ) async {
      bigScreen(tester);
      final repo = _repo();
      Post? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [postRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<Post>(
                    MaterialPageRoute(builder: (_) => const PostFormScreen()),
                  );
                },
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Judul tes');
      await tester.enterText(find.byType(TextField).at(1), 'Isi tes');
      await tester.tap(find.widgetWithText(GlassChip, 'Diskusi'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Posting'));
      await tester.pumpAndSettle();

      expect(result?.caption, 'Judul tes\nIsi tes');
      expect(result?.tags.single.name, 'Diskusi');
      expect(find.text('buka'), findsOneWidget); // kembali ke layar awal
    });

    testWidgets(
      'mode ubah: kategori terkunci, Simpan aktif setelah isi berubah',
      (tester) async {
        bigScreen(tester);
        final repo = _repo();
        // Future.delayed di dalam testWidgets butuh runAsync (jam palsu).
        final feed = await tester.runAsync(
          () => repo.fetchFeed(sort: PostSort.newest, limit: 50),
        );
        final post = feed!.items.firstWhere((p) => p.id == 'p15');

        await tester.pumpWidget(host(repo, editing: post));
        await tester.pumpAndSettle();

        expect(find.text('Ubah Postingan'), findsOneWidget);
        expect(find.byType(GlassChip), findsNothing); // tag tidak bisa diubah
        FilledButton button() =>
            tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button().onPressed, isNull); // belum ada perubahan

        await tester.enterText(
          find.byType(TextField).at(1),
          'Isi yang sudah diperbaiki',
        );
        await tester.pump();
        expect(button().onPressed, isNotNull);
      },
    );
  });
}
