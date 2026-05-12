import api from './api';

export type AdminLoginRequest = {
  username: string;
  password: string;
};

export type User = {
  id: string;
  phone: string;
  name: string;
  role: string;
  region?: string;
  isActive?: boolean;
  is_active?: boolean; // API may return snake_case
  enrollment_date?: string;
  enrollmentDate?: string; // API may return camelCase
  createdAt?: string;
  updatedAt?: string;
  // Member fields
  fullName?: string;
  fatherName?: string;
  dateOfBirth?: string;
  gender?: string;
  aadharNumber?: string;
  epicNumber?: string;
  epicFileUrl?: string;
  village?: string;
  mandal?: string;
  district?: string;
  parliamentConstituencyId?: number;
  parliamentConstituencyRef?: {
    id: number;
    constituencyNumber: number;
    name_en: string;
    name_te: string;
  };
  assemblyConstituencyId?: number;
  assemblyConstituencyRef?: {
    id: number;
    constituencyNumber: number;
    name_en: string;
    name_te: string;
  };
  fullAddress?: string;
  partyDesignation?: string;
  occupation?: string;
  volunteerInterest?: boolean;
  hasInsurance?: boolean;
  insuranceNumber?: string;
  status?: string;
};

export type AdminLoginResponse = {
  access_token: string;
  user: User;
  message: string;
};

export const authService = {
  // Admin login
  async adminLogin(credentials: AdminLoginRequest): Promise<AdminLoginResponse> {
    const response = await api.post('/auth/admin-login', credentials);
    return response.data;
  },

  // Logout (clear token)
  logout() {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    window.location.href = '/login';
  },

  // Check if user is authenticated
  isAuthenticated(): boolean {
    return !!localStorage.getItem('token');
  },

  // Get stored user info
  getStoredUser() {
    const userStr = localStorage.getItem('user');
    if (userStr) {
      try {
        return JSON.parse(userStr);
      } catch {
        return null;
      }
    }
    return null;
  },

  // Store auth data
  storeAuth(token: string, user: any) {
    localStorage.setItem('token', token);
    localStorage.setItem('user', JSON.stringify(user));
  },

  // Get current user profile
  async getProfile(): Promise<User> {
    const response = await api.get('/auth/profile');
    return response.data;
  },

  // Update user profile
  async updateProfile(data: Partial<User>): Promise<User> {
    const response = await api.put('/auth/profile', data);
    const updatedUser = response.data;
    // Update stored user
    this.storeAuth(localStorage.getItem('token') || '', updatedUser);
    return updatedUser;
  },
};
