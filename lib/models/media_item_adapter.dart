import 'package:audio_service/audio_service.dart';
import 'package:hive_ce/hive.dart';

class MediaItemAdapter extends TypeAdapter<MediaItem> {
  @override
  final typeId = 500;

  @override
  MediaItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MediaItem(
      id: fields[0] as String,
      title: fields[1] as String,
      album: fields[2] as String?,
      artist: fields[3] as String?,
      genre: fields[4] as String?,
      duration: fields[5] == null ? null : Duration(microseconds: fields[5] as int),
      artUri: fields[6] == null ? null : Uri.tryParse(fields[6] as String),
      displayTitle: fields[7] as String?,
      displaySubtitle: fields[8] as String?,
      displayDescription: fields[9] as String?,
      rating: null,
      isLive: fields[10] as bool?,
      extras: fields[11] == null ? null : _castMap(fields[11]),
      playable: fields[12] as bool? ?? true,
      artHeaders: fields[13] == null ? null : _castMap(fields[13]).cast<String, String>(),
    );
  }

  @override
  void write(BinaryWriter writer, MediaItem obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.album)
      ..writeByte(3)
      ..write(obj.artist)
      ..writeByte(4)
      ..write(obj.genre)
      ..writeByte(5)
      ..write(obj.duration?.inMicroseconds)
      ..writeByte(6)
      ..write(obj.artUri?.toString())
      ..writeByte(7)
      ..write(obj.displayTitle)
      ..writeByte(8)
      ..write(obj.displaySubtitle)
      ..writeByte(9)
      ..write(obj.displayDescription)
      ..writeByte(10)
      ..write(obj.isLive)
      ..writeByte(11)
      ..write(obj.extras)
      ..writeByte(12)
      ..write(obj.playable)
      ..writeByte(13)
      ..write(obj.artHeaders);
  }

  static Map<String, dynamic> _castMap(dynamic source) {
    final map = source as Map;
    return Map<String, dynamic>.from(
      map.map((k, v) => MapEntry(k.toString(), _wrapValue(v))),
    );
  }

  static dynamic _wrapValue(dynamic value) {
    if (value is Map) {
      return _castMap(value);
    }
    if (value is List) {
      return value.map(_wrapValue).toList();
    }
    return value;
  }
}