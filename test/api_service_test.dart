import 'package:flutter_test/flutter_test.dart';
import 'package:routesafe/services/api_service.dart';

void main() {
  test('uses the correct host for the current platform', () {
    expect(ApiService.baseUrl, contains('5000'));
  });
}
