import 'package:flutter_test/flutter_test.dart';
import 'package:avora_ai/services/api_client.dart';

void main() {
  test('API errors expose a useful message', () {
    const exception = ApiException('Máy chủ chưa phản hồi');
    expect(exception.toString(), 'Máy chủ chưa phản hồi');
  });
}
