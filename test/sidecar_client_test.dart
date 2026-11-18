import 'package:aura_music/core/source/sidecar_source_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JsonRpcFramer encodes and decodes split chunks cleanly', () {
    final msg1 = {
      'jsonrpc': '2.0',
      'id': '1',
      'method': 'source.catalog.search',
    };
    final msg2 = {
      'jsonrpc': '2.0',
      'id': '2',
      'result': {'ok': true},
    };

    final bytes = [
      ...JsonRpcFramer.encode(msg1),
      ...JsonRpcFramer.encode(msg2),
    ];

    final framer = JsonRpcFramer();
    // Feed in arbitrary small chunks to verify streaming reassembly.
    final decoded = <Map<String, dynamic>>[];
    for (int i = 0; i < bytes.length; i += 7) {
      final end = (i + 7 > bytes.length) ? bytes.length : i + 7;
      decoded.addAll(framer.addBytes(bytes.sublist(i, end)));
    }

    expect(decoded.length, 2);
    expect(decoded[0]['method'], 'source.catalog.search');
    expect(decoded[1]['result']['ok'], isTrue);
  });
}
