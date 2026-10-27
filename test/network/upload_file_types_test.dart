import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// A [MagicFile] whose runtime type name is not `MagicFile`.
///
/// It stands in for what a release web build does to EVERY [MagicFile]:
/// dart2js minifies class names, so `runtimeType.toString()` answers
/// `minified:xY`. A driver that recognises a file by that string refuses
/// every picked file in production and accepts it in every test run.
class _RenamedMagicFile extends MagicFile {
  _RenamedMagicFile()
    : super(
        name: 'avatar.png',
        mimeType: 'image/png',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      );
}

/// An [XFile] whose runtime type name is not `XFile`, for the same reason.
class _RenamedXFile extends XFile {
  _RenamedXFile()
    : super.fromData(
        Uint8List.fromList(<int>[4, 5, 6]),
        name: 'photo.jpg',
        path: '/picked/photo.jpg',
        mimeType: 'image/jpeg',
      );
}

void main() {
  group('DioNetworkDriver.upload file types', () {
    late DioNetworkDriver driver;
    late RequestOptions? sent;

    setUp(() {
      sent = null;
      driver = DioNetworkDriver(baseUrl: 'https://api.example.test')
        ..configureDriver((Dio dio) {
          dio.interceptors.add(
            InterceptorsWrapper(
              onRequest:
                  (RequestOptions options, RequestInterceptorHandler handler) {
                    sent = options;
                    handler.resolve(
                      Response<dynamic>(
                        requestOptions: options,
                        statusCode: 200,
                        data: <String, dynamic>{},
                      ),
                    );
                  },
            ),
          );
        });
    });

    MultipartFile sentFile(String field) {
      final FormData form = sent!.data as FormData;

      return form.files
          .firstWhere(
            (MapEntry<String, MultipartFile> entry) => entry.key == field,
          )
          .value;
    }

    test(
      'a MagicFile is uploaded whatever its runtime type is named',
      () async {
        final MagicResponse response = await driver.upload(
          '/user/profile-photo',
          data: <String, dynamic>{},
          files: <String, dynamic>{'photo': _RenamedMagicFile()},
        );

        expect(response.statusCode, 200);
        expect(sentFile('photo').filename, 'avatar.png');
        expect(sentFile('photo').contentType.toString(), 'image/png');
      },
    );

    test('an XFile is uploaded whatever its runtime type is named', () async {
      final MagicResponse response = await driver.upload(
        '/user/profile-photo',
        data: <String, dynamic>{},
        files: <String, dynamic>{'photo': _RenamedXFile()},
      );

      expect(response.statusCode, 200);
      expect(sentFile('photo').filename, 'photo.jpg');
      expect(sentFile('photo').contentType.toString(), 'image/jpeg');
    });
  });
}
