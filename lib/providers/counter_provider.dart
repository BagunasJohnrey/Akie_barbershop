import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CounterProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> todayTransactions = [];
  bool isLoadingTransactions = true;
  int globalPrice = 100; // Dynamic price from Settings
  
  bool isShopClosed = false; // Flags if the shop has already been closed for today

  String _appPin = "1234"; 
  String get appPin => _appPin;

  CounterProvider() {
    fetchTodayTransactions();
    fetchAppPin(); 
  }

  // --- 1. SETTINGS & SECURITY ---
  Future<void> fetchAppPin() async {
    try {
      final data = await _supabase.from('app_settings').select('pin').eq('id', 1).single();
      _appPin = data['pin'];
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching PIN: $e");
    }
  }

  Future<void> updateAppPin(String newPin) async {
    try {
      await _supabase.from('app_settings').update({'pin': newPin}).eq('id', 1);
      _appPin = newPin;
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating PIN: $e");
    }
  }

  void updateGlobalPrice(int newPrice) {
    globalPrice = newPrice;
    notifyListeners();
  }

  // --- 2. BARBER MANAGEMENT ---
  Future<void> addBarber(String name, String dayOff) async {
    try {
      await _supabase.from('barbers').insert({'name': name, 'day_off': dayOff, 'is_active': true, 'is_absent': false});
      notifyListeners();
    } catch (e) {
      debugPrint("Error adding barber: $e");
    }
  }

  Future<void> updateBarber(String id, String newName, String newDayOff, bool isAbsent) async {
    try {
      await _supabase.from('barbers').update({'name': newName, 'day_off': newDayOff, 'is_absent': isAbsent}).eq('id', id);
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating barber: $e");
    }
  }

  Future<void> deleteBarber(String id) async {
    try {
      await _supabase.from('barbers').update({'is_active': false}).eq('id', id);
      notifyListeners();
    } catch (e) {
      debugPrint("Error deleting barber: $e");
    }
  }

  bool isBarberAvailable(barber) {
    if (barber.isAbsent) return false;
    String today = DateFormat('EEEE').format(DateTime.now());
    return barber.dayOff.toLowerCase() != today.toLowerCase();
  }

  // --- 3. TRANSACTION LOGIC ---
  Future<void> fetchTodayTransactions() async {
    final now = DateTime.now();
    final startOfDayUtc = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    final todayDate = now.toIso8601String().split('T')[0];

    try {
      // 1. Check if the shop was already closed today by looking for a report
      final report = await _supabase.from('daily_reports').select('id').eq('date', todayDate).maybeSingle();
      isShopClosed = report != null;

      // 2. Fetch the transactions
      final data = await _supabase.from('transactions').select().gte('created_at', startOfDayUtc);
      
      // 3. If the shop is closed, keep the board at zero. Otherwise, load them.
      if (isShopClosed) {
        todayTransactions = [];
      } else {
        todayTransactions = List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint("Error fetching transactions: $e");
    } finally {
      isLoadingTransactions = false;
      notifyListeners();
    }
  }

  Future<void> incrementWalkIn(String barberId) async {
    if (isShopClosed) return; // Extra safety check

    todayTransactions = [...todayTransactions, {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}', 
      'barber_id': barberId, 'price': globalPrice, 'created_at': DateTime.now().toUtc().toIso8601String(),
    }];
    notifyListeners(); 
    try {
      await _supabase.from('transactions').insert({'barber_id': barberId, 'price': globalPrice});
      await fetchTodayTransactions(); 
    } catch (e) {
      todayTransactions.removeWhere((t) => t['id'].toString().startsWith('temp_'));
      notifyListeners();
    }
  }

  // --- 4. EXPENSE LOGIC ---
  Future<void> addExpense(int amount, String category, String description) async {
    try {
      await _supabase.from('expenses').insert({
        'amount': amount, 'category': category, 'description': description,
        'date': DateTime.now().toUtc().toIso8601String(),
      });
      notifyListeners(); 
    } catch (e) {
      debugPrint("Error adding expense: $e");
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await _supabase.from('expenses').delete().eq('id', id);
      notifyListeners(); 
    } catch (e) {
      debugPrint("Error deleting expense: $e");
    }
  }

  Future<void> closeDay() async {
    try {
      final totalWalkIns = todayTransactions.length;
      final totalRevenue = totalWalkIns * globalPrice.toDouble();

      // 1. Group the counts by barber for the JSON report
      Map<String, int> barberCounts = {};
      for (var t in todayTransactions) {
        String barberId = t['barber_id'];
        barberCounts[barberId] = (barberCounts[barberId] ?? 0) + 1;
      }

      // 2. Get today's date formatted as YYYY-MM-DD
      final todayDate = DateTime.now().toIso8601String().split('T')[0];

      // 3. Save the summary to the daily_reports table in Supabase
      await _supabase.from('daily_reports').insert({
        'date': todayDate,
        'total_clients': totalWalkIns,
        'total_revenue': totalRevenue,
        'barber_stats': barberCounts, // Saves as JSONB
      });

      // 4. Clear the local list and lock the shop for the night
      todayTransactions.clear();
      isShopClosed = true;
      notifyListeners();

    } catch (e) {
      debugPrint("Error closing day: $e");
      rethrow; 
    }
  }

  // NEW REOPEN METHOD
  Future<void> reopenDay() async {
    try {
      final todayDate = DateTime.now().toIso8601String().split('T')[0];
      
      // 1. Delete today's archived summary from Supabase
      await _supabase.from('daily_reports').delete().eq('date', todayDate);
      
      // 2. Refetch transactions (this automatically sets isShopClosed = false and restores data!)
      await fetchTodayTransactions();

    } catch (e) {
      debugPrint("Error reopening day: $e");
      rethrow; 
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllExpenses() async {
    try {
      final data = await _supabase.from('expenses').select().order('date', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  // --- 5. ANALYTICS FETCHING ---
  Future<List<Map<String, dynamic>>> fetchTransactionsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day).toUtc().toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toUtc().toIso8601String();
    final data = await _supabase.from('transactions').select().gte('created_at', startOfDay).lte('created_at', endOfDay);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> fetchExpensesForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day).toUtc().toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toUtc().toIso8601String();
    final data = await _supabase.from('expenses').select().gte('date', startOfDay).lte('date', endOfDay);
    return List<Map<String, dynamic>>.from(data);
  }
}