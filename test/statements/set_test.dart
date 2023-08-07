import 'package:jinja/jinja.dart';
import 'package:jinja/reflection.dart';
import 'package:test/test.dart';

import '../environment.dart';

const emptyMap = <Object?, Object?>{};

void main() {
  group('Set', () {
    test('normal', () {
      var tmpl = envTrim.fromString('{% set foo = 1 %}{{ foo }}');
      expect(tmpl.render(), equals('1'));
    });

    test('block', () {
      var tmpl = envTrim.fromString('{% set foo %}42{% endset %}{{ foo }}');
      expect(tmpl.render(), equals('42'));
    });

    test('block escaping', () {}, skip: 'unsupported');

    test('set invalid', () {
      expect(() => envTrim.fromString('{% set foo["bar"] = 1 %}'),
          throwsA(isA<TemplateSyntaxError>()));
      var tmpl = envTrim.fromString('{% set foo.bar = 1 %}');
      expect(
          () => tmpl.render({'foo': emptyMap}),
          throwsA(predicate<TemplateRuntimeError>(
              (error) => error.message == 'Non-namespace object')));
    });

    test('namespace redefined', () {
      var tmpl = envTrim
          .fromString('{% set ns = namespace() %}{% set ns.bar = "hi" %}');
      expect(
          () => tmpl.render({'namespace': () => emptyMap}),
          throwsA(predicate<TemplateRuntimeError>(
              (error) => error.message == 'Non-namespace object')));
    });

    test('namespace', () {
      var tmpl = envTrim.fromString(
          '{% set ns = namespace() %}{% set ns.bar = "42" %}{{ ns.bar }}');
      expect(tmpl.render(), equals('42'));
    });

    test('namespace block', () {
      var tmpl = envTrim.fromString(
          '{% set ns = namespace() %}{% set ns.bar %}42{% endset %}{{ ns.bar }}');
      expect(tmpl.render(), equals('42'));
    });

    test('init namespace', () {
      var tmpl = envTrim.fromString('{% set ns = namespace(d, self=37) %}'
          '{% set ns.b = 42 %}'
          '{{ ns.a }}|{{ ns.self }}|{{ ns.b }}');
      expect(
          tmpl.render({
            'd': {'a': 13}
          }),
          equals('13|37|42'));
    });

    test('namespace loop', () {
      var tmpl = envTrim.fromString('{% set ns = namespace(found=false) %}'
          '{% for x in range(4) %}'
          '{% if x == v %}'
          '{% set ns.found = true %}'
          '{% endif %}'
          '{% endfor %}'
          '{{ ns.found }}');
      expect(tmpl.render({'v': 3}), equals('true'));
      expect(tmpl.render({'v': 4}), equals('false'));
    });

    test('namespace macro', () {
      var tmpl = envTrim.fromString('{% set ns = namespace() %}'
          '{% set ns.a = 13 %}'
          '{% macro magic(x) %}'
          '{% set x.b = 37 %}'
          '{% endmacro %}'
          '{{ magic(ns) }}'
          '{{ ns.a }}|{{ ns.b }}');
      expect(tmpl.render(), equals('13|37'));
    });

    test('block escapeing filtered', () {}, skip: 'unsupported');

    test('block filtered', () {
      var tmpl = envTrim.fromString(
          '{% set foo | trim | length | string %} 42    {% endset %}{{ foo }}');
      expect(tmpl.render(), equals('2'));
    });

    test('block filtered set', () {
      Object? myfilter(Object? value, Object? arg) {
        assert(arg == ' xxx ');
        return value;
      }

      var env = Environment(
          filters: {'myfilter': myfilter},
          getAttribute: getAttribute,
          trimBlocks: true);
      var tmpl = env.fromString('{% set a = " xxx " %}'
          '{% set foo | myfilter(a) | trim | length | string %}'
          ' {% set b = " yy " %} 42 {{ a }}{{ b }}   '
          '{% endset %}'
          '{{ foo }}');
      expect(tmpl.render(), equals('11'));
    });
  });
}
