import 'package:daftar/application/agent/speech_locale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeSpeechLocale', () {
    test('maps English tags to en and everything else to ar', () {
      expect(normalizeSpeechLocale('en'), 'en');
      expect(normalizeSpeechLocale('en-US'), 'en');
      expect(normalizeSpeechLocale('ar'), 'ar');
      expect(normalizeSpeechLocale('ar-YE'), 'ar');
    });
  });

  group('detectSpeechLocaleSwitch', () {
    test('detects English requests to speak Arabic', () {
      expect(detectSpeechLocaleSwitch('speak Arabic'), 'ar');
      expect(detectSpeechLocaleSwitch('Please speak in Arabic now'), 'ar');
      expect(detectSpeechLocaleSwitch('switch to Arabic'), 'ar');
      expect(detectSpeechLocaleSwitch('reply in Arabic'), 'ar');
    });

    test('detects Arabic requests to speak Arabic', () {
      expect(detectSpeechLocaleSwitch('تحدث بالعربية'), 'ar');
      expect(detectSpeechLocaleSwitch('احك عربي من فضلك'), 'ar');
      expect(detectSpeechLocaleSwitch('جاوب بالعربي'), 'ar');
    });

    test('detects requests to speak English', () {
      expect(detectSpeechLocaleSwitch('speak English'), 'en');
      expect(detectSpeechLocaleSwitch('speak in English'), 'en');
      expect(detectSpeechLocaleSwitch('switch to English'), 'en');
      expect(detectSpeechLocaleSwitch('in English please'), 'en');
      expect(detectSpeechLocaleSwitch('تحدث بالإنجليزية'), 'en');
      expect(detectSpeechLocaleSwitch('احك إنجليزي'), 'en');
      expect(detectSpeechLocaleSwitch('بالإنجليزي'), 'en');
    });

    test('does not treat incidental Arabic as a switch', () {
      expect(detectSpeechLocaleSwitch('Arabic coffee for Mohamed'), isNull);
      expect(detectSpeechLocaleSwitch('سجل محمد 500'), isNull);
      expect(detectSpeechLocaleSwitch('Mohamed owes 500'), isNull);
    });
  });

  group('coerceLocaleToTextScript', () {
    test('keeps Arabic when Arabic letters are present even with Latin names', () {
      expect(
        coerceLocaleToTextScript(locale: 'en', text: 'Mohamed عليه 500'),
        'ar',
      );
      expect(
        coerceLocaleToTextScript(locale: 'en', text: 'محمد عليه 500'),
        'ar',
      );
    });

    test('forces en for Latin-only text even if locale is ar', () {
      expect(
        coerceLocaleToTextScript(
          locale: 'ar',
          text: 'Mohamed owes 500',
        ),
        'en',
      );
    });

    test('keeps requested locale when there are no letters', () {
      expect(coerceLocaleToTextScript(locale: 'ar', text: '500'), 'ar');
      expect(coerceLocaleToTextScript(locale: 'en-US', text: '500'), 'en');
    });
  });
}
