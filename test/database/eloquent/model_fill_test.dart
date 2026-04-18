import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

class Post extends Model {
  @override
  String get table => 'posts';

  @override
  String get resource => 'posts';

  @override
  List<String> get fillable => ['title', 'body', 'published_at', 'views'];

  @override
  Map<String, String> get casts => {'published_at': 'datetime', 'views': 'int'};
}

void main() {
  group('Model.fill', () {
    test('only fillable keys are assigned', () {
      final post = Post()
        ..fill({
          'title': 'Hello',
          'body': 'World',
          'author_id': 42, // not fillable
        });

      expect(post.getAttribute('title'), 'Hello');
      expect(post.getAttribute('body'), 'World');
      expect(post.getAttribute('author_id'), isNull);
    });

    test('non-fillable key drops silently by default', () {
      expect(() => Post().fill({'author_id': 1}), returnsNormally);
    });

    test('strict: true throws MassAssignmentException on non-fillable', () {
      final post = Post();

      expect(
        () => post.fill({'title': 'ok', 'author_id': 1}, strict: true),
        throwsA(isA<MassAssignmentException>()),
      );
    });

    test(
      'strict: true still assigns fillable keys that come before the bad one',
      () {
        final post = Post();

        try {
          post.fill({'title': 'ok', 'author_id': 1}, strict: true);
        } catch (_) {
          // expected
        }

        expect(post.getAttribute('title'), 'ok');
      },
    );

    test('fill does not touch exists flag', () {
      final post = Post()..fill({'title': 'x'});
      expect(post.exists, isFalse);
    });

    test('exception carries attribute name and model type', () {
      try {
        Post().fill({'secret': 1}, strict: true);
        fail('expected MassAssignmentException');
      } on MassAssignmentException catch (e) {
        expect(e.attribute, 'secret');
        expect(e.modelType, Post);
        expect(e.toString(), contains('"secret"'));
        expect(e.toString(), contains('Post'));
      }
    });

    test('casts are still applied on read after fill', () {
      final post = Post()..fill({'views': '42'});
      expect(post.getAttribute('views'), 42);
    });
  });
}
