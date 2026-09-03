import 'dart:convert';
import 'dart:io';

import 'package:flutter_application_bookstore/core/config/app_config.dart';
import 'package:flutter_application_bookstore/core/network/api_client.dart';
import 'package:flutter_application_bookstore/core/storage/token_storage.dart';
import 'package:flutter_application_bookstore/features/cart/data/cart_models.dart';
import 'package:flutter_application_bookstore/features/cart/data/cart_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('CartRepository.addBundle posts to the bundle cart endpoint', () async {
    SharedPreferences.setMockInitialValues({});
    late HttpServer server;
    final requests = <String>[];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add('${request.method} ${request.uri.path}');
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'code': 200,
        'message': '操作成功',
        'data': {
          'items': [],
          'totalQuantity': 0,
          'selectedQuantity': 0,
          'selectedAmount': 0,
        },
      }));
      await request.response.close();
    });

    try {
      final repository = CartRepository(
        ApiClient(
          config: AppConfig(
            baseUrl: 'http://${server.address.address}:${server.port}',
          ),
          tokenStorage: TokenStorage(),
        ),
      );
      final cart = await repository.addBundle(7);
      expect(cart, isA<ShoppingCart>());
      expect(requests, ['POST /api/cart/bundles/7']);
    } finally {
      await server.close(force: true);
    }
  });
}