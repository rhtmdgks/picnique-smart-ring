// Source: colmi_r02_client/colmi_r02_client/client.py get_device_info (MIT)

import '../transport/ring_transport.dart';

class DeviceInfo {
  const DeviceInfo({this.hwVersion, this.fwVersion, this.name, this.address});
  final String? hwVersion;
  final String? fwVersion;
  final String? name;
  final String? address;
}

class DeviceInfoCommand {
  DeviceInfoCommand(this._transport);

  final RingTransport _transport;

  Future<DeviceInfo> read() async {
    final gatt = await _transport.readDeviceInfo();
    return DeviceInfo(
      hwVersion: gatt['hw_version'],
      fwVersion: gatt['fw_version'],
      name: _transport.deviceName,
      address: _transport.deviceAddress,
    );
  }
}
