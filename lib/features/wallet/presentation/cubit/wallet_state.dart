abstract class WalletState {
  const WalletState();
}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletLoaded extends WalletState {
  final double walletBalance;
  final String selectedPaymentMethod;
  final List<Map<String, dynamic>> transactions;

  const WalletLoaded({
    required this.walletBalance,
    required this.selectedPaymentMethod,
    required this.transactions,
  });
}

class WalletError extends WalletState {
  final String message;

  const WalletError(this.message);
}
