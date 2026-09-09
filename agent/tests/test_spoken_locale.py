from calls.spoken_locale import canonicalize_locale


def test_us_arabic_ui_is_en_us() -> None:
    assert canonicalize_locale(region="US", locale="ar") == "en-US"
    assert canonicalize_locale(region="us", locale="ar-SA") == "en-US"


def test_ae_arabic_ui_is_ar_ae() -> None:
    assert canonicalize_locale(region="AE", locale="ar") == "ar-AE"


def test_sa_english_ui_is_en_us() -> None:
    assert canonicalize_locale(region="SA", locale="en") == "en-US"
    assert canonicalize_locale(region="SA", locale="en-US") == "en-US"


def test_eg_om_arabic_ui() -> None:
    assert canonicalize_locale(region="EG", locale="ar") == "ar-EG"
    assert canonicalize_locale(region="OM", locale="ar") == "ar-OM"
