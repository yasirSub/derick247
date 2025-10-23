import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Future<void> saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> saveInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  Future<int?> getInt(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key);
  }

  Future<void> saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }

  Future<void> saveList(String key, List<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value);
  }

  Future<List<String>?> getList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key);
  }

  Future<void> saveMap(String key, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  Future<Map<String, dynamic>?> getMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(key);
    if (value != null) {
      return jsonDecode(value) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Cart specific methods
  Future<void> saveCartItems(List<Map<String, dynamic>> cartItems) async {
    await saveMap('cart_items', {'items': cartItems});
  }

  Future<List<Map<String, dynamic>>> getCartItems() async {
    final cartData = await getMap('cart_items');
    if (cartData != null && cartData['items'] != null) {
      return List<Map<String, dynamic>>.from(cartData['items']);
    }
    return [];
  }

  Future<void> clearCart() async {
    await remove('cart_items');
  }

  // User preferences
  Future<void> saveUserPreference(String key, dynamic value) async {
    if (value is String) {
      await saveString('pref_$key', value);
    } else if (value is int) {
      await saveInt('pref_$key', value);
    } else if (value is bool) {
      await saveBool('pref_$key', value);
    }
  }

  Future<T?> getUserPreference<T>(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (T == String) {
      return prefs.getString('pref_$key') as T?;
    } else if (T == int) {
      return prefs.getInt('pref_$key') as T?;
    } else if (T == bool) {
      return prefs.getBool('pref_$key') as T?;
    }
    return null;
  }
}
