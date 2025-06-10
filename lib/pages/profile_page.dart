import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import '../providers/theme_provider.dart';

class ProfilePage extends StatefulWidget {
  final User user;

  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  String _appVersion = '讀取中...';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${packageInfo.version} (build ${packageInfo.buildNumber})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appVersion = '無法獲取版本';
        });
      }
      print("Error loading app version: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
      ),
      body: ListView(
        children: <Widget>[
          const SizedBox(height: 20),
          if (widget.user.photoURL != null)
            Center(
              child: CircleAvatar(
                backgroundImage: NetworkImage(widget.user.photoURL!),
                radius: 50,
              ),
            ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              widget.user.displayName ?? widget.user.email ?? '用戶',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          if (widget.user.email != null)
            Center(
              child: Text(
                widget.user.email!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: 8),
          const Divider(height: 40),

          ListTile(
            leading: Icon(Icons.brightness_6_outlined),
            title: Text('主題模式'),
            trailing: DropdownButton<ThemeMode>(
              value: themeProvider.themeMode,
              underline: SizedBox(),
              items: const [
                DropdownMenuItem(child: Text('系統預設'), value: ThemeMode.system),
                DropdownMenuItem(child: Text('亮色'), value: ThemeMode.light),
                DropdownMenuItem(child: Text('暗色'), value: ThemeMode.dark),
              ],
              onChanged: (ThemeMode? newMode) {
                if (newMode != null) {
                  themeProvider.setThemeMode(newMode);
                }
              },
            ),
          ),
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('關於 App'),
            subtitle: Text(_appVersion),
            onTap: () {
              PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
                showAboutDialog(
                  context: context,
                  applicationName: packageInfo.appName.isNotEmpty ? packageInfo.appName : "投資理財App",
                  applicationVersion: '版本: ${packageInfo.version} (Build ${packageInfo.buildNumber})',
                  applicationIcon: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset('assets/images/app_icon.png', width: 48, height: 48, errorBuilder: (context, error, stackTrace) => Icon(Icons.app_shortcut, size: 48)),
                  ),
                  applicationLegalese: '© ${DateTime.now().year} 翁子翔',
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Text('感謝您使用本 App！這是一款為大學 Flutter 課程期末專題設計的投資理財輔助工具。'),
                    )
                  ],
                );
              });
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('登出', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('確認登出'),
                  content: Text('您確定要登出嗎？'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('取消')),
                    TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('登出', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                await _authService.signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => LoginPage()),
                  (Route<dynamic> route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}