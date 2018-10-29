part of 'cassandart_impl.dart';

ByteData _byteData(List<int> data) {
  return new ByteData.view(new Uint8List.fromList(data).buffer);
}

Uint8List _toUint8List(List<int> list) {
  if (list is Uint8List) {
    return list;
  } else {
    return new Uint8List.fromList(list);
  }
}

class TypedValue<T> {
  final DataType type;
  final T value;

  TypedValue._(this.type, this.value);

  static TypedValue<int> int8(int value) =>
      new TypedValue._(const DataType.core(DataClass.tinyint), value);

  static TypedValue<int> int16(int value) =>
      new TypedValue._(const DataType.core(DataClass.smallint), value);

  static TypedValue<int> int32(int value) =>
      new TypedValue._(const DataType.core(DataClass.int), value);

  static TypedValue<double> float(double value) =>
      new TypedValue._(const DataType.core(DataClass.float), value);
}

decodeData(DataType type, List<int> data) {
  switch (type.dataClass) {
    case DataClass.blob:
      return data;
    case DataClass.boolean:
      return data[0] != 0;
    case DataClass.ascii:
      return ascii.decode(data);
    case DataClass.varchar:
      return utf8.decode(data);
    case DataClass.bigint:
      return _byteData(data).getInt64(0, Endian.big);
    case DataClass.int:
      return _byteData(data).getInt32(0, Endian.big);
    case DataClass.smallint:
      return _byteData(data).getInt16(0, Endian.big);
    case DataClass.tinyint:
      return _byteData(data).getInt8(0);
    case DataClass.float:
      return _byteData(data).getFloat32(0, Endian.big);
    case DataClass.double:
      return _byteData(data).getFloat64(0, Endian.big);
    default:
      throw new UnimplementedError(
          'Decode of ${type.dataClass} not implemented.');
  }
}

Uint8List encodeString(String value) => _toUint8List(utf8.encode(value));

Uint8List encodeBigint(int value) {
  final data = new ByteData(8);
  data.setInt64(0, value, Endian.big);
  return new Uint8List.view(data.buffer);
}

Uint8List encodeDouble(double value) {
  final data = new ByteData(8);
  data.setFloat64(0, value, Endian.big);
  return new Uint8List.view(data.buffer);
}

final _boolFalse = new Uint8List.fromList([0]);
final _boolTrue = new Uint8List.fromList([1]);

Uint8List encodeData(value) {
  if (value is String) {
    return encodeString(value);
  } else if (value is int) {
    return encodeBigint(value);
  } else if (value is double) {
    return encodeDouble(value);
  } else if (value is bool) {
    return value ? _boolTrue : _boolFalse;
  } else if (value is Uint8List) {
    return value;
  } else if (value is TypedValue<int> &&
      value.type.dataClass == DataClass.tinyint) {
    return _toUint8List([value.value]);
  } else if (value is TypedValue<int> &&
      value.type.dataClass == DataClass.smallint) {
    final data = new ByteData(2);
    data.setInt16(0, value.value, Endian.big);
    return new Uint8List.view(data.buffer);
  } else if (value is TypedValue<int> &&
      value.type.dataClass == DataClass.int) {
    final data = new ByteData(4);
    data.setInt32(0, value.value, Endian.big);
    return new Uint8List.view(data.buffer);
  } else if (value is TypedValue<double> &&
      value.type.dataClass == DataClass.float) {
    final data = new ByteData(4);
    data.setFloat32(0, value.value, Endian.big);
    return new Uint8List.view(data.buffer);
  } else {
    throw new UnimplementedError('Encode of $value not implemented.');
  }
}

class BodyWriter {
  final _chunks = <Uint8List>[];

  void writeByte(int value) {
    _chunks.add(new Uint8List.fromList([value]));
  }

  void writeBytes(Uint8List value) {
    writeInt(value.length);
    _chunks.add(value);
  }

  void writeShort(int value) {
    final data = new ByteData(2);
    data.setInt16(0, value, Endian.big);
    _chunks.add(new Uint8List.view(data.buffer));
  }

  void writeInt(int value) {
    final data = new ByteData(4);
    data.setInt32(0, value, Endian.big);
    _chunks.add(new Uint8List.view(data.buffer));
  }

  void writeShortString(String value) {
    final data = utf8.encode(value);
    writeShort(data.length);
    _chunks.add(_toUint8List(data));
  }

  void writeLongString(String value) {
    final data = utf8.encode(value);
    writeInt(data.length);
    _chunks.add(_toUint8List(data));
  }

  void writeStringMap(Map<String, String> map) {
    writeShort(map.length);
    map.forEach((k, v) {
      writeShortString(k);
      writeShortString(v);
    });
  }

  Uint8List toBytes() {
    if (_chunks.isEmpty) {
      return new Uint8List(0);
    }
    Uint8List result = _chunks[0];
    for (int i = 1; i < _chunks.length; i++) {
      final Uint8List next = _chunks[i];
      result = _toUint8List(result + next);
    }
    return result;
  }
}

class BodyReader {
  final Uint8List _body;
  final ByteData _data;
  int _offset = 0;
  BodyReader(this._body) : _data = new ByteData.view(_body.buffer);

  List<int> readBytes() {
    final length = readInt();
    final offset = _offset;
    _offset += length;
    return new Uint8List.view(_body.buffer, offset, length);
  }

  int readShort() {
    final offset = _offset;
    _offset += 2;
    return _data.getUint16(offset, Endian.big);
  }

  int readInt() {
    final offset = _offset;
    _offset += 4;
    return _data.getInt32(offset, Endian.big);
  }

  String readShortString() {
    final length = readShort();
    final buffer = new Uint8List.view(_body.buffer, _offset, length);
    final str = utf8.decode(buffer);
    _offset += length;
    return str;
  }
}
