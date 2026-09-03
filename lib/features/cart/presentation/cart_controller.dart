import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/cart_models.dart';
import '../data/cart_repository.dart';

enum CartStatus { initial, loading, ready, failure }

class CartState {
  const CartState({
    this.status = CartStatus.initial,
    this.cart = ShoppingCart.empty,
    this.busyBookIds = const {},
    this.busyAll = false,
    this.errorMessage,
  });

  final CartStatus status;
  final ShoppingCart cart;
  final Set<int> busyBookIds;
  final bool busyAll;
  final String? errorMessage;

  bool get isBusy => busyAll || busyBookIds.isNotEmpty;

  CartState copyWith({
    CartStatus? status,
    ShoppingCart? cart,
    Set<int>? busyBookIds,
    bool? busyAll,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CartState(
      status: status ?? this.status,
      cart: cart ?? this.cart,
      busyBookIds: busyBookIds ?? this.busyBookIds,
      busyAll: busyAll ?? this.busyAll,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class CartController extends StateNotifier<CartState> {
  CartController({
    required CartRepository repository,
    required AuthController authController,
  })  : _repository = repository,
        _authController = authController,
        super(const CartState());

  final CartRepository _repository;
  final AuthController _authController;

  Future<void> loadCart() async {
    state = state.copyWith(status: CartStatus.loading, clearError: true);
    try {
      final cart = await _repository.getCart();
      state = state.copyWith(
        status: CartStatus.ready,
        cart: cart,
        clearError: true,
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        status: CartStatus.failure,
        errorMessage: await _messageFor(error),
      );
    } catch (_) {
      state = state.copyWith(
        status: CartStatus.failure,
        errorMessage: '购物车暂时无法加载',
      );
    }
  }

  Future<bool> addItem({required int bookId, int quantity = 1}) {
    return _runBookAction(
      bookId,
      () => _repository.addItem(bookId: bookId, quantity: quantity),
    );
  }

  Future<bool> addBundle(int bundleId) async {
    if (state.isBusy) {
      return false;
    }
    state = state.copyWith(busyAll: true, clearError: true);
    try {
      final cart = await _repository.addBundle(bundleId);
      state = state.copyWith(
        status: CartStatus.ready,
        cart: cart,
        busyAll: false,
        clearError: true,
      );
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        busyAll: false,
        errorMessage: await _messageFor(error),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        busyAll: false,
        errorMessage: '加入组合包失败，请稍后再试',
      );
      return false;
    }
  }
  Future<bool> updateQuantity(CartItem item, int quantity) {
    if (quantity < 1 || quantity > item.stock || quantity > 999) {
      return Future.value(false);
    }
    return _runBookAction(
      item.bookId,
      () => _repository.updateItem(item.bookId, quantity: quantity),
    );
  }

  Future<bool> toggleItem(CartItem item) {
    return _runBookAction(
      item.bookId,
      () => _repository.updateItem(item.bookId, selected: !item.selected),
    );
  }

  Future<bool> removeItem(CartItem item) {
    return _runBookAction(
      item.bookId,
      () => _repository.removeItem(item.bookId),
    );
  }

  Future<bool> toggleAll() async {
    if (state.isBusy || state.cart.items.isEmpty) {
      return false;
    }
    state = state.copyWith(busyAll: true, clearError: true);
    try {
      final cart = await _repository.updateSelection(!state.cart.allSelected);
      state = state.copyWith(
        cart: cart,
        busyAll: false,
        status: CartStatus.ready,
        clearError: true,
      );
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        busyAll: false,
        errorMessage: await _messageFor(error),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        busyAll: false,
        errorMessage: '更新全选状态失败，请稍后再试',
      );
      return false;
    }
  }

  Future<bool> removeSelected() async {
    if (state.isBusy || state.cart.selectedItems.isEmpty) {
      return false;
    }
    state = state.copyWith(busyAll: true, clearError: true);
    try {
      await _repository.removeSelected();
      final cart = await _repository.getCart();
      state = state.copyWith(
        cart: cart,
        busyAll: false,
        status: CartStatus.ready,
        clearError: true,
      );
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        busyAll: false,
        errorMessage: await _messageFor(error),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        busyAll: false,
        errorMessage: '删除已选商品失败，请稍后再试',
      );
      return false;
    }
  }

  Future<void> refreshAfterOrder() async {
    try {
      final cart = await _repository.getCart();
      state = state.copyWith(
        status: CartStatus.ready,
        cart: cart,
        busyAll: false,
        busyBookIds: const {},
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        status: CartStatus.initial,
        cart: ShoppingCart.empty,
        busyAll: false,
        busyBookIds: const {},
      );
    }
  }

  Future<bool> _runBookAction(
    int bookId,
    Future<Object?> Function() action,
  ) async {
    if (state.isBusy) {
      return false;
    }
    state = state.copyWith(
      busyBookIds: {...state.busyBookIds, bookId},
      clearError: true,
    );
    try {
      await action();
      final cart = await _repository.getCart();
      final nextBusy = {...state.busyBookIds}..remove(bookId);
      state = state.copyWith(
        status: CartStatus.ready,
        cart: cart,
        busyBookIds: nextBusy,
        clearError: true,
      );
      return true;
    } on ApiException catch (error) {
      final nextBusy = {...state.busyBookIds}..remove(bookId);
      state = state.copyWith(
        busyBookIds: nextBusy,
        errorMessage: await _messageFor(error),
      );
      return false;
    } catch (_) {
      final nextBusy = {...state.busyBookIds}..remove(bookId);
      state = state.copyWith(
        busyBookIds: nextBusy,
        errorMessage: '购物车操作失败，请稍后再试',
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
      return error.message.isEmpty ? '库存或商品状态已发生变化' : error.message;
    }
    if (error.message == 'Unable to connect to the server') {
      return '暂时无法连接服务，请确认后端已经启动';
    }
    return error.message;
  }
}

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(apiClientProvider));
});

final cartControllerProvider =
    StateNotifierProvider<CartController, CartState>((ref) {
  return CartController(
    repository: ref.watch(cartRepositoryProvider),
    authController: ref.watch(authControllerProvider.notifier),
  );
});
