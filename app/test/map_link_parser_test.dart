import 'package:flutter_test/flutter_test.dart';
import 'package:nexronda/utils/map_link_parser.dart';

void main() {
  group('MapLinkParser tests', () {
    test('Direct coordinates parsing', () async {
      final res = await MapLinkParser.parse('3.1412, 101.6865');
      expect(res, isNotNull);
      expect(res!.latitude, closeTo(3.1412, 0.0001));
      expect(res.longitude, closeTo(101.6865, 0.0001));
    });

    test('Google Maps @lat,lng format', () async {
      final res = await MapLinkParser.parse(
        'https://www.google.com/maps/@3.139003,101.686855,15z?entry=ttu',
      );
      expect(res, isNotNull);
      expect(res!.latitude, closeTo(3.1390, 0.0001));
      expect(res.longitude, closeTo(101.6868, 0.0001));
    });

    test('Google Maps search query q=lat,lng', () async {
      final res = await MapLinkParser.parse(
        'https://maps.google.com/?q=3.4237,101.7932',
      );
      expect(res, isNotNull);
      expect(res!.latitude, closeTo(3.4237, 0.0001));
      expect(res.longitude, closeTo(101.7932, 0.0001));
    });

    test('Apple Maps ll=lat,lng format', () async {
      final res = await MapLinkParser.parse(
        'https://maps.apple.com/?ll=3.1500,101.7100&q=Petronas+Twin+Towers',
      );
      expect(res, isNotNull);
      expect(res!.latitude, closeTo(3.1500, 0.0001));
      expect(res.longitude, closeTo(101.7100, 0.0001));
    });

    test('Waze ll=lat,lng format', () async {
      final res = await MapLinkParser.parse(
        'https://waze.com/ul?ll=3.4237,101.7932&navigate=yes',
      );
      expect(res, isNotNull);
      expect(res!.latitude, closeTo(3.4237, 0.0001));
      expect(res.longitude, closeTo(101.7932, 0.0001));
    });
  });
}
