import 'package:dio/dio.dart';

import '../../app/app_message_service.dart';
import 'network_error_message.dart';

class ErrorMessageInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_isSilent(err.requestOptions)) {
      handler.next(err);
      return;
    }
    final message = NetworkErrorMessage.resolve(
      err,
      ignoreUnauthorized: true,
      ignoreCaptchaRequired: true,
    );
    if (message != null) {
      AppMessageService.showError(message);
    }
    handler.next(err);
  }

  bool _isSilent(RequestOptions options) {
    return options.extra['silentErrorMessage'] == true;
  }
}
