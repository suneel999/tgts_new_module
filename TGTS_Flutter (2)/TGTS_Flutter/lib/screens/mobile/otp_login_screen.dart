import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/index.dart';
import '../../services/language_service.dart';
import '../../services/auth_service.dart';
import '../../utils/lang_ext.dart';
import '../../widgets/otp_input_widget.dart';

// Constants for maintainability
class LoginConstants {
  static const otpLength = 6;
  static const phoneLength = 10;
  static const otpTimeout = Duration(seconds: 30);
  static const debounceDuration = Duration(milliseconds: 300);
  static const snackbarDuration = Duration(seconds: 4);
  
  // Gradients and colors
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFF3E0), // light saffron
      Colors.white,
    ],
  );
  
  static const logoGradient = LinearGradient(
    colors: [Color(0xFFFF9933), Color(0xFFFF6600)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// State holder for better organization
class OTPLoginState {
  final String phoneNumber;
  final String otpValue;
  final bool isOtpSent;
  final bool isLoading;
  final String? errorMessage;

  const OTPLoginState({
    this.phoneNumber = '',
    this.otpValue = '',
    this.isOtpSent = false,
    this.isLoading = false,
    this.errorMessage,
  });

  OTPLoginState copyWith({
    String? phoneNumber,
    String? otpValue,
    bool? isOtpSent,
    bool? isLoading,
    String? errorMessage,
  }) {
    return OTPLoginState(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      otpValue: otpValue ?? this.otpValue,
      isOtpSent: isOtpSent ?? this.isOtpSent,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isPhoneValid => phoneNumber.length == LoginConstants.phoneLength;
  bool get isOtpValid => otpValue.length == LoginConstants.otpLength;
  bool get canSubmitOtp => isOtpValid && !isLoading;
}

class OTPLoginScreen extends StatefulWidget {
  final Function() onLogin;

  const OTPLoginScreen({
    Key? key,
    required this.onLogin,
  }) : super(key: key);

  @override
  State<OTPLoginScreen> createState() => _OTPLoginScreenState();
}

class _OTPLoginScreenState extends State<OTPLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Timer? _otpDebounceTimer;
  
  OTPLoginState _state = const OTPLoginState();
  int _retryCount = 0;
  DateTime? _lastOTPSentTime;

  bool get _canResendOTP => 
      _lastOTPSentTime == null || 
      DateTime.now().difference(_lastOTPSentTime!) > LoginConstants.otpTimeout;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    _updateState(phoneNumber: _phoneController.text);
  }

  void _updateState({
    String? phoneNumber,
    String? otpValue,
    bool? isOtpSent,
    bool? isLoading,
    String? errorMessage,
  }) {
    if (!mounted) return;
    
    setState(() {
      _state = _state.copyWith(
        phoneNumber: phoneNumber,
        otpValue: otpValue,
        isOtpSent: isOtpSent,
        isLoading: isLoading,
        errorMessage: errorMessage,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final language = context.lang;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LoginConstants.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme, colorScheme, language),
                const SizedBox(height: 32),
                _buildLogo(),
                const SizedBox(height: 40),
                _buildInputSection(theme, colorScheme, language),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme, Language language) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              language == Language.en ? 'Welcome' : 'స్వాగతం',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              language == Language.en
                  ? 'Login with your phone number'
                  : 'మీ ఫోన్ నంబర్‌తో లాగిన్ అవ్వండి',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        _buildLanguageSwitch(colorScheme, language),
      ],
    );
  }

  Widget _buildLanguageSwitch(ColorScheme colorScheme, Language language) {
    return TextButton.icon(
      onPressed: () => context.push('/language'),
      icon: const Icon(Icons.language, size: 18),
      label: Text(language == Language.en ? 'తెలుగు' : 'English'),
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LoginConstants.logoGradient,
        ),
        child: const Center(
          child: Icon(Icons.shield, color: Colors.white, size: 60),
        ),
      ),
    );
  }

  Widget _buildInputSection(ThemeData theme, ColorScheme colorScheme, Language language) {
    return Expanded(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            if (!_state.isOtpSent) 
              _buildPhoneInputSection(theme, colorScheme, language)
            else 
              _buildOTPInputSection(theme, colorScheme, language),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneInputSection(ThemeData theme, ColorScheme colorScheme, Language language) {
    return Column(
      children: [
        _buildPhoneInputField(theme, colorScheme, language),
        const SizedBox(height: 30),
        _buildSendOTPButton(colorScheme, language),
      ],
    );
  }

  Widget _buildPhoneInputField(ThemeData theme, ColorScheme colorScheme, Language language) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          language == Language.en ? 'Enter Phone Number' : 'ఫోన్ నంబర్ నమోదు చేయండి',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(LoginConstants.phoneLength),
            ],
            validator: (value) => _validatePhoneNumber(value, language),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: '9XXXXXXXXX',
              prefixIcon: Icon(
                Icons.phone,
                color: colorScheme.outline,
                size: 20,
              ),
              prefixText: '+91 ',
              prefixStyle: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: colorScheme.surface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.outline.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.primary,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.error,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.error,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
        ),
        const SizedBox(height: 8),
        Text(
          language == Language.en
              ? 'Enter your 10-digit mobile number'
              : 'మీ 10-అంకెల మొబైల్ నంబర్ నమోదు చేయండి',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildSendOTPButton(ColorScheme colorScheme, Language language) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _state.isLoading ? null : _sendOTP,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _state.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                language == Language.en ? 'Send OTP' : 'OTP పంపండి',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildOTPInputSection(ThemeData theme, ColorScheme colorScheme, Language language) {
    return Column(
      children: [
        _buildOTPInputField(theme, colorScheme, language),
        const SizedBox(height: 30),
        _buildVerifyOTPButton(colorScheme, language),
        const SizedBox(height: 16),
        _buildChangeNumberButton(colorScheme, language),
        if (!_canResendOTP) ...[
          const SizedBox(height: 16),
          _buildResendTimer(language),
        ],
      ],
    );
  }

  Widget _buildOTPInputField(ThemeData theme, ColorScheme colorScheme, Language language) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          language == Language.en ? 'Enter OTP' : 'OTP నమోదు చేయండి',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          language == Language.en
              ? 'OTP sent to +91 ${_state.phoneNumber}'
              : '+91 ${_state.phoneNumber} కు OTP పంపబడింది',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.outline,
          ),
        ),
        const SizedBox(height: 24),
        OTPInputWidget(
          length: LoginConstants.otpLength,
          onChanged: _onOTPChanged,
          onCompleted: (otp) => _verifyOTP(),
          activeColor: colorScheme.primary,
          inactiveColor: colorScheme.outline,
        ),
      ],
    );
  }

  Widget _buildVerifyOTPButton(ColorScheme colorScheme, Language language) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _state.canSubmitOtp ? _verifyOTP : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _state.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                language == Language.en ? 'Verify OTP' : 'OTPని ధృవీకరించండి',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildChangeNumberButton(ColorScheme colorScheme, Language language) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: TextButton(
        onPressed: _changeNumber,
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          language == Language.en ? 'Change Number' : 'నంబర్ మార్చండి',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildResendTimer(Language language) {
    final remainingTime = _lastOTPSentTime != null 
        ? LoginConstants.otpTimeout - DateTime.now().difference(_lastOTPSentTime!)
        : Duration.zero;
    
    final seconds = remainingTime.inSeconds.clamp(0, LoginConstants.otpTimeout.inSeconds);

    return Text(
      language == Language.en
          ? 'Resend OTP in $seconds seconds'
          : '$seconds సెకన్లలో OTPని మళ్లీ పంపండి',
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 14,
      ),
    );
  }

  String? _validatePhoneNumber(String? value, Language language) {
    if (value == null || value.isEmpty) {
      return language == Language.en
          ? 'Please enter phone number'
          : 'దయచేసి ఫోన్ నంబర్ నమోదు చేయండి';
    }
    if (value.length != LoginConstants.phoneLength) {
      return language == Language.en
          ? 'Please enter a valid 10-digit phone number'
          : 'దయచేసి చెల్లుబాటు అయ్యే 10 అంకెల ఫోన్ నంబర్‌ను నమోదు చేయండి';
    }
    return null;
  }

  void _onOTPChanged(String value) {
    _otpDebounceTimer?.cancel();
    _updateState(otpValue: value);
  }

  void _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    final languageService = Provider.of<LanguageService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final language = languageService.language;

    _updateState(isLoading: true, errorMessage: null);

    try {
      final result = await authService.sendOTP(_state.phoneNumber)
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (result['success']) {
        _lastOTPSentTime = DateTime.now();
        _updateState(isOtpSent: true, isLoading: false);
        
        _showSuccessSnackbar(
          language == Language.en 
              ? 'OTP sent successfully' 
              : 'OTP విజయవంతంగా పంపబడింది',
        );
        
        if (result['otp'] != null) {
          _showDebugOTPDialog(result['otp'], language);
        }
      } else {
        _handleOTPError(result['message'], language);
      }
    } on TimeoutException {
      _handleError(language == Language.en 
          ? 'Request timed out. Please try again.'
          : 'రిక్వెస్ట్ సమయం ముగిసింది. దయచేసి మళ్లీ ప్రయత్నించండి.');
    } catch (e) {
      _handleError(language == Language.en
          ? 'Something went wrong. Please try again.'
          : 'ఏదో తప్పు జరిగింది. దయచేసి మళ్లీ ప్రయత్నించండి.');
    } finally {
      if (mounted) _updateState(isLoading: false);
    }
  }

  void _verifyOTP() async {
    final languageService = Provider.of<LanguageService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final language = languageService.language;

    _updateState(isLoading: true, errorMessage: null);

    try {
      final result = await authService.verifyOTP(_state.phoneNumber, _state.otpValue)
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (result['success']) {
        _showSuccessSnackbar(
          language == Language.en ? 'Login successful!' : 'లాగిన్ విజయవంతంగా!',
        );
        
        // Wait for auth state to update and notifyListeners to complete
        await Future.delayed(const Duration(milliseconds: 300));
        
        if (!mounted) return;
        
        // Check membership status - first check cached value from verifyOTP
        var hasMembership = authService.hasMembership;
        print('🔍 OTP Login - Initial hasMembership from verifyOTP: $hasMembership');
        print('🔍 OTP Login - Current user: ${authService.currentUser?.phone}');
        print('🔍 OTP Login - User fullName: ${authService.currentUser?.fullName}');
        print('🔍 OTP Login - User status: ${authService.currentUser?.status}');
        
        // Always explicitly check membership status to ensure it's accurate
        try {
          hasMembership = await authService.checkMembershipStatus()
              .timeout(const Duration(seconds: 10));
          print('🔍 OTP Login - After checkMembershipStatus: $hasMembership');
        } catch (e) {
          print('❌ Error checking membership: $e');
          // If check fails, use cached value or default to false
          hasMembership = authService.hasMembership ?? false;
        }
        
        // Wait again for state to update
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (!mounted) return;
        
        // Navigate based on membership status
        if (hasMembership == true) {
          // User has membership, go to home
          print('✅ OTP Login - User HAS membership, navigating to /home');
          // Use replace to prevent back navigation
          context.go('/home');
        } else {
          // User doesn't have membership, go to membership page
          print('❌ OTP Login - User does NOT have membership, navigating to /membership');
          // Use replace to prevent back navigation and ensure route guard doesn't interfere
          context.go('/membership');
        }
        
        // Don't call widget.onLogin() as it might trigger additional navigation
        // widget.onLogin();
      } else {
        _handleError(result['message'] ?? 'Verification failed');
      }
    } on TimeoutException {
      _handleError(language == Language.en
          ? 'Verification timed out. Please try again.'
          : 'ధృవీకరణ సమయం ముగిసింది. దయచేసి మళ్లీ ప్రయత్నించండి.');
    } catch (e) {
      _handleError(language == Language.en
          ? 'Verification failed. Please try again.'
          : 'ధృవీకరణ విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.');
    } finally {
      if (mounted) _updateState(isLoading: false);
    }
  }

  void _changeNumber() {
    _updateState(
      isOtpSent: false,
      otpValue: '',
      errorMessage: null,
    );
    _phoneController.clear();
  }

  void _handleOTPError(String errorMessage, Language language) {
    String localizedMessage = errorMessage;
    
    if (errorMessage.contains('network') || errorMessage.contains('connection')) {
      localizedMessage = language == Language.en
          ? 'Unable to connect to server. Please check your internet connection.'
          : 'సర్వర్‌కు కనెక్ట్ కాలేదు. దయచేసి మీ ఇంటర్నెట్ కనెక్షన్‌ని తనిఖీ చేయండి.';
    } else if (errorMessage.contains('timeout')) {
      localizedMessage = language == Language.en
          ? 'Request timed out. Please try again.'
          : 'రిక్వెస్ట్ సమయం ముగిసింది. దయచేసి మళ్లీ ప్రయత్నించండి.';
    }
    
    _handleError(localizedMessage);
  }

  void _handleError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: LoginConstants.snackbarDuration,
      ),
    );
    
    debugPrint('OTP Error: $message');
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: LoginConstants.snackbarDuration,
      ),
    );
  }

  void _showDebugOTPDialog(String otp, Language language) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            language == Language.en ? 'Debug OTP' : 'డీబగ్ OTP',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                language == Language.en 
                    ? 'For debugging purposes, your OTP is:'
                    : 'డీబగ్ ప్రయోజనాల కోసం, మీ OTP:',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        otp,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: otp));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              language == Language.en 
                                  ? 'OTP copied to clipboard' 
                                  : 'OTP క్లిప్‌బోర్డ్‌కు కాపీ చేయబడింది',
                            ),
                            duration: const Duration(seconds: 2),
                            backgroundColor: Colors.green,
                          ),
                        );
                        // Close the dialog after copying
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: language == Language.en ? 'Copy OTP' : 'OTPని కాపీ చేయండి',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                language == Language.en 
                    ? 'This dialog will be removed in production.'
                    : 'ఈ డైలాగ్ ప్రొడక్షన్‌లో తొలగించబడుతుంది.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                language == Language.en ? 'OK' : 'సరే',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _otpDebounceTimer?.cancel();
    super.dispose();
  }
}