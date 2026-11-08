import 'dart:async';
import 'dart:typed_data';

import 'package:darna/features/listings/manage_listing_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'support/upload_fakes.dart';

void main() {
  testWidgets('every picture is uploaded and attached once, and its tile goes away when done', (tester) async {
    final h = UploadHarness();
    await h.open(tester);

    await h.pick(tester, [photo(1), photo(2), photo(3)]);

    expect((h.repo.tickets, h.repo.puts, h.repo.attaches), (3, 3, 3));
    expect(find.text('جارٍ الرفع'), findsNothing);
    expect(find.text('في الانتظار'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed picture shows its own error and can be retried without a second upload slot', (tester) async {
    final h = UploadHarness();
    h.repo.failPut = (n) => n == 2 ? offlineError : null; // the second storage upload fails once
    await h.open(tester);

    await h.pick(tester, [photo(1), photo(2), photo(3)]);

    // pictures 1 and 3 went through; picture 2 stayed as a failed tile with both actions
    expect(h.repo.attaches, 2);
    expect(find.textContaining('فشل رفع الصورة'), findsOneWidget);
    expect(find.text('إعادة'), findsOneWidget);
    expect(find.text('إزالة'), findsOneWidget);

    await tester.tap(find.text('إعادة'));
    await tester.pumpAndSettle();

    expect(h.repo.attaches, 3);
    expect(h.repo.tickets, 3); // the retry reused picture 2's ticket
    expect(h.repo.puts, 4);
    expect(find.text('إعادة'), findsNothing);
  });

  testWidgets('a failed picture can be dismissed', (tester) async {
    final h = UploadHarness();
    h.repo.failPut = (_) => offlineError;
    await h.open(tester);

    await h.pick(tester, [photo(1)]);
    expect(find.text('إزالة'), findsOneWidget);

    await tester.tap(find.text('إزالة'));
    await tester.pumpAndSettle();
    expect(find.text('إزالة'), findsNothing);
    expect(h.repo.attaches, 0);
  });

  testWidgets('a file that is not an image fails for good: no retry, no upload', (tester) async {
    final h = UploadHarness();
    await h.open(tester);

    await h.pick(tester, [XFile.fromData(Uint8List.fromList(List.filled(40, 65)), name: 'notes.jpg')]);

    expect(find.text('نوع الصورة غير مدعوم (JPG أو PNG أو WebP)'), findsOneWidget);
    expect(find.text('إعادة'), findsNothing);
    expect(find.text('إزالة'), findsOneWidget);
    expect(h.repo.tickets, 0);
  });

  testWidgets('a file that cannot be read ends in an error instead of spinning forever', (tester) async {
    final h = UploadHarness();
    await h.open(tester);

    await h.pick(tester, [BrokenFile(), photo(2)]);

    expect(find.text('تعذرت قراءة الصورة، اخترها من جديد'), findsOneWidget);
    expect(h.repo.attaches, 1); // the next picture was not held up by the broken one
    expect(tester.takeException(), isNull);
  });

  testWidgets('the same picture chosen twice is uploaded once', (tester) async {
    final h = UploadHarness();
    await h.open(tester);

    await h.pick(tester, [photo(1, name: 'a.jpg'), photo(1, name: 'copy_of_a.jpg')]);

    expect(h.repo.attaches, 1);
    expect(find.text('تم تجاهل صورة مكررة'), findsOneWidget);
  });

  testWidgets('choosing the same picture again later is also ignored', (tester) async {
    final h = UploadHarness();
    await h.open(tester);

    await h.pick(tester, [photo(1)]);
    await tester.pumpAndSettle(const Duration(seconds: 5)); // let the first snackbar (if any) go
    await h.pick(tester, [photo(1)]);

    expect(h.repo.attaches, 1);
  });

  testWidgets('no more than the limit is queued from one selection', (tester) async {
    final h = UploadHarness();
    await h.open(tester);

    await h.pick(tester, [for (var i = 0; i < 25; i++) photo(i)]);

    expect(h.repo.attaches, 20);
    expect(find.text('سيُرفع أول 20 صور فقط (الحد الأقصى 20)'), findsOneWidget);
  });

  testWidgets('pictures wait their turn: only one is sent at a time', (tester) async {
    final h = UploadHarness();
    h.repo.gate = Completer<void>();
    await h.open(tester);

    await h.pick(tester, [photo(1), photo(2), photo(3)], settle: false);

    expect(h.repo.puts, 1); // the others are queued behind the first
    expect(find.text('جارٍ الرفع'), findsOneWidget);
    expect(find.text('في الانتظار'), findsNWidgets(2));

    h.repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(h.repo.attaches, 3);
  });

  testWidgets('leaving while pictures are being sent asks first, and staying keeps them going', (tester) async {
    final h = UploadHarness();
    h.repo.gate = Completer<void>();
    await h.open(tester);
    await h.pick(tester, [photo(1), photo(2)], settle: false);

    await tester.binding.handlePopRoute(); // the system back button
    await tester.pump(const Duration(milliseconds: 400)); // a spinner is on screen: it never "settles"
    expect(find.text('رفع الصور جارٍ'), findsOneWidget);

    await tester.tap(find.text('إلغاء')); // stay
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('رفع الصور جارٍ'), findsNothing);
    expect(find.byType(ManageListingScreen), findsOneWidget);

    h.repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(h.repo.attaches, 2);
  });
}
