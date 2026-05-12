import axios from 'axios';

// Use the same API URL configuration as the main api service
const USE_PRODUCTION = true;
const PRODUCTION_URL = 'https://apitgts.codeology.solutions/api';
const API_URL = USE_PRODUCTION ? PRODUCTION_URL : 'http://localhost:5000/api';

export interface VerifyMemberResponse {
  memberId: string;
  fullName: string;
  status: string;
  profilePictureUrl: string | null;
  partyDesignation: string | null;
  cadreLevel: number | null;
  cadreLevelName: string | null;
  district: string | null;
  assemblyConstituency: string | null;
  isVerified: boolean;
}

/**
 * Fetch member verification data from the public API endpoint.
 * This uses a plain axios instance (no auth token) since the endpoint is public.
 */
export async function fetchMemberVerification(memberId: string): Promise<VerifyMemberResponse> {
  const response = await axios.get<VerifyMemberResponse>(`${API_URL}/verify/${memberId}`);
  return response.data;
}
