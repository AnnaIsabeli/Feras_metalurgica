import 'package:flutter/material.dart';

Widget googleButton({required VoidCallback onPressed}) =>
    FilledButton(onPressed: onPressed, child: const Text('Entrar com Google'));
