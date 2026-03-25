import 'package:dio/dio.dart';
import 'package:gocaptcha/slide_captcha_model.dart';

class CaptchaApiClient {
  CaptchaApiClient(this._dio);

  final Dio _dio;

  Future<SlideCaptchaPayload> fetchSlideCaptcha({
    required String scene,
    required String meta,
    int type = 4,
  }) async {
    final response = await _dio.get(
      '/v1/captcha',
      queryParameters: <String, dynamic>{
        'type': type,
        'scene': scene,
        'meta': meta,
      },
    );
    final payload = _unwrapBody(response.data);
    return SlideCaptchaPayload.fromMap(
      payload,
      scene: scene,
      meta: meta,
      raw: payload,
    );
  }

  Future<bool> verifySlideCaptcha({
    required String scene,
    required String meta,
    required int x,
    required int y,
  }) async {
    final response = await _dio.post(
      '/v1/captcha',
      data: <String, dynamic>{
        'scene': scene,
        'meta': meta,
        'angle': 0,
        'point': <String, dynamic>{'x': x, 'y': y},
        'dots': const <Map<String, dynamic>>[],
      },
    );
    final payload = _unwrapBody(response.data);
    final isExpired = _readBool(payload['is_expired']);
    final isSuccess = _readBool(payload['is_success']);
    return !isExpired && isSuccess;
  }

  Map<String, dynamic> _unwrapBody(dynamic raw) {
    final map = _asMap(raw);
    final nested = _asMap(map['data']);
    if (nested.isNotEmpty) {
      return nested;
    }
    return map;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((dynamic key, dynamic item) => MapEntry('$key', item));
    }
    return const <String, dynamic>{};
  }

  bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    final normalized = '$value'.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
}

class SlideCaptchaPayload {
  const SlideCaptchaPayload({
    required this.type,
    required this.model,
    required this.raw,
  });

  final int type;
  final SlideCaptchaModel model;
  final Map<String, dynamic> raw;

  bool get isSupported => type == 3 || type == 4;

  Map<String, Object?> toDebugMap() {
    return <String, Object?>{
      'type': type,
      'raw': raw,
      'displayX': model.displayX,
      'displayY': model.displayY,
      'masterWidth': model.masterWidth,
      'masterHeight': model.masterHeight,
      'thumbWidth': model.thumbWidth,
      'thumbHeight': model.thumbHeight,
      'thumbSize': model.thumbSize,
      'captchaId': model.captchaId,
      'captchaKey': model.captchaKey,
    };
  }

  factory SlideCaptchaPayload.fromMap(
    Map<String, dynamic> map, {
    required String scene,
    required String meta,
    Map<String, dynamic>? raw,
  }) {
    return SlideCaptchaPayload(
      type: _readInt(map['type']),
      raw: raw ?? map,
      model: SlideCaptchaModel.fromJson(<String, dynamic>{
        'captchaId': '${map['captchaId'] ?? map['captcha_id'] ?? scene}:$meta',
        'captchaKey': '${map['captchaKey'] ?? map['captcha_key'] ?? meta}',
        'displayX': _readInt(
          map['displayX'] ?? map['thumb_x'] ?? map['thumbX'],
        ),
        'displayY': _readInt(
          map['displayY'] ?? map['thumb_y'] ?? map['thumbY'],
        ),
        'masterHeight': _readInt(
          map['masterHeight'] ??
              map['master_height'] ??
              map['height'] ??
              map['image_height'],
          fallback: 170,
        ),
        'masterImageBase64': _normalizeBase64(
          map['image'] ?? map['masterImageBase64'],
        ),
        'masterWidth': _readInt(
          map['masterWidth'] ??
              map['master_width'] ??
              map['width'] ??
              map['image_width'],
          fallback: 320,
        ),
        'thumbHeight': _readInt(
          map['thumbHeight'] ?? map['thumb_height'],
          fallback: 44,
        ),
        'thumbImageBase64': _normalizeBase64(
          map['thumb'] ?? map['thumbImageBase64'],
        ),
        'thumbSize': _readInt(
          map['thumbSize'] ?? map['thumb_size'],
          fallback: 44,
        ),
        'thumbWidth': _readInt(
          map['thumbWidth'] ?? map['thumb_width'],
          fallback: 44,
        ),
      }),
    );
  }

  SlideCaptchaPayload copyWithModel(SlideCaptchaModel nextModel) {
    return SlideCaptchaPayload(type: type, model: nextModel, raw: raw);
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? fallback;
  }

  static String _normalizeBase64(dynamic value) {
    final raw = '$value'.trim();
    if (raw.isEmpty) {
      return '';
    }
    if (raw.startsWith('data:image')) {
      return raw;
    }
    return 'data:image/png;base64,$raw';
  }
}
