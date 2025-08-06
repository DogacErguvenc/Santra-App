import 'package:flutter/material.dart';

void showSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).removeCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      // YENİ EKLENEN MANTIK:
      // Hata ise kırmızı, değilse yeşil, hiçbiri belirtilmemişse varsayılan renk.
      backgroundColor: isError ? Colors.red[700] : Colors.green[700],
      behavior: SnackBarBehavior.floating, // Daha şık bir görünüm için
    ),
  );
}
