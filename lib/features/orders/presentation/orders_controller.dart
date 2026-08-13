import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../data/models/profile/user_address.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../profile/presentation/profile_controller.dart';
import '../data/order_models.dart';
import '../data/order_repository.dart';

enum OrdersStatus { initial, loading, ready, failure }

class OrdersState {
  const OrdersState({
    this.status = OrdersStatus.initial,
    this.orders = const [],
    this.filter,
    this.busyOrderId,
    this.creating = false,
    this.errorMessage,
  });

  final OrdersStatus status;
  final List<BookOrder> orders;
  final String? filter;
  final int? busyOrderId;
  final bool creating;
  final String? errorMessage;

  OrdersState copyWith({
    OrdersStatus? status,
    List<BookOrder>? orders,
    String? filter,
    bool clearFilter = false,
    int? busyOrderId,
    bool clearBusyOrder = false,
    bool? creating,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OrdersState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      filter: clearFilter ? null : filter ?? this.filter,
      busyOrderId: clearBusyOrder ? null : busyOrderId ?? this.busyOrderId,
      creating: creating ?? this.creating,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class OrdersController extends StateNotifier<OrdersState> {
  OrdersController({
    required OrderRepository repository,
    required AuthController authController,
    required CartController cartController,
  }) : _repository = repository,
       _authController = authController,
       _cartController = cartController,
       super(const OrdersState());

  final OrderRepository _repository;
  final AuthController _authController;
  final CartController _cartController;

  Future<void> loadOrders({String? status, bool clearFilter = false}) async {
    final nextFilter = clearFilter ? null : status ?? state.filter;
    state = state.copyWith(
      status: OrdersStatus.loading,
      filter: nextFilter,
      clearFilter: clearFilter,
      clearError: true,
    );
    try {
      final page = await _repository.listOrders(status: nextFilter);
      state = state.copyWith(
        status: OrdersStatus.ready,
        orders: page.records,
        filter: nextFilter,
        clearFilter: nextFilter == null,
        clearError: true,
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        status: OrdersStatus.failure,
        errorMessage: await _messageFor(error),
      );
    } catch (_) {
      state = state.copyWith(
        status: OrdersStatus.failure,
        errorMessage: '订单暂时无法加载',
      );
    }
  }

  Future<BookOrder?> createOrder({
    required int addressId,
    String? remark,
  }) async {
    if (state.creating) {
      return null;
    }
    state = state.copyWith(creating: true, clearError: true);
    try {
      final order = await _repository.createOrder(
        addressId: addressId,
        remark: remark,
      );
      await _cartController.refreshAfterOrder();
      state = state.copyWith(
        creating: false,
        orders: [order, ...state.orders.where((item) => item.id != order.id)],
        clearError: true,
      );
      return order;
    } on ApiException catch (error) {
      state = state.copyWith(
        creating: false,
        errorMessage: await _messageFor(error),
      );
      return null;
    } catch (_) {
      state = state.copyWith(creating: false, errorMessage: '创建订单失败，请稍后再试');
      return null;
    }
  }

  Future<bool> payOrder(BookOrder order) async {
    return _runOrderAction(order.id, () => _repository.payOrder(order.id));
  }

  Future<bool> cancelOrder(BookOrder order) async {
    return _runOrderAction(order.id, () => _repository.cancelOrder(order.id));
  }

  Future<BookOrder?> confirmReceipt(BookOrder order) async {
    if (state.busyOrderId != null) {
      return null;
    }
    state = state.copyWith(busyOrderId: order.id, clearError: true);
    try {
      final updated = await _repository.confirmReceipt(order.id);
      state = state.copyWith(
        status: OrdersStatus.ready,
        orders: [
          for (final item in state.orders)
            if (item.id != updated.id)
              item
            else if (state.filter == null || state.filter == updated.status)
              updated,
        ],
        clearBusyOrder: true,
        clearError: true,
      );
      return updated;
    } on ApiException catch (error) {
      state = state.copyWith(
        clearBusyOrder: true,
        errorMessage: await _messageFor(error),
      );
      return null;
    } catch (_) {
      state = state.copyWith(
        clearBusyOrder: true,
        errorMessage: '确认收货失败，请稍后再试',
      );
      return null;
    }
  }

  Future<bool> _runOrderAction(
    int orderId,
    Future<Object?> Function() action,
  ) async {
    if (state.busyOrderId != null) {
      return false;
    }
    state = state.copyWith(busyOrderId: orderId, clearError: true);
    try {
      await action();
      final page = await _repository.listOrders(status: state.filter);
      state = state.copyWith(
        status: OrdersStatus.ready,
        orders: page.records,
        clearBusyOrder: true,
        clearError: true,
      );
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        clearBusyOrder: true,
        errorMessage: await _messageFor(error),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        clearBusyOrder: true,
        errorMessage: '订单操作失败，请稍后再试',
      );
      return false;
    }
  }

  Future<String> _messageFor(ApiException error) async {
    if (error.isUnauthorized) {
      await _authController.logout();
      return '登录已过期，请重新登录';
    }
    if (error.isConflict) {
      return error.message.isEmpty ? '订单状态已发生变化，请刷新后重试' : error.message;
    }
    if (error.message == 'Unable to connect to the server') {
      return '暂时无法连接服务，请确认后端已经启动';
    }
    return error.message;
  }
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(apiClientProvider));
});

final ordersControllerProvider =
    StateNotifierProvider<OrdersController, OrdersState>((ref) {
      return OrdersController(
        repository: ref.watch(orderRepositoryProvider),
        authController: ref.watch(authControllerProvider.notifier),
        cartController: ref.watch(cartControllerProvider.notifier),
      );
    });

final checkoutAddressesProvider = FutureProvider.autoDispose<List<UserAddress>>(
  (ref) {
    return ref.watch(profileRepositoryProvider).listAddresses();
  },
);

final orderDetailProvider = FutureProvider.autoDispose.family<BookOrder, int>((
  ref,
  orderId,
) {
  return ref.watch(orderRepositoryProvider).getOrder(orderId);
});
