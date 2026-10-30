/// Maps an empty D-Bus string onto `null`.
String? optional(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return value;
}

/// Reads a mandatory string out of a JSON object.
String readString(Object? value) {
  if (value is String) {
    return value;
  }
  throw FormatException('expected a string, received ${value.runtimeType}');
}

/// Reads a mandatory integer out of a JSON object.
int readInt(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('expected a number, received ${value.runtimeType}');
}

/// Reads a number that the service serializes as an `f32`.
double readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('expected a number, received ${value.runtimeType}');
}

/// Reads a nested object out of a JSON payload.
Map<String, dynamic> readMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw FormatException('expected an object, received ${value.runtimeType}');
}
