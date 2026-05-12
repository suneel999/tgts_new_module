import React, { createContext, useContext, useState, useEffect } from 'react';
import type { ReactNode } from 'react';
import { authService } from '../services/authService';
import type { AdminLoginResponse } from '../services/authService';

type User = AdminLoginResponse['user'];

interface AuthContextType {
  user: User | null;
  loading: boolean;
  isAuthenticated: boolean;
  login: (phone: string, otp: string) => Promise<void>;
  adminLogin: (username: string, password: string) => Promise<void>;
  logout: () => void;
  updateUser: (user: User) => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

interface AuthProviderProps {
  children: ReactNode;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Check if user is already logged in
    const initAuth = async () => {
      try {
        const storedUser = authService.getStoredUser();
        if (storedUser && authService.isAuthenticated()) {
          console.log('Found stored user');
          setUser(storedUser);
        }
      } catch (error) {
        console.error('Auth initialization error:', error);
      } finally {
        // Always set loading to false after a short delay
        setTimeout(() => setLoading(false), 100);
      }
    };

    initAuth();

    // Listen for auto-logout events (e.g., token expiration)
    const handleAutoLogout = (event: CustomEvent) => {
      console.log('Auto-logout triggered:', event.detail?.reason || 'unknown');
      setUser(null);
    };

    window.addEventListener('auth:logout', handleAutoLogout as EventListener);

    return () => {
      window.removeEventListener('auth:logout', handleAutoLogout as EventListener);
    };
  }, []);

  const login = async (_phone: string, _otp: string) => {
    // OTP-based login (for mobile app)
    // This can be implemented if needed
    throw new Error('OTP login not implemented in admin panel');
  };

  const adminLogin = async (username: string, password: string) => {
    const response = await authService.adminLogin({ username, password });
    authService.storeAuth(response.access_token, response.user);
    setUser(response.user);
  };

  const logout = () => {
    authService.logout();
    setUser(null);
  };

  const updateUser = (updatedUser: User) => {
    setUser(updatedUser);
    localStorage.setItem('user', JSON.stringify(updatedUser));
  };

  const value: AuthContextType = {
    user,
    loading,
    isAuthenticated: !!user,
    login,
    adminLogin,
    logout,
    updateUser,
  };

  // Don't block rendering while loading - just render with loading=true
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

