/// SafeMap工具类
/// 
/// 提供安全的Map访问方法，避免空指针异常
class SafeMapValue {
  final dynamic _value;
  
  SafeMapValue(this._value);
  
  /// 获取布尔值
  bool get boolean => _value is bool ? _value : false;
  
  /// 获取整数值
  int get integer => _value is int ? _value : 0;
  
  /// 获取字符串值
  String get string => _value?.toString() ?? '';
  
  /// 获取双精度值
  double get doubleValue => _value is double ? _value : 0.0;
  
  /// 获取原始值
  dynamic get value => _value;
}

/// SafeMap构造函数
SafeMapValue SafeMap(Map<dynamic, dynamic>? map) {
  return SafeMapValue(map);
}

/// SafeMap扩展，支持链式调用
extension SafeMapExtension on SafeMapValue {
  SafeMapValue operator [](dynamic key) {
    if (_value is Map) {
      final map = _value;
      return SafeMapValue(map[key]);
    }
    return SafeMapValue(null);
  }
}