import 'package:jinja/src/context.dart';
import 'package:jinja/src/namespace.dart';
import 'package:jinja/src/utils.dart';

export 'package:jinja/src/filters.dart' show filters;
export 'package:jinja/src/tests.dart' show tests;

const Map<String, Object?> globals = <String, Object?>{
  'namespace': Namespace.factory,
  'list': list,
  'print': print,
  'range': range,
};

Object finalize(Context context, Object? value) {
  return value ?? '';
}

Object? getItem(dynamic object, Object? item) {
  try {
    // TODO: dynamic invocation
    // ignore: avoid_dynamic_calls
    return object[item];
  } on NoSuchMethodError {
    if (object == null) {
      rethrow;
    }

    return null;
  }
}
