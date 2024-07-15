import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:adminoffacebookapp/buttom_navigation_screens.dart';
import 'package:adminoffacebookapp/reusable/text_widgets.dart';
import 'consts/colors.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: primaryTextColor,
        ),
        appBarTheme:  AppBarTheme(
          centerTitle: true,
          color: primaryTextColor,
        ),
        scaffoldBackgroundColor: primaryTextColor,
      ),
      home: LoginScreen(), // Start with LoginScreen
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _checking = true;
  AccessToken? _accessToken;

  @override
  void initState() {
    super.initState();
    _checkUserLoggedIn();
  }

  _checkUserLoggedIn() async {
    final accessToken = await FacebookAuth.instance.accessToken;
    if (accessToken != null) {
      setState(() {
        _accessToken = accessToken;
        _checking = false;
      });
    } else {
      setState(() {
        _checking = false;
      });
    }
  }

  _login() async {
    final LoginResult result = await FacebookAuth.instance.login(
      permissions: ['public_profile', 'email', 'pages_manage_posts', 'pages_read_engagement'],
    );
    if (result.status == LoginStatus.success) {
      setState(() {
        _accessToken = result.accessToken;
      });
    } else {
      print('Failed to login: ${result.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else if (_accessToken != null) {
      return BottomNavigation(accessToken: _accessToken!);
    } else {
      return Scaffold(
        appBar: AppBar(
          title: largeText(title: 'Login with Facebook'),
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: _login,
            child: mediumText(title: 'Login with Facebook',color: blueColor),
          ),
        ),
      );
    }
  }
}
