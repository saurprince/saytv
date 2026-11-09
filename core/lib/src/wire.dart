import 'dart:convert';
import 'dart:typed_data';

/// A tiny protobuf codec: varints and length-delimited fields are all this protocol needs.

Uint8List varint(int n) {
  final out = <int>[];
  while (true) {
    final b = n & 0x7f;
    n >>= 7;
    if (n != 0) {
      out.add(b | 0x80);
    } else {
      out.add(b);
      break;
    }
  }
  return Uint8List.fromList(out);
}

Uint8List concat(List<List<int>> parts) {
  final out = BytesBuilder(copy: false);
  for (final p in parts) {
    out.add(p);
  }
  return out.toBytes();
}

Uint8List fInt(int field, int value) => concat([varint(field << 3), varint(value)]);

Uint8List fBytes(int field, List<int> data) =>
    concat([varint(field << 3 | 2), varint(data.length), data]);

Uint8List fStr(int field, String text) => fBytes(field, utf8.encode(text));

/// A parsed message: field number -> values (int for varints, Uint8List for everything else).
class Fields {
  Fields(this._map);
  final Map<int, List<Object>> _map;

  bool has(int field) => _map.containsKey(field);
  Iterable<int> get numbers => _map.keys;

  int? intOf(int field) {
    final v = _map[field];
    return (v != null && v.first is int) ? v.first as int : null;
  }

  Uint8List? bytesOf(int field) {
    final v = _map[field];
    return (v != null && v.first is Uint8List) ? v.first as Uint8List : null;
  }

  String? stringOf(int field) {
    final b = bytesOf(field);
    return b == null ? null : utf8.decode(b, allowMalformed: true);
  }

  Fields? subOf(int field) {
    final b = bytesOf(field);
    return b == null ? null : parseFields(b);
  }

  @override
  String toString() => _map.toString();
}

Fields parseFields(List<int> buf) {
  final map = <int, List<Object>>{};
  var i = 0;
  while (i < buf.length) {
    final (key, afterKey) = _readVarint(buf, i);
    i = afterKey;
    final field = key >> 3;
    final wire = key & 7;
    Object value;
    switch (wire) {
      case 0:
        final (v, next) = _readVarint(buf, i);
        value = v;
        i = next;
      case 2:
        final (len, next) = _readVarint(buf, i);
        i = next;
        value = Uint8List.fromList(buf.sublist(i, i + len));
        i += len;
      case 1:
        value = Uint8List.fromList(buf.sublist(i, i + 8));
        i += 8;
      case 5:
        value = Uint8List.fromList(buf.sublist(i, i + 4));
        i += 4;
      default:
        throw FormatException('unsupported wire type $wire');
    }
    map.putIfAbsent(field, () => []).add(value);
  }
  return Fields(map);
}

(int, int) _readVarint(List<int> buf, int i) {
  var shift = 0;
  var value = 0;
  while (true) {
    final b = buf[i++];
    value |= (b & 0x7f) << shift;
    if (b & 0x80 == 0) return (value, i);
    shift += 7;
  }
}

/// Collects bytes from a socket and hands out whole length-prefixed messages.
class FrameReader {
  final _buf = BytesBuilder(copy: true);

  void add(List<int> data) => _buf.add(data);

  /// Every complete message received so far (the rest stays buffered).
  List<Uint8List> takeFrames() {
    final out = <Uint8List>[];
    var data = _buf.toBytes();
    var pos = 0;
    while (true) {
      var i = pos;
      var shift = 0;
      var size = 0;
      var complete = false;
      while (i < data.length) {
        final b = data[i++];
        size |= (b & 0x7f) << shift;
        if (b & 0x80 == 0) {
          complete = true;
          break;
        }
        shift += 7;
      }
      if (!complete || data.length - i < size) break;
      out.add(Uint8List.sublistView(data, i, i + size));
      pos = i + size;
    }
    _buf.clear();
    if (pos < data.length) _buf.add(data.sublist(pos));
    return out;
  }
}

Uint8List frame(List<int> message) => concat([varint(message.length), message]);
