//import 'dart:io';
import 'dart:convert';

String dataSchemeFromHtml(String htmlStr) {
  return 'data:text/html;charset=utf-8,' + Uri.encodeComponent(htmlStr);
}

String dataSchemeFromPlainTitleAndBody(String title, String body) {
  const HtmlEscape htmlEscape = HtmlEscape();
  return dataSchemeFromHtml(
      r'<!DOCTYPE html><html lang="en"><head><title>Notification</title><meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"><meta name="HandheldFriendly" content="true"></head><body style="font-size: 9vmin;">' +
          htmlEscape.convert(title) +
          r'<br><br>' +
          htmlEscape.convert(body));
}
