import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/filter_list_screen.dart';
import 'services/filter_data_service.dart';

void main() {
  runApp(
    const ProviderScope(
      child: FilterPlayApp(),
    ),
  );
}

class FilterPlayApp extends StatelessWidget {
  const FilterPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FilterPlay',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: FilterListScreen(
        category: FilterDataService.getCategoryById('ranking')!,
      ),
    );
  }
}
