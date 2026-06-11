import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class EmailService {
  static const _resendUrl = 'https://api.resend.com/emails';

  static String? _webProxyUrl() {
    final buildTimeValue = const String.fromEnvironment('EMAIL_PROXY_URL');
    if (buildTimeValue.trim().isNotEmpty) {
      return buildTimeValue.trim();
    }

    final envValue = dotenv.maybeGet('EMAIL_PROXY_URL')?.trim();
    if (envValue != null && envValue.isNotEmpty) {
      return envValue;
    }

    return null;
  }

  static Future<void> sendClaimEmail({
    required String to,
    required String title,
    required String claimUrl,
    required String? selectedTermLabel,
  }) async {
    final isWeb = kIsWeb;
    if (isWeb) {
      final proxyUrl = _webProxyUrl();
      if (proxyUrl == null || proxyUrl.isEmpty) {
        throw StateError('EMAIL_PROXY_URL is missing from .env for web');
      }

      final bodyText = _buildBodyText(title, claimUrl, selectedTermLabel);
      final resp = await http.post(
        Uri.parse('$proxyUrl/send-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': to,
          'subject': 'Potrditev rezervacije: $title',
          'text': bodyText,
          'html': _buildHtml(title, claimUrl, selectedTermLabel),
        }),
      );

      debugPrint('EmailService(web): status=${resp.statusCode} body=${resp.body}');

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw StateError('Email proxy failed: ${resp.statusCode} ${resp.body}');
      }
      debugPrint('Offer email sent to $to via web proxy');
      return;
    }

    final apiKey = dotenv.maybeGet('EMAIL_API_KEY');
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('EMAIL_API_KEY is missing from .env for mobile');
    }
    final fromAddress = dotenv.maybeGet('EMAIL_FROM_ADDRESS')?.trim().isNotEmpty == true
        ? dotenv.maybeGet('EMAIL_FROM_ADDRESS')!.trim()
        : 'onboarding@resend.dev';

    final bodyText = _buildBodyText(title, claimUrl, selectedTermLabel);
    final html = _buildHtml(title, claimUrl, selectedTermLabel);
    final payload = jsonEncode({
      'from': fromAddress,
      'to': to,
      'subject': 'Potrditev rezervacije: $title',
      'text': bodyText,
      'html': html,
    });

    debugPrint('EmailService(mobile): sending to=$to from=$fromAddress subject=Potrditev rezervacije: $title');
    debugPrint('EmailService(mobile): payload=${payload.length} bytes');

    final resp = await http.post(
      Uri.parse(_resendUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: payload,
    );

    debugPrint('EmailService(mobile): status=${resp.statusCode} body=${resp.body}');

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('Email API failed: ${resp.statusCode} ${resp.body}');
    }
    debugPrint('Offer email sent to $to via Resend');
  }

  static Future<void> sendPickupQrEmail({
    required String to,
    required String title,
    required int reservedPortions,
    required String pickupUrl,
    required String? selectedTermLabel,
  }) async {
    final isWeb = kIsWeb;
    if (isWeb) {
      final proxyUrl = _webProxyUrl();
      if (proxyUrl == null || proxyUrl.isEmpty) {
        throw StateError('EMAIL_PROXY_URL is missing from .env for web');
      }

      final bodyText = _buildPickupBodyText(
        title,
        reservedPortions,
        pickupUrl,
        selectedTermLabel,
      );
      final resp = await http.post(
        Uri.parse('$proxyUrl/send-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': to,
          'subject': 'QR koda za prevzem: $title',
          'text': bodyText,
          'html': _buildPickupHtml(title, reservedPortions, pickupUrl, selectedTermLabel),
        }),
      );

      debugPrint('EmailService(web pickup): status=${resp.statusCode} body=${resp.body}');

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw StateError('Email proxy failed: ${resp.statusCode} ${resp.body}');
      }
      debugPrint('Pickup QR email sent to $to via web proxy');
      return;
    }

    final apiKey = dotenv.maybeGet('EMAIL_API_KEY');
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('EMAIL_API_KEY is missing from .env for mobile');
    }
    final fromAddress = dotenv.maybeGet('EMAIL_FROM_ADDRESS')?.trim().isNotEmpty == true
        ? dotenv.maybeGet('EMAIL_FROM_ADDRESS')!.trim()
        : 'onboarding@resend.dev';

    final bodyText = _buildPickupBodyText(
      title,
      reservedPortions,
      pickupUrl,
      selectedTermLabel,
    );
    final html = _buildPickupHtml(
      title,
      reservedPortions,
      pickupUrl,
      selectedTermLabel,
    );
    final payload = jsonEncode({
      'from': fromAddress,
      'to': to,
      'subject': 'QR koda za prevzem: $title',
      'text': bodyText,
      'html': html,
    });

    debugPrint('EmailService(mobile pickup): sending to=$to from=$fromAddress subject=QR koda za prevzem: $title');
    debugPrint('EmailService(mobile pickup): payload=${payload.length} bytes');

    final resp = await http.post(
      Uri.parse(_resendUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: payload,
    );

    debugPrint('EmailService(mobile pickup): status=${resp.statusCode} body=${resp.body}');

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('Email API failed: ${resp.statusCode} ${resp.body}');
    }
    debugPrint('Pickup QR email sent to $to via Resend');
  }

  static String _buildBodyText(String title, String claimUrl, String? selectedTermLabel) {
    final bodyText = StringBuffer()
      ..writeln('Rezervacija za "$title" je pripravljena za potrditev.')
      ..writeln()
      ..writeln('Kliknite povezavo za potrditev in izbiro termina:')
      ..writeln(claimUrl)
      ..writeln()
      ..writeln('Ta povezava velja 3 ure.');
    if (selectedTermLabel != null && selectedTermLabel.isNotEmpty) {
      bodyText.writeln();
      bodyText.writeln('Predlagani termin: $selectedTermLabel');
    }
    return bodyText.toString();
  }

  static String _buildHtml(String title, String claimUrl, String? selectedTermLabel) {
    return '''
      <div style="font-family:Arial,sans-serif;line-height:1.5;color:#1f2937">
        <h2 style="margin:0 0 12px">Rezervacija čaka na potrditev</h2>
        <p>Za oglas <strong>${_escapeHtml(title)}</strong> je na voljo 3-urni rok za potrditev.</p>
        ${selectedTermLabel != null && selectedTermLabel.isNotEmpty ? '<p>Predlagani termin: <strong>${_escapeHtml(selectedTermLabel)}</strong></p>' : ''}
        <p><a href="$claimUrl" style="display:inline-block;background:#2E7D32;color:#fff;text-decoration:none;padding:12px 16px;border-radius:10px;font-weight:700">Odpri potrditev</a></p>
        <p>Če gumb ne deluje, kopirajte povezavo:</p>
        <p><a href="$claimUrl">$claimUrl</a></p>
      </div>
    ''';
  }

  static String _buildPickupBodyText(
    String title,
    int reservedPortions,
    String pickupUrl,
    String? selectedTermLabel,
  ) {
    final qrUrl = _buildQrImageUrl(pickupUrl);
    final bodyText = StringBuffer()
      ..writeln('QR koda za prevzem za "$title" je pripravljena.')
      ..writeln('Rezervirali ste ${reservedPortions} ${reservedPortions == 1 ? 'porcijo' : reservedPortions < 5 ? 'porcije' : 'porcij'}.')
      ..writeln()
      ..writeln('Organizacija naj skenira QR kodo ali odpre povezavo za potrditev prevzema:')
      ..writeln(pickupUrl)
      ..writeln()
      ..writeln('QR slika: $qrUrl');
    if (selectedTermLabel != null && selectedTermLabel.isNotEmpty) {
      bodyText.writeln();
      bodyText.writeln('Izbran termin: $selectedTermLabel');
    }
    return bodyText.toString();
  }

  static String _buildPickupHtml(
    String title,
    int reservedPortions,
    String pickupUrl,
    String? selectedTermLabel,
  ) {
    final qrUrl = _buildQrImageUrl(pickupUrl);
    return '''
      <div style="font-family:Arial,sans-serif;line-height:1.5;color:#1f2937">
        <h2 style="margin:0 0 12px">QR koda za prevzem</h2>
        <p>Za oglas <strong>${_escapeHtml(title)}</strong> je pripravljena QR koda za potrditev prevzema.</p>
        <p>Rezervirali ste <strong>$reservedPortions</strong> ${reservedPortions == 1 ? 'porcijo' : reservedPortions < 5 ? 'porcije' : 'porcij'}.</p>
        ${selectedTermLabel != null && selectedTermLabel.isNotEmpty ? '<p>Izbran termin: <strong>${_escapeHtml(selectedTermLabel)}</strong></p>' : ''}
        <p style="margin:20px 0"><img src="$qrUrl" alt="QR koda za prevzem" width="220" height="220" style="display:block;border:8px solid #fff;border-radius:16px;box-shadow:0 8px 24px rgba(0,0,0,0.08)" /></p>
        <p>Če QR ne deluje, odprite povezavo:</p>
        <p><a href="$pickupUrl">$pickupUrl</a></p>
      </div>
    ''';
  }

  static String _buildQrImageUrl(String value) {
    return 'https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=${Uri.encodeComponent(value)}';
  }

  static String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static Future<void> sendPickupConfirmedEmail({
    required String to,
    required String title,
    required String confirmationCode,
  }) async {
    final isWeb = kIsWeb;
    final subject = 'Prevzem potrjen: $title';
    final bodyText = 'Prevzem za "$title" je potrjen.\n\nKoda: $confirmationCode\n\nHvala.';
    final html = '''
      <div style="font-family:Arial,sans-serif;line-height:1.5;color:#1f2937">
        <h2 style="margin:0 0 12px">Prevzem potrjen</h2>
        <p>Prevzem za oglas <strong>${_escapeHtml(title)}</strong> je bil potrjen.</p>
        <p style="font-size:20px;font-weight:700;">Koda: ${_escapeHtml(confirmationCode)}</p>
        <p>Hvala, ker uporabljate FoodWasteZero.</p>
      </div>
    ''';

    if (isWeb) {
      final proxyUrl = _webProxyUrl();
      if (proxyUrl == null || proxyUrl.isEmpty) {
        throw StateError('EMAIL_PROXY_URL is missing from .env for web');
      }

      final resp = await http.post(
        Uri.parse('$proxyUrl/send-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': to,
          'subject': subject,
          'text': bodyText,
          'html': html,
        }),
      );

      debugPrint('Pickup confirmed email (web): status=${resp.statusCode} body=${resp.body}');

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw StateError('Email proxy failed: ${resp.statusCode} ${resp.body}');
      }
      return;
    }

    final apiKey = dotenv.maybeGet('EMAIL_API_KEY');
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('EMAIL_API_KEY is missing from .env for mobile');
    }
    final fromAddress = dotenv.maybeGet('EMAIL_FROM_ADDRESS')?.trim().isNotEmpty == true
        ? dotenv.maybeGet('EMAIL_FROM_ADDRESS')!.trim()
        : 'onboarding@resend.dev';

    final payload = jsonEncode({
      'from': fromAddress,
      'to': to,
      'subject': subject,
      'text': bodyText,
      'html': html,
    });

    final resp = await http.post(
      Uri.parse(_resendUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: payload,
    );

    debugPrint('Pickup confirmed email: status=${resp.statusCode} body=${resp.body}');

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('Email API failed: ${resp.statusCode} ${resp.body}');
    }
    debugPrint('Pickup confirmed email sent to $to');
  }
}