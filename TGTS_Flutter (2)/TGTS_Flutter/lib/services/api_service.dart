import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Generic API call method with fallback handling
  Future<Map<String, dynamic>> makeRequest({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requireAuth = false,
    String? authToken,
  }) async {
    try {
      final url = ApiConfig.getFullUrl(endpoint);
      final requestHeaders = Map<String, String>.from(ApiConfig.defaultHeaders);
      
      if (headers != null) {
        requestHeaders.addAll(headers);
      }
      
      if (requireAuth && authToken != null) {
        requestHeaders['Authorization'] = 'Bearer $authToken';
      }

      http.Response response;
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(
            Uri.parse(url),
            headers: requestHeaders,
          ).timeout(const Duration(seconds: ApiConfig.timeoutDuration));
          break;
        case 'POST':
          response = await http.post(
            Uri.parse(url),
            headers: requestHeaders,
            body: body != null ? json.encode(body) : null,
          ).timeout(const Duration(seconds: ApiConfig.timeoutDuration));
          break;
        case 'PUT':
          response = await http.put(
            Uri.parse(url),
            headers: requestHeaders,
            body: body != null ? json.encode(body) : null,
          ).timeout(const Duration(seconds: ApiConfig.timeoutDuration));
          break;
        case 'DELETE':
          response = await http.delete(
            Uri.parse(url),
            headers: requestHeaders,
          ).timeout(const Duration(seconds: ApiConfig.timeoutDuration));
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      return _handleResponse(response);
    } on SocketException {
      return {
        'success': false,
        'message': 'No internet connection. Please check your network.',
        'error': 'network_error',
      };
    } on http.ClientException {
      return {
        'success': false,
        'message': 'Network error. Please try again.',
        'error': 'client_error',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred: ${e.toString()}',
        'error': 'unknown_error',
      };
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      // Handle HTML responses (like 404 pages)
      if (response.headers['content-type']?.contains('text/html') == true) {
        if (response.statusCode == 404) {
          return {
            'success': false,
            'message': 'API endpoint not found. The server may not have all routes deployed yet.',
            'error': 'endpoint_not_found',
            'statusCode': response.statusCode,
            'suggestion': 'Please check with the backend team to ensure all API routes are properly deployed.',
          };
        }
        return {
          'success': false,
          'message': 'Server returned HTML instead of JSON. This may indicate a server configuration issue.',
          'error': 'invalid_response_format',
          'statusCode': response.statusCode,
        };
      }

      final data = json.decode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'data': data,
          'statusCode': response.statusCode,
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? data['message'] ?? 'Request failed',
          'error': 'api_error',
          'statusCode': response.statusCode,
          'data': data,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to parse response: ${e.toString()}',
        'error': 'parse_error',
        'statusCode': response.statusCode,
        'rawResponse': response.body,
      };
    }
  }

  // Authentication methods
  Future<Map<String, dynamic>> sendOTP(String phone) async {
    return await makeRequest(
      endpoint: ApiConfig.loginEndpoint,
      method: 'POST',
      body: {'phone': phone},
    );
  }

  Future<Map<String, dynamic>> verifyOTP(String phone, String otp) async {
    return await makeRequest(
      endpoint: ApiConfig.verifyOtpEndpoint,
      method: 'POST',
      body: {'phone': phone, 'otp': otp},
    );
  }

  Future<Map<String, dynamic>> getProfile(String authToken) async {
    return await makeRequest(
      endpoint: ApiConfig.profileEndpoint,
      method: 'GET',
      requireAuth: true,
      authToken: authToken,
    );
  }

  Future<Map<String, dynamic>> updateProfile(
    String authToken,
    Map<String, dynamic> profileData,
  ) async {
    return await makeRequest(
      endpoint: ApiConfig.profileEndpoint,
      method: 'PUT',
      body: profileData,
      requireAuth: true,
      authToken: authToken,
    );
  }

  Future<Map<String, dynamic>> uploadProfilePicture(
    String authToken,
    File imageFile,
  ) async {
    try {
      final url = ApiConfig.getFullUrl('/auth/upload-profile-picture');
      final request = http.MultipartRequest('POST', Uri.parse(url));
      
      // Add authorization header
      request.headers['Authorization'] = 'Bearer $authToken';
      request.headers['Content-Type'] = 'multipart/form-data';
      
      // Add file
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();
      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: imageFile.path.split('/').last,
      );
      request.files.add(multipartFile);
      
      // Send request
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: ApiConfig.timeoutDuration),
      );
      
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on SocketException {
      return {
        'success': false,
        'message': 'No internet connection. Please check your network.',
        'error': 'network_error',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to upload profile picture: ${e.toString()}',
        'error': 'upload_error',
      };
    }
  }

  // Upload media using the same two-step flow as the admin portal:
  // Step 1 — POST /media/upload (multipart) → get file URL from local/S3 storage
  // Step 2 — POST /media/ (JSON) → create DB record with is_published=true
  Future<Map<String, dynamic>> uploadMedia({
    required String authToken,
    required String filePath,
    required String titleEn,
    required String titleTe,
    required String type, // 'photo' or 'video'
    String accessLevel = 'public',
  }) async {
    try {
      // ── Step 1: upload the file, get back its URL ──────────────────────────
      final ext = filePath.split('.').last.toLowerCase();
      final subtype = ext == 'jpg' ? 'jpeg' : ext;
      final contentType =
          type == 'photo' ? MediaType('image', subtype) : MediaType('video', subtype);

      final uploadUri = Uri.parse(ApiConfig.getFullUrl('/media/upload'));
      final uploadRequest = http.MultipartRequest('POST', uploadUri)
        ..headers['Authorization'] = 'Bearer $authToken'
        ..headers['Accept'] = 'application/json'
        ..fields['type'] = type;

      uploadRequest.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: contentType,
      ));

      final uploadStreamed =
          await uploadRequest.send().timeout(const Duration(seconds: 120));
      final uploadResponse = await http.Response.fromStream(uploadStreamed);
      final uploadResult = _handleResponse(uploadResponse);

      if (uploadResult['success'] != true) {
        return uploadResult;
      }

      final fileUrl = uploadResult['data']?['url'] as String?;
      final thumbnailUrl = uploadResult['data']?['thumbnail_url'] as String?;

      if (fileUrl == null || fileUrl.isEmpty) {
        return {
          'success': false,
          'message': 'File uploaded but no URL returned from server.',
          'error': 'upload_error',
        };
      }

      // ── Step 2: create the DB record (published immediately) ──────────────
      final createResult = await makeRequest(
        endpoint: '/media/',
        method: 'POST',
        authToken: authToken,
        requireAuth: true,
        body: {
          'type': type,
          'url': fileUrl,
          if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
          'title_en': titleEn,
          'title_te': titleTe,
          'is_published': true,
          'access_level': [accessLevel],
        },
      );

      return createResult;
    } on SocketException {
      return {
        'success': false,
        'message': 'No internet connection. Please check your network.',
        'error': 'network_error',
      };
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Upload timed out. Please try again.',
        'error': 'timeout_error',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Upload failed: ${e.toString()}',
        'error': 'upload_error',
      };
    }
  }

  // ── Event image upload (any authenticated user) ─────────────────────────────
  Future<Map<String, dynamic>> uploadEventImage({
    required String authToken,
    required String filePath,
  }) async {
    try {
      final ext = filePath.split('.').last.toLowerCase();
      final subtype = ext == 'jpg' ? 'jpeg' : ext;

      final uri = Uri.parse(ApiConfig.getFullUrl('/events/upload-image'));
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $authToken'
        ..headers['Accept'] = 'application/json';

      request.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: MediaType('image', subtype),
      ));

      final streamed = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } on SocketException {
      return {'success': false, 'message': 'No internet connection.', 'error': 'network_error'};
    } on TimeoutException {
      return {'success': false, 'message': 'Upload timed out. Please try again.', 'error': 'timeout_error'};
    } catch (e) {
      return {'success': false, 'message': 'Image upload failed: ${e.toString()}', 'error': 'upload_error'};
    }
  }

  // Submit a user-created event for admin review
  Future<Map<String, dynamic>> createUserEvent({
    required String authToken,
    required String titleEn,
    required String titleTe,
    required String descriptionEn,
    required String descriptionTe,
    required String eventDate,
    required String eventTime,
    required String locationEn,
    required String locationTe,
    String? imageUrl,
  }) async {
    return await makeRequest(
      endpoint: '/events/user-submit',
      method: 'POST',
      authToken: authToken,
      requireAuth: true,
      body: {
        'title_en': titleEn,
        'title_te': titleTe,
        'description_en': descriptionEn,
        'description_te': descriptionTe,
        'event_date': eventDate,
        'event_time': eventTime,
        'location_en': locationEn,
        'location_te': locationTe,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
      },
    );
  }

  // Get events submitted by the current user
  Future<Map<String, dynamic>> getMyEvents(String authToken) async {
    final uri = Uri.parse(ApiConfig.getFullUrl('/events/my'));
    try {
      final response = await http.get(uri, headers: {
        ...ApiConfig.defaultHeaders,
        'Authorization': 'Bearer $authToken',
      }).timeout(const Duration(seconds: ApiConfig.timeoutDuration));
      return _handleResponse(response);
    } on SocketException {
      return {'success': false, 'message': 'No internet connection.', 'error': 'network_error'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch your events: ${e.toString()}', 'error': 'network_error'};
    }
  }

  // News methods
  Future<Map<String, dynamic>> getNews({
    int page = 1,
    int perPage = 20,
    String? category,
    String? authToken,
    int? districtId,
    int? mandalId,
    int? assemblyConstituencyId,
    int? parliamentConstituencyId,
  }) async {
    String endpoint = ApiConfig.getFullUrl('/news/');
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    if (category != null) queryParams['category'] = category;
    if (districtId != null) queryParams['district_id'] = districtId.toString();
    if (mandalId != null) queryParams['mandal_id'] = mandalId.toString();
    if (assemblyConstituencyId != null) queryParams['assembly_constituency_id'] = assemblyConstituencyId.toString();
    if (parliamentConstituencyId != null) queryParams['parliament_constituency_id'] = parliamentConstituencyId.toString();

    final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
    final headers = Map<String, String>.from(ApiConfig.defaultHeaders);
    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    try {
      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: ApiConfig.timeoutDuration));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch news: ${e.toString()}',
        'error': 'network_error',
      };
    }
  }

  // JWT-authenticated local news — backend resolves user location from DB automatically
  Future<Map<String, dynamic>> getLocalNews({
    int page = 1,
    int perPage = 20,
    required String authToken,
  }) async {
    final endpoint = ApiConfig.getFullUrl('/news/local');
    final uri = Uri.parse(endpoint).replace(queryParameters: {
      'page': page.toString(),
      'per_page': perPage.toString(),
    });
    final headers = Map<String, String>.from(ApiConfig.defaultHeaders)
      ..['Authorization'] = 'Bearer $authToken';

    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: ApiConfig.timeoutDuration));
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch local news: ${e.toString()}',
        'error': 'network_error',
      };
    }
  }

  // Events methods
  Future<Map<String, dynamic>> getEvents({
    int page = 1,
    int perPage = 20,
    bool upcomingOnly = false,
    String? authToken,
  }) async {
    String endpoint = ApiConfig.getFullUrl('/events/');
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      'upcoming_only': upcomingOnly.toString().toLowerCase(),
    };
    
    final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
    
    try {
      final headers = Map<String, String>.from(ApiConfig.defaultHeaders);
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }
      
      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: ApiConfig.timeoutDuration));
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch events: ${e.toString()}',
        'error': 'network_error',
      };
    }
  }

  Future<Map<String, dynamic>> rsvpToEvent(String eventId, String authToken) async {
    String endpoint = ApiConfig.getFullUrl('/events/$eventId/rsvp');
    
    try {
      final headers = Map<String, String>.from(ApiConfig.defaultHeaders);
      headers['Authorization'] = 'Bearer $authToken';
      
      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
      ).timeout(const Duration(seconds: ApiConfig.timeoutDuration));
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to RSVP: ${e.toString()}',
        'error': 'network_error',
      };
    }
  }

  // Media methods
  Future<Map<String, dynamic>> getMedia({
    int page = 1,
    int perPage = 20,
    String? type,
    String? authToken,
  }) async {
    String endpoint = ApiConfig.getFullUrl('/media/');
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    
    if (type != null) {
      queryParams['type'] = type;
    }
    
    final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
    
    try {
      final headers = Map<String, String>.from(ApiConfig.defaultHeaders);
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }
      
      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: ApiConfig.timeoutDuration));
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch media: ${e.toString()}',
        'error': 'network_error',
      };
    }
  }


  // Documents methods
  Future<Map<String, dynamic>> getDocuments({
    int page = 1,
    int perPage = 20,
    String? category,
    String? authToken,
  }) async {
    String endpoint = ApiConfig.getFullUrl('/documents/');
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    
    if (category != null) {
      queryParams['category'] = category;
    }
    
    final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
    
    try {
      final headers = Map<String, String>.from(ApiConfig.defaultHeaders);
      if (authToken != null) {
        headers['Authorization'] = 'Bearer $authToken';
      }
      
      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: ApiConfig.timeoutDuration));
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch documents: ${e.toString()}',
        'error': 'network_error',
      };
    }
  }

  // Health check
  Future<Map<String, dynamic>> checkHealth() async {
    return await makeRequest(
      endpoint: '/health',
      method: 'GET',
    );
  }

  // Voter list methods
  Future<Map<String, dynamic>> getVoterData(
    String path,
    Map<String, String> params,
    String token,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.voterListEndpoint}$path')
        .replace(queryParameters: params.isEmpty ? null : params);
    try {
      final response = await http.get(uri, headers: {
        ...ApiConfig.defaultHeaders,
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: ApiConfig.timeoutDuration));
      return _handleResponse(response);
    } on SocketException {
      return {'success': false, 'message': 'No internet connection.', 'error': 'network_error'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch voter data: $e', 'error': 'network_error'};
    }
  }

  Future<Map<String, dynamic>> getSchemeBeneficiaries(
    String schemeName,
    Map<String, String> params,
    String token,
  ) async {
    final allParams = {'scheme_name': schemeName, ...params};
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.schemeBeneficiariesEndpoint}/')
        .replace(queryParameters: allParams);
    try {
      final response = await http.get(uri, headers: {
        ...ApiConfig.defaultHeaders,
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: ApiConfig.timeoutDuration));
      return _handleResponse(response);
    } on SocketException {
      return {'success': false, 'message': 'No internet connection.', 'error': 'network_error'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch scheme data: $e', 'error': 'network_error'};
    }
  }

  Future<Map<String, dynamic>> getSchemesSummary(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.schemeBeneficiariesEndpoint}/schemes/');
    try {
      final response = await http.get(uri, headers: {
        ...ApiConfig.defaultHeaders,
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: ApiConfig.timeoutDuration));
      return _handleResponse(response);
    } on SocketException {
      return {'success': false, 'message': 'No internet connection.', 'error': 'network_error'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch schemes: $e', 'error': 'network_error'};
    }
  }

  Future<Map<String, dynamic>> uploadVoterCSV(
    String token,
    List<int> csvBytes,
    String filename,
  ) async {
    try {
      final url = '${ApiConfig.baseUrl}${ApiConfig.voterListEndpoint}/upload/';
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        csvBytes,
        filename: filename,
      ));
      final streamed = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } on SocketException {
      return {'success': false, 'message': 'No internet connection.', 'error': 'network_error'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to upload CSV: $e', 'error': 'upload_error'};
    }
  }

  // Constituencies methods
  Future<Map<String, dynamic>> getConstituencies({
    String? state,
    bool? isActive,
    String? search,
  }) async {
    String endpoint = ApiConfig.getFullUrl('/constituencies/');
    final queryParams = <String, String>{};
    
    if (state != null) {
      queryParams['state'] = state;
    }
    if (isActive != null) {
      queryParams['is_active'] = isActive.toString().toLowerCase();
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    
    final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
    
    try {
      final response = await http.get(
        uri,
        headers: ApiConfig.defaultHeaders,
      ).timeout(const Duration(seconds: ApiConfig.timeoutDuration));
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch constituencies: ${e.toString()}',
        'error': 'network_error',
      };
    }
  }

  // Assembly Constituencies methods
  Future<Map<String, dynamic>> getAssemblyConstituencies({
    String? parliamentConstituencyId,
    String? state,
    bool? isActive,
    String? search,
  }) async {
    String endpoint = ApiConfig.getFullUrl('/assembly-constituencies/');
    final queryParams = <String, String>{};
    
    if (parliamentConstituencyId != null && parliamentConstituencyId.isNotEmpty) {
      queryParams['parliament_constituency_id'] = parliamentConstituencyId;
    }
    if (state != null) {
      queryParams['state'] = state;
    }
    if (isActive != null) {
      queryParams['is_active'] = isActive.toString().toLowerCase();
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    
    final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
    
    try {
      final response = await http.get(
        uri,
        headers: ApiConfig.defaultHeaders,
      ).timeout(const Duration(seconds: ApiConfig.timeoutDuration));
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch assembly constituencies: ${e.toString()}',
        'error': 'network_error',
      };
    }
  }

  // Districts methods
  Future<Map<String, dynamic>> getDistricts({
    String? state,
    bool? isActive,
    String? search,
  }) async {
    String endpoint = ApiConfig.getFullUrl('/districts/');
    final queryParams = <String, String>{};
    
    if (state != null) {
      queryParams['state'] = state;
    }
    if (isActive != null) {
      queryParams['is_active'] = isActive.toString().toLowerCase();
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    
    final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
    
    try {
      final response = await http.get(
        uri,
        headers: ApiConfig.defaultHeaders,
      ).timeout(const Duration(seconds: ApiConfig.timeoutDuration));
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch districts: ${e.toString()}',
        'error': 'network_error',
      };
    }
  }

  // Mandals methods
  Future<Map<String, dynamic>> getMandals({
    int? districtId,
    bool? isActive,
    String? search,
  }) async {
    String endpoint = ApiConfig.getFullUrl('/mandals/');
    final queryParams = <String, String>{};
    
    if (districtId != null) {
      queryParams['district_id'] = districtId.toString();
    }
    if (isActive != null) {
      queryParams['is_active'] = isActive.toString().toLowerCase();
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    
    final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
    
    try {
      final response = await http.get(
        uri,
        headers: ApiConfig.defaultHeaders,
      ).timeout(const Duration(seconds: ApiConfig.timeoutDuration));
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch mandals: ${e.toString()}',
        'error': 'network_error',
      };
    }
  }

  // Members methods
  Future<Map<String, dynamic>> submitMembership({
    required String fullName,
    required String phone,
    String? fatherName,
    String? dateOfBirth,
    String? gender,
    String? aadharNumber,
    String? epicNumber,
    String? epicFileUrl,
    String? village,
    int? districtId,
    int? mandalId,
    String? parliamentConstituency,
    String? parliamentConstituencyId,
    String? assemblyConstituency,
    String? assemblyConstituencyId,
    String? fullAddress,
    String? partyDesignation,
    String? occupation,
    bool volunteerInterest = false,
    bool hasInsurance = false,
    String? insuranceNumber,
  }) async {
    String endpoint = ApiConfig.getFullUrl('/members/');
    
    try {
      final body = <String, dynamic>{
        'fullName': fullName,
        'phone': phone,
      };
      
      // Add optional fields only if they have values
      if (fatherName != null && fatherName.isNotEmpty) {
        body['fatherName'] = fatherName;
      }
      if (dateOfBirth != null && dateOfBirth.isNotEmpty) {
        body['dateOfBirth'] = dateOfBirth;
      }
      if (gender != null && gender.isNotEmpty) {
        body['gender'] = gender;
      }
      if (aadharNumber != null && aadharNumber.isNotEmpty) {
        body['aadharNumber'] = aadharNumber;
      }
      if (epicNumber != null && epicNumber.isNotEmpty) {
        body['epicNumber'] = epicNumber;
      }
      if (epicFileUrl != null && epicFileUrl.isNotEmpty) {
        body['epicFileUrl'] = epicFileUrl;
      }
      if (village != null && village.isNotEmpty) {
        body['village'] = village;
      }
      if (districtId != null) {
        body['districtId'] = districtId;
      }
      if (mandalId != null) {
        body['mandalId'] = mandalId;
      }
      if (parliamentConstituency != null && parliamentConstituency.isNotEmpty) {
        body['parliamentConstituency'] = parliamentConstituency;
      }
      if (parliamentConstituencyId != null && parliamentConstituencyId.isNotEmpty) {
        body['parliamentConstituencyId'] = parliamentConstituencyId;
      }
      if (assemblyConstituency != null && assemblyConstituency.isNotEmpty) {
        body['assemblyConstituency'] = assemblyConstituency;
      }
      if (assemblyConstituencyId != null && assemblyConstituencyId.isNotEmpty) {
        body['assemblyConstituencyId'] = assemblyConstituencyId;
      }
      if (fullAddress != null && fullAddress.isNotEmpty) {
        body['fullAddress'] = fullAddress;
      }
      if (partyDesignation != null && partyDesignation.isNotEmpty) {
        body['partyDesignation'] = partyDesignation;
      }
      if (occupation != null && occupation.isNotEmpty) {
        body['occupation'] = occupation;
      }
      body['volunteerInterest'] = volunteerInterest;
      body['hasInsurance'] = hasInsurance;
      if (insuranceNumber != null && insuranceNumber.isNotEmpty) {
        body['insuranceNumber'] = insuranceNumber;
      }
      
      final response = await http.post(
        Uri.parse(endpoint),
        headers: ApiConfig.defaultHeaders,
        body: json.encode(body),
      ).timeout(const Duration(seconds: ApiConfig.timeoutDuration));
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to submit membership: ${e.toString()}',
        'error': 'network_error',
      };
    }
  }
}
