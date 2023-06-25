import 'package:jinja/src/visitor.dart';

part 'nodes/expressions.dart';
part 'nodes/statements.dart';

abstract final class Node {
  const Node();

  R accept<C, R>(Visitor<C, R> visitor, C context);

  Node copyWith();

  Iterable<T> findAll<T extends Node>() sync* {}
}

final class Data extends Node {
  const Data({this.data = ''});

  final String data;

  bool get isLeaf {
    return trimmed.isEmpty;
  }

  String get literal {
    return '"${data.replaceAll('"', r'\"').replaceAll('\r\n', r'\n').replaceAll('\n', r'\n')}"';
  }

  String get trimmed {
    return data.trim();
  }

  @override
  R accept<C, R>(Visitor<C, R> visitor, C context) {
    return visitor.visitData(this, context);
  }

  @override
  Data copyWith({String? data}) {
    return Data(data: data ?? this.data);
  }
}

abstract final class Expression extends Node {
  const Expression();
}

abstract final class Statement extends Node {
  const Statement();
}

final class Interpolation extends Node {
  const Interpolation({required this.value});

  final Expression value;

  @override
  R accept<C, R>(Visitor<C, R> visitor, C context) {
    return visitor.visitInterpolation(this, context);
  }

  @override
  Interpolation copyWith({Expression? value}) {
    return Interpolation(value: value ?? this.value);
  }

  @override
  Iterable<T> findAll<T extends Node>() sync* {
    if (value case T value) {
      yield value;
    }

    yield* value.findAll<T>();
  }
}

final class Output extends Node {
  const Output({this.nodes = const <Node>[]});

  final List<Node> nodes;

  @override
  R accept<C, R>(Visitor<C, R> visitor, C context) {
    return visitor.visitOutput(this, context);
  }

  @override
  Output copyWith({List<Node>? nodes}) {
    return Output(nodes: nodes ?? this.nodes);
  }

  @override
  Iterable<T> findAll<T extends Node>() sync* {
    for (var node in nodes) {
      if (node is T) {
        yield node;
      }

      yield* node.findAll<T>();
    }
  }
}

final class TemplateNode extends Node {
  const TemplateNode({this.blocks = const <Block>[], required this.body});

  final List<Block> blocks;

  final Node body;

  @override
  R accept<C, R>(Visitor<C, R> visitor, C context) {
    return visitor.visitTemplateNode(this, context);
  }

  @override
  TemplateNode copyWith({List<Block>? blocks, Node? body}) {
    return TemplateNode(blocks: blocks ?? this.blocks, body: body ?? this.body);
  }

  @override
  Iterable<T> findAll<T extends Node>() sync* {
    for (var block in blocks) {
      if (block case T block) {
        yield block;
      }

      yield* block.findAll<T>();
    }

    if (body case T body) {
      yield body;
    }

    yield* body.findAll<T>();
  }
}
