import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/player_play_mode.dart';
import '../../domain/entities/player_history_item.dart';
import '../../domain/entities/player_track.dart';

const _historyStorageKey = 'player_play_history_v1';
const _historyLimit = 100;

class PlayerHistoryDataSource {
  const PlayerHistoryDataSource();

  Future<List<PlayerHistoryItem>> listHistory() async {
    final list = await _readRawList();
    return list.map(_toHistoryItem).toList(growable: false);
  }

  Future<int> getCount() async {
    final list = await _readRawList();
    return list.length;
  }

  Future<int> appendTrack(
    PlayerTrack track, {
    bool isRadioMode = false,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
    PlayerPlayMode? previousPlayModeBeforeRadio,
  }) async {
    final list = await _readRawList();
    final item = _toMap(
      track,
      isRadioMode: isRadioMode,
      currentRadioId: currentRadioId,
      currentRadioPlatform: currentRadioPlatform,
      currentRadioPageIndex: currentRadioPageIndex,
      previousPlayModeBeforeRadio: previousPlayModeBeforeRadio,
    );
    final next = _appendAndTrim(list, item);
    await _saveRawList(next);
    return next.length;
  }

  Future<void> clearHistory() async {
    await _saveRawList(const <Map<String, dynamic>>[]);
  }

  List<Map<String, dynamic>> _appendAndTrim(
    List<Map<String, dynamic>> history,
    Map<String, dynamic> item,
  ) {
    final deduped = history
        .where((entry) {
          return _trackKey(entry) != _trackKey(item);
        })
        .toList(growable: true);
    deduped.insert(0, item);
    if (deduped.length > _historyLimit) {
      return deduped.sublist(0, _historyLimit);
    }
    return deduped;
  }

  Future<List<Map<String, dynamic>>> _readRawList() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString(_historyStorageKey);
    if (payload == null || payload.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! List) {
        return <Map<String, dynamic>>[];
      }
      return decoded.whereType<Map>().map(_asMap).toList(growable: false);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _saveRawList(List<Map<String, dynamic>> value) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(value);
    await prefs.setString(_historyStorageKey, payload);
  }

  Map<String, dynamic> _toMap(
    PlayerTrack track, {
    required bool isRadioMode,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
    PlayerPlayMode? previousPlayModeBeforeRadio,
  }) {
    return <String, dynamic>{
      'id': track.id,
      'title': track.title,
      'artist': track.artist ?? '',
      'album': track.album ?? '',
      'artworkUrl': track.artworkUrl ?? '',
      'url': track.url,
      'platform': track.platform ?? '',
      'playedAt': DateTime.now().millisecondsSinceEpoch,
      'is_radio_mode': isRadioMode,
      'current_radio_id': currentRadioId,
      'current_radio_platform': currentRadioPlatform,
      'current_radio_page_index': currentRadioPageIndex,
      'previous_play_mode_before_radio': previousPlayModeBeforeRadio?.name,
    };
  }

  Map<String, dynamic> _asMap(Map value) {
    return value.map((key, entry) => MapEntry('$key', entry));
  }

  String _trackKey(Map<String, dynamic> item) {
    final id = '${item['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      return '';
    }
    final platform = '${item['platform'] ?? ''}'.trim();
    if (platform == 'local') {
      return id;
    }
    if (platform.isNotEmpty) {
      return '$id|$platform';
    }
    return id;
  }

  PlayerHistoryItem _toHistoryItem(Map<String, dynamic> item) {
    return PlayerHistoryItem(
      id: '${item['id'] ?? ''}',
      title: '${item['title'] ?? ''}',
      artist: '${item['artist'] ?? ''}',
      album: '${item['album'] ?? ''}',
      artworkUrl: '${item['artworkUrl'] ?? ''}',
      url: '${item['url'] ?? ''}',
      playedAt: _toInt(item['playedAt']),
      platform: _toOptionalText(item['platform']),
      isRadioMode: item['is_radio_mode'] == true,
      currentRadioId: _toOptionalText(item['current_radio_id']),
      currentRadioPlatform: _toOptionalText(item['current_radio_platform']),
      currentRadioPageIndex: _toOptionalInt(item['current_radio_page_index']),
      previousPlayModeBeforeRadio: _toPlayMode(
        item['previous_play_mode_before_radio'],
      ),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }

  String? _toOptionalText(dynamic value) {
    if (value == null) {
      return null;
    }
    final text = '$value'.trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  int? _toOptionalInt(dynamic value) {
    if (value == null) {
      return null;
    }
    final parsed = int.tryParse('$value');
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  PlayerPlayMode? _toPlayMode(dynamic value) {
    final normalized = '$value'.trim();
    if (normalized.isEmpty || normalized == 'null') {
      return null;
    }
    for (final mode in PlayerPlayMode.values) {
      if (mode.name == normalized) {
        return mode;
      }
    }
    return null;
  }
}
