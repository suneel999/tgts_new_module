import { useState, useEffect, useRef, useMemo } from 'react';
import { Check, ChevronDown } from 'lucide-react';
import { districtsService, type District, type Mandal } from '../services/districtsService';
import { constituencyService, type ParliamentaryConstituency } from '../services/constituencyService';

export type GeographicAccessData = {
  districtIds: number[];
  mandalIds: number[];
  assemblyConstituencyIds: number[];
  parliamentaryConstituencyIds: number[];
  postToAll: boolean;
};

type GeographicAccessSelectorProps = {
  value: GeographicAccessData;
  onChange: (value: GeographicAccessData) => void;
  disabled?: boolean;
};

type AssemblyConstituency = {
  id: number;
  constituencyNumber: number;
  name_en: string;
  name_te?: string;
  parliament_constituency_id?: number;
};

export default function GeographicAccessSelector({
  value,
  onChange,
  disabled = false,
}: GeographicAccessSelectorProps) {
  const [districts, setDistricts] = useState<District[]>([]);
  const [mandals, setMandals] = useState<Mandal[]>([]);
  const [parliamentaryConstituencies, setParliamentaryConstituencies] = useState<ParliamentaryConstituency[]>([]);
  const [assemblyConstituencies, setAssemblyConstituencies] = useState<AssemblyConstituency[]>([]);
  
  const [loadingDistricts, setLoadingDistricts] = useState(false);
  const [loadingMandals, setLoadingMandals] = useState(false);
  const [loadingParliamentary, setLoadingParliamentary] = useState(false);
  const [loadingAssembly, setLoadingAssembly] = useState(false);
  
  const [districtDropdownOpen, setDistrictDropdownOpen] = useState(false);
  const [mandalDropdownOpen, setMandalDropdownOpen] = useState(false);
  const [parliamentaryDropdownOpen, setParliamentaryDropdownOpen] = useState(false);
  const [assemblyDropdownOpen, setAssemblyDropdownOpen] = useState(false);
  
  const districtRef = useRef<HTMLDivElement>(null);
  const mandalRef = useRef<HTMLDivElement>(null);
  const parliamentaryRef = useRef<HTMLDivElement>(null);
  const assemblyRef = useRef<HTMLDivElement>(null);
  const assemblyRequestAbortController = useRef<AbortController | null>(null);
  const assemblyRequestInProgress = useRef(false);

  // Close dropdowns when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (districtRef.current && !districtRef.current.contains(event.target as Node)) {
        setDistrictDropdownOpen(false);
      }
      if (mandalRef.current && !mandalRef.current.contains(event.target as Node)) {
        setMandalDropdownOpen(false);
      }
      if (parliamentaryRef.current && !parliamentaryRef.current.contains(event.target as Node)) {
        setParliamentaryDropdownOpen(false);
      }
      if (assemblyRef.current && !assemblyRef.current.contains(event.target as Node)) {
        setAssemblyDropdownOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  // Load districts
  useEffect(() => {
    const loadDistricts = async () => {
      setLoadingDistricts(true);
      try {
        const data = await districtsService.getDistricts({ state: 'Telangana', is_active: true });
        setDistricts(data);
      } catch (error) {
        console.error('Failed to load districts:', error);
      } finally {
        setLoadingDistricts(false);
      }
    };
    loadDistricts();
  }, []);

  // Load mandals when districts are selected
  useEffect(() => {
    const loadMandals = async () => {
      if (value.districtIds.length === 0) {
        setMandals([]);
        return;
      }
      
      setLoadingMandals(true);
      try {
        // Fetch mandals for all selected districts
        const allMandals: Mandal[] = [];
        for (const districtId of value.districtIds) {
          const mandalsForDistrict = await districtsService.getMandalsForDistrict(districtId, { is_active: true });
          allMandals.push(...mandalsForDistrict);
        }
        // Remove duplicates
        const uniqueMandals = Array.from(
          new Map(allMandals.map(m => [m.id, m])).values()
        );
        setMandals(uniqueMandals);
      } catch (error) {
        console.error('Failed to load mandals:', error);
      } finally {
        setLoadingMandals(false);
      }
    };
    loadMandals();
  }, [value.districtIds]);

  // Load parliamentary constituencies
  useEffect(() => {
    const loadParliamentaryConstituencies = async () => {
      setLoadingParliamentary(true);
      try {
        const data = await constituencyService.getConstituencies({ state: 'Telangana', is_active: true });
        setParliamentaryConstituencies(data);
      } catch (error) {
        console.error('Failed to load parliamentary constituencies:', error);
      } finally {
        setLoadingParliamentary(false);
      }
    };
    loadParliamentaryConstituencies();
  }, []);

  // Create a stable string representation of parliamentary constituency IDs for dependency comparison
  const parliamentaryConstituencyIdsKey = useMemo(() => {
    return JSON.stringify([...value.parliamentaryConstituencyIds].sort((a, b) => a - b));
  }, [value.parliamentaryConstituencyIds]);

  // Load assembly constituencies when parliamentary constituencies are selected
  useEffect(() => {
    // Cancel any in-flight request
    if (assemblyRequestAbortController.current) {
      assemblyRequestAbortController.current.abort();
      assemblyRequestAbortController.current = null;
    }

    const loadAssemblyConstituencies = async () => {
      const parliamentIds = JSON.parse(parliamentaryConstituencyIdsKey);
      
      if (parliamentIds.length === 0) {
        setAssemblyConstituencies([]);
        return;
      }
      
      // Mark request as in progress
      assemblyRequestInProgress.current = true;
      setLoadingAssembly(true);
      
      // Create abort controller for this request
      const abortController = new AbortController();
      assemblyRequestAbortController.current = abortController;
      
      try {
        // Fetch assembly constituencies for all selected parliamentary constituencies
        const allAssembly: AssemblyConstituency[] = [];
        for (const parliamentId of parliamentIds) {
          // Check if request was aborted
          if (abortController.signal.aborted) {
            return;
          }
          
          const assemblyForParliament = await constituencyService.getAssemblyConstituencies({
            parliamentary_constituency_id: parliamentId,
            state: 'Telangana',
            is_active: true,
          });
          allAssembly.push(...assemblyForParliament);
        }
        
        // Check if request was aborted before setting state
        if (abortController.signal.aborted) {
          return;
        }
        
        // Remove duplicates
        const uniqueAssembly = Array.from(
          new Map(allAssembly.map(a => [a.id || a.constituencyNumber, a])).values()
        );
        setAssemblyConstituencies(uniqueAssembly);
      } catch (error: any) {
        // Don't log error if request was aborted
        if (error.name !== 'AbortError' && !abortController.signal.aborted) {
          console.error('Failed to load assembly constituencies:', error);
        }
      } finally {
        if (!abortController.signal.aborted) {
          setLoadingAssembly(false);
        }
        assemblyRequestInProgress.current = false;
        if (assemblyRequestAbortController.current === abortController) {
          assemblyRequestAbortController.current = null;
        }
      }
    };
    
    loadAssemblyConstituencies();
    
    // Cleanup function to abort request if component unmounts or effect re-runs
    return () => {
      if (assemblyRequestAbortController.current) {
        assemblyRequestAbortController.current.abort();
        assemblyRequestAbortController.current = null;
      }
      assemblyRequestInProgress.current = false;
    };
  }, [parliamentaryConstituencyIdsKey]);

  const handlePostToAllToggle = (checked: boolean) => {
    if (checked) {
      onChange({
        districtIds: [],
        mandalIds: [],
        assemblyConstituencyIds: [],
        parliamentaryConstituencyIds: [],
        postToAll: true,
      });
    } else {
      onChange({
        ...value,
        postToAll: false,
      });
    }
  };

  const toggleDistrict = (districtId: number) => {
    if (value.postToAll) return;
    
    const newDistrictIds = value.districtIds.includes(districtId)
      ? value.districtIds.filter(id => id !== districtId)
      : [...value.districtIds, districtId];
    
    // If district is removed, remove mandals from that district
    const removedDistrictIds = value.districtIds.filter(id => !newDistrictIds.includes(id));
    let newMandalIds = value.mandalIds;
    if (removedDistrictIds.length > 0) {
      const mandalsToRemove = mandals
        .filter(m => removedDistrictIds.includes(m.districtId))
        .map(m => m.id);
      newMandalIds = value.mandalIds.filter(id => !mandalsToRemove.includes(id));
    }
    
    // Clear constituencies when selecting districts/mandals (mutually exclusive)
    onChange({
      ...value,
      districtIds: newDistrictIds,
      mandalIds: newMandalIds,
      assemblyConstituencyIds: [],
      parliamentaryConstituencyIds: [],
      postToAll: false,
    });
  };

  const toggleMandal = (mandalId: number) => {
    if (value.postToAll) return;
    
    const newMandalIds = value.mandalIds.includes(mandalId)
      ? value.mandalIds.filter(id => id !== mandalId)
      : [...value.mandalIds, mandalId];
    
    // Clear constituencies when selecting districts/mandals (mutually exclusive)
    onChange({
      ...value,
      mandalIds: newMandalIds,
      assemblyConstituencyIds: [],
      parliamentaryConstituencyIds: [],
      postToAll: false,
    });
  };

  const toggleParliamentaryConstituency = (constituencyId: number) => {
    if (value.postToAll) return;
    
    const newParliamentaryIds = value.parliamentaryConstituencyIds.includes(constituencyId)
      ? value.parliamentaryConstituencyIds.filter(id => id !== constituencyId)
      : [...value.parliamentaryConstituencyIds, constituencyId];
    
    // If parliamentary constituency is removed, remove assembly constituencies from that parliament
    const removedParliamentIds = value.parliamentaryConstituencyIds.filter(id => !newParliamentaryIds.includes(id));
    let newAssemblyIds = value.assemblyConstituencyIds;
    if (removedParliamentIds.length > 0) {
      const assemblyToRemove = assemblyConstituencies
        .filter(a => removedParliamentIds.includes(a.parliament_constituency_id || 0))
        .map(a => a.id || a.constituencyNumber);
      newAssemblyIds = value.assemblyConstituencyIds.filter(id => !assemblyToRemove.includes(id));
    }
    
    // Clear districts/mandals when selecting constituencies (mutually exclusive)
    onChange({
      ...value,
      parliamentaryConstituencyIds: newParliamentaryIds,
      assemblyConstituencyIds: newAssemblyIds,
      districtIds: [],
      mandalIds: [],
      postToAll: false,
    });
  };

  const toggleAssemblyConstituency = (constituencyId: number) => {
    if (value.postToAll) return;
    
    const newAssemblyIds = value.assemblyConstituencyIds.includes(constituencyId)
      ? value.assemblyConstituencyIds.filter(id => id !== constituencyId)
      : [...value.assemblyConstituencyIds, constituencyId];
    
    // Clear districts/mandals when selecting constituencies (mutually exclusive)
    onChange({
      ...value,
      assemblyConstituencyIds: newAssemblyIds,
      districtIds: [],
      mandalIds: [],
      postToAll: false,
    });
  };

  const getSelectedDistrictNames = () => {
    return districts
      .filter(d => value.districtIds.includes(d.id))
      .map(d => d.name_en)
      .join(', ');
  };

  const getSelectedMandalNames = () => {
    return mandals
      .filter(m => value.mandalIds.includes(m.id))
      .map(m => m.name_en)
      .join(', ');
  };

  const getSelectedParliamentaryNames = () => {
    return parliamentaryConstituencies
      .filter(p => value.parliamentaryConstituencyIds.includes(p.id))
      .map(p => p.name_en)
      .join(', ');
  };

  const getSelectedAssemblyNames = () => {
    return assemblyConstituencies
      .filter(a => value.assemblyConstituencyIds.includes(a.id || a.constituencyNumber))
      .map(a => a.name_en)
      .join(', ');
  };

  return (
    <div className="space-y-4">
      {/* Post to All Toggle */}
      <div className="flex items-center space-x-2">
        <input
          type="checkbox"
          id="postToAll"
          checked={value.postToAll}
          onChange={(e) => handlePostToAllToggle(e.target.checked)}
          disabled={disabled}
          className="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
        />
        <label htmlFor="postToAll" className="text-sm font-medium text-gray-700">
          Post to All (Visible to everyone)
        </label>
      </div>

      {!value.postToAll && (
        <div className="space-y-6">
          {/* Districts/Mandals Group */}
          <div className="border border-gray-200 rounded-lg p-4 bg-gray-50">
            <div className="mb-3">
              <h4 className="text-sm font-semibold text-gray-900">Districts & Mandals</h4>
              <p className="text-xs text-gray-500 mt-1">Select districts and/or mandals (mutually exclusive with constituencies)</p>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {/* Districts Multi-Select */}
              <div className="relative" ref={districtRef}>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Districts
            </label>
            <div className="relative">
              <button
                type="button"
                onClick={() => setDistrictDropdownOpen(!districtDropdownOpen)}
                disabled={disabled || loadingDistricts}
                className="w-full px-3 py-2 text-left bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 disabled:bg-gray-100 disabled:cursor-not-allowed flex items-center justify-between"
              >
                <span className="truncate">
                  {value.districtIds.length === 0
                    ? 'Select districts...'
                    : `${value.districtIds.length} selected: ${getSelectedDistrictNames()}`}
                </span>
                <ChevronDown className="w-4 h-4 text-gray-400" />
              </button>
              
              {districtDropdownOpen && !disabled && (
                <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg max-h-60 overflow-auto">
                  {loadingDistricts ? (
                    <div className="px-3 py-2 text-sm text-gray-500">Loading...</div>
                  ) : districts.length === 0 ? (
                    <div className="px-3 py-2 text-sm text-gray-500">No districts available</div>
                  ) : (
                    districts.map((district) => (
                      <div
                        key={district.id}
                        onClick={() => toggleDistrict(district.id)}
                        className="px-3 py-2 hover:bg-gray-100 cursor-pointer flex items-center space-x-2"
                      >
                        <div className={`w-4 h-4 border-2 rounded flex items-center justify-center ${
                          value.districtIds.includes(district.id)
                            ? 'bg-blue-600 border-blue-600'
                            : 'border-gray-300'
                        }`}>
                          {value.districtIds.includes(district.id) && (
                            <Check className="w-3 h-3 text-white" />
                          )}
                        </div>
                        <span className="text-sm">{district.name_en}</span>
                      </div>
                    ))
                  )}
                </div>
              )}
            </div>
          </div>

          {/* Mandals Multi-Select */}
          <div className="relative" ref={mandalRef}>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Mandals
            </label>
            <div className="relative">
              <button
                type="button"
                onClick={() => setMandalDropdownOpen(!mandalDropdownOpen)}
                disabled={disabled || loadingMandals || value.districtIds.length === 0}
                className="w-full px-3 py-2 text-left bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 disabled:bg-gray-100 disabled:cursor-not-allowed flex items-center justify-between"
              >
                <span className="truncate">
                  {value.districtIds.length === 0
                    ? 'Select districts first...'
                    : value.mandalIds.length === 0
                    ? 'Select mandals...'
                    : `${value.mandalIds.length} selected: ${getSelectedMandalNames()}`}
                </span>
                <ChevronDown className="w-4 h-4 text-gray-400" />
              </button>
              
              {mandalDropdownOpen && !disabled && value.districtIds.length > 0 && (
                <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg max-h-60 overflow-auto">
                  {loadingMandals ? (
                    <div className="px-3 py-2 text-sm text-gray-500">Loading...</div>
                  ) : mandals.length === 0 ? (
                    <div className="px-3 py-2 text-sm text-gray-500">No mandals available</div>
                  ) : (
                    mandals.map((mandal) => (
                      <div
                        key={mandal.id}
                        onClick={() => toggleMandal(mandal.id)}
                        className="px-3 py-2 hover:bg-gray-100 cursor-pointer flex items-center space-x-2"
                      >
                        <div className={`w-4 h-4 border-2 rounded flex items-center justify-center ${
                          value.mandalIds.includes(mandal.id)
                            ? 'bg-blue-600 border-blue-600'
                            : 'border-gray-300'
                        }`}>
                          {value.mandalIds.includes(mandal.id) && (
                            <Check className="w-3 h-3 text-white" />
                          )}
                        </div>
                        <span className="text-sm">{mandal.name_en}</span>
                      </div>
                    ))
                  )}
                </div>
              )}
            </div>
          </div>
            </div>
          </div>

          {/* Constituencies Group */}
          <div className="border border-gray-200 rounded-lg p-4 bg-gray-50">
            <div className="mb-3">
              <h4 className="text-sm font-semibold text-gray-900">Constituencies</h4>
              <p className="text-xs text-gray-500 mt-1">Select parliamentary and/or assembly constituencies (mutually exclusive with districts/mandals)</p>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {/* Parliamentary Constituencies Multi-Select */}
              <div className="relative" ref={parliamentaryRef}>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Parliamentary Constituencies
            </label>
            <div className="relative">
              <button
                type="button"
                onClick={() => setParliamentaryDropdownOpen(!parliamentaryDropdownOpen)}
                disabled={disabled || loadingParliamentary}
                className="w-full px-3 py-2 text-left bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 disabled:bg-gray-100 disabled:cursor-not-allowed flex items-center justify-between"
              >
                <span className="truncate">
                  {value.parliamentaryConstituencyIds.length === 0
                    ? 'Select parliamentary constituencies...'
                    : `${value.parliamentaryConstituencyIds.length} selected: ${getSelectedParliamentaryNames()}`}
                </span>
                <ChevronDown className="w-4 h-4 text-gray-400" />
              </button>
              
              {parliamentaryDropdownOpen && !disabled && (
                <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg max-h-60 overflow-auto">
                  {loadingParliamentary ? (
                    <div className="px-3 py-2 text-sm text-gray-500">Loading...</div>
                  ) : parliamentaryConstituencies.length === 0 ? (
                    <div className="px-3 py-2 text-sm text-gray-500">No parliamentary constituencies available</div>
                  ) : (
                    parliamentaryConstituencies.map((constituency) => (
                      <div
                        key={constituency.id}
                        onClick={() => toggleParliamentaryConstituency(constituency.id)}
                        className="px-3 py-2 hover:bg-gray-100 cursor-pointer flex items-center space-x-2"
                      >
                        <div className={`w-4 h-4 border-2 rounded flex items-center justify-center ${
                          value.parliamentaryConstituencyIds.includes(constituency.id)
                            ? 'bg-blue-600 border-blue-600'
                            : 'border-gray-300'
                        }`}>
                          {value.parliamentaryConstituencyIds.includes(constituency.id) && (
                            <Check className="w-3 h-3 text-white" />
                          )}
                        </div>
                        <span className="text-sm">{constituency.name_en}</span>
                      </div>
                    ))
                  )}
                </div>
              )}
            </div>
          </div>

          {/* Assembly Constituencies Multi-Select */}
          <div className="relative" ref={assemblyRef}>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Assembly Constituencies
            </label>
            <div className="relative">
              <button
                type="button"
                onClick={() => setAssemblyDropdownOpen(!assemblyDropdownOpen)}
                disabled={disabled || loadingAssembly || value.parliamentaryConstituencyIds.length === 0}
                className="w-full px-3 py-2 text-left bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 disabled:bg-gray-100 disabled:cursor-not-allowed flex items-center justify-between"
              >
                <span className="truncate">
                  {value.parliamentaryConstituencyIds.length === 0
                    ? 'Select parliamentary constituencies first...'
                    : value.assemblyConstituencyIds.length === 0
                    ? 'Select assembly constituencies...'
                    : `${value.assemblyConstituencyIds.length} selected: ${getSelectedAssemblyNames()}`}
                </span>
                <ChevronDown className="w-4 h-4 text-gray-400" />
              </button>
              
              {assemblyDropdownOpen && !disabled && value.parliamentaryConstituencyIds.length > 0 && (
                <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg max-h-60 overflow-auto">
                  {loadingAssembly ? (
                    <div className="px-3 py-2 text-sm text-gray-500">Loading...</div>
                  ) : assemblyConstituencies.length === 0 ? (
                    <div className="px-3 py-2 text-sm text-gray-500">No assembly constituencies available</div>
                  ) : (
                    assemblyConstituencies.map((constituency) => {
                      const id = constituency.id || constituency.constituencyNumber;
                      return (
                        <div
                          key={id}
                          onClick={() => toggleAssemblyConstituency(id)}
                          className="px-3 py-2 hover:bg-gray-100 cursor-pointer flex items-center space-x-2"
                        >
                          <div className={`w-4 h-4 border-2 rounded flex items-center justify-center ${
                            value.assemblyConstituencyIds.includes(id)
                              ? 'bg-blue-600 border-blue-600'
                              : 'border-gray-300'
                          }`}>
                            {value.assemblyConstituencyIds.includes(id) && (
                              <Check className="w-3 h-3 text-white" />
                            )}
                          </div>
                          <span className="text-sm">{constituency.name_en}</span>
                        </div>
                      );
                    })
                  )}
                </div>
              )}
            </div>
          </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

