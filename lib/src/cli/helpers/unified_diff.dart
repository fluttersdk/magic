import 'dart:convert';

enum _Kind { equal, delete, insert }

typedef _Edit = ({_Kind kind, String line});

/// Line-based unified diff used to preview `lib/main.dart` changes.
///
/// Computes an edit script from a longest-common-subsequence table (O(n*m)
/// time and memory in line counts, fine for source files) and renders it in
/// the `difflib` unified format: `@@ -s,l +s,l @@` headers where a range of
/// length 1 omits the comma and a range of length 0 prints `start - 1`.
class UnifiedDiff {
  const UnifiedDiff._();

  /// Renders the unified diff of [existing] against [template].
  ///
  /// Inputs are split with [LineSplitter], so a trailing newline does not add
  /// an empty line. Hunks carry [context] unchanged lines on each side and are
  /// merged when the unchanged run between two changes is at most
  /// `2 * context` lines. Lines are joined with `\n` and the result has no
  /// trailing newline.
  ///
  /// The two label lines are always emitted, so identical input yields just
  /// `--- [sourceLabel]\n+++ [targetLabel]` with no hunks.
  static String format(
    String existing,
    String template, {
    required String sourceLabel,
    required String targetLabel,
    int context = 3,
  }) {
    final edits = _editScript(
      LineSplitter.split(existing).toList(),
      LineSplitter.split(template).toList(),
    );

    return [
      '--- $sourceLabel',
      '+++ $targetLabel',
      ..._hunks(edits, context),
    ].join('\n');
  }

  /// Builds the edit script via an LCS table over line suffixes, preferring
  /// deletions before insertions when both are equally good.
  static List<_Edit> _editScript(List<String> from, List<String> to) {
    // 1. table[i][j] is the LCS length of from[i..] and to[j..].
    final table = List<List<int>>.generate(
      from.length + 1,
      (_) => List<int>.filled(to.length + 1, 0),
    );
    for (var i = from.length - 1; i >= 0; i--) {
      for (var j = to.length - 1; j >= 0; j--) {
        table[i][j] = from[i] == to[j]
            ? table[i + 1][j + 1] + 1
            : (table[i + 1][j] >= table[i][j + 1]
                  ? table[i + 1][j]
                  : table[i][j + 1]);
      }
    }

    // 2. Walk the table from the start, emitting one edit per step.
    final edits = <_Edit>[];
    var i = 0;
    var j = 0;
    while (i < from.length && j < to.length) {
      if (from[i] == to[j]) {
        edits.add((kind: _Kind.equal, line: from[i]));
        i++;
        j++;
      } else if (table[i + 1][j] >= table[i][j + 1]) {
        edits.add((kind: _Kind.delete, line: from[i++]));
      } else {
        edits.add((kind: _Kind.insert, line: to[j++]));
      }
    }
    while (i < from.length) {
      edits.add((kind: _Kind.delete, line: from[i++]));
    }
    while (j < to.length) {
      edits.add((kind: _Kind.insert, line: to[j++]));
    }

    return edits;
  }

  /// Renders every hunk (header plus body lines) for [edits].
  static List<String> _hunks(List<_Edit> edits, int context) {
    // 1. Positions of the changed edits.
    final changed = <int>[
      for (var index = 0; index < edits.length; index++)
        if (edits[index].kind != _Kind.equal) index,
    ];
    if (changed.isEmpty) {
      return const [];
    }

    // 2. Cluster changes whose unchanged gap fits inside two context windows.
    final clusters = <(int, int)>[];
    var first = changed.first;
    var last = changed.first;
    for (final position in changed.skip(1)) {
      if (position - last - 1 > 2 * context) {
        clusters.add((first, last));
        first = position;
      }
      last = position;
    }
    clusters.add((first, last));

    // 3. Render each cluster padded with context.
    final lines = <String>[];
    for (final (firstChange, lastChange) in clusters) {
      final start = firstChange - context < 0 ? 0 : firstChange - context;
      final end = lastChange + context >= edits.length
          ? edits.length - 1
          : lastChange + context;

      lines.add(_header(edits, start, end));
      for (final edit in edits.sublist(start, end + 1)) {
        lines.add(switch (edit.kind) {
          _Kind.equal => ' ${edit.line}',
          _Kind.delete => '-${edit.line}',
          _Kind.insert => '+${edit.line}',
        });
      }
    }

    return lines;
  }

  /// Renders the `@@ -s,l +s,l @@` header for `edits[start..end]`.
  static String _header(List<_Edit> edits, int start, int end) {
    var sourceStart = 0;
    var targetStart = 0;
    for (final edit in edits.take(start)) {
      if (edit.kind != _Kind.insert) sourceStart++;
      if (edit.kind != _Kind.delete) targetStart++;
    }

    var sourceLength = 0;
    var targetLength = 0;
    for (final edit in edits.sublist(start, end + 1)) {
      if (edit.kind != _Kind.insert) sourceLength++;
      if (edit.kind != _Kind.delete) targetLength++;
    }

    return '@@ -${_range(sourceStart, sourceLength)} '
        '+${_range(targetStart, targetLength)} @@';
  }

  /// Formats a zero-based [start] and [length] as a difflib range.
  static String _range(int start, int length) {
    return switch (length) {
      1 => '${start + 1}',
      0 => '$start,0',
      _ => '${start + 1},$length',
    };
  }
}
