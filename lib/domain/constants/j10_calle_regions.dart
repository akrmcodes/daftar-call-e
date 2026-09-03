/// J.10 CALL-E supported regions and calling-code lookup (device SoT).
///
/// Keep in lockstep with [`agent/calls/j10.py`](../../../agent/calls/j10.py) and
/// [CALL-E Supported Regions](https://github.com/CALLE-AI/call-e-integrations#-supported-regions-and-languages).
abstract final class J10CalleRegions {
  /// Sentinel for NANP (+1). Never infer `US` from a leading `+1`.
  static const String nanp = 'NANP';

  /// ISO codes supported by CALL-E (GitHub snapshot Sep 2026). YE is absent.
  static const Set<String> supportedRegions = {
    'AE',
    'AU',
    'BD',
    'BR',
    'BW',
    'CA',
    'CM',
    'DE',
    'EG',
    'ES',
    'FI',
    'FR',
    'GB',
    'GH',
    'HN',
    'ID',
    'IE',
    'IL',
    'IN',
    'JP',
    'KE',
    'LK',
    'MX',
    'MY',
    'MZ',
    'NA',
    'NG',
    'NL',
    'OM',
    'PH',
    'PK',
    'PL',
    'SA',
    'SG',
    'TH',
    'TN',
    'TR',
    'TW',
    'UA',
    'US',
    'VN',
    'ZA',
  };

  /// Non-NANP calling-code prefix → ISO. Longest prefix wins.
  static const List<(String prefix, String iso)> _callingPrefixes = [
    ('216', 'TN'),
    ('233', 'GH'),
    ('234', 'NG'),
    ('237', 'CM'),
    ('254', 'KE'),
    ('258', 'MZ'),
    ('264', 'NA'),
    ('267', 'BW'),
    ('353', 'IE'),
    ('358', 'FI'),
    ('380', 'UA'),
    ('504', 'HN'),
    ('880', 'BD'),
    ('886', 'TW'),
    ('966', 'SA'),
    ('967', 'YE'),
    ('968', 'OM'),
    ('971', 'AE'),
    ('972', 'IL'),
    ('20', 'EG'),
    ('27', 'ZA'),
    ('31', 'NL'),
    ('33', 'FR'),
    ('34', 'ES'),
    ('44', 'GB'),
    ('48', 'PL'),
    ('49', 'DE'),
    ('52', 'MX'),
    ('55', 'BR'),
    ('60', 'MY'),
    ('61', 'AU'),
    ('62', 'ID'),
    ('63', 'PH'),
    ('65', 'SG'),
    ('66', 'TH'),
    ('81', 'JP'),
    ('84', 'VN'),
    ('90', 'TR'),
    ('91', 'IN'),
    ('92', 'PK'),
    ('94', 'LK'),
  ];

  /// Maps [e164] (`+` + digits) to ISO, [nanp], `YE`, or `null` if unknown.
  static String? callingRegion(String e164) {
    if (!e164.startsWith('+')) {
      return null;
    }
    final digits = e164.substring(1);
    if (digits.startsWith('1')) {
      return nanp;
    }
    for (final (prefix, iso) in _callingPrefixes) {
      if (digits.startsWith(prefix)) {
        return iso;
      }
    }
    return null;
  }

  /// ISO region for J.10 gate: NANP uses [allowlistRegion]; else mapped ISO.
  static String declaredRegionFor(String? e164, String allowlistRegion) {
    final fallback = allowlistRegion.trim().toUpperCase();
    if (e164 == null || e164.isEmpty) {
      return fallback;
    }
    final mapped = callingRegion(e164);
    if (mapped == null || mapped == nanp) {
      return fallback;
    }
    return mapped;
  }
}
