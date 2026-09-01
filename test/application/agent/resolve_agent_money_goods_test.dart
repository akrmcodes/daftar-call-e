import 'package:daftar/application/agent/resolve_agent_money_goods.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveAgentMoneyGoods', () {
    test('itemName is goods and note is remark', () {
      final goods = resolveAgentMoneyGoods(
        itemName: 'juice',
        note: 'he will pay Friday',
      );
      expect(goods.itemName, 'juice');
      expect(goods.note, 'he will pay Friday');
    });

    test('legacy note-only becomes itemName', () {
      final goods = resolveAgentMoneyGoods(note: 'juice');
      expect(goods.itemName, 'juice');
      expect(goods.note, isNull);
    });

    test('duplicate item and note keeps itemName only', () {
      final goods = resolveAgentMoneyGoods(
        itemName: 'juice',
        note: 'juice',
      );
      expect(goods.itemName, 'juice');
      expect(goods.note, isNull);
    });

    test('empty fields stay empty', () {
      final goods = resolveAgentMoneyGoods(itemName: '  ', note: '');
      expect(goods.itemName, isNull);
      expect(goods.note, isNull);
    });
  });
}
