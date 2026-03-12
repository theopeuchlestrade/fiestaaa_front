bool isSafeAbsoluteHttpUri(Uri uri) {
  if (!uri.hasScheme) return false;

  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return false;
  }

  final host = uri.host;
  if (host.isEmpty) {
    return false;
  }

  return _isSafePublicHost(host);
}

Uri? tryParseSafeAbsoluteHttpUri(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(value);
  if (uri == null) {
    return null;
  }

  return isSafeAbsoluteHttpUri(uri) ? uri : null;
}

bool _isSafePublicHost(String rawHost) {
  var host = rawHost.toLowerCase();
  while (host.endsWith('.')) {
    host = host.substring(0, host.length - 1);
  }
  if (host.isEmpty) {
    return false;
  }

  if (host == 'localhost' || host.endsWith('.localhost')) {
    return false;
  }

  final ipv4 = _tryParseIpv4(host);
  if (ipv4 != null) {
    return !_isPrivateOrLocalIpv4(ipv4);
  }

  final ipv6 = _tryParseIpv6(host);
  if (ipv6 != null) {
    return !_isPrivateOrLocalIpv6(ipv6);
  }

  return true;
}

List<int>? _tryParseIpv4(String host) {
  final parts = host.split('.');
  if (parts.length != 4) {
    return null;
  }

  final values = <int>[];
  for (final part in parts) {
    if (part.isEmpty || part.length > 3) {
      return null;
    }
    final value = int.tryParse(part);
    if (value == null || value < 0 || value > 255) {
      return null;
    }
    values.add(value);
  }

  return values;
}

bool _isPrivateOrLocalIpv4(List<int> octets) {
  final first = octets[0];
  final second = octets[1];

  if (first == 0 || first == 10 || first == 127) {
    return true;
  }
  if (first == 169 && second == 254) {
    return true;
  }
  if (first == 172 && second >= 16 && second <= 31) {
    return true;
  }
  if (first == 192 && second == 168) {
    return true;
  }
  if (first == 100 && second >= 64 && second <= 127) {
    return true;
  }

  return false;
}

List<int>? _tryParseIpv6(String host) {
  if (!host.contains(':')) {
    return null;
  }

  const compressedMarker = '::';
  if (host.indexOf(compressedMarker) != host.lastIndexOf(compressedMarker)) {
    return null;
  }

  final hasCompression = host.contains(compressedMarker);
  final parts = host.split(compressedMarker);
  final left = parts.first.isEmpty ? <String>[] : parts.first.split(':');
  final right = parts.length == 2 && parts[1].isNotEmpty
      ? parts[1].split(':')
      : <String>[];

  final leftGroups = _parseIpv6Groups(left);
  if (leftGroups == null) {
    return null;
  }

  final groups = <int>[...leftGroups];
  if (hasCompression) {
    final rightGroups = _parseIpv6Groups(right);
    if (rightGroups == null) {
      return null;
    }
    final missingGroups = 8 - leftGroups.length - rightGroups.length;
    if (missingGroups < 1) {
      return null;
    }
    groups.addAll(List<int>.filled(missingGroups, 0));
    groups.addAll(rightGroups);
  } else if (groups.length != 8) {
    return null;
  }

  if (groups.length != 8) {
    return null;
  }

  final bytes = <int>[];
  for (final group in groups) {
    bytes.add((group >> 8) & 0xff);
    bytes.add(group & 0xff);
  }
  return bytes;
}

List<int>? _parseIpv6Groups(List<String> groups) {
  final parsed = <int>[];
  for (final group in groups) {
    if (group.isEmpty) {
      return null;
    }
    if (group.contains('.')) {
      final ipv4 = _tryParseIpv4(group);
      if (ipv4 == null) {
        return null;
      }
      parsed.add((ipv4[0] << 8) | ipv4[1]);
      parsed.add((ipv4[2] << 8) | ipv4[3]);
      continue;
    }

    final value = int.tryParse(group, radix: 16);
    if (value == null || value < 0 || value > 0xffff) {
      return null;
    }
    parsed.add(value);
  }
  return parsed;
}

bool _isPrivateOrLocalIpv6(List<int> bytes) {
  if (bytes.length != 16) {
    return true;
  }

  final isUnspecified = bytes.every((byte) => byte == 0);
  if (isUnspecified) {
    return true;
  }

  final isLoopback =
      bytes.sublist(0, 15).every((byte) => byte == 0) && bytes[15] == 1;
  if (isLoopback) {
    return true;
  }

  final first = bytes[0];
  final second = bytes[1];
  final isIpv4Mapped =
      bytes.sublist(0, 10).every((byte) => byte == 0) &&
      bytes[10] == 0xff &&
      bytes[11] == 0xff;

  if (isIpv4Mapped) {
    return _isPrivateOrLocalIpv4(bytes.sublist(12, 16));
  }

  if ((first & 0xfe) == 0xfc) {
    return true;
  }
  if (first == 0xfe && (second & 0xc0) == 0x80) {
    return true;
  }

  return false;
}
