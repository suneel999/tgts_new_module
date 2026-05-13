import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/index.dart';
import '../services/language_service.dart';

extension L10nX on BuildContext {
  Language get lang => read<LanguageService>().language;
}
