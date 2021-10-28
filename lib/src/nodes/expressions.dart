part of '../nodes.dart';

enum AssignContext {
  load,
  store,
  parameter,
}

mixin Assignable on Expression {
  bool get canAssign;

  abstract AssignContext context;
}

class Name extends Expression implements Assignable {
  Name(this.name, {this.context = AssignContext.load});

  String name;

  @override
  AssignContext context;

  @override
  bool get canAssign {
    return context == AssignContext.store;
  }

  @override
  Object? asConst(Context context) {
    throw Impossible();
  }

  @override
  Object? resolve(Context context) {
    switch (this.context) {
      case AssignContext.load:
        return context.resolve(name);
      case AssignContext.store:
      case AssignContext.parameter:
        return name;
    }
  }

  @override
  String toString() {
    return context == AssignContext.load
        ? 'Name($name)'
        : 'Name($name, $context)';
  }
}

class NamespaceRef extends Expression {
  NamespaceRef(this.name, this.attribute);

  String name;

  String attribute;

  @override
  NamespaceValue resolve(Context context) {
    return NamespaceValue(name, attribute);
  }

  @override
  String toString() {
    return 'NamespaceRef($name, $attribute)';
  }
}

abstract class Literal extends Expression {}

class Constant extends Literal {
  Constant(this.value);

  Object? value;

  @override
  Object? asConst(Context context) {
    return value;
  }

  @override
  Object? resolve(Context context) {
    return value;
  }

  @override
  String toString() {
    return 'Constant(${repr(value, true)})';
  }
}

class Tuple extends Literal implements Assignable {
  Tuple(this.values, [AssignContext? context]) {
    context = context ?? AssignContext.load;
  }

  List<Expression> values;

  @override
  AssignContext get context {
    if (values.isEmpty) {
      return AssignContext.load;
    }

    var first = values.first;
    return first is Assignable ? first.context : AssignContext.load;
  }

  @override
  set context(AssignContext context) {
    if (values.isEmpty) {
      return;
    }

    for (var value in values) {
      if (value is! Assignable) {
        throw TypeError();
      }

      value.context = context;
    }
  }

  @override
  bool get canAssign {
    return values.every((value) => value is Assignable && !value.canAssign);
  }

  @override
  List<Node> get childrens {
    return values;
  }

  @override
  List<Object?> asConst(Context context) {
    return List<Object?>.generate(
        values.length, (index) => values[index].asConst(context));
  }

  @override
  List<Object?> resolve(Context context) {
    return List<Object?>.generate(
        values.length, (index) => values[index].resolve(context));
  }

  @override
  String toString() {
    return 'Tuple(${values.join(', ')})';
  }
}

class Array extends Literal {
  Array(this.values);

  List<Expression> values;

  @override
  List<Node> get childrens {
    return values;
  }

  @override
  List<Object?> asConst(Context context) {
    return List<Object?>.generate(
        values.length, (index) => values[index].asConst(context));
  }

  @override
  List<Object?> resolve(Context context) {
    return List<Object?>.generate(
        values.length, (index) => values[index].resolve(context));
  }

  @override
  String toString() {
    return 'Array(${values.join(', ')})';
  }
}

class Pair extends Expression {
  Pair(this.key, this.value);

  Expression key;

  Expression value;

  @override
  List<Node> get childrens {
    return <Node>[key, value];
  }

  @override
  MapEntry<Object?, Object?> asConst(Context context) {
    return MapEntry<Object?, Object?>(
        key.asConst(context), value.asConst(context));
  }

  @override
  MapEntry<Object?, Object?> resolve(Context context) {
    return MapEntry<Object?, Object?>(
        key.resolve(context), value.resolve(context));
  }
}

class Dict extends Literal {
  Dict(this.pairs);

  List<Pair> pairs;

  @override
  List<Node> get childrens {
    return <Node>[for (var pair in pairs) ...pair.childrens];
  }

  @override
  Map<Object?, Object?> asConst(Context context) {
    return Map<Object?, Object?>.fromEntries(
        pairs.map<MapEntry<Object?, Object?>>((pair) => pair.asConst(context)));
  }

  @override
  Map<Object?, Object?> resolve(Context context) {
    return Map<Object?, Object?>.fromEntries(
        pairs.map<MapEntry<Object?, Object?>>((pair) => pair.resolve(context)));
  }

  @override
  String toString() {
    return 'Dict(${pairs.join(', ')})';
  }
}

class Condition extends Expression {
  Condition(this.test, this.value, [this.orElse]);

  Expression test;

  Expression value;

  Expression? orElse;

  @override
  List<Node> get childrens {
    return <Node>[test, value, if (orElse != null) orElse!];
  }

  @override
  Object? asConst(Context context) {
    if (boolean(test.asConst(context))) {
      return value.asConst(context);
    }

    return orElse?.asConst(context);
  }

  @override
  Object? resolve(Context context) {
    if (boolean(test.resolve(context))) {
      return value.resolve(context);
    }

    return orElse?.resolve(context);
  }

  @override
  String toString() {
    return orElse == null
        ? 'Condition($test, $value)'
        : 'Condition($test, $value, $orElse)';
  }
}

typedef Callback<T> = T Function(List<Object?>, Map<Symbol, Object?>);

class Keyword extends Expression {
  Keyword(this.key, this.value);

  String key;

  Expression value;

  @override
  List<Node> get childrens {
    return <Node>[value];
  }

  @override
  Object? asConst(Context context) {
    return value.asConst(context);
  }

  @override
  Object? resolve(Context context) {
    return value.resolve(context);
  }

  Pair toPair() {
    return Pair(Constant(key), value);
  }

  @override
  String toString() {
    return 'Keyword($key, $value)';
  }
}

class Callable extends Expression {
  Callable({this.arguments, this.keywords, this.dArguments, this.dKeywords});

  List<Expression>? arguments;

  List<Keyword>? keywords;

  Expression? dArguments;

  Expression? dKeywords;

  @override
  List<Node> get childrens {
    return <Node>[
      ...?arguments,
      ...?keywords,
      if (dArguments != null) dArguments!,
      if (dKeywords != null) dKeywords!
    ];
  }

  Object? applyAsConst(Context context, Callback<Object?> callback) {
    var arguments = this.arguments;
    List<Object?> positional;

    if (arguments == null) {
      positional = <Object?>[];
    } else {
      positional = arguments
          .map<Object?>((argument) => argument.asConst(context))
          .toList();
    }

    var named = <Symbol, Object?>{};
    var keywords = this.keywords;

    if (keywords != null) {
      for (var argument in keywords) {
        named[Symbol(argument.key)] = argument.asConst(context);
      }
    }

    var dArguments = this.dArguments;

    if (dArguments != null) {
      positional.addAll(dArguments.asConst(context) as Iterable<Object?>);
    }

    var dKeywords = this.dKeywords;

    if (dKeywords != null) {
      var resolvedKeywords = dKeywords.asConst(context);

      if (resolvedKeywords is! Map) {
        throw TypeError();
      }

      resolvedKeywords.cast<String, Object?>().forEach((key, value) {
        named[Symbol(key)] = value;
      });
    }

    return callback(positional, named);
  }

  T apply<T extends Object?>(Context context, Callback<T> callback) {
    var arguments = this.arguments;
    List<Object?> positional;

    if (arguments == null) {
      positional = <Object?>[];
    } else {
      positional = arguments
          .map<Object?>((argument) => argument.resolve(context))
          .toList();
    }

    var named = <Symbol, Object?>{};
    var keywords = this.keywords;

    if (keywords != null) {
      for (var argument in keywords) {
        named[Symbol(argument.key)] = argument.resolve(context);
      }
    }

    var dArguments = this.dArguments;

    if (dArguments != null) {
      positional.addAll(dArguments.resolve(context) as Iterable<Object?>);
    }

    var dKeywords = this.dKeywords;

    if (dKeywords != null) {
      var resolvedKeywords = dKeywords.resolve(context);

      if (resolvedKeywords is! Map) {
        throw TypeError();
      }

      resolvedKeywords.cast<String, Object?>().forEach((key, value) {
        named[Symbol(key)] = value;
      });
    }

    return callback(positional, named);
  }

  String printArguments({bool comma = false}) {
    var result = '';
    var arguments = this.arguments;

    if (arguments != null && arguments.isNotEmpty) {
      if (comma) {
        result = '$result, ';
      } else {
        comma = true;
      }

      result = '$result${arguments.join(', ')}';
    }

    var keywords = this.keywords;

    if (keywords != null && keywords.isNotEmpty) {
      if (comma) {
        result = '$result, ';
      } else {
        comma = true;
      }

      result = '$result${keywords.join(', ')}';
    }

    if (dArguments != null) {
      if (comma) {
        result = '$result, ';
      } else {
        comma = true;
      }

      result = '$result*$dArguments';
    }

    if (dKeywords != null) {
      if (comma) {
        result = '$result, ';
      }

      result = '$result**$dKeywords';
    }

    return result;
  }
}

class Call extends Callable {
  Call(this.expression,
      {List<Expression>? arguments,
      List<Keyword>? keywords,
      Expression? dArguments,
      Expression? dKeywords})
      : super(
            arguments: arguments,
            keywords: keywords,
            dArguments: dArguments,
            dKeywords: dKeywords);

  Expression expression;

  @override
  List<Node> get childrens {
    return <Node>[expression, ...super.childrens];
  }

  @override
  Object? asConst(Context context) {
    var function = expression.asConst(context);
    return applyAsConst(context, (positional, named) {
      return context(function, positional, named);
    });
  }

  @override
  Object? resolve(Context context) {
    var function = expression.resolve(context);
    return apply(context, (positional, named) {
      return context(function, positional, named);
    });
  }

  @override
  String toString() {
    return 'Call($expression${printArguments(comma: true)})';
  }
}

class Filter extends Callable {
  Filter(this.name,
      {Expression? expression,
      List<Expression>? arguments,
      List<Keyword>? keywords,
      Expression? dArguments,
      Expression? dKeywords})
      // TODO: remove after better null safety promotion
      // ignore: prefer_initializing_formals
      : expression = expression,
        super(
            arguments: arguments,
            keywords: keywords,
            dArguments: dArguments,
            dKeywords: dKeywords) {
    if (expression != null) {
      if (arguments == null) {
        arguments = <Expression>[expression];
      } else {
        arguments.add(expression);
      }
    }
  }

  String name;

  Expression? expression;

  @override
  Object? asConst(Context context) {
    throw Impossible();
  }

  @override
  Object? resolve(Context context) {
    return apply(context, (positional, named) {
      return context.environment.callFilter(name, positional, named, context);
    });
  }

  @override
  String toString() {
    return 'Filter.$name(${printArguments()})';
  }
}

class Test extends Callable {
  Test(this.name,
      {List<Expression>? arguments,
      List<Keyword>? keywords,
      Expression? dArguments,
      Expression? dKeywords})
      : super(
            arguments: arguments,
            keywords: keywords,
            dArguments: dArguments,
            dKeywords: dKeywords);

  String name;

  @override
  Object? asConst(Context context) {
    if (!context.environment.tests.containsKey(name)) {
      throw Impossible();
    }

    return applyAsConst(context, (positional, named) {
      return context.environment.callTest(name, positional, named);
    });
  }

  @override
  bool resolve(Context context) {
    return apply<bool>(context, (positional, named) {
      return context.environment.callTest(name, positional, named);
    });
  }

  @override
  String toString() {
    return 'Test.$name(${printArguments()})';
  }
}

class Item extends Expression {
  Item(this.key, this.value);

  Expression key;

  Expression value;

  @override
  List<Node> get childrens {
    return <Node>[key, value];
  }

  @override
  Object? asConst(Context context) {
    var key = this.key.asConst(context);
    var value = this.value.asConst(context);
    return context.environment.getItem(value, key);
  }

  @override
  Object? resolve(Context context) {
    var key = this.key.resolve(context);
    var value = this.value.resolve(context);
    return context.environment.getItem(value, key);
  }

  @override
  String toString() {
    return 'Item($key, $value)';
  }
}

class Attribute extends Expression {
  Attribute(this.attribute, this.value);

  String attribute;

  Expression value;

  @override
  List<Node> get childrens {
    return <Node>[value];
  }

  @override
  Object? asConst(Context context) {
    var value = this.value.asConst(context);
    return context.environment.getAttribute(value, attribute);
  }

  @override
  Object? resolve(Context context) {
    var value = this.value.resolve(context);
    return context.environment.getAttribute(value, attribute);
  }

  @override
  String toString() {
    return 'Attribute($attribute, $value)';
  }
}

class Concat extends Expression {
  Concat(this.values);

  List<Expression> values;

  @override
  List<Node> get childrens {
    return values;
  }

  @override // TODO: try reduce operands if imposible
  Object? asConst(Context context) {
    return values.map<Object?>((value) => value.asConst(context)).join();
  }

  @override
  String resolve(Context context) {
    var buffer = StringBuffer();

    for (var expression in values) {
      buffer.write(expression.resolve(context));
    }

    return '$buffer';
  }

  @override
  String toString() {
    return 'Concat(${values.join(', ')})';
  }
}

class Operand extends Expression {
  Operand(this.operator, this.value);

  String operator;

  Expression value;

  @override
  List<Node> get childrens {
    return <Node>[value];
  }

  @override
  Object? asConst(Context context) {
    return value.asConst(context);
  }

  @override
  Object? resolve(Context context) {
    return value.resolve(context);
  }

  @override
  String toString() {
    return 'Operand(\'$operator\', $value)';
  }
}

class Compare extends Expression {
  Compare(this.value, this.operands);

  Expression value;

  List<Operand> operands;

  @override
  List<Node> get childrens {
    return <Node>[value, ...operands];
  }

  @override // TODO: try reduce operands if imposible
  Object? asConst(Context context) {
    var temp = value.asConst(context);

    for (var operand in operands) {
      if (!calc(operand.operator, temp, temp = operand.asConst(context))) {
        return false;
      }
    }

    return true;
  }

  @override
  Object? resolve(Context context) {
    var temp = value.resolve(context);

    for (var operand in operands) {
      if (!calc(operand.operator, temp, temp = operand.resolve(context))) {
        return false;
      }
    }

    return true;
  }

  @override
  String toString() {
    return 'Compare($value, $operands)';
  }

  static bool calc(String operator, Object? left, Object? right) {
    switch (operator) {
      case 'eq':
        return tests.isEqual(left, right);
      case 'ne':
        return tests.isNotEqual(left, right);
      case 'lt':
        return tests.isLessThan(left, right);
      case 'lteq':
        return tests.isLessThanOrEqual(left, right);
      case 'gt':
        return tests.isGreaterThan(left, right);
      case 'gteq':
        return tests.isGreaterThanOrEqual(left, right);
      case 'in':
        return tests.isIn(left, right);
      case 'notin':
        return !tests.isIn(left, right);
      default:
        // TODO: update error
        throw UnimplementedError(operator);
    }
  }
}

class Unary extends Expression {
  Unary(this.operator, this.value);

  String operator;

  Expression value;

  @override
  List<Node> get childrens {
    return <Node>[value];
  }

  @override
  Object? asConst(Context context) {
    try {
      return calc(operator, value.asConst(context));
    } catch (error) {
      throw Impossible();
    }
  }

  @override
  Object? resolve(Context context) {
    return calc(operator, value.resolve(context));
  }

  @override
  String toString() {
    return 'Unary(\'$operator\', $value)';
  }

  static Object? calc(String operator, dynamic value) {
    switch (operator) {
      case '+':
        // how i should implement this?
        return value;
      case '-':
        return -value;
      case 'not':
        return !boolean(value);
      default:
        // TODO: update error
        throw UnimplementedError();
    }
  }
}

class Binary extends Expression {
  Binary(this.operator, this.left, this.right);

  String operator;

  Expression left;

  Expression right;

  @override
  List<Node> get childrens {
    return <Node>[left, right];
  }

  @override
  Object? asConst(Context context) {
    try {
      return calc(operator, left.asConst(context), right.asConst(context));
    } catch (error) {
      throw Impossible();
    }
  }

  @override
  Object? resolve(Context context) {
    return calc(operator, left.resolve(context), right.resolve(context));
  }

  @override
  String toString() {
    return 'Binary(\'$operator\', $left, $right)';
  }

  static Object? calc(String operator, dynamic left, dynamic right) {
    switch (operator) {
      case '**':
        return math.pow(left as num, right as num);
      case '%':
        return left % right;
      case '//':
        return left ~/ right;
      case '/':
        return left / right;
      case '*':
        return left * right;
      case '-':
        return left - right;
      case '+':
        return left + right;
      case 'or':
        return boolean(left) ? left : right;
      case 'and':
        return boolean(left) ? right : left;
      default:
        // TODO: update error
        throw UnimplementedError();
    }
  }
}
