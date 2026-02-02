import '../../models/label.dart';

/// 标签与撤销历史存储。
///
/// 负责维护当前标签列表、损坏行列表，以及撤销/重做快照。
/// 快照使用深拷贝，避免外部修改影响历史记录。
class LabelHistoryStore {
  List<Label> _labels = [];
  List<String> _corruptedLines = [];
  final List<List<Label>> _history = [];
  final List<List<Label>> _redoHistory = [];
  bool _isDirty = false;

  /// 当前标签列表。
  List<Label> get labels => _labels;

  /// 解析失败或保留的损坏行列表。
  List<String> get corruptedLines => _corruptedLines;

  /// 是否存在未保存的修改。
  bool get isDirty => _isDirty;

  /// 是否可撤销。
  bool get canUndo => _history.isNotEmpty;

  /// 是否可重做。
  bool get canRedo => _redoHistory.isNotEmpty;

  /// 替换当前标签及损坏行。
  ///
  /// [markDirty] 决定是否标记为“脏”状态。
  void replaceLabels(
    List<Label> labels, {
    List<String>? corruptedLines,
    bool markDirty = false,
  }) {
    _labels = labels;
    if (corruptedLines != null) {
      _corruptedLines = corruptedLines;
    }
    _isDirty = markDirty;
  }

  /// 设置损坏行列表（不影响当前标签）。
  void setCorruptedLines(List<String> lines) {
    _corruptedLines = lines;
  }

  /// 标记为“脏”状态。
  void markDirty() {
    _isDirty = true;
  }

  /// 标记为“干净”状态。
  void markClean() {
    _isDirty = false;
  }

  /// 清空撤销/重做历史。
  void clearHistory() {
    _history.clear();
    _redoHistory.clear();
  }

  /// 添加标签并记录历史。
  void addLabel(Label label) {
    addToHistory();
    _labels.add(label);
    _isDirty = true;
  }

  /// 更新指定索引的标签。
  ///
  /// [addToHistory] 控制是否记录历史快照。
  void updateLabel(int index, Label label, {bool addToHistory = true}) {
    if (index < 0 || index >= _labels.length) return;
    if (addToHistory) {
      this.addToHistory();
    }
    _labels[index] = label;
    _isDirty = true;
  }

  /// 删除指定索引的标签并记录历史。
  void removeLabel(int index) {
    if (index < 0 || index >= _labels.length) return;
    addToHistory();
    _labels.removeAt(index);
    _isDirty = true;
  }

  /// 将当前标签状态压入历史栈（最多保留 50 条）。
  void addToHistory() {
    _history.add(_snapshot());
    if (_history.length > 50) {
      _history.removeAt(0);
    }
    _redoHistory.clear();
  }

  /// 撤销到上一快照，返回是否成功。
  bool undo() {
    if (_history.isEmpty) return false;
    _redoHistory.add(_snapshot());
    _labels = _history.removeLast();
    _isDirty = true;
    return true;
  }

  /// 重做到下一快照，返回是否成功。
  bool redo() {
    if (_redoHistory.isEmpty) return false;
    _history.add(_snapshot());
    _labels = _redoHistory.removeLast();
    _isDirty = true;
    return true;
  }

  /// 对当前标签进行深拷贝，生成快照。
  List<Label> _snapshot() {
    return _labels.map((l) => l.copyWith()).toList();
  }
}
