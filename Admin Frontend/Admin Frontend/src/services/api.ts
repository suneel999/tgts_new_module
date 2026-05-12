// import axios from 'axios';

// // API Configuration
// // Production mode - always use production API
// const USE_PRODUCTION = true;

// // Production API URL
// const PRODUCTION_URL = 'https://apitgts.codeology.solutions/api';

// const API_URL = USE_PRODUCTION ? PRODUCTION_URL : 'http://localhost:5000/api';

// console.log('API Configuration:', {
//   mode: USE_PRODUCTION ? 'PRODUCTION' : 'DEVELOPMENT',
//   url: API_URL,
//   env: {
//     VITE_USE_PRODUCTION: import.meta.env.VITE_USE_PRODUCTION,
//     VITE_API_URL: import.meta.env.VITE_API_URL,
//   }
// });

// // Create axios instance with base configuration
// // Note: Don't set Content-Type as default - it will be set per request
// // For JSON requests, we'll set it in the interceptor
// // For FormData requests, axios will set it automatically with boundary
// const api = axios.create({
//   baseURL: API_URL,
//   timeout: 10000, // 10 second timeout
// });

// // Request interceptor to add auth token and handle production URL pattern
// api.interceptors.request.use(
//   (config) => {
//     // Ensure headers object exists
//     if (!config.headers) {
//       config.headers = {} as any;
//     }

//     const token = localStorage.getItem('token');
//     if (token) {
//       // Always set Authorization header, even for FormData requests
//       config.headers.Authorization = `Bearer ${token}`;
//     } else {
//       // Log warning if token is missing for protected endpoints
//       const protectedEndpoints = ['/documents/', '/media/', '/users/', '/events/'];
//       const isProtected = protectedEndpoints.some(endpoint => config.url?.includes(endpoint));
//       if (isProtected) {
//         console.warn('No auth token found for protected endpoint:', config.url);
//       }
//     }

//     // For FormData requests, don't set Content-Type manually
//     // Axios will automatically set it with the correct boundary
//     if (config.data instanceof FormData) {
//       // Explicitly remove Content-Type header to let axios set it with boundary
//       // This is critical - if Content-Type is set to application/json, Flask won't parse multipart/form-data
//       if (config.headers['Content-Type']) {
//         delete config.headers['Content-Type'];
//       }
//       // Also remove it from common headers if present
//       if (config.headers.common && config.headers.common['Content-Type']) {
//         delete config.headers.common['Content-Type'];
//       }
//       // Ensure Authorization header is preserved for FormData
//       if (token && !config.headers.Authorization) {
//         config.headers.Authorization = `Bearer ${token}`;
//       }
//     } else {
//       // For non-FormData requests, set Content-Type to application/json
//       // Only if it's not already set and the data is not FormData
//       if (!config.headers['Content-Type'] && config.data !== null && config.data !== undefined) {
//         config.headers['Content-Type'] = 'application/json';
//       }
//     }

//     // Base URL already includes /api, so no need to add another /api prefix
//     // The services call endpoints like /events/, /media/, etc.
//     // With baseURL = 'https://apitgts.codeology.solutions/api'
//     // Final URL will be: https://apitgts.codeology.solutions/api/events/

//     return config;
//   },
//   (error) => {
//     return Promise.reject(error);
//   }
// );

// // Response interceptor for error handling
// api.interceptors.response.use(
//   (response) => response,
//   (error) => {
//     // Log full error for debugging
//     console.error('API Error:', {
//       message: error.message,
//       code: error.code,
//       status: error.response?.status,
//       url: error.config?.url,
//       baseURL: error.config?.baseURL,
//       fullError: error
//     });

//     if (error.response?.status === 401) {
//       // Handle unauthorized - token expired or invalid
//       console.warn('Unauthorized access - token expired or invalid. Auto-logging out...');

//       // Clear auth tokens
//       localStorage.removeItem('token');
//       localStorage.removeItem('user');

//       // Store logout reason in sessionStorage to show message on login page
//       sessionStorage.setItem('logoutReason', 'token_expired');

//       // Dispatch custom event to notify AuthContext
//       window.dispatchEvent(new CustomEvent('auth:logout', { detail: { reason: 'token_expired' } }));

//       // Only redirect if we're not already on login page
//       if (window.location.pathname !== '/login') {
//         // Use setTimeout to ensure state is cleared before redirect
//         setTimeout(() => {
//           window.location.href = '/login';
//         }, 100);
//       }
//     } else if (error.response?.status === 0 || error.code === 'ERR_NETWORK' || error.code === 'ECONNREFUSED') {
//       // Network error - could be CORS, connection refused, or server down
//       const apiUrl = error.config?.baseURL || API_URL;
//       console.error('Network error connecting to backend:', apiUrl);
//       console.error('This could be due to:');
//       console.error('1. CORS configuration issue - backend needs to allow your domain');
//       console.error('2. Backend server is not running or not accessible');
//       console.error('3. Network connectivity issues');
//       console.error('Current origin:', window.location.origin);
//       console.error('Backend URL:', apiUrl);
//       console.error('Backend server is not reachable. Please check your connection and ensure the backend is running.');
//     } else if (error.response?.status) {
//       // HTTP error response received
//       const status = error.response.status;
//       const statusText = error.response.statusText;
//       const method = error.config?.method?.toUpperCase();
//       const url = error.config?.url;
//       const fullUrl = error.config?.baseURL + url;

//       console.error(`HTTP ${status}: ${statusText}`);
//       console.error(`Request: ${method} ${fullUrl}`);

//       // Special handling for method not allowed errors
//       if (status === 405) {
//         console.error('Method Not Allowed - This usually means:');
//         console.error('1. The HTTP method (GET/POST/PUT/DELETE) is not supported for this endpoint');
//         console.error('2. The URL might be incorrect (check for double /api/api pattern in production)');
//         console.error('3. CORS preflight (OPTIONS) might be failing');
//         console.error(`Attempted: ${method} ${fullUrl}`);
//       }
//     }
//     return Promise.reject(error);
//   }
// );

// export default api;


// import axios from 'axios';

// // API Configuration
// // Automatically switches between local and production based on environment
// const API_URL = import.meta.env.VITE_API_URL || 
//   (import.meta.env.DEV ? 'http://localhost:5000/api' : 'https://apitgts.codeology.solutions/api');

// console.log('API Configuration:', {
//   mode: import.meta.env.DEV ? 'DEVELOPMENT' : 'PRODUCTION',
//   url: API_URL,
//   env: {
//     VITE_API_URL: import.meta.env.VITE_API_URL,
//   }
// });

// // Create axios instance with base configuration
// // Note: Don't set Content-Type as default - it will be set per request
// // For JSON requests, we'll set it in the interceptor
// // For FormData requests, axios will set it automatically with boundary
// const api = axios.create({
//   baseURL: API_URL,
//   timeout: 10000, // 10 second timeout
// });

// // Request interceptor to add auth token and handle content types
// api.interceptors.request.use(
//   (config) => {
//     // Ensure headers object exists
//     if (!config.headers) {
//       config.headers = {} as any;
//     }

//     const token = localStorage.getItem('token');
//     if (token) {
//       // Always set Authorization header, even for FormData requests
//       config.headers.Authorization = `Bearer ${token}`;
//     } else {
//       // Log warning if token is missing for protected endpoints
//       const protectedEndpoints = ['/documents/', '/media/', '/users/', '/events/'];
//       const isProtected = protectedEndpoints.some(endpoint => config.url?.includes(endpoint));
//       if (isProtected) {
//         console.warn('No auth token found for protected endpoint:', config.url);
//       }
//     }

//     if (config.data instanceof FormData) {
//       // For FormData requests, remove Content-Type so axios sets it automatically
//       // with the correct multipart/form-data boundary
//       if (config.headers['Content-Type']) {
//         delete config.headers['Content-Type'];
//       }
//       if (config.headers.common && config.headers.common['Content-Type']) {
//         delete config.headers.common['Content-Type'];
//       }
//       // Ensure Authorization header is preserved for FormData
//       if (token && !config.headers.Authorization) {
//         config.headers.Authorization = `Bearer ${token}`;
//       }
//     } else {
//       // For non-FormData requests, set Content-Type to application/json
//       if (!config.headers['Content-Type'] && config.data !== null && config.data !== undefined) {
//         config.headers['Content-Type'] = 'application/json';
//       }
//     }

//     return config;
//   },
//   (error) => {
//     return Promise.reject(error);
//   }
// );

// // Response interceptor for error handling
// api.interceptors.response.use(
//   (response) => response,
//   (error) => {
//     // Log full error for debugging
//     console.error('API Error:', {
//       message: error.message,
//       code: error.code,
//       status: error.response?.status,
//       url: error.config?.url,
//       baseURL: error.config?.baseURL,
//     });

//     if (error.response?.status === 401) {
//       // Handle unauthorized - token expired or invalid
//       console.warn('Unauthorized access - token expired or invalid. Auto-logging out...');

//       // Clear auth tokens
//       localStorage.removeItem('token');
//       localStorage.removeItem('user');

//       // Store logout reason in sessionStorage to show message on login page
//       sessionStorage.setItem('logoutReason', 'token_expired');

//       // Dispatch custom event to notify AuthContext
//       window.dispatchEvent(new CustomEvent('auth:logout', { detail: { reason: 'token_expired' } }));

//       // Only redirect if we're not already on login page
//       if (window.location.pathname !== '/login') {
//         setTimeout(() => {
//           window.location.href = '/login';
//         }, 100);
//       }

//     } else if (error.response?.status === 405) {
//       // Method Not Allowed
//       const method = error.config?.method?.toUpperCase();
//       const fullUrl = (error.config?.baseURL || '') + (error.config?.url || '');
//       console.error('Method Not Allowed - This usually means:');
//       console.error('1. The HTTP method is not supported for this endpoint');
//       console.error('2. The URL might be incorrect (check for double /api/api pattern)');
//       console.error('3. CORS preflight (OPTIONS) might be failing');
//       console.error(`Attempted: ${method} ${fullUrl}`);

//     } else if (
//       error.response?.status === 0 ||
//       error.code === 'ERR_NETWORK' ||
//       error.code === 'ECONNREFUSED'
//     ) {
//       // Network error - CORS, connection refused, or server down
//       const apiUrl = error.config?.baseURL || API_URL;
//       console.error('Network error connecting to backend:', apiUrl);
//       console.error('Possible causes:');
//       console.error('1. CORS configuration issue - backend needs to allow your domain');
//       console.error('2. Backend server is not running or not accessible');
//       console.error('3. Network connectivity issues');
//       console.error('Current origin:', window.location.origin);
//       console.error('Backend URL:', apiUrl);

//     } else if (error.response?.status) {
//       // Other HTTP error responses
//       const status = error.response.status;
//       const statusText = error.response.statusText;
//       const method = error.config?.method?.toUpperCase();
//       const fullUrl = (error.config?.baseURL || '') + (error.config?.url || '');
//       console.error(`HTTP ${status}: ${statusText} — ${method} ${fullUrl}`);
//     }

//     return Promise.reject(error);
//   }
// );

// export default api;



import axios from 'axios';

// API Configuration
// Automatically switches between local and production based on environment
const API_URL = import.meta.env.VITE_API_URL || 
  (import.meta.env.DEV ? 'http://localhost:5000/api' : 'https://apitgts.codeology.solutions/api');

console.log('API Configuration:', {
  mode: import.meta.env.DEV ? 'DEVELOPMENT' : 'PRODUCTION',
  url: API_URL,
  env: {
    VITE_API_URL: import.meta.env.VITE_API_URL,
  }
});

// Create axios instance with base configuration
// Note: Don't set Content-Type as default - it will be set per request
// For JSON requests, we'll set it in the interceptor
// For FormData requests, axios will set it automatically with boundary
const api = axios.create({
  baseURL: API_URL,
  timeout: 300000, // 10 second timeout
});

// Request interceptor to add auth token and handle content types
api.interceptors.request.use(
  (config) => {
    // Ensure headers object exists
    if (!config.headers) {
      config.headers = {} as any;
    }

    const token = localStorage.getItem('token');
    if (token) {
      // Always set Authorization header, even for FormData requests
      config.headers.Authorization = `Bearer ${token}`;
    } else {
      // Log warning if token is missing for protected endpoints
      const protectedEndpoints = ['/documents/', '/media/', '/users/', '/events/'];
      const isProtected = protectedEndpoints.some(endpoint => config.url?.includes(endpoint));
      if (isProtected) {
        console.warn('No auth token found for protected endpoint:', config.url);
      }
    }

    if (config.data instanceof FormData) {
      // For FormData requests, remove Content-Type so axios sets it automatically
      // with the correct multipart/form-data boundary
      if (config.headers['Content-Type']) {
        delete config.headers['Content-Type'];
      }
      if (config.headers.common && config.headers.common['Content-Type']) {
        delete config.headers.common['Content-Type'];
      }
      // Ensure Authorization header is preserved for FormData
      if (token && !config.headers.Authorization) {
        config.headers.Authorization = `Bearer ${token}`;
      }
    } else {
      // For non-FormData requests, set Content-Type to application/json
      if (!config.headers['Content-Type'] && config.data !== null && config.data !== undefined) {
        config.headers['Content-Type'] = 'application/json';
      }
    }

    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor for error handling
api.interceptors.response.use(
  (response) => response,
  (error) => {
    // Log full error for debugging
    console.error('API Error:', {
      message: error.message,
      code: error.code,
      status: error.response?.status,
      url: error.config?.url,
      baseURL: error.config?.baseURL,
    });

    if (error.response?.status === 401) {
      // Handle unauthorized - token expired or invalid
      console.warn('Unauthorized access - token expired or invalid. Auto-logging out...');

      // Clear auth tokens
      localStorage.removeItem('token');
      localStorage.removeItem('user');

      // Store logout reason in sessionStorage to show message on login page
      sessionStorage.setItem('logoutReason', 'token_expired');

      // Dispatch custom event to notify AuthContext
      window.dispatchEvent(new CustomEvent('auth:logout', { detail: { reason: 'token_expired' } }));

      // Only redirect if we're not already on login page
      if (window.location.pathname !== '/login') {
        setTimeout(() => {
          window.location.href = '/login';
        }, 100);
      }

    } else if (error.response?.status === 405) {
      // Method Not Allowed
      const method = error.config?.method?.toUpperCase();
      const fullUrl = (error.config?.baseURL || '') + (error.config?.url || '');
      console.error('Method Not Allowed - This usually means:');
      console.error('1. The HTTP method is not supported for this endpoint');
      console.error('2. The URL might be incorrect (check for double /api/api pattern)');
      console.error('3. CORS preflight (OPTIONS) might be failing');
      console.error(`Attempted: ${method} ${fullUrl}`);

    } else if (
      error.response?.status === 0 ||
      error.code === 'ERR_NETWORK' ||
      error.code === 'ECONNREFUSED'
    ) {
      // Network error - CORS, connection refused, or server down
      const apiUrl = error.config?.baseURL || API_URL;
      console.error('Network error connecting to backend:', apiUrl);
      console.error('Possible causes:');
      console.error('1. CORS configuration issue - backend needs to allow your domain');
      console.error('2. Backend server is not running or not accessible');
      console.error('3. Network connectivity issues');
      console.error('Current origin:', window.location.origin);
      console.error('Backend URL:', apiUrl);

    } else if (error.response?.status) {
      // Other HTTP error responses
      const status = error.response.status;
      const statusText = error.response.statusText;
      const method = error.config?.method?.toUpperCase();
      const fullUrl = (error.config?.baseURL || '') + (error.config?.url || '');
      console.error(`HTTP ${status}: ${statusText} — ${method} ${fullUrl}`);
    }

    return Promise.reject(error);
  }
);

export default api;