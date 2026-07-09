// Source: colmi_r06_fbp/lib/colmi_ring.dart (BSD-3-Clause, CitizenOneX)
// Source: Gadgetbridge YawellRingConstants.java (AGPL-3.0, Arjan Schrijver)
// Source: colmi_r02_client/colmi_r02_client/client.py (MIT, Wesley Ellis)

/// Colmi/Yawell RF03 ring GATT UUIDs and opcode constants.
abstract final class RingProtocolConstants {
  // ── GATT UUIDs ──────────────────────────────────────────────────────────
  static const cmdServiceV1 = '6e40fff0-b5a3-f393-e0a9-e50e24dcca9e';
  static const cmdWriteChar = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
  static const cmdNotifyCharV1 = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

  /// Big-data 0xBC channel — **separate service** de5bf728 (btsnoop handle 0x0016/0x0018).
  /// Some firmwares expose an extra write/notify pair on 6e40fff0 (not 002/003).
  static const cmdServiceV2 = 'de5bf728-d711-4e47-af26-65e3012a5dc7';
  static const cmdWriteCharV2 = 'de5bf72a-d711-4e47-af26-65e3012a5dc7';
  static const cmdNotifyCharV2 = 'de5bf729-d711-4e47-af26-65e3012a5dc7';

  static const deviceInfoService = '0000180a-0000-1000-8000-00805f9b34fb';
  static const deviceHwChar = '00002a27-0000-1000-8000-00805f9b34fb';
  static const deviceFwChar = '00002a26-0000-1000-8000-00805f9b34fb';

  /// colmi_r06_fbp advertisedNamePattern
  static final advertisedNamePattern = RegExp(r'^R0\d_[0-9A-Z]{4}$');

  // ── Opcodes ─────────────────────────────────────────────────────────────
  static const int cmdSetDateTime = 0x01;
  /// Ring→phone keepalive, btsnoop: `02 02 00 … 04` every ~7–15s on main notify.
  static const int cmdHeartbeat = 0x02;
  static const int cmdBattery = 0x03;
  static const int cmdPhoneName = 0x04;
  static const int cmdDisplayPref = 0x05;
  static const int cmdPowerOff = 0x08;
  static const int cmdPreferences = 0x0a;
  static const int cmdSyncHeartRate = 0x15;
  static const int cmdAutoHrPref = 0x16;
  static const int cmdRealtimeHeartRate = 0x1e;
  static const int cmdGoals = 0x21;
  static const int cmdAutoSpo2Pref = 0x2c;
  static const int cmdPacketSize = 0x2f;
  static const int cmdAutoStressPref = 0x36;
  static const int cmdSyncStress = 0x37;
  static const int cmdAutoHrvPref = 0x38;
  static const int cmdSyncHrv = 0x39;
  static const int cmdAutoTempPref = 0x3a;
  static const int cmdSyncActivity = 0x43;
  static const int cmdFindDevice = 0x50;
  static const int cmdManualHeartRate = 0x69;
  static const int cmdStartRealTime = 0x69; // colmi_r02_client uses 105=0x69
  static const int cmdStopRealTime = 0x6a;
  static const int cmdNotification = 0x73;
  static const int cmdBigDataV2 = 0xbc;
  static const int cmdFactoryReset = 0xff;

  static const int cmdRawSensor = 0xa1;

  // colmi_r02_client real_time.py
  static const int cmdRealTimeHeartRateContinue = 0x1e;

  // ── Notification subtypes (0x73) ─────────────────────────────────────────
  static const int notifNewHrData = 0x01;
  static const int notifNewSpo2Data = 0x03;
  static const int notifNewStepsData = 0x04;
  static const int notifBatteryLevel = 0x0c;
  static const int notifLiveActivity = 0x12;

  // ── Big data types (0xBC) ─────────────────────────────────────────────────
  static const int bigDataTypeTemperature = 0x25;
  static const int bigDataTypeSleep = 0x27;
  static const int bigDataTypeSpo2 = 0x2a;

  // ── Sleep stage raw bytes ─────────────────────────────────────────────────
  static const int sleepTypeLight = 0x02;
  static const int sleepTypeDeep = 0x03;
  static const int sleepTypeRem = 0x04;
  static const int sleepTypeAwake = 0x05;

  // ── Raw sensor subtypes (0xA1) ────────────────────────────────────────────
  static const int rawSpo2 = 0x01;
  static const int rawPpg = 0x02;
  static const int rawAccelerometer = 0x03;

  // ── Manual HR subtypes (0x69) ───────────────────────────────────────────
  static const int manualHrSubtype = 0x01;
  static const int manualSpo2Subtype = 0x03;
  /// Auto-monitoring pref opcode group (0x36 etc.) — not on-demand 0x69 subtype.
  static const int manualStressSubtype = 0x08;
  /// On-demand stress/HRV realtime — btsnoop R08: `69 0b 25`, finalize `6a 0b`.
  static const int manualStressMeasureSubtype = 0x0b;

  static const int prefRead = 0x01;
  static const int prefWrite = 0x02;

  static const int packetLength = 16;

  /// Ring pushes these without a prior app request — route to push streams, not one-shot waiters.
  static const Set<int> pushOpcodes = {
    cmdManualHeartRate, // 0x69 stream frames
    cmdSyncActivity, // 0x43 activity chunks
    cmdSyncHeartRate, // 0x15 HR history chunks
    cmdSyncStress, // 0x37
    cmdSyncHrv, // 0x39
    cmdNotification, // 0x73
    cmdRawSensor, // 0xa1 stream
  };

  /// Ignored on main notify (no log).
  static const Set<int> silentOpcodes = {
    cmdHeartbeat,
    cmdPacketSize,
    cmdPhoneName, // unsolicited ack after connect
  };

  /// Stable-sample flag in 0x69 stream byte[2] (btsnoop R08).
  static const int manualStreamStableFlag = 0x60;

  /// Default on-demand measure window (seconds) in 0x69 start byte[2] for SpO2/stress.
  static const int manualMeasureDurationSec = 0x25;

  static bool isPushOpcode(int opcode) => pushOpcodes.contains(opcode & 0xff);

  static bool isSilentOpcode(int opcode) => silentOpcodes.contains(opcode & 0xff);
}
