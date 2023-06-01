import 'dart:convert';

import 'package:html_unescape/html_unescape.dart';

/// HTML escape [Converter].
final HtmlEscape htmlEscape = HtmlEscape(
  HtmlEscapeMode(
    escapeLtGt: true,
    escapeQuot: true,
    escapeApos: true,
  ),
);

/// HTML unescape [Converter].
final HtmlUnescape htmlUnescape = HtmlUnescape();

String escape(String text) {
  return htmlEscape.convert(text);
}

String escapeSafe(Object? object) {
  if (object case Markup markup) {
    return markup.value.toString();
  }

  return escape(object.toString());
}

String unescape(String text) {
  return htmlUnescape.convert(text);
}

final class Markup {
  factory Markup(Object? value) {
    if (value case Markup markup) {
      return markup;
    }

    return Markup.escape(value);
  }

  Markup.escape(this.value);

  const factory Markup.escaped(Object? value) = Escaped;

  final Object? value;

  @override
  int get hashCode {
    return value.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return other is Markup && value == other.value;
  }

  @override
  String toString() {
    return escape(value.toString());
  }
}

final class Escaped implements Markup {
  const Escaped(this.value);

  @override
  final Object? value;

  @override
  int get hashCode {
    return value.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return other is Markup && value == other.value;
  }

  @override
  String toString() {
    return value.toString();
  }
}
