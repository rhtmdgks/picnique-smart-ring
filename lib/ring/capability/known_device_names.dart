// Source: https://github.com/atc1441/ATC_RF03_Ring/blob/main/Known_BLE_OEM_Ring_Names.txt

/// Known BLE OEM ring name prefixes/substrings for Colmi/Yawell RF03 platform.
abstract final class KnownDeviceNames {
  static const allowlist = [
    // ATC_RF03_Ring OEM list
    'R01',
    'R02',
    'R03',
    'R04',
    'R05',
    'R06',
    'R07',
    'R08',
    'R09',
    'R10',
    'R11',
    'R12',
    'VK-5098',
    'MERLIN',
    'Hello Ring',
    'RING1',
    'boAtring',
    'TR-R02',
    'SE',
    'EVOLVEO',
    'GL-SR2',
    'Blaupunkt',
    'KSIX RING',
    'iGET',
    'Kogan',
    'FITNESS',
    'Fyri',
    'OneRing SR01',
    'BOK',
    '9FSM',
    'STF',
    'Newgen',
    'SSR',
    'SEEKEN',
    'MXSR',
    // Gadgetbridge coordinators
    'COLMI',
    'YAWELL',
    'H59',
    'QRING',
    'Q RING',
    'SMART RING',
    'SMART_RING',
  ];

  static bool matches(String? name) {
    if (name == null || name.trim().isEmpty) return false;
    final upper = name.toUpperCase();
    for (final entry in allowlist) {
      if (upper.contains(entry.toUpperCase())) return true;
    }
    return false;
  }
}
