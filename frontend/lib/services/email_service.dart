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
    final apiKey = dotenv.maybeGet('EMAIL_API_KEY');
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('EMAIL_API_KEY is missing from .env');
    }
    final fromAddress = dotenv.maybeGet('EMAIL_FROM_ADDRESS')?.trim().isNotEmpty == true
        ? dotenv.maybeGet('EMAIL_FROM_ADDRESS')!.trim()
        : 'FoodWasteZero <onboarding@resend.dev>';

    final bodyText = StringBuffer()
      ..writeln('Rezervacija za "$title" je pripravljena za potrditev.')
      ..writeln()
      ..writeln('Kliknite povezavo za potrditev in izbiro termina:')
      ..writeln(claimUrl)
      ..writeln()
      ..writeln('Ta povezava velja 3 ure.')
      ..writeln();
    if (selectedTermLabel != null && selectedTermLabel.isNotEmpty) {
      bodyText.writeln('Predlagani termin: $selectedTermLabel');
    }

    final resp = await http.post(
      Uri.parse(_resendUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'from': fromAddress,
        'to': [to],
        'subject': 'Potrditev rezervacije: $title',
        'text': bodyText.toString(),
        'html': '''
          <div style="font-family:Arial,sans-serif;line-height:1.5;color:#1f2937">
            <h2 style="margin:0 0 12px">Rezervacija čaka na potrditev</h2>
            <p>Za oglas <strong>${_escapeHtml(title)}</strong> je na voljo 3-urni rok za potrditev.</p>
            ${selectedTermLabel != null && selectedTermLabel.isNotEmpty ? '<p>Predlagani termin: <strong>${_escapeHtml(selectedTermLabel)}</strong></p>' : ''}
            <p><a href="$claimUrl" style="display:inline-block;background:#2E7D32;color:#fff;text-decoration:none;padding:12px 16px;border-radius:10px;font-weight:700">Odpri potrditev</a></p>
            <p>Če gumb ne deluje, kopirajte povezavo:</p>
            <p><a href="$claimUrl">$claimUrl</a></p>
          </div>
        ''',
      }),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      debugPrint('Email API response: ${resp.statusCode} ${resp.body}');
      throw StateError('Email API failed: ${resp.statusCode} ${resp.body}');
    }
    debugPrint('Offer email sent to $to');
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