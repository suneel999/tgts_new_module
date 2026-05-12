import api from './api';

export type District = {
  id: number;
  name: {
    en: string;
    te: string;
  };
  name_en: string;
  name_te: string;
  state: string;
  description?: string;
  isActive: boolean;
  createdAt?: string;
  updatedAt?: string;
};

export type Mandal = {
  id: number;
  districtId: number;
  districtRef?: District;
  name: {
    en: string;
    te: string;
  };
  name_en: string;
  name_te: string;
  description?: string;
  isActive: boolean;
  createdAt?: string;
  updatedAt?: string;
};

export type DistrictFilters = {
  state?: string;
  is_active?: boolean;
  search?: string;
};

export type DistrictUpdateData = {
  name_en?: string;
  name_te?: string;
  state?: string;
  description?: string;
  isActive?: boolean;
};

export type DistrictCreateData = {
  name_en: string;
  name_te?: string;
  state?: string;
  description?: string;
  isActive?: boolean;
};

export type MandalCreateData = {
  name_en: string;
  name_te?: string;
  description?: string;
  isActive?: boolean;
};

export type MandalUpdateData = {
  name_en?: string;
  name_te?: string;
  description?: string;
  isActive?: boolean;
};

export type MandalFilters = {
  district_id?: number;
  is_active?: boolean;
  search?: string;
};

export const districtsService = {
  // Get all districts
  async getDistricts(filters: DistrictFilters = {}): Promise<District[]> {
    const response = await api.get('/districts/', { params: filters });
    return response.data;
  },

  // Get district by ID
  async getDistrictById(districtId: number): Promise<District> {
    const response = await api.get(`/districts/${districtId}`);
    return response.data;
  },

  // Get mandals for a district
  async getMandalsForDistrict(districtId: number, filters: { is_active?: boolean; search?: string } = {}): Promise<Mandal[]> {
    const params: any = {};
    if (filters.is_active !== undefined) {
      params.is_active = filters.is_active.toString();
    }
    if (filters.search) {
      params.search = filters.search;
    }
    
    const response = await api.get(`/districts/${districtId}/mandals`, { params });
    return response.data;
  },

  // Get all mandals (optional: filtered by district_id)
  async getMandals(filters: MandalFilters = {}): Promise<Mandal[]> {
    const params: any = {};
    if (filters.district_id !== undefined && filters.district_id !== null) {
      params.district_id = filters.district_id;
    }
    if (filters.is_active !== undefined) {
      params.is_active = filters.is_active.toString();
    }
    if (filters.search) {
      params.search = filters.search;
    }
    
    const response = await api.get('/mandals/', { params });
    return response.data;
  },

  // Update district
  async updateDistrict(districtId: number, data: DistrictUpdateData): Promise<District> {
    const response = await api.put(`/districts/${districtId}`, data);
    return response.data;
  },

  // Create district
  async createDistrict(data: DistrictCreateData): Promise<District> {
    const response = await api.post('/districts/', data);
    return response.data;
  },

  // Create mandal
  async createMandal(districtId: number, data: MandalCreateData): Promise<Mandal> {
    const response = await api.post(`/districts/${districtId}/mandals`, data);
    return response.data;
  },

  // Update mandal
  async updateMandal(mandalId: number, data: MandalUpdateData): Promise<Mandal> {
    const response = await api.put(`/mandals/${mandalId}`, data);
    return response.data;
  },
};

