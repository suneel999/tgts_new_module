import api from './api';

export type ParliamentaryConstituency = {
  id: number;  // Now using constituency_number as ID
  constituencyNumber: number;
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

export type ConstituencyFilters = {
  state?: string;
  is_active?: boolean;
  search?: string;
};

export type ConstituencyUpdateData = {
  name_en?: string;
  name_te?: string;
  state?: string;
  description?: string;
  isActive?: boolean;
};

export type ConstituencyCreateData = {
  constituencyNumber: number;
  name_en: string;
  name_te?: string;
  state?: string;
  description?: string;
  isActive?: boolean;
};

export type AssemblyConstituencyCreateData = {
  constituencyNumber: number;
  name_en: string;
  name_te?: string;
  state?: string;
  parliamentConstituencyId: number;
  description?: string;
  isActive?: boolean;
};

export type AssemblyConstituencyUpdateData = {
  name_en?: string;
  name_te?: string;
  state?: string;
  parliamentConstituencyId?: number;
  description?: string;
  isActive?: boolean;
};

export const constituencyService = {
  // Get all parliamentary constituencies
  async getConstituencies(filters: ConstituencyFilters = {}): Promise<ParliamentaryConstituency[]> {
    const response = await api.get('/constituencies/', { params: filters });
    return response.data;
  },

  // Get constituency by ID (constituency number)
  async getConstituencyById(constituencyId: number): Promise<ParliamentaryConstituency> {
    const response = await api.get(`/constituencies/${constituencyId}`);
    return response.data;
  },

  // Get constituency by number (same as by ID now)
  async getConstituencyByNumber(constituencyNumber: number): Promise<ParliamentaryConstituency> {
    const response = await api.get(`/constituencies/by-number/${constituencyNumber}`);
    return response.data;
  },

  // Update constituency
  async updateConstituency(constituencyId: number, data: ConstituencyUpdateData): Promise<ParliamentaryConstituency> {
    const response = await api.put(`/constituencies/${constituencyId}`, data);
    return response.data;
  },

  // Create constituency
  async createConstituency(data: ConstituencyCreateData): Promise<ParliamentaryConstituency> {
    const response = await api.post('/constituencies/', data);
    return response.data;
  },

  // Create assembly constituency
  async createAssemblyConstituency(data: AssemblyConstituencyCreateData): Promise<any> {
    const response = await api.post('/assembly-constituencies/', data);
    return response.data;
  },

  // Update assembly constituency
  async updateAssemblyConstituency(constituencyId: number, data: AssemblyConstituencyUpdateData): Promise<any> {
    const response = await api.put(`/assembly-constituencies/${constituencyId}`, data);
    return response.data;
  },

  // Get assembly constituencies
  async getAssemblyConstituencies(filters: { parliamentary_constituency_id?: number; state?: string; is_active?: boolean } = {}): Promise<any[]> {
    // Convert boolean to string for query params
    // Note: Backend expects 'parliament_constituency_id' (without 'ary')
    const params: any = {};
    if (filters.parliamentary_constituency_id !== undefined && filters.parliamentary_constituency_id !== null) {
      params.parliament_constituency_id = filters.parliamentary_constituency_id;
    }
    if (filters.state) {
      params.state = filters.state;
    }
    if (filters.is_active !== undefined) {
      params.is_active = filters.is_active.toString();
    }
    
    console.log('Fetching assembly constituencies with params:', params);
    const response = await api.get('/assembly-constituencies/', { params });
    // Handle both direct array response and wrapped response
    const data = response.data;
    console.log('Raw API response:', data);
    console.log('Response type:', typeof data, 'Is array:', Array.isArray(data));
    
    let result: any[] = [];
    if (Array.isArray(data)) {
      result = data;
    } else if (data && Array.isArray(data.data)) {
      result = data.data;
    } else if (data && data.success && Array.isArray(data.data)) {
      result = data.data;
    }
    
    console.log(`Received ${result.length} assembly constituencies:`, result);
    if (result.length > 0) {
      console.log('First item structure:', result[0]);
    }
    return result;
  },
};

