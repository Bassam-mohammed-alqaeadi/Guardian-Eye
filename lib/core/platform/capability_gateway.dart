import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

enum GuardianCapability {
  notifications,
  location,
  microphone,
  usageStats,
  accessibility,
  overlay,
  screenCapture
}

class CapabilityStatus {
  const CapabilityStatus(
      {required this.capability,
      required this.granted,
      required this.supported,
      required this.requiresSettings});
  final GuardianCapability capability;
  final bool granted;
  final bool supported;
  final bool requiresSettings;
}

class CapabilityGateway {
  const CapabilityGateway();
  static const _channel = MethodChannel('com.guardianeye.app/capabilities');
  Future<List<CapabilityStatus>> inspectAll() async => [
        await _permissionCapability(GuardianCapability.notifications,
            await Permission.notification.status),
        await _permissionCapability(GuardianCapability.location,
            await Permission.locationWhenInUse.status),
        await _permissionCapability(
            GuardianCapability.microphone, await Permission.microphone.status),
        await _nativeCapability(GuardianCapability.usageStats),
        await _nativeCapability(GuardianCapability.accessibility),
        await _nativeCapability(GuardianCapability.overlay),
        await _nativeCapability(GuardianCapability.screenCapture)
      ];
  Future<CapabilityStatus> request(GuardianCapability capability) async {
    switch (capability) {
      case GuardianCapability.notifications:
        return _permissionCapability(
            capability, await Permission.notification.request());
      case GuardianCapability.location:
        return _permissionCapability(
            capability, await Permission.locationWhenInUse.request());
      case GuardianCapability.microphone:
        return _permissionCapability(
            capability, await Permission.microphone.request());
      default:
        try {
          await _channel.invokeMethod<void>(
              'openSettings', {'capability': capability.name});
        } on MissingPluginException {
          return CapabilityStatus(
              capability: capability,
              granted: false,
              supported: false,
              requiresSettings: true);
        }
        return _nativeCapability(capability);
    }
  }

  Future<CapabilityStatus> _permissionCapability(
          GuardianCapability capability, PermissionStatus status) async =>
      CapabilityStatus(
          capability: capability,
          granted: status.isGranted || status.isLimited,
          supported: true,
          requiresSettings: status.isPermanentlyDenied || status.isRestricted);
  Future<CapabilityStatus> _nativeCapability(
      GuardianCapability capability) async {
    try {
      final granted = await _channel.invokeMethod<bool>(
              'isGranted', {'capability': capability.name}) ??
          false;
      return CapabilityStatus(
          capability: capability,
          granted: granted,
          supported: true,
          requiresSettings: true);
    } on MissingPluginException {
      return CapabilityStatus(
          capability: capability,
          granted: false,
          supported: false,
          requiresSettings: true);
    }
  }
}
