import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

Widget googleButton({required VoidCallback onPressed}) =>
    google_web.renderButton();
