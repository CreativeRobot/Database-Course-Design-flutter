import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_bookstore/core/config/app_config.dart';
import 'package:flutter_application_bookstore/core/network/api_client.dart';
import 'package:flutter_application_bookstore/core/storage/token_storage.dart';
import 'package:flutter_application_bookstore/features/cart/data/bundle_models.dart';
import 'package:flutter_application_bookstore/features/cart/data/cart_models.dart';
import 'package:flutter_application_bookstore/features/cart/data/cart_repository.dart';
import 'package:flutter_application_bookstore/features/cart/presentation/cart_page.dart';
import 'package:flutter_application_bookstore/features/books/presentation/book_bundle_offers.dart';
import 'package:flutter_application_bookstore/features/orders/data/order_models.dart';
import 'package:flutter_application_bookstore/features/orders/presentation/order_bundle_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('ShoppingCart.fromJson parses bundle pricing fields', () {
    final cart = ShoppingCart.fromJson({
      'items': [],
      'totalQuantity': 2,
      'selectedQuantity': 2,
      'selectedAmount': 30,
      'regularAmount': 30,
      'bundleDiscountAmount': 5,
      'payableAmount': 25,
      'eligibleBundles': [
        {
          'id': 7,
          'name': '文学套装',
          'bundlePrice': 25,
          'regularAmount': 30,
          'savings': 5,
          'applied': true,
          'items': [],
        },
      ],
      'appliedBundles': [],
    });

    expect(cart.regularAmount, 30);
    expect(cart.bundleDiscountAmount, 5);
    expect(cart.payableAmount, 25);
    expect(cart.eligibleBundles.single.id, 7);
    expect(cart.checkoutAmount, 25);
  });

  test('CartBundle.fromJson parses applied flag', () {
    final bundle = CartBundle.fromJson({
      'id': 7,
      'name': '文学套装',
      'bundlePrice': 25,
      'regularAmount': 30,
      'savings': 5,
      'applied': true,
      'items': [],
    });

    expect(bundle.applied, isTrue);
  });

  test('BookOrder.fromJson parses historical bundle snapshots', () {
    final order = BookOrder.fromJson({
      'id': 1,
      'orderNo': 'ORDER-1',
      'status': 'PENDING_PAYMENT',
      'totalAmount': 30,
      'discountAmount': 5,
      'shippingFee': 0,
      'payableAmount': 25,
      'receiverName': '读者',
      'receiverPhone': '13800000000',
      'receiverAddress': '书店路 1 号',
      'remark': '',
      'items': [],
      'bundles': [
        {
          'bundleId': 7,
          'bundleName': '文学套装',
          'bundlePrice': 25,
          'regularAmount': 30,
          'discountAmount': 5,
          'items': [
            {
              'bookId': 11,
              'bookTitle': '旧书名',
              'unitPrice': 15,
              'quantity': 1,
              'allocatedDiscount': 2.5,
            },
          ],
        },
      ],
    });

    expect(order.bundles.single.bundleId, 7);
    expect(order.bundles.single.items.single.bookTitle, '旧书名');
    expect(order.bundles.single.discountAmount, 5);
  });

  testWidgets('bundle suggestions are hidden for empty lists and shown otherwise',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CartBundleSuggestions(
            bundles: [
              CartBundle(
                id: 7,
                name: '文学套装',
                bundlePrice: 25,
                regularAmount: 30,
                savings: 5,
                items: [],
                applied: false,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('文学套装'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CartBundleSuggestions(bundles: [])),
      ),
    );
    expect(find.text('组合包推荐'), findsNothing);
  });

  testWidgets('book detail bundle offers hide empty state and add a complete bundle',
      (tester) async {
    var addedBundleId = 0;
    const bundle = BookBundle(
      id: 7,
      name: '文学套装',
      description: '两本一起读更划算',
      bundlePrice: 25,
      regularAmount: 30,
      savings: 5,
      items: [
        BundleItem(bookId: 11, title: '旧书名', salePrice: 15),
        BundleItem(bookId: 12, title: '新书名', salePrice: 15),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookBundleOffers(
            bundles: const [bundle],
            onAddBundle: (id) async {
              addedBundleId = id;
              return true;
            },
          ),
        ),
      ),
    );

    expect(find.text('组合购买更优惠'), findsOneWidget);
    expect(find.text('文学套装'), findsOneWidget);
    expect(find.textContaining('旧书名'), findsOneWidget);
    expect(find.text('组合价 ¥25.00'), findsOneWidget);
    expect(find.textContaining('节省 ¥5.00'), findsOneWidget);

    await tester.tap(find.text('整套加入购物车'));
    await tester.pump();
    expect(addedBundleId, 7);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookBundleOffers(
            bundles: const [],
            onAddBundle: (_) async => true,
          ),
        ),
      ),
    );
    expect(find.text('组合购买更优惠'), findsNothing);
  });

  testWidgets('order bundle history renders immutable price snapshots',
      (tester) async {
    const application = OrderBundleApplication(
      id: 1,
      bundleId: 7,
      bundleName: '下单时的文学套装',
      bundlePrice: 25,
      regularAmount: 30,
      discountAmount: 5,
      items: [
        OrderBundleApplicationItem(
          orderItemId: 10,
          bookId: 11,
          bookTitle: '下单时的书名',
          isbn: 'ISBN-OLD',
          salePrice: 15,
          allocatedDiscount: 2.5,
          quantity: 1,
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OrderBundleHistory(bundles: [application])),
      ),
    );

    expect(find.text('组合包优惠记录'), findsOneWidget);
    expect(find.text('下单时的文学套装'), findsOneWidget);
    expect(find.textContaining('下单时的书名'), findsOneWidget);
    expect(find.textContaining('历史售价 ¥15.00'), findsOneWidget);
    expect(find.textContaining('优惠分摊 ¥2.50'), findsOneWidget);
    expect(find.text('组合价 ¥25.00'), findsOneWidget);
    expect(find.textContaining('节省 ¥5.00'), findsOneWidget);
  });
}



