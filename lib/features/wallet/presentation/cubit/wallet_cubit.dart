import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'wallet_state.dart';

class WalletCubit extends Cubit<WalletState> {
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription? _userSubscription;

  WalletCubit() : super(WalletInitial());

  void loadWalletData(String uid) {
    emit(WalletLoading());
    _userSubscription?.cancel();

    _userSubscription = _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .listen((userList) async {
      if (userList.isNotEmpty) {
        final data = Map<String, dynamic>.from(userList.first);
        final rawBal = data['wallet_balance'] ?? data['walletBalance'];
        final double balance = (rawBal is num) ? rawBal.toDouble() : (double.tryParse(rawBal?.toString() ?? '0') ?? 0.0);
        final String selectedMethod = data['selected_payment_method'] ?? data['selectedPaymentMethod'] ?? 'كاش';

        List<Map<String, dynamic>> txList = [];
        try {
          final queryRes = await _supabase
              .from('transactions')
              .select()
              .eq('user_id', uid);

          final docs = List<Map<String, dynamic>>.from(queryRes as List);
          docs.sort((a, b) {
            final aTime = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
            final bTime = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
            return bTime.compareTo(aTime);
          });

          txList = docs.map((tData) {
            final dateObj = DateTime.tryParse(tData['created_at'] ?? '') ?? DateTime.now();
            final rawAmt = tData['amount'];
            final double amt = (rawAmt is num) ? rawAmt.toDouble() : (double.tryParse(rawAmt?.toString() ?? '0') ?? 0.0);
            return {
              'id': tData['id'],
              'amount': amt,
              'type': tData['type'] ?? 'payment',
              'description': tData['title'] ?? tData['description'] ?? '',
              'date': '${dateObj.year}-${dateObj.month}-${dateObj.day}',
            };
          }).toList();
        } catch (_) {}

        emit(WalletLoaded(
          walletBalance: balance,
          selectedPaymentMethod: selectedMethod,
          transactions: txList,
        ));
      } else {
        emit(const WalletLoaded(walletBalance: 250.00, selectedPaymentMethod: 'كاش', transactions: []));
      }
    }, onError: (e) {
      emit(WalletError(e.toString()));
    });
  }

  Future<void> depositFunds(String uid, double amount) async {
    try {
      final userRes = await _supabase.from('users').select('wallet_balance').eq('id', uid).single();
      final balance = ((userRes['wallet_balance']) as num? ?? 0.0).toDouble() + amount;
      await _supabase.from('users').update({'wallet_balance': balance}).eq('id', uid);
      await _supabase.from('transactions').insert({
        'user_id': uid,
        'title': 'شحن رصيد المحفظة',
        'amount': amount,
        'type': 'deposit',
        'balance_after': balance,
      });
    } catch (_) {}
  }

  Future<void> selectPaymentMethod(String uid, String method) async {
    try {
      await _supabase.from('users').update({
        'selected_payment_method': method,
      }).eq('id', uid);
    } catch (_) {}
  }

  void reset() {
    _userSubscription?.cancel();
    emit(WalletInitial());
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    return super.close();
  }
}
