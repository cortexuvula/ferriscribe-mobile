import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/pairing/pairing_payload.dart';

void main() {
  const fullUrl =
      'ferriscribe://pair?code=123456&host=Clinic%20Server&lan=192.168.1.42'
      '&op=11435&wp=8081&pp=11436&ts=clinic.tail-abc.ts.net&vp=11437'
      '&lp=1235&mp=8001';

  group('PairingPayload.parse', () {
    test('parses the full QR payload', () {
      final p = PairingPayload.parse(fullUrl);
      expect(p.code, '123456');
      expect(p.host, 'Clinic Server');
      expect(p.lan, '192.168.1.42');
      expect(p.tailscale, 'clinic.tail-abc.ts.net');
      expect(p.pairingPort, 11436);
      expect(p.ollamaPort, 11435);
      expect(p.whisperPort, 8081);
      expect(p.lmstudioPort, 1235);
      expect(p.omlxPort, 8001);
      expect(p.dataPort, 11437);
    });

    test('parses a minimal payload with only required params', () {
      final p = PairingPayload.parse(
        'ferriscribe://pair?code=000042&host=Clinic&op=11435&wp=8081&pp=11436',
      );
      expect(p.code, '000042');
      expect(p.lan, isNull);
      expect(p.tailscale, isNull);
      expect(p.lmstudioPort, isNull);
      expect(p.omlxPort, isNull);
      expect(p.dataPort, isNull);
    });

    test('is order-insensitive', () {
      final p = PairingPayload.parse(
        'ferriscribe://pair?pp=11436&code=123456&host=Clinic&wp=8081&op=11435',
      );
      expect(p.pairingPort, 11436);
      expect(p.code, '123456');
    });

    test('rejects a non-ferriscribe URL', () {
      expect(
        () => PairingPayload.parse('https://example.com/pair?code=123456'),
        throwsFormatException,
      );
    });

    test('rejects a missing code', () {
      expect(
        () => PairingPayload.parse(
          'ferriscribe://pair?host=Clinic&op=11435&wp=8081&pp=11436',
        ),
        throwsFormatException,
      );
    });

    test('rejects a malformed code', () {
      expect(
        () => PairingPayload.parse(
          'ferriscribe://pair?code=12ab&host=Clinic&op=11435&wp=8081&pp=11436',
        ),
        throwsFormatException,
      );
    });

    test('rejects a missing host', () {
      expect(
        () => PairingPayload.parse(
          'ferriscribe://pair?code=123456&op=11435&wp=8081&pp=11436',
        ),
        throwsFormatException,
      );
    });

    test('rejects a missing or invalid pairing port', () {
      expect(
        () => PairingPayload.parse(
          'ferriscribe://pair?code=123456&host=Clinic&op=11435&wp=8081',
        ),
        throwsFormatException,
      );
      expect(
        () => PairingPayload.parse(
          'ferriscribe://pair?code=123456&host=Clinic&op=11435&wp=8081&pp=99999',
        ),
        throwsFormatException,
      );
    });
  });

  group('PairingPayload.preferredHost', () {
    test('prefers Tailscale over LAN', () {
      final p = PairingPayload.parse(fullUrl);
      expect(p.preferredHost, 'clinic.tail-abc.ts.net');
    });

    test('falls back to LAN when no Tailscale name', () {
      final p = PairingPayload.parse(
        'ferriscribe://pair?code=123456&host=Clinic&lan=192.168.1.42'
        '&op=11435&wp=8081&pp=11436',
      );
      expect(p.preferredHost, '192.168.1.42');
    });
  });
}
