import 'package:http/http.dart' as http;

class MapLinkParser {
  /// Result of parsing a map URL or coordinates string.
  static final RegExp _latLngPairRegex = RegExp(
    r'([-+]?\d{1,2}(?:\.\d+)?)\s*,\s*([-+]?\d{1,3}(?:\.\d+)?)',
  );

  /// Extracts coordinates from text, links, or coordinates strings.
  /// Supports:
  /// - Direct lat,lng: "3.4237, 101.7932" or "3.4237,101.7932"
  /// - Google Maps:
  ///   - `.../@3.1412,101.6865,17z...`
  ///   - `...q=3.1412,101.6865...` or `...query=3.1412,101.6865`
  ///   - `...destination=3.1412,101.6865...`
  ///   - `...ll=3.1412,101.6865...`
  ///   - Shortened URLs: `https://maps.app.goo.gl/...` or `https://goo.gl/maps/...` (follows redirects)
  /// - Apple Maps:
  ///   - `...ll=3.1412,101.6865...`
  ///   - `...daddr=3.1412,101.6865...`
  ///   - `...coordinate=3.1412,101.6865...`
  ///   - `...q=3.1412,101.6865...`
  /// - Waze:
  ///   - `...ll=3.1412,101.6865...`
  ///   - `...navigate=yes&to=ll.3.1412,101.6865`
  static Future<MapParseResult?> parse(String rawInput) async {
    final input = rawInput.trim();
    if (input.isEmpty) return null;

    // Check if input itself is direct lat,lng
    final directMatch = _latLngPairRegex.firstMatch(input);
    if (directMatch != null && !input.startsWith('http://') && !input.startsWith('https://')) {
      final lat = double.tryParse(directMatch.group(1)!);
      final lng = double.tryParse(directMatch.group(2)!);
      if (lat != null && lng != null && _isValid(lat, lng)) {
        return MapParseResult(latitude: lat, longitude: lng);
      }
    }

    String urlToProcess = input;

    // If input contains a URL within text (e.g. shared text from WhatsApp/Telegram)
    final urlRegex = RegExp(r'https?://[^\s]+');
    final match = urlRegex.firstMatch(input);
    if (match != null) {
      urlToProcess = match.group(0)!;
    }

    // Try extracting coordinates directly from URL query/path parameters first
    final directParamResult = _extractFromUrlString(urlToProcess);
    if (directParamResult != null) {
      return directParamResult;
    }

    // If it's a shortened URL (Google Maps shortlinks, etc.), resolve redirect
    if (urlToProcess.contains('maps.app.goo.gl') ||
        urlToProcess.contains('goo.gl/maps') ||
        urlToProcess.contains('waze.com') ||
        urlToProcess.contains('apple.co')) {
      try {
        final client = http.Client();
        final request = http.Request('GET', Uri.parse(urlToProcess))..followRedirects = false;
        // User-agent to prevent bot blockers
        request.headers['User-Agent'] =
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';

        final streamedResponse = await client.send(request).timeout(const Duration(seconds: 4));
        final redirectLocation = streamedResponse.headers['location'];
        if (redirectLocation != null && redirectLocation.isNotEmpty) {
          final redirectedResult = _extractFromUrlString(redirectLocation);
          if (redirectedResult != null) {
            return redirectedResult;
          }

          // If relative or further redirect
          if (redirectLocation.startsWith('/')) {
            final baseUri = Uri.parse(urlToProcess);
            final fullRedirect = '${baseUri.scheme}://${baseUri.host}$redirectLocation';
            final fullResult = _extractFromUrlString(fullRedirect);
            if (fullResult != null) return fullResult;
          }
        }
      } catch (_) {
        // Fallback gracefully if network timeout or offline
      }
    }

    return null;
  }

  static MapParseResult? _extractFromUrlString(String urlStr) {
    // 1. Google Maps /@lat,lng,zoom
    final atPattern = RegExp(r'@([-+]?\d{1,2}\.\d+),([-+]?\d{1,3}\.\d+)');
    final atMatch = atPattern.firstMatch(urlStr);
    if (atMatch != null) {
      final lat = double.tryParse(atMatch.group(1)!);
      final lng = double.tryParse(atMatch.group(2)!);
      if (lat != null && lng != null && _isValid(lat, lng)) {
        return MapParseResult(
          latitude: lat,
          longitude: lng,
          label: _extractPlaceName(urlStr),
        );
      }
    }

    // 2. Query parameters (q=, query=, destination=, daddr=, ll=, coordinate=)
    try {
      final uri = Uri.parse(urlStr);
      final queryParams = uri.queryParameters;

      for (final key in ['destination', 'daddr', 'll', 'coordinate', 'q', 'query']) {
        if (queryParams.containsKey(key)) {
          final val = queryParams[key]!;
          final match = _latLngPairRegex.firstMatch(val);
          if (match != null) {
            final lat = double.tryParse(match.group(1)!);
            final lng = double.tryParse(match.group(2)!);
            if (lat != null && lng != null && _isValid(lat, lng)) {
              return MapParseResult(
                latitude: lat,
                longitude: lng,
                label: queryParams['name'] ?? _extractPlaceName(urlStr),
              );
            }
          }
        }
      }
    } catch (_) {}

    // 3. Fallback regex search for !3d<lat>!4d<lng> (Google Maps place URLs)
    final googleDataPattern = RegExp(r'!3d([-+]?\d{1,2}\.\d+)!4d([-+]?\d{1,3}\.\d+)');
    final googleDataMatch = googleDataPattern.firstMatch(urlStr);
    if (googleDataMatch != null) {
      final lat = double.tryParse(googleDataMatch.group(1)!);
      final lng = double.tryParse(googleDataMatch.group(2)!);
      if (lat != null && lng != null && _isValid(lat, lng)) {
        return MapParseResult(
          latitude: lat,
          longitude: lng,
          label: _extractPlaceName(urlStr),
        );
      }
    }

    // 4. Fallback search for any lat,lng within the string
    final fallbackMatch = _latLngPairRegex.firstMatch(urlStr);
    if (fallbackMatch != null) {
      final lat = double.tryParse(fallbackMatch.group(1)!);
      final lng = double.tryParse(fallbackMatch.group(2)!);
      if (lat != null && lng != null && _isValid(lat, lng)) {
        return MapParseResult(latitude: lat, longitude: lng);
      }
    }

    return null;
  }

  static String? _extractPlaceName(String urlStr) {
    try {
      final uri = Uri.parse(urlStr);
      if (uri.pathSegments.contains('place')) {
        final placeIdx = uri.pathSegments.indexOf('place');
        if (placeIdx + 1 < uri.pathSegments.length) {
          final rawName = uri.pathSegments[placeIdx + 1];
          return Uri.decodeComponent(rawName).replaceAll('+', ' ');
        }
      }
      if (uri.queryParameters.containsKey('name')) {
        return uri.queryParameters['name'];
      }
      if (uri.queryParameters.containsKey('q')) {
        final q = uri.queryParameters['q']!;
        if (!_latLngPairRegex.hasMatch(q)) {
          return Uri.decodeComponent(q).replaceAll('+', ' ');
        }
      }
    } catch (_) {}
    return null;
  }

  static bool _isValid(double lat, double lng) {
    return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
  }
}

class MapParseResult {
  final double latitude;
  final double longitude;
  final String? label;

  const MapParseResult({
    required this.latitude,
    required this.longitude,
    this.label,
  });
}
