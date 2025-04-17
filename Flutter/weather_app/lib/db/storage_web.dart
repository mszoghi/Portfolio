import 'dart:js_interop';
import 'dart:js_util' as js_util;

@JS('localStorage')
external JSObject get localStorage;

String? getLocalStorageItem(String key) {
  try {
    return js_util.callMethod(localStorage, 'getItem', [key]) as String?;
  } catch (e) {
    print('Error reading from localStorage: $e');
    return null;
  }
}

void setLocalStorageItem(String key, String value) {
  try {
    js_util.callMethod(localStorage, 'setItem', [key, value]);
  } catch (e) {
    // Common localStorage errors: QuotaExceededError, SecurityError, etc.
    print('Error writing to localStorage: $e');
    rethrow; // Re-throw the error so the caller can handle it if needed
  }
}