import 'package:flutter_test/flutter_test.dart';
import 'package:shujing/source/rule_engine.dart';

void main() {
  group('RuleEngine @ 链', () {
    test('class.x@tag.a 元素链', () {
      const html = '''
      <html><body>
        <ul class="vui_list">
          <li><a href="/book/1.html">书名A</a><span class="au">作者A</span></li>
          <li><a href="/book/2.html">书名B</a><span class="au">作者B</span></li>
        </ul>
      </body></html>''';
      final doc = RuleEngine.parseBody(html, 'html');
      final els = RuleEngine.optElements(doc, 'class.vui_list@tag.a');
      expect(els.length, 2);
      expect(RuleEngine.optString(els[0], 'text'), '书名A');
      expect(RuleEngine.optString(els[0], 'href'), '/book/1.html');
    });

    test('id.content@textNodes 正文', () {
      const html = '''
      <html><body><div id="content">第一段<br>第二段<br><p>广告</p>第三段</div></body></html>''';
      final doc = RuleEngine.parseBody(html, 'html');
      final text = RuleEngine.optString(doc, 'id.content@textNodes');
      expect(text, contains('第一段'));
      expect(text, contains('第二段'));
    });

    test('|| 回退与 ## 默认值', () {
      const html = '<html><body><div class="x">内容</div></body></html>';
      final doc = RuleEngine.parseBody(html, 'html');
      expect(RuleEngine.optString(doc, 'class.none##默认值'), '默认值');
      expect(RuleEngine.optString(doc, 'class.none||class.x'), '内容');
    });

    test('xpath 与 /@attr', () {
      const html =
          '<html><body><div class="g"><a href="/b/1">T1</a></div></body></html>';
      final doc = RuleEngine.parseBody(html, 'html');
      final els = RuleEngine.optElements(doc, '//div[@class="g"]/a');
      expect(els.length, 1);
      expect(RuleEngine.optString(els[0], 'text'), 'T1');
      expect(RuleEngine.optString(doc, '//a/@href'), '/b/1');
    });

    test('JSON 规则', () {
      const json = '{"data":{"list":[{"title":"T1","url":"/u1"}]}}';
      final doc = RuleEngine.parseBody(json, 'json');
      final els = RuleEngine.optElements(doc, r'$.data.list[*]');
      expect(els.length, 1);
      expect(RuleEngine.optString(els[0], 'title'), 'T1');
    });

    test('&& 链式', () {
      const html =
          '<html><body><ul><li class="r"><a href="/1">N1</a></li></ul></body></html>';
      final doc = RuleEngine.parseBody(html, 'html');
      final v = RuleEngine.optString(doc, 'tag.a&&text');
      expect(v, 'N1');
    });
  });
}
