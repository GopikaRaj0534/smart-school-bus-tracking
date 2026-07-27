import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:routesafe/services/api_service.dart';

void main() {
  test('uses the correct host for the current platform', () {
    if (Platform.isAndroid) {
      expect(ApiService.baseUrl, contains('10.0.2.2'));
    } else {
      expect(ApiService.baseUrl, contains('127.0.0.1'));
    }
  });
}
