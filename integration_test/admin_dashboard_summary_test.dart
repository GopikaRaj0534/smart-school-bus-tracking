import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:routesafe/services/api_service.dart';
import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const testTitle = 'Admin Dashboard Summary Test';

  setUpAll(() {
    IntegrationTestLogger.startTest(testTitle);
  });

  tearDownAll(() {
    IntegrationTestLogger.completeTest(testTitle);
  });

  final baseUrl = ApiService.baseUrl;

  testWidgets(
    'Admin Login Flow - Login successful',
    (WidgetTester tester) async {
      final client = HttpClient();

      try {
        final request =
            await client.postUrl(Uri.parse('$baseUrl/login'));

        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({
          'email': 'admin@gmail.com',
          'password': 'admin123',
          'role': 'Admin',
        }));

        final response = await request.close();
        final body =
            await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map;

        expect(response.statusCode, 200);
        expect(data['success'], true);
        expect(data['user']['role'], 'Admin');

        IntegrationTestLogger.logStep('Admin Authentication Verified Successfully');
      } catch (e, st) {
        IntegrationTestLogger.logFailure(testTitle, e, st);
        rethrow;
      } finally {
        client.close();
      }
    },
  );

  testWidgets(
    'Admin Dashboard - Metrics loaded successfully',
    (WidgetTester tester) async {
      final client = HttpClient();

      try {
        final request = await client.getUrl(
          Uri.parse('$baseUrl/admin/dashboard/metrics'),
        );

        final response = await request.close();
        final body =
            await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map;

        expect(response.statusCode, 200);
        expect(data['success'], true);

        final metrics = data['metrics'] as Map;

        expect(metrics['total_buses'], isA<num>());
        expect(metrics['total_drivers'], isA<num>());
        expect(metrics['total_parents'], isA<num>());
        expect(metrics['total_routes'], isA<num>());
        expect(metrics['total_students'], isA<num>());

        IntegrationTestLogger.logStep('Admin Fleet Metrics Loaded Successfully');
        IntegrationTestLogger.logStep('Fleet Analytics Data Validated Successfully');
      } catch (e, st) {
        IntegrationTestLogger.logFailure(testTitle, e, st);
        rethrow;
      } finally {
        client.close();
      }
    },
  );
}
