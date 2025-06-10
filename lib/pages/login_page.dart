import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart'; 
import 'main_page.dart'; // 引入 MainPage
import 'register_page.dart'; // 引入註冊頁面

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  bool _isLoadingGoogle = false; // 為每個按鈕分別設置 loading 狀態
  bool _isLoadingFacebook = false;
  bool _isLoadingApple = false;
  bool _keepMeSignedIn = false; // "保持登入" 的狀態

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();
  bool _isLoadingEmailPassword = false; // Email/密碼登入的 loading 狀態
  bool _obscureLoginPassword = true;

  // Google 登入邏輯 (保持不變，但更新 loading 狀態)
  void _signInWithGoogle(BuildContext context) async {
    if (_isLoadingGoogle) return; // 防止重複點擊
    setState(() => _isLoadingGoogle = true);
    try {
      UserCredential? userCredential = await _authService.signInWithGoogle();
      if (!mounted) return;
      if (userCredential != null && userCredential.user != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainPage(user: userCredential.user!),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Google 登入已取消或失敗')));
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // ... (錯誤處理 SnackBar)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google 登入失敗: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google 登入發生未知錯誤: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingGoogle = false);
    }
  }

  // Facebook 登入邏輯
  void _signInWithFacebook(BuildContext context) async {
  if (_isLoadingFacebook) return;
  setState(() => _isLoadingFacebook = true);
  try {
    UserCredential? userCredential = await _authService.signInWithFacebook(); // 調用 AuthService 中的方法
    if (!mounted) return;

    if (userCredential != null && userCredential.user != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MainPage(user: userCredential.user!),
        ),
      );
    } else {
      // 如果 AuthService 返回 null (例如用戶取消)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Facebook 登入已取消或失敗')),
        );
      }
    }
  } on FirebaseAuthException catch (e) { // 捕獲 Firebase 相關的異常
    if (!mounted) return;
    String errorMessage = "Facebook 登入失敗";
    if (e.code == 'account-exists-with-different-credential') {
      errorMessage = '此 Email 已通過其他方式與帳戶關聯。請嘗試使用其他登入方式。';
    } else if (e.code == 'facebook-sign-in-failed'){
      errorMessage = e.message ?? errorMessage; // 使用 AuthService 拋出的 Facebook 特定錯誤訊息
    }
    // 可以根據需要添加更多 FirebaseAuthException 的 code 處理
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$errorMessage (${e.code})')),
    );
  } catch (e) { // 捕獲其他一般性異常
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Facebook 登入時發生未知錯誤: $e')),
    );
  } finally {
    if (mounted) setState(() => _isLoadingFacebook = false);
  }
}

  // Apple ID 登入邏輯
  void _signInWithApple(BuildContext context) async {
  // 首先檢查平台是否支援 Apple 登入 (通常只在 iOS/macOS 上)
  if (!await SignInWithApple.isAvailable()) {
     if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此設備或平台不支持 Apple 登入')),
      );
    }
    return;
  }

  if (_isLoadingApple) return;
  setState(() => _isLoadingApple = true);

  try {
    UserCredential? userCredential = await _authService.signInWithApple();
    if (!mounted) return;

    if (userCredential != null && userCredential.user != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MainPage(user: userCredential.user!),
        ),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apple ID 登入已取消或失敗')),
        );
      }
    }
  } on FirebaseAuthException catch (e) {
    if (!mounted) return;
    String errorMessage = "Apple ID 登入失敗";
     if (e.code == 'account-exists-with-different-credential') {
      errorMessage = '此 Email 已通過其他方式與帳戶關聯。';
    } else if (e.code == 'apple-sign-in-failed'){
       errorMessage = e.message ?? errorMessage;
    }
    // ... 更多錯誤處理 ...
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$errorMessage (${e.code})')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Apple ID 登入時發生未知錯誤: $e')),
    );
  } finally {
    if (mounted) setState(() => _isLoadingApple = false);
  }
}

  // (可選) Email/密碼登入邏輯
  void _signInWithEmailPassword(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoadingEmailPassword) return;

    setState(() => _isLoadingEmailPassword = true);
    try {
      final email = _loginEmailController.text;
      final password = _loginPasswordController.text;
      UserCredential? userCredential = await _authService
          .signInWithEmailAndPassword(email, password);

      if (!mounted) return;

      if (userCredential != null && userCredential.user != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainPage(user: userCredential.user!),
          ),
        );
      }
      // AuthService 中的 signInWithEmailAndPassword 已經拋出異常了，所以這裡不需要額外的 else
    } on FirebaseAuthException catch (e) {
      String errorMessage = '登入失敗，請檢查您的憑證。';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'INVALID_LOGIN_CREDENTIALS') {
        errorMessage = 'Email 或密碼錯誤。';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Email 格式無效。';
      } else if (e.code == 'user-disabled') {
        errorMessage = '此帳戶已被禁用。';
      }
      // 可以為更多 e.code 添加處理
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('登入時發生未知錯誤: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingEmailPassword = false);
    }
  }

  @override
void dispose() {
  _loginEmailController.dispose();
  _loginPasswordController.dispose();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      // appBar: AppBar(title: Text('登入')), // 移除 AppBar 以實現全螢幕背景效果
      body: Stack(
        // 使用 Stack 來疊加背景和前景內容
        children: [
          // --- 背景圖片 ---
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                // 你需要一張背景圖片，例如 'assets/images/login_background.jpg'
                // 並在 pubspec.yaml 中宣告
                image: AssetImage(
                  'assets/images/login_background.jpg',
                ), // 替換成你的背景圖片路徑
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black45,
                  BlendMode.darken,
                ), // 給背景加一層暗色濾鏡
              ),
            ),
          ),
          // --- 前景登入卡片 ---
          Center(
            child: SingleChildScrollView(
              // 允許內容在小螢幕上滾動
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
              child: Card(
                elevation: 8.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
                color:
                    theme.brightness == Brightness.dark
                        ? colorScheme.surface.withOpacity(0.9)
                        : Colors.white.withOpacity(0.95), // 半透明效果
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // 讓 Column 只佔據必要的空間
                      children: <Widget>[
                        // --- 標題 ---
                        Text(
                          '登入',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24.0),
                        // --- Email 輸入框 ---
                        TextFormField(
                          key: ValueKey('loginEmailField'), // 添加 key 以便測試
                          controller: _loginEmailController,
                          decoration: const InputDecoration(
                            labelText: 'EMAIL',
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return '請輸入用戶名或Email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),

                        // --- 密碼輸入框 ---
                        TextFormField(
                          key: ValueKey('loginPasswordField'),
                          controller: _loginPasswordController,
                          decoration: InputDecoration(
                            labelText: '密碼',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureLoginPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed:
                                  () => setState(
                                    () =>
                                        _obscureLoginPassword =
                                            !_obscureLoginPassword,
                                  ),
                            ),
                          ),
                          obscureText: _obscureLoginPassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) return '請輸入密碼';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),

                        // --- 保持登入 & 忘記密碼 ---
                        Row(
                          // 只保留 "Keep me signed in" 在這一行，並使其居左
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _keepMeSignedIn,
                              onChanged: (bool? value) {
                                setState(() {
                                  _keepMeSignedIn = value ?? false;
                                });
                              },
                              activeColor: colorScheme.primary,
                              visualDensity:
                                  VisualDensity.compact, // 讓 Checkbox 更緊湊
                            ),
                            Text(
                              '保持登入',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24.0),

                        // --- 主要登入按鈕 ---
                        _isLoadingEmailPassword
    ? const CircularProgressIndicator()
    : ElevatedButton(
                          onPressed: () => _signInWithEmailPassword(context),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            minimumSize: const Size(
                              double.infinity,
                              50,
                            ), // 꽉滿寬度
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30.0),
                            ),
                          ),
                          child: const Text(
                            '登入',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // TODO: 導航到忘記密碼頁面
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('忘記密碼功能待開發')),
                            );
                          },
                          child: Text(
                            '忘記帳號或密碼?',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              // 可以用 bodyMedium 或 bodySmall
                              color: colorScheme.secondary, // 使用次要顏色
                              decoration: TextDecoration.underline, // <--- 添加底線
                              decorationColor:
                                  colorScheme
                                      .secondary, // <--- 底線顏色與文字顏色一致 (可選)
                            ),
                          ),
                        ),
                        const SizedBox(height: 20.0),

                        // --- "OR" 分隔線 ---
                        Row(
                          children: <Widget>[
                            const Expanded(child: Divider(thickness: 0.5)),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10.0,
                              ),
                              child: Text(
                                'OR',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(thickness: 0.5)),
                          ],
                        ),
                        const SizedBox(height: 20.0),

                        // --- 社交媒體登入按鈕 ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            // Google
                            _buildSocialButton(
                              iconPath:
                                  'assets/images/google_logo.png', // 你已有的 Google logo
                              onPressed: () => _signInWithGoogle(context),
                              isLoading: _isLoadingGoogle,
                              theme: theme,
                            ),
                            const SizedBox(width: 16),
                            // Facebook (你需要 Facebook logo 圖片)
                            _buildSocialButton(
                              iconPath:
                                  'assets/images/facebook_logo.png', // 準備 Facebook logo
                              onPressed: () => _signInWithFacebook(context),
                              isLoading: _isLoadingFacebook,
                              backgroundColor: const Color(
                                0xFF3b5998,
                              ), // Facebook 藍
                              theme: theme,
                            ),
                            const SizedBox(width: 16),
                            // Apple (你需要 Apple logo 圖片)
                            _buildSocialButton(
                              iconPath:
                                  'assets/images/apple_logo.png', // 準備 Apple logo (通常是黑色或白色)
                              onPressed: () => _signInWithApple(context),
                              isLoading: _isLoadingApple,
                              backgroundColor:
                                  theme.brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.black, // Apple logo 通常是單色
                              iconColor:
                                  theme.brightness == Brightness.dark
                                      ? Colors.black
                                      : Colors.white, // 圖示顏色與背景反色
                              theme: theme,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24.0),

                        // --- 註冊提示 ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "還沒註冊? ",
                              style: theme.textTheme.bodyMedium,
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const RegisterPage(),
                                  ),
                                );
                              },
                              child: Text(
                                '註冊',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 輔助方法來創建社交媒體登入按鈕
  Widget _buildSocialButton({
    required String iconPath,
    required VoidCallback onPressed,
    required bool isLoading,
    Color? backgroundColor, // 可選的背景色
    Color? iconColor, // 可選的圖示顏色
    required ThemeData theme,
  }) {
    return isLoading
        ? const SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ) // 載入中顯示進度條
        : InkWell(
          // 使用 InkWell 實現圓形點擊效果
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(10.0), // 調整圖示周圍的 padding
            decoration: BoxDecoration(
              color:
                  backgroundColor ??
                  theme.colorScheme.surfaceVariant, // 如果不提供背景色，使用主題色
              shape: BoxShape.circle,
              boxShadow: [
                // 可以加一點陰影
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Image.asset(
              iconPath,
              height: 24.0, // 圖示大小
              width: 24.0,
              color: iconColor, // 允許覆蓋圖示顏色，主要用於單色圖示
            ),
          ),
        );
  }
}
