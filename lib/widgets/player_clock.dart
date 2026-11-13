import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/services/app_preferences.dart';

class PlayerClock extends StatefulWidget {
  const PlayerClock({super.key,this.compact = false});
  final bool compact;

  @override
  State<PlayerClock> createState() => _PlayerClockState();
}

class _PlayerClockState extends State<PlayerClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds:5),(_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = context.watch<AppPreferences?>()?.clockTime() ?? DateTime.now();
    final locale = Localizations.localeOf(context).languageCode;
    return FittedBox(fit:BoxFit.scaleDown,child:Column(
      crossAxisAlignment:CrossAxisAlignment.end,mainAxisSize:MainAxisSize.min,children:[
        Text(DateFormat('HH:mm',locale).format(now),style:TextStyle(
          fontSize:widget.compact ? 24 : 52,fontWeight:FontWeight.w200,letterSpacing:-2)),
        Text(DateFormat('d MMMM · EEEE',locale).format(now),style:const TextStyle(fontSize:11,color:Colors.white60)),
      ],));
  }
}
