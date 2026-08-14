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
    this.page = 0,
    this.totalPages = 0,
    this.total = 0,
    this.loadingMore = false,
    this.errorMessage,
  });

  final OrdersStatus status;
  final List<BookOrder> orders;
  final String? filter;
  final int? busyOrderId;
  final bool creating;
  final int page;
  final int totalPages;
  final int total;
  final bool loadingMore;
  final String? errorMessage;

  bool get hasMore => page < totalPages;

  OrdersState copyWith({
    OrdersStatus? status,
    List<BookOrder>? orders,
    String? filter,
    bool clearFilter = false,
    int? busyOrderId,
    bool clearBusyOrder = false,
    bool? creating,
    int? page,
    int? totalPages,
    int? total,
    bool? loadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OrdersState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      filter: clearFilter ? null : filter ?? this.filter,
      busyOrderId: clearBusyOrder ? null : busyOrderId ?? this.busyOrderId,
      creating: creating ?? this.creating,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      loadingMore: loadingMore ?? this.loadingMore,
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
  static const _pageSize = 10;
  bool _refreshing = false;

  Future<void> loadOrders({String? status, bool clearFilter = false}) async {
    final nextFilter = clearFilter ? null : status ?? state.filter;
    final filterChanged = nextFilter != state.filter;
    state = state.copyWith(
      status: OrdersStatus.loading,
      orders: filterChanged ? const [] : state.orders,
      filter: nextFilter,
      clearFilter: clearFilter,
      page: filterChanged ? 0 : state.page,
      totalPages: filterChanged ? 0 : state.totalPages,
      total: filterChanged ? 0 : state.total,
      clearError: true,
    );
    try {
      final page = await _repository.listOrders(
        status: nextFilter,
        size: _pageSize,
      );
      state = state.copyWith(
        status: OrdersStatus.ready,
        orders: page.records,
        filter: nextFilter,
        clearFilter: nextFilter == null,
        page: page.page,
        totalPages: page.totalPages,
        total: page.total,
        loadingMore: false,
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

  Future<void> loadMore() async {
    if (state.loadingMore ||
        state.status != OrdersStatus.ready ||
        !state.hasMore) {
      return;
    }
    final nextPage = state.page + 1;
    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final page = await _repository.listOrders(
        status: state.filter,
        page: nextPage,
        size: _pageSize,
      );
      final knownIds = state.orders.map((order) => order.id).toSet();
      state = state.copyWith(
        status: OrdersStatus.ready,
        orders: [
          ...state.orders,
          ...page.records.where((order) => !knownIds.contains(order.id)),
        ],
        page: page.page,
        totalPages: page.totalPages,
        total: page.total,
        loadingMore: false,
        clearError: true,
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        loadingMore: false,
        errorMessage: await _messageFor(error),
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false, errorMessage: '更多订单暂时无法加载');
    }
  }

  Future<void> refreshLoadedOrders() async {
    if (_refreshing ||
        state.status == OrdersStatus.loading ||
        state.loadingMore) {
      return;
    }
    _refreshing = true;
    final pagesToLoad = state.page < 1 ? 1 : state.page;
    try {
      final refreshed = <BookOrder>[];
      var totalPages = 0;
      var total = 0;
      var loadedPage = 0;
      for (var pageNumber = 1; pageNumber <= pagesToLoad; pageNumber++) {
        final page = await _repository.listOrders(
          status: state.filter,
          page: pageNumber,
          size: _pageSize,
        );
        refreshed.addAll(page.records);
        totalPages = page.totalPages;
        total = page.total;
        loadedPage = page.page;
        if (pageNumber >= page.totalPages) break;
      }
      state = state.copyWith(
        status: OrdersStatus.ready,
        orders: refreshed,
        page: loadedPage,
        totalPages: totalPages,
        total: total,
        clearError: true,
      );
    } on ApiException catch (error) {
      state = state.copyWith(errorMessage: await _messageFor(error));
    } catch (_) {
      state = state.copyWith(errorMessage: '订单状态刷新失败，请手动刷新');
    } finally {
      _refreshing = false;
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
      await refreshLoadedOrders();
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

  void clearError() {
    state = state.copyWith(clearError: true);
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
      state = state.copyWith(clearBusyOrder: true, clearError: true);
      await refreshLoadedOrders();
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
