import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../utils/app_colors.dart';

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({Key? key}) : super(key: key);

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  
  String _testResults = '';
  bool _isLoading = false;
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _phoneController.text = '9876543210'; // Default test phone
  }

  void _addResult(String result) {
    setState(() {
      _testResults += '$result\n';
    });
  }

  void _clearResults() {
    setState(() {
      _testResults = '';
    });
  }

  Future<void> _testHealthCheck() async {
    setState(() => _isLoading = true);
    _addResult('🔍 Testing Health Check...');
    
    final result = await _apiService.checkHealth();
    if (result['success']) {
      _addResult('✅ Health Check: ${result['data']['status']}');
      _addResult('   Version: ${result['data']['version']}');
      _addResult('   Timestamp: ${result['data']['timestamp']}');
    } else {
      _addResult('❌ Health Check Failed: ${result['message']}');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _testSendOTP() async {
    if (_phoneController.text.isEmpty) {
      _addResult('❌ Please enter a phone number');
      return;
    }

    setState(() => _isLoading = true);
    _addResult('📱 Testing Send OTP...');
    
    final result = await _apiService.sendOTP(_phoneController.text);
    if (result['success']) {
      _addResult('✅ OTP Sent: ${result['data']['message']}');
      _addResult('   OTP: ${result['data']['otp']}');
      _addResult('   Phone: ${result['data']['phone']}');
    } else {
      _addResult('❌ Send OTP Failed: ${result['message']}');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _testVerifyOTP() async {
    if (_phoneController.text.isEmpty || _otpController.text.isEmpty) {
      _addResult('❌ Please enter phone number and OTP');
      return;
    }

    setState(() => _isLoading = true);
    _addResult('🔐 Testing Verify OTP...');
    
    final result = await _apiService.verifyOTP(_phoneController.text, _otpController.text);
    if (result['success']) {
      _addResult('✅ OTP Verified: ${result['data']['message']}');
      _addResult('   Access Token: ${result['data']['access_token']?.substring(0, 20)}...');
      _addResult('   User ID: ${result['data']['user']['id']}');
      _addResult('   User Name: ${result['data']['user']['name']}');
      _addResult('   User Role: ${result['data']['user']['role']}');
      
      _authToken = result['data']['access_token'];
    } else {
      _addResult('❌ Verify OTP Failed: ${result['message']}');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _testGetNews() async {
    setState(() => _isLoading = true);
    _addResult('📰 Testing Get News...');
    
    final result = await _apiService.getNews(page: 1, perPage: 5);
    if (result['success']) {
      final data = result['data'];
      _addResult('✅ News Retrieved: ${data['total']} total items');
      _addResult('   Current Page: ${data['current_page']}');
      _addResult('   Total Pages: ${data['pages']}');
      
      if (data['news'] != null && data['news'].isNotEmpty) {
        _addResult('   First News Title: ${data['news'][0]['title']['en'] ?? 'N/A'}');
      }
    } else {
      _addResult('❌ Get News Failed: ${result['message']}');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _testGetEvents() async {
    setState(() => _isLoading = true);
    _addResult('📅 Testing Get Events...');
    
    final result = await _apiService.getEvents(page: 1, perPage: 5);
    if (result['success']) {
      final data = result['data'];
      _addResult('✅ Events Retrieved: ${data['total']} total items');
      _addResult('   Current Page: ${data['current_page']}');
      _addResult('   Total Pages: ${data['pages']}');
      
      if (data['events'] != null && data['events'].isNotEmpty) {
        _addResult('   First Event Title: ${data['events'][0]['title']['en'] ?? 'N/A'}');
      }
    } else {
      _addResult('❌ Get Events Failed: ${result['message']}');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _testGetMedia() async {
    setState(() => _isLoading = true);
    _addResult('🎬 Testing Get Media...');
    
    final result = await _apiService.getMedia(page: 1, perPage: 5);
    if (result['success']) {
      final data = result['data'];
      _addResult('✅ Media Retrieved: ${data['total']} total items');
      _addResult('   Current Page: ${data['current_page']}');
      _addResult('   Total Pages: ${data['pages']}');
      
      if (data['media'] != null && data['media'].isNotEmpty) {
        _addResult('   First Media Title: ${data['media'][0]['title']['en'] ?? 'N/A'}');
        _addResult('   First Media Type: ${data['media'][0]['type'] ?? 'N/A'}');
      }
    } else {
      _addResult('❌ Get Media Failed: ${result['message']}');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _testGetDocuments() async {
    if (_authToken == null) {
      _addResult('❌ Please authenticate first to test documents');
      return;
    }

    setState(() => _isLoading = true);
    _addResult('📄 Testing Get Documents...');
    
    final result = await _apiService.getDocuments(
      page: 1, 
      perPage: 5, 
      authToken: _authToken,
    );
    if (result['success']) {
      final data = result['data'];
      _addResult('✅ Documents Retrieved: ${data['total']} total items');
      _addResult('   Current Page: ${data['current_page']}');
      _addResult('   Total Pages: ${data['pages']}');
      
      if (data['documents'] != null && data['documents'].isNotEmpty) {
        _addResult('   First Document Title: ${data['documents'][0]['title']['en'] ?? 'N/A'}');
      }
    } else {
      _addResult('❌ Get Documents Failed: ${result['message']}');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _testGetProfile() async {
    if (_authToken == null) {
      _addResult('❌ Please authenticate first to test profile');
      return;
    }

    setState(() => _isLoading = true);
    _addResult('👤 Testing Get Profile...');
    
    final result = await _apiService.getProfile(_authToken!);
    if (result['success']) {
      final data = result['data'];
      _addResult('✅ Profile Retrieved:');
      _addResult('   User ID: ${data['id']}');
      _addResult('   Name: ${data['name']}');
      _addResult('   Phone: ${data['phone']}');
      _addResult('   Role: ${data['role']}');
      _addResult('   Region: ${data['region'] ?? 'N/A'}');
    } else {
      _addResult('❌ Get Profile Failed: ${result['message']}');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _runAllTests() async {
    _clearResults();
    _addResult('🚀 Starting Comprehensive API Tests...');
    _addResult('API Base URL: ${ApiConfig.baseUrl}');
    _addResult('=' * 50);
    
    await _testHealthCheck();
    await Future.delayed(const Duration(seconds: 1));
    
    await _testSendOTP();
    await Future.delayed(const Duration(seconds: 1));
    
    if (_otpController.text.isNotEmpty) {
      await _testVerifyOTP();
      await Future.delayed(const Duration(seconds: 1));
      
      if (_authToken != null) {
        await _testGetProfile();
        await Future.delayed(const Duration(seconds: 1));
        
        await _testGetDocuments();
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    
    await _testGetNews();
    await Future.delayed(const Duration(seconds: 1));
    
    await _testGetEvents();
    await Future.delayed(const Duration(seconds: 1));
    
    await _testGetMedia();
    
    _addResult('=' * 50);
    _addResult('✅ All tests completed!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Test Screen'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearResults,
            tooltip: 'Clear Results',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // API Configuration Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'API Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Base URL: ${ApiConfig.baseUrl}'),
                    Text('Health Endpoint: ${ApiConfig.getFullUrl('/health')}'),
                    if (_authToken != null)
                      Text('Auth Token: ${_authToken!.substring(0, 20)}...'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Input Fields
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                      hintText: '9876543210',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _otpController,
                    decoration: const InputDecoration(
                      labelText: 'OTP',
                      border: OutlineInputBorder(),
                      hintText: '123456',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Test Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testHealthCheck,
                  icon: const Icon(Icons.health_and_safety),
                  label: const Text('Health Check'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testSendOTP,
                  icon: const Icon(Icons.sms),
                  label: const Text('Send OTP'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testVerifyOTP,
                  icon: const Icon(Icons.verified),
                  label: const Text('Verify OTP'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testGetNews,
                  icon: const Icon(Icons.article),
                  label: const Text('Get News'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testGetEvents,
                  icon: const Icon(Icons.event),
                  label: const Text('Get Events'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testGetMedia,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Get Media'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testGetDocuments,
                  icon: const Icon(Icons.description),
                  label: const Text('Get Documents'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testGetProfile,
                  icon: const Icon(Icons.person),
                  label: const Text('Get Profile'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Run All Tests Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _runAllTests,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run All Tests'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Loading Indicator
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
            
            const SizedBox(height: 16),
            
            // Results
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Test Results',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _clearResults,
                            icon: const Icon(Icons.clear),
                            label: const Text('Clear'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            _testResults.isEmpty ? 'No tests run yet...' : _testResults,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}
