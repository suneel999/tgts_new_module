import { useMemo, useState, useEffect } from "react";
import {
  Search,
  ChevronDown,
  CheckCircle2,
  Clock,
  XCircle,
  Eye,
  Edit2,
  X,
  Save,
  ThumbsUp,
  ThumbsDown,
} from "lucide-react";
import clsx from "clsx";
import { memberService } from "../../services/memberService";
import { constituencyService } from "../../services/constituencyService";
import { districtsService } from "../../services/districtsService";
import type { Member, MemberUpdateData, CadreLevel } from "../../services/memberService";
import type { ParliamentaryConstituency } from "../../services/constituencyService";
import type { District, Mandal } from "../../services/districtsService";

type UserRow = {
  id: string;
  epicNumber?: string;
  name: string;
  email: string;
  contact: string;
  region: string;
  constituency?: string;
  role: "CADRE" | "PUBLIC" | "ADMIN";
  date: string;
  status: "pending" | "approved" | "rejected";
  memberData: Member;
};

const statusOptions = ["All Status", "approved", "pending", "rejected"] as const;

function RolePill({ role }: { role: UserRow["role"] }) {
  const classes = {
    CADRE: "bg-green-100 text-green-700 border border-green-200",
    ADMIN: "bg-orange-100 text-orange-700 border border-orange-200",
    PUBLIC: "bg-white text-gray-700 border border-gray-300",
  }[role];
  return <span className={clsx("px-3 py-1 rounded-full text-xs font-semibold", classes)}>{role}</span>;
}

function StatusPill({ status }: { status: UserRow["status"] }) {
  const config = {
    approved: {
      classes: "bg-green-50 text-green-700 border border-green-200",
      icon: <CheckCircle2 className="w-3 h-3" />,
      label: "Approved",
    },
    pending: {
      classes: "bg-yellow-50 text-yellow-700 border border-yellow-200",
      icon: <Clock className="w-3 h-3" />,
      label: "Pending",
    },
    rejected: {
      classes: "bg-red-50 text-red-700 border border-red-200",
      icon: <XCircle className="w-3 h-3" />,
      label: "Rejected",
    },
  }[status] ?? {
    classes: "bg-gray-50 text-gray-700 border",
    icon: <Clock className="w-3 h-3" />,
    label: status,
  };

  return (
    <span
      className={clsx(
        "px-3 py-1 rounded-full text-xs font-medium inline-flex items-center gap-1",
        config.classes
      )}
    >
      {config.icon}
      {config.label}
    </span>
  );
}

export default function UserManagement() {
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState<(typeof statusOptions)[number]>("All Status");
  const [region, setRegion] = useState<string>("All Regions");
  const [page, setPage] = useState(1);
  const [users, setUsers] = useState<UserRow[]>([]);
  const [totalCount, setTotalCount] = useState(0);
  const [loading, setLoading] = useState(false);
  const [availableRegions, setAvailableRegions] = useState<string[]>(["All Regions"]);
  const [selectedMember, setSelectedMember] = useState<Member | null>(null);
  const [showDetailModal, setShowDetailModal] = useState(false);
  const [editingMember, setEditingMember] = useState<string | null>(null);
  const [editData, setEditData] = useState<MemberUpdateData>({});
  const [saving, setSaving] = useState(false);
  const [constituencies, setConstituencies] = useState<ParliamentaryConstituency[]>([]);
  const [assemblyConstituencies, setAssemblyConstituencies] = useState<any[]>([]);
  const [loadingAssemblyConstituencies, setLoadingAssemblyConstituencies] = useState(false);
  const [districts, setDistricts] = useState<District[]>([]);
  const [mandals, setMandals] = useState<Mandal[]>([]);
  const [loadingMandals, setLoadingMandals] = useState(false);
  const [selectedDistrictId, setSelectedDistrictId] = useState<number | null>(null);
  const [selectedMandalId, setSelectedMandalId] = useState<number | null>(null);
  const [cadreLevels, setCadreLevels] = useState<CadreLevel[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const pageSize = 10;

  // Fetch constituencies for dropdown
  useEffect(() => {
    const fetchConstituencies = async () => {
      try {
        const data = await constituencyService.getConstituencies({ state: 'Telangana', is_active: true });
        setConstituencies(data);
      } catch (err) {
        console.error('Failed to fetch constituencies:', err);
      }
    };
    fetchConstituencies();
  }, []);

  // Fetch districts for dropdown
  useEffect(() => {
    const fetchDistricts = async () => {
      try {
        const data = await districtsService.getDistricts({ state: 'Telangana', is_active: true });
        setDistricts(data);
      } catch (err) {
        console.error('Failed to fetch districts:', err);
      }
    };
    fetchDistricts();
  }, []);

  // Fetch cadre levels for dropdown
  useEffect(() => {
    const fetchCadreLevels = async () => {
      try {
        const data = await memberService.getCadreLevels();
        setCadreLevels(data.cadreLevels || []);
      } catch (err) {
        console.error('Failed to fetch cadre levels:', err);
      }
    };
    fetchCadreLevels();
  }, []);

  const mapMemberToUserRow = (member: Member): UserRow => {
    const dateStr = member.createdAt 
      ? new Date(member.createdAt).toLocaleDateString('en-GB') 
      : 'N/A';
    
    const memberRoleRaw = member.role?.toUpperCase() || "PUBLIC";
    const memberRole = ["CADRE", "PUBLIC", "ADMIN"].includes(memberRoleRaw) 
      ? (memberRoleRaw as "CADRE" | "PUBLIC" | "ADMIN") 
      : "PUBLIC";
    
    let constituencyName = '';
    if (member.parliamentConstituencyRef) {
      constituencyName = `${member.parliamentConstituencyRef.constituencyNumber}. ${member.parliamentConstituencyRef.name_en}`;
    }
    
    return {
      id: member.id,
      epicNumber: member.epicNumber,
      name: member.fullName || 'Unknown',
      email: member.phone,
      contact: member.phone,
      region: member.district || member.mandal || member.village || 'Unknown',
      constituency: constituencyName || undefined,
      role: memberRole,
      date: dateStr,
      status: (member.status as "pending" | "approved" | "rejected") || 'pending',
      memberData: member,
    };
  };

  // Fetch members from API
  useEffect(() => {
    const fetchMembers = async () => {
      setLoading(true);
      setError(null);
      try {
        const response = await memberService.getMembers({
          page,
          per_page: pageSize,
          status: status !== "All Status" ? status as 'pending' | 'approved' | 'rejected' : undefined,
          search: query || undefined,
        });
        
        // Map API members to UserRow format
        const mappedUsers = response.data.map(mapMemberToUserRow);
        
        setUsers(mappedUsers);
        setTotalCount(response.total);
        
        const regions = new Set<string>(["All Regions"]);
        response.data.forEach((member: Member) => {
          if (member.district) regions.add(member.district);
        });
        setAvailableRegions(Array.from(regions));
      } catch (error: any) {
        setError(error.response?.data?.message || 'Failed to fetch members');
        console.error('Failed to fetch members:', error);
        setUsers([]);
        setTotalCount(0);
      } finally {
        setLoading(false);
      }
    };

    fetchMembers();
  }, [page, status, query]);

  const handleViewDetails = async (memberId: string) => {
    try {
      const member = await memberService.getMemberById(memberId);
      setSelectedMember(member);
      setShowDetailModal(true);
    } catch (error: any) {
      setError(error.response?.data?.message || 'Failed to fetch member details');
    }
  };

  const handleEdit = async (member: Member) => {
    setEditingMember(member.id);
    setEditData({
      fullName: member.fullName,
      fatherName: member.fatherName,
      dateOfBirth: member.dateOfBirth,
      gender: member.gender,
      phone: member.phone,
      aadharNumber: member.aadharNumber,
      epicNumber: member.epicNumber,
      village: member.village,
      mandal: member.mandal,
      district: member.district,
      parliamentConstituencyId: member.parliamentConstituencyId,
      assemblyConstituencyId: member.assemblyConstituencyId,
      fullAddress: member.fullAddress,
      partyDesignation: member.partyDesignation,
      cadreLevel: member.cadreLevel,
      occupation: member.occupation,
      status: member.status,
      isActive: member.isActive,
      volunteerInterest: member.volunteerInterest,
      hasInsurance: member.hasInsurance,
      insuranceNumber: member.insuranceNumber,
      role: member.role,
    });
    
    // Find district ID from district name
    if (member.district) {
      const foundDistrict = districts.find(d => 
        d.name_en === member.district || d.name_te === member.district
      );
      if (foundDistrict) {
        setSelectedDistrictId(foundDistrict.id);
        // Fetch mandals for this district
        const fetchedMandals = await districtsService.getMandals({
          district_id: foundDistrict.id,
          is_active: true,
        });
        const filteredMandals = Array.isArray(fetchedMandals) ? fetchedMandals : [];
        setMandals(filteredMandals);
        
        // Find mandal ID from mandal name after mandals are loaded
        if (member.mandal && filteredMandals.length > 0) {
          const foundMandal = filteredMandals.find(m => 
            m.name_en === member.mandal || m.name_te === member.mandal
          );
          if (foundMandal) {
            setSelectedMandalId(foundMandal.id);
          } else {
            setSelectedMandalId(null);
          }
        } else {
          setSelectedMandalId(null);
        }
      } else {
        setSelectedDistrictId(null);
        setMandals([]);
        setSelectedMandalId(null);
      }
    } else {
      setSelectedDistrictId(null);
      setMandals([]);
      setSelectedMandalId(null);
    }
    
    // Fetch assembly constituencies if parliament constituency is set
    if (member.parliamentConstituencyId) {
      await fetchAssemblyConstituencies(member.parliamentConstituencyId);
    } else {
      setAssemblyConstituencies([]);
    }
    
    setError(null);
    setSuccess(null);
  };

  const fetchAssemblyConstituencies = async (parliamentId: number) => {
    setLoadingAssemblyConstituencies(true);
    setAssemblyConstituencies([]); // Clear previous results immediately
    try {
      const data = await constituencyService.getAssemblyConstituencies({
        parliamentary_constituency_id: parliamentId,
        state: 'Telangana',
        is_active: true,
      });
      // Ensure we have an array - API should already filter by parliament ID
      const filteredData = Array.isArray(data) ? data : [];
      console.log(`Fetched ${filteredData.length} assembly constituencies for parliament ${parliamentId}`, filteredData);
      // Log first item to verify structure
      if (filteredData.length > 0) {
        console.log('Sample assembly constituency:', filteredData[0]);
      }
      setAssemblyConstituencies(filteredData);
    } catch (err) {
      console.error('Failed to fetch assembly constituencies:', err);
      setAssemblyConstituencies([]);
    } finally {
      setLoadingAssemblyConstituencies(false);
    }
  };

  const fetchMandals = async (districtId: number) => {
    setLoadingMandals(true);
    setMandals([]); // Clear previous results immediately
    try {
      const data = await districtsService.getMandals({
        district_id: districtId,
        is_active: true,
      });
      const filteredData = Array.isArray(data) ? data : [];
      setMandals(filteredData);
    } catch (err) {
      console.error('Failed to fetch mandals:', err);
      setMandals([]);
    } finally {
      setLoadingMandals(false);
    }
  };

  const handleSave = async (memberId: string) => {
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      // Prepare update data with district and mandal names from selected IDs
      const updateData = { ...editData };
      
      // Map district ID to name
      if (selectedDistrictId) {
        const selectedDistrict = districts.find(d => d.id === selectedDistrictId);
        if (selectedDistrict) {
          updateData.district = selectedDistrict.name_en;
        }
      }
      
      // Map mandal ID to name
      if (selectedMandalId) {
        const selectedMandal = mandals.find(m => m.id === selectedMandalId);
        if (selectedMandal) {
          updateData.mandal = selectedMandal.name_en;
        }
      }
      
      // Update the member
      await memberService.updateMember(memberId, updateData);
      
      // Refresh just this member's data
      const updatedMember = await memberService.getMemberById(memberId);
      
      // Update local state
      setUsers(currentUsers => 
        currentUsers.map(u => 
          u.id === memberId ? mapMemberToUserRow(updatedMember) : u
        )
      );

      setEditingMember(null);
      setEditData({});
      setSelectedDistrictId(null);
      setSelectedMandalId(null);
      setMandals([]);
      setSuccess('Member updated successfully');
      setTimeout(() => setSuccess(null), 3000);
    } catch (error: any) {
      setError(error.response?.data?.message || 'Failed to update member');
    } finally {
      setSaving(false);
    }
  };

  const handleStatusChange = async (memberId: string, newStatus: 'pending' | 'approved' | 'rejected') => {
    try {
      setError(null);
      await memberService.updateMemberStatus(memberId, newStatus);
      setSuccess(`Member ${newStatus === 'approved' ? 'approved' : newStatus === 'rejected' ? 'rejected' : 'status updated'} successfully`);
      setTimeout(() => setSuccess(null), 3000);
      
      // Refresh just this member's data
      const updatedMember = await memberService.getMemberById(memberId);
      
      // Update the selected member if the detail modal is open for this member
      if (selectedMember && selectedMember.id === memberId) {
        setSelectedMember(updatedMember);
      }
      
      // Update local state in the table
      setUsers(currentUsers => 
        currentUsers.map(u => 
          u.id === memberId ? mapMemberToUserRow(updatedMember) : u
        )
      );
    } catch (error: any) {
      setError(error.response?.data?.message || 'Failed to update status');
    }
  };

  const filtered = useMemo(() => {
    return users.filter((u) => {
      const matchesRegion = region === "All Regions" || u.region === region;
      return matchesRegion;
    });
  }, [users, region]);

  const pageCount = Math.max(1, Math.ceil(totalCount / pageSize));
  const clampedPage = Math.min(page, pageCount);
  const paged = filtered;

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-xl sm:text-2xl font-semibold">Member Management</h1>
          <p className="text-xs sm:text-sm text-gray-500">Manage members registered through the app</p>
        </div>
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

      {/* Filters */}
      <div className="bg-white rounded-lg shadow-card p-4 flex flex-col sm:flex-row flex-wrap items-stretch sm:items-center gap-3">
        <div className="relative flex-1 min-w-0 sm:min-w-[260px]">
          <Search className="w-4 h-4 text-gray-500 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search..."
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="w-full pl-9 pr-3 py-2 rounded-md border bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300 text-sm"
          />
        </div>

        <div className="relative sm:w-auto w-full">
          <select
            className="appearance-none pl-3 pr-8 py-2 rounded-md border text-sm focus:outline-none focus:ring-2 focus:ring-orange-300 bg-white text-gray-900 w-full sm:w-auto"
            value={status}
            onChange={(e) => {
              setStatus(e.target.value as (typeof statusOptions)[number]);
              setPage(1);
            }}
          >
            {statusOptions.map((s) => (
              <option key={s} value={s}>
                {s.charAt(0).toUpperCase() + s.slice(1)}
              </option>
            ))}
          </select>
          <ChevronDown className="w-4 h-4 text-gray-500 absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none" />
        </div>

        <div className="relative sm:w-auto w-full">
          <select
            className="appearance-none pl-3 pr-8 py-2 rounded-md border text-sm focus:outline-none focus:ring-2 focus:ring-orange-300 bg-white text-gray-900 w-full sm:w-auto"
            value={region}
            onChange={(e) => {
              setRegion(e.target.value);
              setPage(1);
            }}
          >
            {availableRegions.map((r) => (
              <option key={r} value={r}>
                {r}
              </option>
            ))}
          </select>
          <ChevronDown className="w-4 h-4 text-gray-500 absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none" />
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-lg shadow-card overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="text-gray-500">Loading members...</div>
          </div>
        ) : (
          <>
            <div className="hidden md:block overflow-x-auto">
              <table className="min-w-full">
                <thead className="bg-gray-50">
                  <tr className="text-left text-sm text-gray-600">
                    <th className="px-4 py-3 font-medium">Name</th>
                    <th className="px-4 py-3 font-medium">EPIC No.</th>
                    <th className="px-4 py-3 font-medium">Contact</th>
                    <th className="px-4 py-3 font-medium">Region</th>
                    <th className="px-4 py-3 font-medium">Constituency</th>
                    <th className="px-4 py-3 font-medium">Role</th>
                    <th className="px-4 py-3 font-medium">Cadre Level</th>
                    <th className="px-4 py-3 font-medium">Date</th>
                    <th className="px-4 py-3 font-medium">Status</th>
                    <th className="px-4 py-3 font-medium">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {paged.map((u) => (
                    <tr key={u.id} className="border-t">
                      <td className="px-4 py-3">
                        <div className="font-medium text-gray-900">{u.name}</div>
                        <div className="text-xs text-gray-500">{u.email}</div>
                      </td>
                      <td className="px-4 py-3">
                        {u.epicNumber ? (
                          <span className="inline-block px-2 py-0.5 rounded bg-amber-50 border border-amber-200 text-amber-800 text-xs font-mono font-semibold">
                            {u.epicNumber}
                          </span>
                        ) : (
                          <span className="text-gray-400 text-xs">—</span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-gray-700">{u.contact}</td>
                      <td className="px-4 py-3 text-gray-700">{u.region}</td>
                      <td className="px-4 py-3 text-gray-700">{u.constituency || '-'}</td>
                      <td className="px-4 py-3">
                        <RolePill role={u.role} />
                      </td>
                      <td className="px-4 py-3 text-gray-700 text-xs">
                        {u.memberData.cadreLevelRef ? (
                          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-indigo-50 text-indigo-700 border border-indigo-200">
                            <span className="font-bold">{u.memberData.cadreLevelRef.level}</span>
                            <span className="hidden lg:inline">{u.memberData.cadreLevelRef.nameEn.length > 20 ? u.memberData.cadreLevelRef.nameEn.slice(0, 20) + '…' : u.memberData.cadreLevelRef.nameEn}</span>
                          </span>
                        ) : (
                          <span className="text-gray-400">—</span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-gray-700">{u.date}</td>
                      <td className="px-4 py-3">
                        <StatusPill status={u.status} />
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-1">
                          <button
                            onClick={() => handleViewDetails(u.id)}
                            className="p-2 text-blue-600 hover:bg-blue-50 rounded-md transition"
                            title="View Details"
                          >
                            <Eye className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() => handleEdit(u.memberData)}
                            className="p-2 text-gray-600 hover:bg-gray-50 rounded-md transition"
                            title="Edit"
                          >
                            <Edit2 className="w-4 h-4" />
                          </button>
                          {u.status !== 'approved' && (
                            <button
                              onClick={() => handleStatusChange(u.id, 'approved')}
                              className="p-2 text-green-600 hover:bg-green-50 rounded-md transition"
                              title="Approve"
                            >
                              <ThumbsUp className="w-4 h-4" />
                            </button>
                          )}
                          {u.status !== 'rejected' && (
                            <button
                              onClick={() => handleStatusChange(u.id, 'rejected')}
                              className="p-2 text-red-600 hover:bg-red-50 rounded-md transition"
                              title="Reject"
                            >
                              <ThumbsDown className="w-4 h-4" />
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  ))}
                  {paged.length === 0 && (
                    <tr>
                      <td className="px-4 py-6 text-center text-gray-500" colSpan={9}>
                        {loading ? 'Loading members...' : 'No members match your filters.'}
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>

            {/* Mobile Cards */}
            <div className="md:hidden divide-y">
              {paged.map((u) => (
                <div key={u.id} className="p-4 space-y-3">
                  <div className="flex items-start justify-between">
                    <div className="flex-1 min-w-0">
                      <div className="font-medium text-gray-900">{u.name}</div>
                      <div className="text-xs text-gray-500 mt-1">{u.email}</div>
                      <div className="text-sm text-gray-700 mt-1">{u.contact}</div>
                      {u.epicNumber && (
                        <div className="mt-1">
                          <span className="text-xs text-gray-500">EPIC: </span>
                          <span className="inline px-1.5 py-0.5 rounded bg-amber-50 border border-amber-200 text-amber-800 text-xs font-mono font-semibold">
                            {u.epicNumber}
                          </span>
                        </div>
                      )}
                    </div>
                    <div className="flex items-center gap-1">
                      <button
                        onClick={() => handleViewDetails(u.id)}
                        className="p-2 text-blue-600 hover:bg-blue-50 rounded-md"
                      >
                        <Eye className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => handleEdit(u.memberData)}
                        className="p-2 text-gray-600 hover:bg-gray-50 rounded-md"
                      >
                        <Edit2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                  <div className="flex flex-wrap items-center gap-2 text-sm">
                    <div className="flex-1 min-w-[120px]">
                      <span className="text-gray-500">Region:</span>
                      <span className="ml-2 text-gray-700">{u.region}</span>
                    </div>
                    {u.constituency && (
                      <div className="flex-1 min-w-[120px]">
                        <span className="text-gray-500">Constituency:</span>
                        <span className="ml-2 text-gray-700">{u.constituency}</span>
                      </div>
                    )}
                    <div className="flex-1 min-w-[120px]">
                      <span className="text-gray-500">Date:</span>
                      <span className="ml-2 text-gray-700">{u.date}</span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <RolePill role={u.role} />
                      <StatusPill status={u.status} />
                    </div>
                    <div className="flex items-center gap-1">
                      {u.status !== 'approved' && (
                        <button
                          onClick={() => handleStatusChange(u.id, 'approved')}
                          className="px-3 py-1.5 text-xs font-medium text-green-700 bg-green-50 border border-green-200 rounded-md hover:bg-green-100 transition"
                        >
                          Approve
                        </button>
                      )}
                      {u.status !== 'rejected' && (
                        <button
                          onClick={() => handleStatusChange(u.id, 'rejected')}
                          className="px-3 py-1.5 text-xs font-medium text-red-700 bg-red-50 border border-red-200 rounded-md hover:bg-red-100 transition"
                        >
                          Reject
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              ))}
              {paged.length === 0 && (
                <div className="px-4 py-6 text-center text-gray-500">
                  {loading ? 'Loading members...' : 'No members match your filters.'}
                </div>
              )}
            </div>
          </>
        )}
      </div>

      {/* Pagination */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-3">
        <div className="text-xs sm:text-sm text-gray-600 text-center sm:text-left">
          Showing {(clampedPage - 1) * pageSize + 1}-{Math.min(clampedPage * pageSize, filtered.length)} of {totalCount.toLocaleString()}
        </div>
        <div className="flex items-center gap-2">
          <button
            className="px-3 py-2 text-xs sm:text-sm rounded-md border hover:bg-gray-50 disabled:opacity-50"
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            disabled={clampedPage <= 1}
          >
            Previous
          </button>
          <button
            className="px-3 py-2 text-xs sm:text-sm rounded-md border hover:bg-gray-50 disabled:opacity-50"
            onClick={() => setPage((p) => Math.min(pageCount, p + 1))}
            disabled={clampedPage >= pageCount}
          >
            Next
          </button>
        </div>
      </div>

      {/* Detail Modal */}
      {showDetailModal && selectedMember && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div className="sticky top-0 bg-white border-b px-6 py-4 flex items-center justify-between">
              <h2 className="text-xl font-bold">Member Details</h2>
              <button
                onClick={() => {
                  setShowDetailModal(false);
                  setSelectedMember(null);
                }}
                className="p-2 hover:bg-gray-100 rounded-md"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="p-6 space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="text-sm font-medium text-gray-700">Full Name</label>
                  <div className="mt-1 text-gray-900">{selectedMember.fullName}</div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-700">EPIC Number</label>
                  <div className="mt-1">
                    {selectedMember.epicNumber ? (
                      <span className="inline-block px-2 py-0.5 rounded bg-amber-50 border border-amber-200 text-amber-800 font-mono font-semibold text-sm">
                        {selectedMember.epicNumber}
                      </span>
                    ) : (
                      <span className="text-gray-400">—</span>
                    )}
                  </div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-700">Phone</label>
                  <div className="mt-1 text-gray-900">{selectedMember.phone}</div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-700">District</label>
                  <div className="mt-1 text-gray-900">{selectedMember.district || '-'}</div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-700">Mandal</label>
                  <div className="mt-1 text-gray-900">{selectedMember.mandal || '-'}</div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-700">Village</label>
                  <div className="mt-1 text-gray-900">{selectedMember.village || '-'}</div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-700">Parliament Constituency</label>
                  <div className="mt-1 text-gray-900">
                    {selectedMember.parliamentConstituencyRef
                      ? `${selectedMember.parliamentConstituencyRef.constituencyNumber}. ${selectedMember.parliamentConstituencyRef.name_en}`
                      : '-'}
                  </div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-700">Assembly Constituency</label>
                  <div className="mt-1 text-gray-900">
                    {selectedMember.assemblyConstituencyRef
                      ? (() => {
                          const num = selectedMember.assemblyConstituencyRef.constituencyNumber || 
                                     selectedMember.assemblyConstituencyRef.id;
                          return num ? `${num}. ${selectedMember.assemblyConstituencyRef.name_en}` : selectedMember.assemblyConstituencyRef.name_en;
                        })()
                      : '-'}
                  </div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-700">Status</label>
                  <div className="mt-1">
                    <span className={clsx(
                      "px-3 py-1 rounded-full text-xs font-medium",
                      selectedMember.status === 'approved' ? "bg-green-100 text-green-700" :
                      selectedMember.status === 'pending' ? "bg-yellow-100 text-yellow-700" :
                      "bg-red-100 text-red-700"
                    )}>
                      {selectedMember.status}
                    </span>
                  </div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-700">Cadre Level</label>
                  <div className="mt-1">
                    {selectedMember.cadreLevelRef ? (
                      <span className="inline-flex items-center gap-1 px-3 py-1 rounded-full text-xs font-medium bg-indigo-100 text-indigo-700 border border-indigo-200">
                        <span className="font-bold">{selectedMember.cadreLevelRef.level}.</span>
                        {selectedMember.cadreLevelRef.nameEn}
                      </span>
                    ) : selectedMember.cadreLevel ? (
                      <span className="text-gray-900">Level {selectedMember.cadreLevel}</span>
                    ) : (
                      <span className="text-gray-400">Not assigned</span>
                    )}
                  </div>
                </div>
              </div>
              <div className="flex gap-2 pt-4 border-t">
                <button
                  onClick={() => {
                    handleEdit(selectedMember);
                    setShowDetailModal(false);
                  }}
                  className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
                >
                  <Edit2 className="w-4 h-4" />
                  Edit
                </button>
                {selectedMember.status !== 'approved' && (
                  <button
                    onClick={() => handleStatusChange(selectedMember.id, 'approved')}
                    className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700"
                  >
                    Approve
                  </button>
                )}
                {selectedMember.status !== 'rejected' && (
                  <button
                    onClick={() => handleStatusChange(selectedMember.id, 'rejected')}
                    className="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700"
                  >
                    Reject
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Edit Modal */}
      {editingMember && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div className="sticky top-0 bg-white border-b px-6 py-4 flex items-center justify-between">
              <h2 className="text-xl font-bold">Edit Member</h2>
                <button
                  onClick={() => {
                    setEditingMember(null);
                    setEditData({});
                    setAssemblyConstituencies([]);
                    setSelectedDistrictId(null);
                    setSelectedMandalId(null);
                    setMandals([]);
                  }}
                  className="p-2 hover:bg-gray-100 rounded-md"
                >
                  <X className="w-5 h-5" />
                </button>
            </div>
            <div className="p-6 space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Full Name *</label>
                  <input
                    type="text"
                    value={editData.fullName || ''}
                    onChange={(e) => setEditData({ ...editData, fullName: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Father's Name</label>
                  <input
                    type="text"
                    value={editData.fatherName || ''}
                    onChange={(e) => setEditData({ ...editData, fatherName: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Date of Birth</label>
                  <input
                    type="date"
                    value={editData.dateOfBirth || ''}
                    onChange={(e) => setEditData({ ...editData, dateOfBirth: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Gender</label>
                  <select
                    value={editData.gender || ''}
                    onChange={(e) => setEditData({ ...editData, gender: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500"
                  >
                    <option value="">Select Gender</option>
                    <option value="male">Male</option>
                    <option value="female">Female</option>
                    <option value="other">Other</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Phone *</label>
                  <input
                    type="text"
                    value={editData.phone || ''}
                    onChange={(e) => setEditData({ ...editData, phone: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Aadhar Number</label>
                  <input
                    type="text"
                    value={editData.aadharNumber || ''}
                    onChange={(e) => setEditData({ ...editData, aadharNumber: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">EPIC Number</label>
                  <input
                    type="text"
                    value={editData.epicNumber || ''}
                    onChange={(e) => setEditData({ ...editData, epicNumber: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Village</label>
                  <input
                    type="text"
                    value={editData.village || ''}
                    onChange={(e) => setEditData({ ...editData, village: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">District</label>
                  <select
                    value={selectedDistrictId?.toString() || ''}
                    onChange={async (e) => {
                      const newDistrictId = e.target.value ? parseInt(e.target.value) : null;
                      setSelectedDistrictId(newDistrictId);
                      // Clear mandal when district changes
                      setSelectedMandalId(null);
                      setMandals([]);
                      setEditData({ ...editData, district: undefined, mandal: undefined });
                      // Fetch mandals for the selected district
                      if (newDistrictId) {
                        await fetchMandals(newDistrictId);
                      }
                    }}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500"
                  >
                    <option value="">Select District</option>
                    {districts.map((d) => (
                      <option key={d.id} value={d.id}>
                        {d.name_en}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Mandal</label>
                  <select
                    value={selectedMandalId?.toString() || ''}
                    onChange={(e) => {
                      const mandalId = e.target.value ? parseInt(e.target.value) : null;
                      setSelectedMandalId(mandalId);
                      const selectedMandal = mandals.find(m => m.id === mandalId);
                      setEditData({ 
                        ...editData, 
                        mandal: selectedMandal ? selectedMandal.name_en : undefined 
                      });
                    }}
                    disabled={!selectedDistrictId || loadingMandals}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500 disabled:bg-gray-100 disabled:cursor-not-allowed"
                  >
                    <option value="">
                      {loadingMandals 
                        ? 'Loading...' 
                        : !selectedDistrictId 
                        ? 'Select District first' 
                        : 'Select Mandal'}
                    </option>
                    {mandals.map((m) => (
                      <option key={m.id} value={m.id}>
                        {m.name_en}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Parliament Constituency</label>
                  <select
                    value={editData.parliamentConstituencyId?.toString() || ''}
                    onChange={async (e) => {
                      const newParliamentId = e.target.value ? parseInt(e.target.value) : undefined;
                      // Immediately clear assembly constituency and list
                      setAssemblyConstituencies([]);
                      setEditData({ ...editData, parliamentConstituencyId: newParliamentId, assemblyConstituencyId: undefined });
                      // Only fetch if a parliament constituency is selected
                      if (newParliamentId) {
                        await fetchAssemblyConstituencies(newParliamentId);
                      }
                    }}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500"
                  >
                    <option value="">Select Constituency</option>
                    {constituencies.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.constituencyNumber}. {c.name_en}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Assembly Constituency</label>
                  <select
                    value={editData.assemblyConstituencyId?.toString() || ''}
                    onChange={(e) => setEditData({ ...editData, assemblyConstituencyId: e.target.value ? parseInt(e.target.value) : undefined })}
                    disabled={!editData.parliamentConstituencyId || loadingAssemblyConstituencies}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500 disabled:bg-gray-100 disabled:cursor-not-allowed"
                  >
                    <option value="">
                      {loadingAssemblyConstituencies 
                        ? 'Loading...' 
                        : !editData.parliamentConstituencyId 
                        ? 'Select Parliament Constituency first' 
                        : 'Select Assembly Constituency'}
                    </option>
                    {assemblyConstituencies.map((ac) => {
                      // Log to debug if needed
                      if (assemblyConstituencies.length > 0 && assemblyConstituencies.indexOf(ac) === 0) {
                        console.log('Rendering assembly constituency:', ac, 'for parliament:', editData.parliamentConstituencyId);
                      }
                      const constituencyNumber = ac.constituencyNumber || ac.assembly_constituency_number || ac.number || ac.id;
                      return (
                        <option key={ac.id} value={ac.id}>
                          {constituencyNumber ? `${constituencyNumber}. ` : ''}{ac.name_en}
                        </option>
                      );
                    })}
                  </select>
                </div>
                <div className="md:col-span-2">
                  <label className="block text-sm font-medium text-gray-700 mb-1">Full Address</label>
                  <textarea
                    value={editData.fullAddress || ''}
                    onChange={(e) => setEditData({ ...editData, fullAddress: e.target.value })}
                    rows={3}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Cadre Level</label>
                  <select
                    value={editData.cadreLevel ?? ''}
                    onChange={(e) => setEditData({ ...editData, cadreLevel: e.target.value ? Number(e.target.value) : null })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500"
                  >
                    <option value="">Not Assigned</option>
                    {cadreLevels.map((cl) => (
                      <option key={cl.level} value={cl.level}>
                        {cl.level}. {cl.nameEn} ({cl.geographicScope})
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Party Designation (Optional)</label>
                  <input
                    type="text"
                    value={editData.partyDesignation || ''}
                    onChange={(e) => setEditData({ ...editData, partyDesignation: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Occupation</label>
                  <input
                    type="text"
                    value={editData.occupation || ''}
                    onChange={(e) => setEditData({ ...editData, occupation: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Role</label>
                  <select
                    value={editData.role || 'public'}
                    onChange={(e) => setEditData({ ...editData, role: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500"
                  >
                    <option value="public">Public</option>
                    <option value="cadre">Cadre</option>
                    <option value="admin">Admin</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Status</label>
                  <select
                    value={editData.status || 'pending'}
                    onChange={(e) => setEditData({ ...editData, status: e.target.value as any })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500"
                  >
                    <option value="pending">Pending</option>
                    <option value="approved">Approved</option>
                    <option value="rejected">Rejected</option>
                  </select>
                </div>
                <div className="md:col-span-2 flex items-center gap-6">
                  <label className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      checked={editData.volunteerInterest || false}
                      onChange={(e) => setEditData({ ...editData, volunteerInterest: e.target.checked })}
                      className="w-4 h-4 text-orange-600 border-gray-300 rounded focus:ring-orange-500"
                    />
                    <span className="text-sm font-medium text-gray-700">Volunteer Interest</span>
                  </label>
                  <label className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      checked={editData.hasInsurance || false}
                      onChange={(e) => setEditData({ ...editData, hasInsurance: e.target.checked })}
                      className="w-4 h-4 text-orange-600 border-gray-300 rounded focus:ring-orange-500"
                    />
                    <span className="text-sm font-medium text-gray-700">Has Insurance</span>
                  </label>
                  <label className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      checked={editData.isActive ?? true}
                      onChange={(e) => setEditData({ ...editData, isActive: e.target.checked })}
                      className="w-4 h-4 text-orange-600 border-gray-300 rounded focus:ring-orange-500"
                    />
                    <span className="text-sm font-medium text-gray-700">Active</span>
                  </label>
                </div>
                {editData.hasInsurance && (
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Insurance Number</label>
                    <input
                      type="text"
                      value={editData.insuranceNumber || ''}
                      onChange={(e) => setEditData({ ...editData, insuranceNumber: e.target.value })}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-orange-500"
                    />
                  </div>
                )}
              </div>
              <div className="flex gap-2 pt-4 border-t">
                <button
                  onClick={() => handleSave(editingMember)}
                  disabled={saving}
                  className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 disabled:opacity-50"
                >
                  <Save className="w-4 h-4" />
                  {saving ? 'Saving...' : 'Save'}
                </button>
                <button
                  onClick={() => {
                    setEditingMember(null);
                    setEditData({});
                    setAssemblyConstituencies([]);
                    setSelectedDistrictId(null);
                    setSelectedMandalId(null);
                    setMandals([]);
                  }}
                  className="px-4 py-2 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
