import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/models/label.dart';
import 'package:label_load/services/labels/label_history_store.dart';

void main() {
  group('LabelHistoryStore', () {
    test('addLabel marks dirty and records history', () {
      final store = LabelHistoryStore();
      store.addLabel(Label(id: 0));

      expect(store.labels.length, 1);
      expect(store.isDirty, isTrue);
      expect(store.canUndo, isTrue);
    });

    test('undo/redo restores snapshots', () {
      final store = LabelHistoryStore();
      store.addLabel(Label(id: 0));

      expect(store.undo(), isTrue);
      expect(store.labels, isEmpty);

      expect(store.redo(), isTrue);
      expect(store.labels.length, 1);
      expect(store.labels.first.id, 0);
    });

    test('replaceLabels updates corrupted lines and dirty flag', () {
      final store = LabelHistoryStore();
      store.replaceLabels(
        [Label(id: 1)],
        corruptedLines: ['bad'],
        markDirty: false,
      );

      expect(store.labels.length, 1);
      expect(store.corruptedLines, ['bad']);
      expect(store.isDirty, isFalse);
    });

    test('setCorruptedLines overwrites list', () {
      final store = LabelHistoryStore();
      store.setCorruptedLines(['x', 'y']);
      expect(store.corruptedLines, ['x', 'y']);
    });

    test('updateLabel replaces label and records history', () {
      final store = LabelHistoryStore();
      store.addLabel(Label(id: 0));

      store.updateLabel(0, Label(id: 2));

      expect(store.labels.first.id, 2);
      expect(store.canUndo, isTrue);
    });

    test('removeLabel deletes label and marks dirty', () {
      final store = LabelHistoryStore();
      store.addLabel(Label(id: 0));
      store.markClean();

      store.removeLabel(0);

      expect(store.labels, isEmpty);
      expect(store.isDirty, isTrue);
    });

    test('updateLabel ignores invalid index', () {
      final store = LabelHistoryStore();
      store.addLabel(Label(id: 0));
      store.markClean();

      store.updateLabel(5, Label(id: 2));

      expect(store.labels.first.id, 0);
      expect(store.isDirty, isFalse);
    });

    test('removeLabel ignores invalid index', () {
      final store = LabelHistoryStore();
      store.addLabel(Label(id: 0));
      store.markClean();

      store.removeLabel(-1);

      expect(store.labels.length, 1);
      expect(store.isDirty, isFalse);
    });

    test('markDirty/markClean toggles state', () {
      final store = LabelHistoryStore();
      store.markDirty();
      expect(store.isDirty, isTrue);
      store.markClean();
      expect(store.isDirty, isFalse);
    });

    test('clearHistory resets undo/redo availability', () {
      final store = LabelHistoryStore();
      store.addLabel(Label(id: 0));
      expect(store.canUndo, isTrue);

      store.clearHistory();
      expect(store.canUndo, isFalse);
      expect(store.canRedo, isFalse);
    });

    test('history caps at 50 snapshots', () {
      final store = LabelHistoryStore();
      for (int i = 0; i < 52; i++) {
        store.addLabel(Label(id: i));
      }

      var undoCount = 0;
      while (store.undo()) {
        undoCount += 1;
      }

      expect(undoCount, 50);
      expect(store.undo(), isFalse);
    });
  });
}
