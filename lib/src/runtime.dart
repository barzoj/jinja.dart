import 'utils.dart' show getSymbolName;

/// The default undefined type.
class Undefined {
  const Undefined();

  void call() {}

  @override
  String toString() => '';
}

class NameSpace {
  static final Function namespace = _NameSpaceFactory();

  NameSpace([Map<String, Object> data]) : data = data != null ? Map<String, Object>.of(data) : <String, Object>{};

  final Map<String, Object> data;
  Iterable<MapEntry<String, Object>> get entries => data.entries;

  Object operator [](String key) => data[key];

  void operator []=(String key, Object value) {
    data[key] = value;
  }

  @override
  Object noSuchMethod(Invocation invocation) {
    var name = invocation.memberName.toString().substring(0);

    if (invocation.isSetter) {
      // 'name='
      name = name.substring(0, name.length - 1);
      data[name] = invocation.positionalArguments.first;
      return null;
    }

    if (data.containsKey(name)) {
      if (invocation.isGetter) return data[name];

      if (invocation.isMethod) {
        return Function.apply(data[name] as Function, invocation.positionalArguments, invocation.namedArguments);
      }
    }

    return super.noSuchMethod(invocation);
  }
}

// TODO: remove deprecated
// ignore: deprecated_extends_function
class _NameSpaceFactory extends Function {
  NameSpace call() => NameSpace();

  @override
  Object noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #call) {
      var data = <String, Object>{};

      if (invocation.positionalArguments.length == 1) {
        Object arg = invocation.positionalArguments.first;

        if (arg is Map<String, Object>) {
          data.addAll(arg);
        } else if (arg is List<Object>) {
          for (var i = 0; i < arg.length; i++) {
            var pair = arg[i];
            List<Object> list;

            if (pair is Iterable<Object>) {
              list = pair.toList();
            } else if (pair is String) {
              list = pair.split('');
            } else {
              throw ArgumentError('cannot convert map update sequence '
                  'element #$i to a sequence');
            }

            if (list.length < 2 || list.length > 2) {
              throw ArgumentError('map update sequence element #$i, '
                  'has length ${list.length}; 2 is required');
            }

            if (list[0] is String) data[list[0] as String] = list[1];
          }
        } else {
          throw TypeError();
        }
      } else if (invocation.positionalArguments.length > 1) {
        throw ArgumentError('map expected at most 1 arguments, '
            'got ${invocation.positionalArguments.length}');
      }

      data.addAll(invocation.namedArguments
          .map<String, Object>((Symbol key, Object value) => MapEntry<String, Object>(getSymbolName(key), value)));
      return NameSpace(data);
    }

    return super.noSuchMethod(invocation);
  }
}

class LoopContext {
  LoopContext(int index0, int length, Object previtem, Object nextitem, Function changed)
      : data = <String, Object>{
          'index0': index0,
          'length': length,
          'previtem': previtem,
          'nextitem': nextitem,
          'changed': changed,
          'index': index0 + 1,
          'first': index0 == 0,
          'last': index0 + 1 == length,
          'revindex': length - index0,
          'revindex0': length - index0 - 1,
          'cycle': _CycleWrapper((List<Object> args) => args[index0 % args.length]),
        };

  final Map<String, Object> data;

  Object operator [](String key) => data[key];
}

// TODO: remove deprecated
// ignore: deprecated_extends_function
class _CycleWrapper extends Function {
  _CycleWrapper(this.function);

  final Object Function(List<Object> values) function;

  Object call();

  @override
  Object noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #call) {
      return function(invocation.positionalArguments);
    }

    return super.noSuchMethod(invocation);
  }
}
