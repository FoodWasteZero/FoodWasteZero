import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class EmailService {
  static const _resendUrl = 'https://api.resend.com/emails';

  static Future<void> sendClaimEmail({
    required String to,
    required String title,
    required String claimUrl,
    required String? selectedTermLabel,
  }) async {
    final isWeb = kIsWeb;
    if (isWeb) {
      final proxyUrl = dotenv.maybeGet('EMAIL_PROXY_URL');
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
      headers: {'Content-Type': 'application/json'},
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

  static String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}