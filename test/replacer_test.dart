import 'package:flutter_test/flutter_test.dart';
import 'package:shujing/data/models.dart';
import 'package:shujing/source/replacer.dart';

void main() {
  group('Replacer 净化引擎', () {
    setUp(() => Replacer.instance.update([]));

    test('正则规则删除整行广告', () {
      Replacer.instance.update(const [
        ReplaceRule(name: '广告', pattern: r'^.*天才一秒记住.*$'),
      ]);
      const input = '第一章 初入江湖\n天才一秒记住本站地址：www.xxx.com\n他拔出了剑。';
      final out = Replacer.instance.clean(input);
      expect(out, isNot(contains('天才一秒记住')));
      expect(out, contains('他拔出了剑'));
      expect(out, contains('第一章'));
    });

    test('替换为指定文本', () {
      Replacer.instance.update(const [
        ReplaceRule(name: '主角改名', pattern: '张三', replacement: '李四', isRegex: false),
      ]);
      expect(Replacer.instance.clean('张三见了张三'), '李四见了李四');
    });

    test('## 分隔多条正则', () {
      Replacer.instance.update(const [
        ReplaceRule(name: '多条', pattern: '广告词一##广告词二'),
      ]);
      final out = Replacer.instance.clean('广告词一\n正文\n广告词二');
      expect(out, '正文');
    });

    test('非法正则退化为字面量', () {
      Replacer.instance.update(const [
        ReplaceRule(name: '坏正则', pattern: r'([未闭合'),
      ]);
      expect(Replacer.instance.clean('前([未闭合后'), '前后');
    });

    test('禁用规则不生效', () {
      Replacer.instance.update(const [
        ReplaceRule(name: 'off', pattern: '广告', enabled: false),
      ]);
      expect(Replacer.instance.clean('有广告'), '有广告');
    });

    test('净化后压缩多余空行', () {
      Replacer.instance.update(const [
        ReplaceRule(name: '删行', pattern: r'^水$'),
      ]);
      final out = Replacer.instance.clean('A\n水\n水\n水\nB');
      expect(out, 'A\n\nB');
    });

    test('导入阅读3.0 格式（rule 字段）', () {
      final rules = Replacer.parseImport(
          '[{"name":"x","rule":"abc","replacement":"","isRegex":false,"isEnabled":true}]');
      expect(rules.length, 1);
      expect(rules.first.pattern, 'abc');
      expect(rules.first.isRegex, false);
    });

    test('导出再导入保持一致', () {
      const original = [
        ReplaceRule(name: 'r1', pattern: r'\d+章', replacement: ''),
      ];
      final json = Replacer.exportJson(original);
      final back = Replacer.parseImport(json);
      expect(back.first.name, 'r1');
      expect(back.first.pattern, r'\d+章');
    });
  });
}
