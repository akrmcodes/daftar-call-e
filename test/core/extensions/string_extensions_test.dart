import 'package:daftar/core/extensions/string_extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArabicNormalization', () {
    group('Negative and edge cases', () {
      test('strips full tashkeel range without leaving combining marks', () {
        const input = 'أَحْمَدُ بِنْ عَلِيٍّ';
        expect(input.normalizeArabic(), 'احمد بن علي');
      });

      test('unifies all alef variants to bare alef', () {
        expect('أإآٱ'.normalizeArabic(), 'اااا');
        expect('إبراهيم'.normalizeArabic(), 'ابراهيم');
        expect('آمنة'.normalizeArabic(), 'امنه');
      });

      test('maps taa marbuta to haa for search equivalence', () {
        expect('فاطمة'.normalizeArabic(), 'فاطمه');
        expect('محمدة'.normalizeArabic(), 'محمده');
        expect('ةةة'.normalizeArabic(), 'ههه');
      });

      test('maps alef maqsura to yaa', () {
        expect('موسى'.normalizeArabic(), 'موسي');
        expect('على'.normalizeArabic(), 'علي');
      });

      test('collapses internal whitespace and trims ends', () {
        expect('  أحمد   علي  '.normalizeArabic(), 'احمد علي');
        expect('\n\tفاطمة\r\n'.normalizeArabic(), 'فاطمه');
      });

      test('preserves latin digits and punctuation inside Arabic text', () {
        expect('محمد 123'.normalizeArabic(), 'محمد 123');
        expect('أحمد-علي'.normalizeArabic(), 'احمد-علي');
      });

      test('empty and whitespace-only strings normalize to empty', () {
        expect(''.normalizeArabic(), '');
        expect('   '.normalizeArabic(), '');
        expect('\u064B\u064C'.normalizeArabic(), '');
      });

      test('does not strip non-tashkeel arabic letters', () {
        expect('ئؤء'.normalizeArabic(), 'ئؤء');
      });

      test('isArabic rejects latin letters and mixed scripts', () {
        expect('محمد'.isArabic, isTrue);
        expect('محمد Ali'.isArabic, isFalse);
        expect('hello'.isArabic, isFalse);
        expect('123'.isArabic, isTrue);
        expect(''.isArabic, isFalse);
      });

      test('isBlank and isNotBlank treat unicode whitespace', () {
        expect(' \u00a0 '.isBlank, isTrue);
        expect('أحمد'.isNotBlank, isTrue);
      });
    });

    group('Cross-form search equivalence', () {
      test('diacritic-heavy name matches stripped bare form', () {
        const bare = 'احمد';
        const decorated = 'أَحْمَد';
        expect(decorated.normalizeArabic(), bare);
      });

      test('alef-variant name matches bare alef form', () {
        expect('أحمد'.normalizeArabic(), 'احمد');
        expect('إحمد'.normalizeArabic(), 'احمد');
      });

      test('taa marbuta name matches haa ending form', () {
        expect('فاطمة'.normalizeArabic(), 'فاطمه');
      });
    });
  });
}
