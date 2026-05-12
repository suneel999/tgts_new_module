import api from './api';
import type { User } from './authService';

export type PaginatedResponse<T> = {
  data: T[];
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
};

export type UserFilters = {
  page?: number;
  per_page?: number;
  role?: string;
  search?: string;
};

export const userService = {
  // Get all users (admin only)
  async getUsers(filters: UserFilters = {}): Promise<PaginatedResponse<User>> {
    const response = await api.get('/users/', { params: filters });
    return response.data;
  },

  // Get user by ID
  async getUserById(userId: number): Promise<User> {
    const response = await api.get(`/users/${userId}`);
    return response.data;
  },

  // Update user (admin only)
  async updateUser(userId: number, data: Partial<User>): Promise<User> {
    const response = await api.put(`/users/${userId}`, data);
    return response.data;
  },

  // Delete user (admin only)
  async deleteUser(userId: number) {
    const response = await api.delete(`/users/${userId}`);
    return response.data;
  },
};

