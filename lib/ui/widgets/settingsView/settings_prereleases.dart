import 'package:flutter/material.dart';
import 'package:revanced_manager/app/app.locator.dart';
import 'package:revanced_manager/services/toast.dart';
import 'package:revanced_manager/gen/strings.g.dart';
import 'package:revanced_manager/ui/views/settings/settings_viewmodel.dart';

class SPreReleases extends StatefulWidget {
  const SPreReleases({super.key});

  @override
  State<SPreReleases> createState() => _SPreReleases();
}

final _settingsViewModel = SettingsViewModel();

class _SPreReleases extends State<SPreReleases> {
  final Toast _toast = locator<Toast>();

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
      title: Text(
        t.settingsView.preReleasesLabel,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(t.settingsView.preReleasesHint),
      value: _settingsViewModel.isPreReleasesEnabled(),
      onChanged: (value) {
        setState(() {
          _settingsViewModel.showPreReleases(value);
        });
      },
    );
  }
}
