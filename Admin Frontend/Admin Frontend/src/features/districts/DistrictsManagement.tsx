import { useState, useEffect, useRef } from "react";
import { Search, Edit2, Save, X, CheckCircle2, ChevronDown, ChevronRight, Plus } from "lucide-react";
import clsx from "clsx";
import { districtsService } from "../../services/districtsService";
import type { District, DistrictUpdateData, DistrictCreateData, Mandal, MandalCreateData, MandalUpdateData } from "../../services/districtsService";
import { translationService } from "../../services/translationService";

export default function DistrictsManagement() {
  const [districts, setDistricts] = useState<District[]>([]);
  const [loading, setLoading] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [editingId, setEditingId] = useState<number | null>(null);
  const [editData, setEditData] = useState<DistrictUpdateData>({});
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  // New state for expansion
  const [expandedRows, setExpandedRows] = useState<Set<number>>(new Set());
  const [mandalsData, setMandalsData] = useState<Record<number, Mandal[]>>({});
  const [loadingMandals, setLoadingMandals] = useState<Set<number>>(new Set());

  // State for adding new items
  const [showAddDistrict, setShowAddDistrict] = useState(false);
  const [addingDistrict, setAddingDistrict] = useState(false);
  const [newDistrict, setNewDistrict] = useState<DistrictCreateData>({
    name_en: '',
    name_te: '',
    state: 'Telangana',
    description: '',
    isActive: true,
  });

  const [addingMandalForDistrict, setAddingMandalForDistrict] = useState<number | null>(null);
  const [newMandal, setNewMandal] = useState<MandalCreateData>({
    name_en: '',
    name_te: '',
    description: '',
    isActive: true,
  });

  // State for editing mandals
  const [editingMandalId, setEditingMandalId] = useState<number | null>(null);
  const [editingMandalDistrictId, setEditingMandalDistrictId] = useState<number | null>(null);
  const [editMandalData, setEditMandalData] = useState<MandalUpdateData>({});
  const [savingMandal, setSavingMandal] = useState(false);

  // Track if Telugu fields were manually edited
  const districtNameTeManualEdit = useRef(false);
  const editDistrictNameTeManualEdit = useRef(false);
  const mandalNameTeManualEdit = useRef(false);
  const editMandalNameTeManualEdit = useRef(false);

  useEffect(() => {
    fetchDistricts();
  }, []);

  // Auto-translate District Name English to Telugu (add form)
  useEffect(() => {
    if (!newDistrict.name_en || districtNameTeManualEdit.current) {
      return;
    }
    
    const debouncedTranslate = translationService.createDebouncedTranslator(800);
    const currentNameEn = newDistrict.name_en;
    
    debouncedTranslate(currentNameEn, (translated) => {
      if (!districtNameTeManualEdit.current) {
        setNewDistrict((prev) => {
          // Only update if English hasn't changed since translation started
          if (prev.name_en === currentNameEn) {
            return { ...prev, name_te: translated };
          }
          return prev;
        });
      }
    });
  }, [newDistrict.name_en]);

  // Auto-translate District Name English to Telugu (edit form)
  useEffect(() => {
    if (!editData.name_en || editDistrictNameTeManualEdit.current || editingId === null) {
      return;
    }
    
    const debouncedTranslate = translationService.createDebouncedTranslator(800);
    const currentNameEn = editData.name_en;
    
    debouncedTranslate(currentNameEn, (translated) => {
      if (!editDistrictNameTeManualEdit.current && editingId !== null) {
        setEditData((prev) => {
          // Only update if English hasn't changed since translation started
          if (prev.name_en === currentNameEn) {
            return { ...prev, name_te: translated };
          }
          return prev;
        });
      }
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [editData.name_en, editingId]);

  // Auto-translate Mandal Name English to Telugu (add form)
  useEffect(() => {
    if (!newMandal.name_en || mandalNameTeManualEdit.current) {
      return;
    }
    
    const debouncedTranslate = translationService.createDebouncedTranslator(800);
    const currentNameEn = newMandal.name_en;
    
    debouncedTranslate(currentNameEn, (translated) => {
      if (!mandalNameTeManualEdit.current) {
        setNewMandal((prev) => {
          // Only update if English hasn't changed since translation started
          if (prev.name_en === currentNameEn) {
            return { ...prev, name_te: translated };
          }
          return prev;
        });
      }
    });
  }, [newMandal.name_en]);

  // Auto-translate Mandal Name English to Telugu (edit form)
  useEffect(() => {
    if (!editMandalData.name_en || editMandalNameTeManualEdit.current || editingMandalId === null) {
      return;
    }
    
    const debouncedTranslate = translationService.createDebouncedTranslator(800);
    const currentNameEn = editMandalData.name_en;
    
    debouncedTranslate(currentNameEn, (translated) => {
      if (!editMandalNameTeManualEdit.current && editingMandalId !== null) {
        setEditMandalData((prev) => {
          // Only update if English hasn't changed since translation started
          if (prev.name_en === currentNameEn) {
            return { ...prev, name_te: translated };
          }
          return prev;
        });
      }
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [editMandalData.name_en, editingMandalId]);

  const fetchDistricts = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await districtsService.getDistricts({
        state: 'Telangana',
        is_active: undefined, // Get all
      });
      setDistricts(data);
    } catch (err: any) {
      setError(err.response?.data?.message || 'Failed to fetch districts');
      console.error('Failed to fetch districts:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = (district: District) => {
    setEditingId(district.id);
    setEditData({
      name_en: district.name_en,
      name_te: district.name_te || district.name_en,
      state: district.state,
      description: district.description || '',
      isActive: district.isActive,
    });
    setError(null);
    setSuccess(null);
    editDistrictNameTeManualEdit.current = false; // Reset manual edit flag when opening edit
  };

  const handleCancel = () => {
    setEditingId(null);
    setEditData({});
    setError(null);
    setSuccess(null);
    editDistrictNameTeManualEdit.current = false; // Reset manual edit flag
  };

  const handleSave = async (id: number) => {
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const updated = await districtsService.updateDistrict(id, editData);
      setDistricts(districts.map(d => d.id === id ? updated : d));
      setEditingId(null);
      setEditData({});
      setSuccess('District updated successfully');
      setTimeout(() => setSuccess(null), 3000);
    } catch (err: any) {
      setError(err.response?.data?.message || 'Failed to update district');
      console.error('Failed to update district:', err);
    } finally {
      setSaving(false);
    }
  };

  const toggleExpand = async (id: number) => {
    const newExpanded = new Set(expandedRows);
    if (newExpanded.has(id)) {
      newExpanded.delete(id);
      setExpandedRows(newExpanded);
    } else {
      newExpanded.add(id);
      setExpandedRows(newExpanded);
      
      // Fetch data if not present
      if (!mandalsData[id]) {
        setLoadingMandals(prev => new Set(prev).add(id));
        try {
            const data = await districtsService.getMandalsForDistrict(id);
            setMandalsData(prev => ({ ...prev, [id]: data }));
        } catch (err) {
            console.error("Failed to fetch mandals", err);
            // Optionally set error state specific to this expansion
        } finally {
            setLoadingMandals(prev => {
                const next = new Set(prev);
                next.delete(id);
                return next;
            });
        }
      }
    }
  };

  const handleAddDistrict = async () => {
    if (!newDistrict.name_en.trim()) {
      setError('District name (English) is required');
      return;
    }

    setAddingDistrict(true);
    setError(null);
    setSuccess(null);
    try {
      const created = await districtsService.createDistrict(newDistrict);
      setDistricts([...districts, created].sort((a, b) => a.name_en.localeCompare(b.name_en)));
      setNewDistrict({
        name_en: '',
        name_te: '',
        state: 'Telangana',
        description: '',
        isActive: true,
      });
      setShowAddDistrict(false);
      districtNameTeManualEdit.current = false; // Reset manual edit flag
      setSuccess('District created successfully');
      setTimeout(() => setSuccess(null), 3000);
    } catch (err: any) {
      setError(err.response?.data?.message || 'Failed to create district');
      console.error('Failed to create district:', err);
    } finally {
      setAddingDistrict(false);
    }
  };

  const handleAddMandal = async (districtId: number) => {
    if (!newMandal.name_en.trim()) {
      setError('Mandal name (English) is required');
      return;
    }

    setAddingMandalForDistrict(districtId);
    setError(null);
    setSuccess(null);
    try {
      const created = await districtsService.createMandal(districtId, newMandal);
      // Update mandals data for this district
      const currentMandals = mandalsData[districtId] || [];
      setMandalsData({
        ...mandalsData,
        [districtId]: [...currentMandals, created].sort((a, b) => a.name_en.localeCompare(b.name_en)),
      });
      setNewMandal({
        name_en: '',
        name_te: '',
        description: '',
        isActive: true,
      });
      mandalNameTeManualEdit.current = false; // Reset manual edit flag
      setSuccess('Mandal created successfully');
      setTimeout(() => setSuccess(null), 3000);
    } catch (err: any) {
      setError(err.response?.data?.message || 'Failed to create mandal');
      console.error('Failed to create mandal:', err);
    } finally {
      setAddingMandalForDistrict(null);
    }
  };

  const handleEditMandal = (mandal: Mandal, districtId: number) => {
    setEditingMandalId(mandal.id);
    setEditingMandalDistrictId(districtId);
    setEditMandalData({
      name_en: mandal.name_en,
      name_te: mandal.name_te || mandal.name_en,
      description: mandal.description || '',
      isActive: mandal.isActive,
    });
    setError(null);
    setSuccess(null);
    editMandalNameTeManualEdit.current = false; // Reset manual edit flag
  };

  const handleCancelMandalEdit = () => {
    setEditingMandalId(null);
    setEditingMandalDistrictId(null);
    setEditMandalData({});
    setError(null);
    setSuccess(null);
    editMandalNameTeManualEdit.current = false; // Reset manual edit flag
  };

  const handleSaveMandal = async () => {
    if (!editingMandalId || editingMandalDistrictId === null) return;

    setSavingMandal(true);
    setError(null);
    setSuccess(null);
    try {
      const updated = await districtsService.updateMandal(editingMandalId, editMandalData);
      // Update mandals data for this district
      const currentMandals = mandalsData[editingMandalDistrictId] || [];
      setMandalsData({
        ...mandalsData,
        [editingMandalDistrictId]: currentMandals.map(m => m.id === editingMandalId ? updated : m).sort((a, b) => a.name_en.localeCompare(b.name_en)),
      });
      setEditingMandalId(null);
      setEditingMandalDistrictId(null);
      setEditMandalData({});
      setSuccess('Mandal updated successfully');
      setTimeout(() => setSuccess(null), 3000);
    } catch (err: any) {
      setError(err.response?.data?.message || 'Failed to update mandal');
      console.error('Failed to update mandal:', err);
    } finally {
      setSavingMandal(false);
    }
  };

  const filteredDistricts = districts.filter(d => {
    if (!searchQuery) return true;
    const query = searchQuery.toLowerCase();
    return (
      d.name_en.toLowerCase().includes(query) ||
      (d.name_te && d.name_te.toLowerCase().includes(query)) ||
      d.id.toString().includes(query)
    );
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Districts & Mandals Management</h1>
          <p className="text-sm text-gray-600 mt-1">Manage districts and view mandals</p>
        </div>
      </div>

      {/* Search */}
      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
        <input
          type="text"
          placeholder="Search districts..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
        />
      </div>

      {/* Messages */}
      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg">
          {error}
        </div>
      )}
      {success && (
        <div className="bg-green-50 border border-green-200 text-green-700 px-4 py-3 rounded-lg">
          {success}
        </div>
      )}

      {/* Table */}
      <div className="bg-white rounded-lg shadow-card overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="text-gray-500">Loading districts...</div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full">
              <thead className="bg-gray-50">
                <tr className="text-left text-sm text-gray-600">
                  <th className="w-10 px-4 py-3"></th> {/* Expand toggle column */}
                  <th className="px-4 py-3 font-medium">ID</th>
                  <th className="px-4 py-3 font-medium">Name (English)</th>
                  <th className="px-4 py-3 font-medium">Name (Telugu)</th>
                  <th className="px-4 py-3 font-medium">State</th>
                  <th className="px-4 py-3 font-medium">Status</th>
                  <th className="px-4 py-3 font-medium">Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredDistricts.map((district) => (
                  <>
                  <tr key={district.id} className={clsx("border-t", expandedRows.has(district.id) ? "bg-gray-50" : "")}>
                     {/* Expand Toggle */}
                     <td className="px-4 py-3">
                        <button 
                            onClick={() => toggleExpand(district.id)}
                            className="text-gray-400 hover:text-gray-600 p-1"
                            title={expandedRows.has(district.id) ? "Collapse" : "Expand"}
                        >
                            {expandedRows.has(district.id) ? <ChevronDown className="w-5 h-5" /> : <ChevronRight className="w-5 h-5" />}
                        </button>
                     </td>

                    {editingId === district.id ? (
                      <>
                        <td className="px-4 py-3">
                          <div className="font-medium text-gray-900">{district.id}</div>
                        </td>
                        <td className="px-4 py-3">
                          <input
                            type="text"
                            value={editData.name_en || ''}
                            onChange={(e) => setEditData({ ...editData, name_en: e.target.value })}
                            className="w-full px-3 py-1 border border-gray-300 rounded focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                          />
                        </td>
                        <td className="px-4 py-3">
                          <input
                            type="text"
                            value={editData.name_te || ''}
                            onChange={(e) => {
                              setEditData({ ...editData, name_te: e.target.value });
                              editDistrictNameTeManualEdit.current = true;
                            }}
                            className="w-full px-3 py-1 border border-gray-300 rounded focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                            placeholder="Auto-translated"
                          />
                        </td>
                        <td className="px-4 py-3">
                          <input
                            type="text"
                            value={editData.state || ''}
                            onChange={(e) => setEditData({ ...editData, state: e.target.value })}
                            className="w-full px-3 py-1 border border-gray-300 rounded focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                          />
                        </td>
                        <td className="px-4 py-3">
                          <select
                            value={editData.isActive ? 'true' : 'false'}
                            onChange={(e) => setEditData({ ...editData, isActive: e.target.value === 'true' })}
                            className="px-3 py-1 border border-gray-300 rounded focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                          >
                            <option value="true">Active</option>
                            <option value="false">Inactive</option>
                          </select>
                        </td>
                        <td className="px-4 py-3">
                          <div className="flex items-center gap-2">
                            <button
                              onClick={() => handleSave(district.id)}
                              disabled={saving}
                              className="p-2 text-green-600 hover:bg-green-50 rounded-md transition disabled:opacity-50"
                              title="Save"
                            >
                              <Save className="w-4 h-4" />
                            </button>
                            <button
                              onClick={handleCancel}
                              disabled={saving}
                              className="p-2 text-red-600 hover:bg-red-50 rounded-md transition disabled:opacity-50"
                              title="Cancel"
                            >
                              <X className="w-4 h-4" />
                            </button>
                          </div>
                        </td>
                      </>
                    ) : (
                      <>
                        <td className="px-4 py-3">
                          <div className="font-medium text-gray-900">{district.id}</div>
                        </td>
                        <td className="px-4 py-3 text-gray-700">{district.name_en}</td>
                        <td className="px-4 py-3 text-gray-700">{district.name_te || district.name_en}</td>
                        <td className="px-4 py-3 text-gray-700">{district.state}</td>
                        <td className="px-4 py-3">
                          <span
                            className={clsx(
                              "px-3 py-1 rounded-full text-xs font-medium inline-flex items-center gap-1",
                              district.isActive
                                ? "bg-green-50 text-green-700 border border-green-200"
                                : "bg-gray-50 text-gray-700 border"
                            )}
                          >
                            <CheckCircle2 className="w-3 h-3" />
                            {district.isActive ? "Active" : "Inactive"}
                          </span>
                        </td>
                        <td className="px-4 py-3">
                          <button
                            onClick={() => handleEdit(district)}
                            className="p-2 text-blue-600 hover:bg-blue-50 rounded-md transition"
                            title="Edit"
                          >
                            <Edit2 className="w-4 h-4" />
                          </button>
                        </td>
                      </>
                    )}
                  </tr>
                  {expandedRows.has(district.id) && (
                      <tr key={`expanded-${district.id}`} className="bg-gray-50 border-b">
                          <td colSpan={7} className="px-4 py-4 pl-12">
                            {loadingMandals.has(district.id) ? (
                                <div className="flex items-center justify-center py-4">
                                    <div className="text-sm text-gray-500 animate-pulse">Loading mandals...</div>
                                </div>
                            ) : (
                                <div>
                                    <div className="flex items-center justify-between mb-3">
                                        <h4 className="text-sm font-semibold text-gray-900 flex items-center gap-2">
                                            <div className="w-2 h-2 bg-orange-500 rounded-full"></div>
                                            Mandals
                                        </h4>
                                    </div>
                                    {mandalsData[district.id]?.length > 0 ? (
                                        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 mb-4">
                                            {mandalsData[district.id].map((mandal: Mandal) => (
                                                <div key={mandal.id} className="bg-white p-3 rounded-lg border border-gray-200 shadow-sm hover:shadow-md transition-shadow">
                                                    {editingMandalId === mandal.id && editingMandalDistrictId === district.id ? (
                                                        <div className="space-y-2">
                                                            <div>
                                                                <label className="block text-xs font-medium text-gray-700 mb-1">Name (English) *</label>
                                                                <input
                                                                    type="text"
                                                                    value={editMandalData.name_en || ''}
                                                                    onChange={(e) => setEditMandalData({ ...editMandalData, name_en: e.target.value })}
                                                                    className="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                                                                />
                                                            </div>
                                                            <div>
                                                                <label className="block text-xs font-medium text-gray-700 mb-1">Name (Telugu)</label>
                                                                <input
                                                                    type="text"
                                                                    value={editMandalData.name_te || ''}
                                                                    onChange={(e) => {
                                                                      setEditMandalData({ ...editMandalData, name_te: e.target.value });
                                                                      editMandalNameTeManualEdit.current = true;
                                                                    }}
                                                                    className="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                                                                    placeholder="Auto-translated"
                                                                />
                                                            </div>
                                                            <div className="flex items-center gap-2">
                                                                <button
                                                                    onClick={handleSaveMandal}
                                                                    disabled={savingMandal}
                                                                    className="flex-1 px-2 py-1 text-xs bg-green-600 text-white rounded hover:bg-green-700 transition disabled:opacity-50"
                                                                >
                                                                    <Save className="w-3 h-3 inline" />
                                                                </button>
                                                                <button
                                                                    onClick={handleCancelMandalEdit}
                                                                    disabled={savingMandal}
                                                                    className="flex-1 px-2 py-1 text-xs bg-red-600 text-white rounded hover:bg-red-700 transition disabled:opacity-50"
                                                                >
                                                                    <X className="w-3 h-3 inline" />
                                                                </button>
                                                            </div>
                                                        </div>
                                                    ) : (
                                                        <div className="flex justify-between items-start gap-2">
                                                            <div className="min-w-0 flex-1">
                                                                <div className="font-medium text-gray-900 truncate" title={typeof mandal.name === 'object' ? mandal.name?.en : mandal.name_en}>
                                                                    {typeof mandal.name === 'object' ? mandal.name?.en : mandal.name_en}
                                                                </div>
                                                                {(mandal.name_te || mandal.name?.te) && (
                                                                    <div className="text-xs text-gray-500 truncate" title={mandal.name_te || mandal.name?.te}>
                                                                        {mandal.name_te || mandal.name?.te}
                                                                    </div>
                                                                )}
                                                            </div>
                                                            <div className="flex items-center gap-1">
                                                                <div className="flex-shrink-0 text-xs font-mono bg-gray-100 px-2 py-1 rounded text-gray-600 border border-gray-200">
                                                                    {mandal.id}
                                                                </div>
                                                                <button
                                                                    onClick={() => handleEditMandal(mandal, district.id)}
                                                                    className="p-1 text-blue-600 hover:bg-blue-50 rounded transition"
                                                                    title="Edit"
                                                                >
                                                                    <Edit2 className="w-3 h-3" />
                                                                </button>
                                                            </div>
                                                        </div>
                                                    )}
                                                </div>
                                            ))}
                                        </div>
                                    ) : (
                                        <div className="text-sm text-gray-500 italic py-2 pl-2 border-l-2 border-gray-300 mb-4">No mandals found.</div>
                                    )}
                                    
                                    {/* Add Mandal Form */}
                                    <div className="bg-white p-4 rounded-lg border border-gray-200 shadow-sm">
                                        <h5 className="text-sm font-medium text-gray-900 mb-3 flex items-center gap-2">
                                            <Plus className="w-4 h-4" />
                                            Add New Mandal
                                        </h5>
                                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                                            <div>
                                                <label className="block text-xs font-medium text-gray-700 mb-1">Name (English) *</label>
                                                <input
                                                    type="text"
                                                    value={newMandal.name_en}
                                                    onChange={(e) => setNewMandal({ ...newMandal, name_en: e.target.value })}
                                                    className="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                                                    placeholder="Enter mandal name"
                                                />
                                            </div>
                                            <div>
                                                <label className="block text-xs font-medium text-gray-700 mb-1">Name (Telugu)</label>
                                                <input
                                                    type="text"
                                                    value={newMandal.name_te}
                                                    onChange={(e) => {
                                                      setNewMandal({ ...newMandal, name_te: e.target.value });
                                                      mandalNameTeManualEdit.current = true;
                                                    }}
                                                    className="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                                                    placeholder="Enter Telugu name (Auto-translated)"
                                                />
                                            </div>
                                        </div>
                                        <div className="mt-3 flex items-center gap-3">
                                            <button
                                                onClick={() => handleAddMandal(district.id)}
                                                disabled={addingMandalForDistrict === district.id || !newMandal.name_en.trim()}
                                                className="px-4 py-2 bg-orange-500 text-white text-sm font-medium rounded-md hover:bg-orange-600 transition disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                                            >
                                                {addingMandalForDistrict === district.id ? (
                                                    <>Adding...</>
                                                ) : (
                                                    <>
                                                        <Plus className="w-4 h-4" />
                                                        Add Mandal
                                                    </>
                                                )}
                                            </button>
                                            {newMandal.name_en && (
                                                <button
                                                    onClick={() => {
                                                      setNewMandal({ name_en: '', name_te: '', description: '', isActive: true });
                                                      mandalNameTeManualEdit.current = false; // Reset manual edit flag
                                                    }}
                                                    className="px-4 py-2 text-sm text-gray-600 hover:text-gray-800"
                                                >
                                                    Clear
                                                </button>
                                            )}
                                        </div>
                                    </div>
                                </div>
                            )}
                          </td>
                      </tr>
                  )}
                  </>
                ))}
                {filteredDistricts.length === 0 && (
                  <tr>
                    <td className="px-4 py-6 text-center text-gray-500" colSpan={7}>
                      {searchQuery ? 'No districts match your search.' : 'No districts found.'}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Summary */}
      <div className="text-sm text-gray-600">
        Showing {filteredDistricts.length} of {districts.length} districts
      </div>

      {/* Add District Form */}
      <div className="bg-white rounded-lg shadow-card p-6 border-t-4 border-orange-500">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
            <Plus className="w-5 h-5" />
            Add New District
          </h2>
          {!showAddDistrict && (
            <button
              onClick={() => setShowAddDistrict(true)}
              className="px-4 py-2 bg-orange-500 text-white text-sm font-medium rounded-md hover:bg-orange-600 transition flex items-center gap-2"
            >
              <Plus className="w-4 h-4" />
              Add District
            </button>
          )}
        </div>

        {showAddDistrict && (
          <div className="space-y-4">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Name (English) *</label>
                <input
                  type="text"
                  value={newDistrict.name_en}
                  onChange={(e) => setNewDistrict({ ...newDistrict, name_en: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                  placeholder="Enter district name"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Name (Telugu)</label>
                <input
                  type="text"
                  value={newDistrict.name_te}
                  onChange={(e) => {
                    setNewDistrict({ ...newDistrict, name_te: e.target.value });
                    districtNameTeManualEdit.current = true;
                  }}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                  placeholder="Enter Telugu name (Auto-translated)"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">State</label>
                <input
                  type="text"
                  value={newDistrict.state}
                  onChange={(e) => setNewDistrict({ ...newDistrict, state: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                  placeholder="Enter state"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Status</label>
                <select
                  value={newDistrict.isActive ? 'true' : 'false'}
                  onChange={(e) => setNewDistrict({ ...newDistrict, isActive: e.target.value === 'true' })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                >
                  <option value="true">Active</option>
                  <option value="false">Inactive</option>
                </select>
              </div>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
              <textarea
                value={newDistrict.description}
                onChange={(e) => setNewDistrict({ ...newDistrict, description: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                placeholder="Enter description (optional)"
                rows={2}
              />
            </div>
            <div className="flex items-center gap-3">
              <button
                onClick={handleAddDistrict}
                disabled={addingDistrict || !newDistrict.name_en.trim()}
                className="px-6 py-2 bg-orange-500 text-white font-medium rounded-md hover:bg-orange-600 transition disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
              >
                {addingDistrict ? (
                  <>Creating...</>
                ) : (
                  <>
                    <Plus className="w-4 h-4" />
                    Create District
                  </>
                )}
              </button>
              <button
                onClick={() => {
                  setShowAddDistrict(false);
                  setNewDistrict({
                    name_en: '',
                    name_te: '',
                    state: 'Telangana',
                    description: '',
                    isActive: true,
                  });
                  districtNameTeManualEdit.current = false; // Reset manual edit flag
                }}
                className="px-6 py-2 border border-gray-300 text-gray-700 font-medium rounded-md hover:bg-gray-50 transition"
              >
                Cancel
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

