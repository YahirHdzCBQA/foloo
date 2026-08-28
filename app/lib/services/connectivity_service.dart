/// Device-transport connectivity boundary for Foloo's visual status.
///
/// A reported connection means that a network interface is available. It does
/// not prove internet access or Foloo backend health (SYN-05, RNF-13).
library;

import 'package:connectivity_plus/connectivity_plus.dart';

/// Supplies the current device transport state and subsequent changes.
abstract interface class ConnectivityService {
  Future<bool> isConnected();

  Stream<bool> get changes;
}

/// Uses the platform connectivity plugin without performing network requests.
class DeviceConnectivityService implements ConnectivityService {
  DeviceConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isConnected() async =>
      _hasTransport(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get changes =>
      _connectivity.onConnectivityChanged.map(_hasTransport).distinct();

  static bool _hasTransport(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
