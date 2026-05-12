import api from './api';
import type { PaginatedResponse } from './userService';

export type CadreLevel = {
  level: number;
  nameEn: string;
  nameTe: string;
  geographicScope: 'state' | 'district' | 'mandal' | 'booth';
};

export type CadreLevelsResponse = {
  cadreLevels: CadreLevel[];
  total: number;
};

export type Member = {
  id: string;
  fullName: string;
  fatherName?: string;
  dateOfBirth?: string;
  gender?: string;
  phone: string;
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
  cadreLevel?: number;
  cadreLevelRef?: CadreLevel;
  occupation?: string;
  volunteerInterest: boolean;
  hasInsurance: boolean;
  insuranceNumber?: string;
  status: 'pending' | 'approved' | 'rejected';
  isActive: boolean;
  role?: string;
  createdAt?: string;
  updatedAt?: string;
};

export type MemberFilters = {
  page?: number;
  per_page?: number;
  status?: 'pending' | 'approved' | 'rejected';
  district?: string;
  search?: string;
};

export type MemberUpdateData = {
  fullName?: string;
  fatherName?: string;
  dateOfBirth?: string;
  gender?: string;
  phone?: string;
  aadharNumber?: string;
  epicNumber?: string;
  village?: string;
  mandal?: string;
  district?: string;
  parliamentConstituencyId?: number;
  assemblyConstituencyId?: number;
  fullAddress?: string;
  partyDesignation?: string;
  cadreLevel?: number | null;
  occupation?: string;
  volunteerInterest?: boolean;
  hasInsurance?: boolean;
  insuranceNumber?: string;
  status?: 'pending' | 'approved' | 'rejected';
  isActive?: boolean;
  role?: string;
};

export const memberService = {
  // Get all cadre levels (predefined hierarchy)
  async getCadreLevels(): Promise<CadreLevelsResponse> {
    const response = await api.get('/cadre-levels/');
    return response.data;
  },

  // Get all members (admin/cadre only)
  async getMembers(filters: MemberFilters = {}): Promise<PaginatedResponse<Member>> {
    const response = await api.get('/members/', { params: filters });
    return response.data;
  },

  // Get member by ID
  async getMemberById(memberId: string): Promise<Member> {
    const response = await api.get(`/members/${memberId}`);
    return response.data;
  },

  // Update member status (admin/cadre only)
  async updateMemberStatus(memberId: string, status: 'pending' | 'approved' | 'rejected'): Promise<Member> {
    const response = await api.put(`/members/${memberId}`, { status });
    return response.data;
  },

  // Update member (admin only)
  async updateMember(memberId: string, data: MemberUpdateData): Promise<Member> {
    const response = await api.put(`/members/${memberId}`, data);
    return response.data;
  },
};

