import 'dart:io' as io;
import 'dart:ui';

import 'package:bip39/bip39.dart' as bip39;
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/constants.dart';
import 'package:photos/ui/common/custom_color_scheme.dart';
import 'package:share_plus/share_plus.dart';

class RecoveryKeyPage extends StatefulWidget {
  final bool showAppBar;
  final String recoveryKey;
  final String doneText;
  final Function() onDone;
  final bool isDismissible;
  final String title;
  final String text;
  final String subText;

  const RecoveryKeyPage(this.recoveryKey, this.doneText,
      {Key key,
      this.showAppBar,
      this.onDone,
      this.isDismissible,
      this.title,
      this.text,
      this.subText})
      : super(key: key);

  @override
  _RecoveryKeyPageState createState() => _RecoveryKeyPageState();
}

class _RecoveryKeyPageState extends State<RecoveryKeyPage> {
  bool _hasTriedToSave = false;
  final _recoveryKeyFile = io.File(
      Configuration.instance.getTempDirectory() + "ente-recovery-key.txt");
  final _recoveryKey = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final String recoveryKey = bip39.entropyToMnemonic(widget.recoveryKey);
    if (recoveryKey.split(' ').length != kMnemonicKeyWordCount) {
      throw AssertionError(
          'recovery code should have $kMnemonicKeyWordCount words');
    }

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(""),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          // mainAxisAlignment: MainAxisAlignment.center,

          mainAxisSize: MainAxisSize.max,
          children: [
            Text(widget.title ?? "Recovery Key",
                style: Theme.of(context).textTheme.headline4),
            Padding(padding: EdgeInsets.all(12)),
            Text(
              widget.text ??
                  "If you forget your password, the only way you can recover your data is with this key.",
              style: Theme.of(context).textTheme.subtitle1,
            ),
            Padding(padding: EdgeInsets.only(top: 24)),
            DottedBorder(
              color: Color.fromRGBO(17, 127, 56, 1),
              //color of dotted/dash line
              strokeWidth: 1,
              //thickness of dash/dots
              dashPattern: const [6, 6],
              radius: Radius.circular(8),
              //dash patterns, 10 is dash width, 6 is space width
              child: SizedBox(
                //inner container
                height: 200, //height of inner container
                width:
                    double.infinity, //width to 100% match to parent container.
                // ignore: prefer_const_literals_to_create_immutables
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Color.fromRGBO(49, 155, 86, .2),
                        ),
                        borderRadius: BorderRadius.all(
                          Radius.circular(12),
                        ),
                        color: Color.fromRGBO(49, 155, 86, .2),
                      ),
                      // color: Color.fromRGBO(49, 155, 86, .2),
                      height: 120,
                      padding: EdgeInsets.all(20),
                      width: double.infinity,
                      child: Text(
                        recoveryKey,
                        style: Theme.of(context).textTheme.bodyText1,
                      ),
                    ),
                    SizedBox(
                      height: 80,
                      width: double.infinity,
                      child: Padding(
                          child: Text(
                            widget.subText ??
                                "we don’t store this key, please save this in a safe place",
                            style: Theme.of(context).textTheme.bodyText1,
                          ),
                          padding: EdgeInsets.all(20)),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                alignment: Alignment.bottomCenter,
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(10, 10, 10, 24),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _saveOptions(context, recoveryKey)),
              ),
            )
          ],
        ),
      ),
    );
  }

  List<Widget> _saveOptions(BuildContext context, String recoveryKey) {
    List<Widget> childrens = [];
    if (!_hasTriedToSave) {
      childrens.add(ElevatedButton(
        child: Text('Save Later'),
        style: Theme.of(context).colorScheme.optionalActionButtonStyle,
        onPressed: () async {
          await _saveKeys();
        },
      ));
      childrens.add(SizedBox(height: 10));
    }

    childrens.add(ElevatedButton(
      child: Text('Save'),
      style: Theme.of(context).colorScheme.primaryActionButtonStyle,
      onPressed: () async {
        await _shareRecoveryKey(recoveryKey);
      },
    ));
    if (_hasTriedToSave) {
      childrens.add(SizedBox(height: 10));
      childrens.add(ElevatedButton(
        child: Text(widget.doneText),
        // style: Theme.of(context).colorScheme.primaryActionButtonStyle,
        onPressed: () async {
          await _saveKeys();
        },
      ));
    }
    childrens.add(SizedBox(height: 12));
    return childrens;
  }

  Future _shareRecoveryKey(String recoveryKey) async {
    if (_recoveryKeyFile.existsSync()) {
      await _recoveryKeyFile.delete();
    }
    _recoveryKeyFile.writeAsStringSync(recoveryKey);
    await Share.shareFiles([_recoveryKeyFile.path]);
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _hasTriedToSave = true;
        });
      }
    });
  }

  Future<void> _saveKeys() async {
    Navigator.of(context).pop();
    if (_recoveryKeyFile.existsSync()) {
      await _recoveryKeyFile.delete();
    }
    widget.onDone();
  }
}
