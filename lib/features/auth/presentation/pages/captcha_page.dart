import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gocaptcha/slide_captcha_model.dart';

import '../../../../app/app_message_service.dart';
import '../../../../core/network/api_dio_provider.dart';
import '../../data/datasources/captcha_api_client.dart';

class CaptchaPage extends ConsumerStatefulWidget {
  const CaptchaPage({required this.scene, required this.meta, super.key});

  final String scene;
  final String meta;

  @override
  ConsumerState<CaptchaPage> createState() => _CaptchaPageState();
}

class _CaptchaPageState extends ConsumerState<CaptchaPage> {
  int _captchaSeed = 0;
  bool _loading = true;
  String? _errorMessage;
  String? _unsupportedMessage;
  SlideCaptchaPayload? _captchaPayload;

  CaptchaApiClient get _client => CaptchaApiClient(ref.read(apiDioProvider));

  @override
  void initState() {
    super.initState();
    _loadCaptcha();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('验证码验证'),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _resetCaptcha,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return _StatusPanel(
        title: '验证码加载失败',
        message: errorMessage,
        primaryLabel: '重新加载',
        onPrimaryTap: _resetCaptcha,
      );
    }
    final unsupportedMessage = _unsupportedMessage;
    if (unsupportedMessage != null) {
      return _StatusPanel(
        title: '当前验证码类型暂不支持',
        message: unsupportedMessage,
        primaryLabel: '重新获取',
        onPrimaryTap: _resetCaptcha,
      );
    }
    final payload = _captchaPayload;
    if (payload == null) {
      return _StatusPanel(
        title: '验证码数据为空',
        message: '请重新加载',
        primaryLabel: '重新加载',
        onPrimaryTap: _resetCaptcha,
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: switch (payload.type) {
        3 => _DragCaptchaCard(
          key: ValueKey<int>(_captchaSeed),
          model: payload.model,
          onVerify: _verifyCaptcha,
        ),
        _ => _SlideCaptchaCard(
          key: ValueKey<int>(_captchaSeed),
          model: payload.model,
          onVerify: _verifyCaptcha,
        ),
      },
    );
  }

  Future<void> _loadCaptcha() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
        _unsupportedMessage = null;
      });
    }
    try {
      final rawPayload = await _client.fetchSlideCaptcha(
        scene: widget.scene,
        meta: widget.meta,
      );
      final payload = await _normalizeCaptchaPayload(rawPayload);
      // debugPrint('captcha payload mapped: ${jsonEncode(payload.toDebugMap())}');
      if (!payload.isSupported) {
        if (!mounted) {
          return;
        }
        setState(() {
          _captchaPayload = null;
          _loading = false;
          _unsupportedMessage = '后端当前返回的类型是 ${payload.type}，当前只接入滑块/拖拽拼图验证码。';
        });
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _captchaPayload = payload;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _captchaPayload = null;
        _loading = false;
        _errorMessage = _normalizeError(error);
      });
    }
  }

  Future<bool> _verifyCaptcha(int x, int y) async {
    try {
      final isSuccess = await _client.verifySlideCaptcha(
        scene: widget.scene,
        meta: widget.meta,
        x: x,
        y: y,
      );
      if (!isSuccess) {
        _showMessage('验证码校验失败，请重试。');
        _resetCaptcha();
        return false;
      }
      if (mounted) {
        context.pop(true);
      }
      return true;
    } catch (error) {
      _showMessage(_normalizeError(error));
      _resetCaptcha();
      return false;
    }
  }

  Future<SlideCaptchaPayload> _normalizeCaptchaPayload(
    SlideCaptchaPayload payload,
  ) async {
    final model = payload.model;
    final decodedMaster = await _decodeImageSize(model.masterImageBase64);
    final decodedThumb = await _decodeImageSize(model.thumbImageBase64);
    final raw = payload.raw;
    final masterWidth = _pickDimension(
      preferred: model.masterWidth,
      decoded: decodedMaster?.$1,
      rawCandidates: <dynamic>[
        raw['masterWidth'],
        raw['master_width'],
        raw['image_width'],
        raw['width'],
      ],
    );
    final masterHeight = _pickDimension(
      preferred: model.masterHeight,
      decoded: decodedMaster?.$2,
      rawCandidates: <dynamic>[
        raw['masterHeight'],
        raw['master_height'],
        raw['image_height'],
        raw['height'],
      ],
    );
    final thumbWidth = _pickDimension(
      preferred: model.thumbWidth,
      decoded: decodedThumb?.$1,
      rawCandidates: <dynamic>[raw['thumbWidth'], raw['thumb_width']],
    );
    final thumbHeight = _pickDimension(
      preferred: model.thumbHeight,
      decoded: decodedThumb?.$2,
      rawCandidates: <dynamic>[raw['thumbHeight'], raw['thumb_height']],
    );
    final normalizedModel = SlideCaptchaModel.fromJson(<String, dynamic>{
      'captchaId': model.captchaId,
      'captchaKey': model.captchaKey,
      'displayX': model.displayX,
      'displayY': model.displayY,
      'masterWidth': masterWidth,
      'masterHeight': masterHeight,
      'masterImageBase64': _bytesToBase64DataUrl(model.masterImageBase64),
      'thumbWidth': thumbWidth,
      'thumbHeight': thumbHeight,
      'thumbSize': model.thumbSize,
      'thumbImageBase64': _bytesToBase64DataUrl(model.thumbImageBase64),
    });
    return payload.copyWithModel(normalizedModel);
  }

  Future<(int, int)?> _decodeImageSize(Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    final completer = Completer<(int, int)?>();
    ui.decodeImageFromList(bytes, (ui.Image image) {
      completer.complete((image.width, image.height));
      image.dispose();
    });
    return completer.future;
  }

  int _pickDimension({
    required int? preferred,
    required int? decoded,
    required List<dynamic> rawCandidates,
  }) {
    for (final candidate in rawCandidates) {
      final value = _readInt(candidate);
      if (value != null && value > 0) {
        return value;
      }
    }
    if (decoded != null && decoded > 0) {
      return decoded;
    }
    if (preferred != null && preferred > 0) {
      return preferred;
    }
    return 1;
  }

  int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value');
  }

  String _bytesToBase64DataUrl(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return '';
    }
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }

  void _resetCaptcha() {
    setState(() {
      _captchaSeed += 1;
    });
    _loadCaptcha();
  }

  void _showMessage(String message) {
    AppMessageService.showError(message);
  }

  String _normalizeError(Object error) {
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return '$error';
  }
}

class _SlideCaptchaCard extends StatefulWidget {
  const _SlideCaptchaCard({
    required this.model,
    required this.onVerify,
    super.key,
  });

  final SlideCaptchaModel model;
  final Future<bool> Function(int x, int y) onVerify;

  @override
  State<_SlideCaptchaCard> createState() => _SlideCaptchaCardState();
}

class _SlideCaptchaCardState extends State<_SlideCaptchaCard> {
  static const double _handleWidth = 82;

  late double _dragLeft;
  bool _submitting = false;

  double get _imageWidth => (widget.model.masterWidth ?? 0).toDouble();
  double get _imageHeight => (widget.model.masterHeight ?? 0).toDouble();
  double get _thumbWidth => (widget.model.thumbWidth ?? 0).toDouble();
  double get _thumbHeight => (widget.model.thumbHeight ?? 0).toDouble();
  double get _thumbTop => (widget.model.displayY ?? 0).toDouble();
  double get _maxThumbLeft =>
      (_imageWidth - _thumbWidth).clamp(0, double.infinity);
  double get _maxDragLeft =>
      (_imageWidth - _handleWidth).clamp(0, double.infinity);

  double get _thumbLeft {
    if (_maxDragLeft <= 0 || _maxThumbLeft <= 0) {
      return 0;
    }
    return (_dragLeft * _maxThumbLeft / _maxDragLeft).clamp(0, _maxThumbLeft);
  }

  @override
  void initState() {
    super.initState();
    _dragLeft = _thumbToDrag((widget.model.displayX ?? 0).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: _imageWidth,
          height: _imageHeight,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Image.memory(
                  widget.model.masterImageBase64!,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
              ),
              Positioned(
                left: _thumbLeft,
                top: _thumbTop,
                child: SizedBox(
                  width: _thumbWidth,
                  height: _thumbHeight,
                  child: Image.memory(
                    widget.model.thumbImageBase64!,
                    width: _thumbWidth,
                    height: _thumbHeight,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: _imageWidth,
          height: 52,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Positioned(
                left: _dragLeft,
                child: GestureDetector(
                  onHorizontalDragUpdate: _submitting
                      ? null
                      : _handleDragUpdate,
                  onHorizontalDragEnd: _submitting ? null : (_) => _submit(),
                  child: Container(
                    width: _handleWidth,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: _submitting
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.arrow_forward_rounded,
                            color: theme.colorScheme.onPrimary,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragLeft = (_dragLeft + details.delta.dx).clamp(0, _maxDragLeft);
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
    });
    await widget.onVerify(_thumbLeft.round(), _thumbTop.round());
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
    });
  }

  double _thumbToDrag(double thumbLeft) {
    if (_maxThumbLeft <= 0 || _maxDragLeft <= 0) {
      return 0;
    }
    return (thumbLeft * _maxDragLeft / _maxThumbLeft).clamp(0, _maxDragLeft);
  }
}

class _DragCaptchaCard extends StatefulWidget {
  const _DragCaptchaCard({
    required this.model,
    required this.onVerify,
    super.key,
  });

  final SlideCaptchaModel model;
  final Future<bool> Function(int x, int y) onVerify;

  @override
  State<_DragCaptchaCard> createState() => _DragCaptchaCardState();
}

class _DragCaptchaCardState extends State<_DragCaptchaCard> {
  late double _left;
  late double _top;
  bool _submitting = false;

  double get _imageWidth => (widget.model.masterWidth ?? 0).toDouble();
  double get _imageHeight => (widget.model.masterHeight ?? 0).toDouble();
  double get _thumbWidth => (widget.model.thumbWidth ?? 0).toDouble();
  double get _thumbHeight => (widget.model.thumbHeight ?? 0).toDouble();
  double get _maxLeft => (_imageWidth - _thumbWidth).clamp(0, double.infinity);
  double get _maxTop => (_imageHeight - _thumbHeight).clamp(0, double.infinity);

  @override
  void initState() {
    super.initState();
    _left = (widget.model.displayX ?? 0).toDouble();
    _top = (widget.model.displayY ?? 0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: _imageWidth,
          height: _imageHeight,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Image.memory(
                  widget.model.masterImageBase64!,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
              ),
              Positioned(
                left: _left,
                top: _top,
                child: GestureDetector(
                  onPanUpdate: _submitting ? null : _handlePanUpdate,
                  onPanEnd: _submitting ? null : (_) => _submit(),
                  child: SizedBox(
                    width: _thumbWidth,
                    height: _thumbHeight,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Positioned.fill(
                          child: Image.memory(
                            widget.model.thumbImageBase64!,
                            width: _thumbWidth,
                            height: _thumbHeight,
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                          ),
                        ),
                        if (_submitting)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _left = (_left + details.delta.dx).clamp(0, _maxLeft);
      _top = (_top + details.delta.dy).clamp(0, _maxTop);
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
    });
    await widget.onVerify(_left.round(), _top.round());
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
    });
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimaryTap,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimaryTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPrimaryTap,
              child: Text(primaryLabel),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.pop(false),
              child: const Text('取消'),
            ),
          ),
        ],
      ),
    );
  }
}
