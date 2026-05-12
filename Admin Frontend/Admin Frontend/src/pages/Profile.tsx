import { useState, useEffect } from 'react';
import { authService, type User } from '../services/authService';
import { useAuth } from '../contexts/AuthContext';
import { Edit2, Save, X, User as UserIcon, Phone, MapPin, Calendar, Users, Home, Briefcase, Shield, FileText } from 'lucide-react';

export default function Profile() {
  const { user: contextUser, updateUser } = useAuth();
  const [user, setUser] = useState<User | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [formData, setFormData] = useState<Partial<User>>({});

  useEffect(() => {
    loadProfile();
  }, []);

  const loadProfile = async () => {
    try {
      setLoading(true);
      const profileData = await authService.getProfile();
      setUser(profileData);
      setFormData(profileData);
      setError(null);
    } catch (err: any) {
      console.error('Failed to load profile:', err);
      setError(err.response?.data?.message || 'Failed to load profile');
      // Fallback to context user if available
      if (contextUser) {
        setUser(contextUser);
        setFormData(contextUser);
      }
    } finally {
      setLoading(false);
    }
  };

  const handleInputChange = (field: keyof User, value: any) => {
    setFormData(prev => ({
      ...prev,
      [field]: value
    }));
  };

  const handleSave = async () => {
    try {
      setSaving(true);
      setError(null);
      const updatedUser = await authService.updateProfile(formData);
      setUser(updatedUser);
      updateUser(updatedUser);
      setIsEditing(false);
    } catch (err: any) {
      console.error('Failed to update profile:', err);
      setError(err.response?.data?.message || 'Failed to update profile');
    } finally {
      setSaving(false);
    }
  };

  const handleCancel = () => {
    if (user) {
      setFormData(user);
    }
    setIsEditing(false);
    setError(null);
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-orange-500 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading profile...</p>
        </div>
      </div>
    );
  }

  if (!user) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <p className="text-red-600">Failed to load profile</p>
          <button
            onClick={loadProfile}
            className="mt-4 px-4 py-2 bg-orange-500 text-white rounded-md hover:bg-orange-600"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg shadow-md p-6">
        {/* Header */}
        <div className="flex items-center justify-between mb-6 pb-4 border-b">
          <div className="flex items-center gap-3">
            <div className="w-16 h-16 rounded-full bg-gradient-to-br from-orange-500 to-green-500 flex items-center justify-center">
              <UserIcon className="w-8 h-8 text-white" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-gray-900">
                {isEditing ? 'Edit Profile' : 'My Profile'}
              </h1>
              <p className="text-sm text-gray-500">Manage your profile information</p>
            </div>
          </div>
          {!isEditing ? (
            <button
              onClick={() => setIsEditing(true)}
              className="flex items-center gap-2 px-4 py-2 bg-orange-500 text-white rounded-md hover:bg-orange-600 transition-colors"
            >
              <Edit2 className="w-4 h-4" />
              Edit Profile
            </button>
          ) : (
            <div className="flex items-center gap-2">
              <button
                onClick={handleCancel}
                className="flex items-center gap-2 px-4 py-2 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300 transition-colors"
              >
                <X className="w-4 h-4" />
                Cancel
              </button>
              <button
                onClick={handleSave}
                disabled={saving}
                className="flex items-center gap-2 px-4 py-2 bg-green-500 text-white rounded-md hover:bg-green-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <Save className="w-4 h-4" />
                {saving ? 'Saving...' : 'Save Changes'}
              </button>
            </div>
          )}
        </div>

        {error && (
          <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-md text-red-700">
            {error}
          </div>
        )}

        {/* Profile Form */}
        <div className="space-y-6">
          {/* Basic Information */}
          <section>
            <h2 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
              <UserIcon className="w-5 h-5 text-orange-500" />
              Basic Information
            </h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Name *
                </label>
                {isEditing ? (
                  <input
                    type="text"
                    value={formData.name || ''}
                    onChange={(e) => handleInputChange('name', e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
                  />
                ) : (
                  <p className="px-3 py-2 bg-gray-50 rounded-md">{user.name || 'Not set'}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1 flex items-center gap-2">
                  <Phone className="w-4 h-4" />
                  Phone Number
                </label>
                <p className="px-3 py-2 bg-gray-100 rounded-md text-gray-600">{user.phone}</p>
                <p className="text-xs text-gray-500 mt-1">Phone number cannot be changed</p>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Full Name
                </label>
                {isEditing ? (
                  <input
                    type="text"
                    value={formData.fullName || ''}
                    onChange={(e) => handleInputChange('fullName', e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
                  />
                ) : (
                  <p className="px-3 py-2 bg-gray-50 rounded-md">{user.fullName || 'Not set'}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Father's Name
                </label>
                {isEditing ? (
                  <input
                    type="text"
                    value={formData.fatherName || ''}
                    onChange={(e) => handleInputChange('fatherName', e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
                  />
                ) : (
                  <p className="px-3 py-2 bg-gray-50 rounded-md">{user.fatherName || 'Not set'}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1 flex items-center gap-2">
                  <Calendar className="w-4 h-4" />
                  Date of Birth
                </label>
                {isEditing ? (
                  <input
                    type="date"
                    value={formData.dateOfBirth || ''}
                    onChange={(e) => handleInputChange('dateOfBirth', e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
                  />
                ) : (
                  <p className="px-3 py-2 bg-gray-50 rounded-md">{user.dateOfBirth || 'Not set'}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1 flex items-center gap-2">
                  <Users className="w-4 h-4" />
                  Gender
                </label>
                {isEditing ? (
                  <select
                    value={formData.gender || ''}
                    onChange={(e) => handleInputChange('gender', e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
                  >
                    <option value="">Select Gender</option>
                    <option value="male">Male</option>
                    <option value="female">Female</option>
                    <option value="other">Other</option>
                  </select>
                ) : (
                  <p className="px-3 py-2 bg-gray-50 rounded-md">{user.gender || 'Not set'}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Region
                </label>
                {isEditing ? (
                  <input
                    type="text"
                    value={formData.region || ''}
                    onChange={(e) => handleInputChange('region', e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
                  />
                ) : (
                  <p className="px-3 py-2 bg-gray-50 rounded-md">{user.region || 'Not set'}</p>
                )}
              </div>
            </div>
          </section>

          {/* Address Information */}
          <section>
            <h2 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
              <MapPin className="w-5 h-5 text-orange-500" />
              Address Information
            </h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Village
                </label>
                {isEditing ? (
                  <input
                    type="text"
                    value={formData.village || ''}
                    onChange={(e) => handleInputChange('village', e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
                  />
                ) : (
                  <p className="px-3 py-2 bg-gray-50 rounded-md">{user.village || 'Not set'}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Mandal
                </label>
                {isEditing ? (
                  <input
                    type="text"
                    value={formData.mandal || ''}
                    onChange={(e) => handleInputChange('mandal', e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
                  />
                ) : (
                  <p className="px-3 py-2 bg-gray-50 rounded-md">{user.mandal || 'Not set'}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  District
                </label>
                {isEditing ? (
                  <input
                    type="text"
                    value={formData.district || ''}
                    onChange={(e) => handleInputChange('district', e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
                  />
                ) : (
                  <p className="px-3 py-2 bg-gray-50 rounded-md">{user.district || 'Not set'}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Assembly Constituency
                </label>
                <p className="px-3 py-2 bg-gray-50 rounded-md">
                  {user.assemblyConstituencyRef 
                    ? (() => {
                        const num = user.assemblyConstituencyRef.constituencyNumber || 
                                   user.assemblyConstituencyRef.id;
                        return num ? `${num}. ${user.assemblyConstituencyRef.name_en}` : user.assemblyConstituencyRef.name_en;
                      })()
                    : 'Not set'}
                </p>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Parliament Constituency
                </label>
                <p className="px-3 py-2 bg-gray-50 rounded-md">
                  {user.parliamentConstituencyRef
                    ? `${user.parliamentConstituencyRef.constituencyNumber}. ${user.parliamentConstituencyRef.name_en}`
                    : 'Not set'}
                </p>
              </div>

              <div className="md:col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-1 flex items-center gap-2">
                  <Home className="w-4 h-4" />
                  Full Address
                </label>
                {isEditing ? (
                  <textarea
                    value={formData.fullAddress || ''}
                    onChange={(e) => handleInputChange('fullAddress', e.target.value)}
                    rows={3}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
                  />
                ) : (
                  <p className="px-3 py-2 bg-gray-50 rounded-md">{user.fullAddress || 'Not set'}</p>
                )}
              </div>
            </div>
          </section>

          {/* Party & Professional Information */}
          <section>
            <h2 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
              <Briefcase className="w-5 h-5 text-orange-500" />
              Party & Professional Information
            </h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Party Designation
                </label>
                {isEditing ? (
                  <input
                    type="text"
                    value={formData.partyDesignation || ''}
                    onChange={(e) => handleInputChange('partyDesignation', e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
                  />
                ) : (
                  <p className="px-3 py-2 bg-gray-50 rounded-md">{user.partyDesignation || 'Not set'}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Occupation
                </label>
                {isEditing ? (
                  <input
                    type="text"
                    value={formData.occupation || ''}
                    onChange={(e) => handleInputChange('occupation', e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
                  />
                ) : (
                  <p className="px-3 py-2 bg-gray-50 rounded-md">{user.occupation || 'Not set'}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Volunteer Interest
                </label>
                {isEditing ? (
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={formData.volunteerInterest || false}
                      onChange={(e) => handleInputChange('volunteerInterest', e.target.checked)}
                      className="w-4 h-4 text-orange-500 border-gray-300 rounded focus:ring-orange-500"
                    />
                    <span className="text-sm text-gray-700">Interested in volunteering</span>
                  </label>
                ) : (
                  <p className="px-3 py-2 bg-gray-50 rounded-md">
                    {user.volunteerInterest ? 'Yes' : 'No'}
                  </p>
                )}
              </div>
            </div>
          </section>

          {/* Identification & Insurance */}
          <section>
            <h2 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
              <FileText className="w-5 h-5 text-orange-500" />
              Identification & Insurance
            </h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Aadhar Number
                </label>
                {isEditing ? (
                  <input
                    type="text"
                    value={formData.aadharNumber || ''}
                    onChange={(e) => handleInputChange('aadharNumber', e.target.value)}
                    maxLength={12}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
                  />
                ) : (
                  <p className="px-3 py-2 bg-gray-50 rounded-md">{user.aadharNumber || 'Not set'}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Voter ID (EPIC)
                </label>
                {isEditing ? (
                  <input
                    type="text"
                    value={formData.epicNumber || ''}
                    onChange={(e) => handleInputChange('epicNumber', e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
                  />
                ) : (
                  <p className="px-3 py-2 bg-gray-50 rounded-md">{user.epicNumber || 'Not set'}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1 flex items-center gap-2">
                  <Shield className="w-4 h-4" />
                  Has Insurance
                </label>
                {isEditing ? (
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={formData.hasInsurance || false}
                      onChange={(e) => handleInputChange('hasInsurance', e.target.checked)}
                      className="w-4 h-4 text-orange-500 border-gray-300 rounded focus:ring-orange-500"
                    />
                    <span className="text-sm text-gray-700">I have insurance</span>
                  </label>
                ) : (
                  <p className="px-3 py-2 bg-gray-50 rounded-md">
                    {user.hasInsurance ? 'Yes' : 'No'}
                  </p>
                )}
              </div>

              {(isEditing ? formData.hasInsurance : user.hasInsurance) && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Insurance Number
                  </label>
                  {isEditing ? (
                    <input
                      type="text"
                      value={formData.insuranceNumber || ''}
                      onChange={(e) => handleInputChange('insuranceNumber', e.target.value)}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
                    />
                  ) : (
                    <p className="px-3 py-2 bg-gray-50 rounded-md">{user.insuranceNumber || 'Not set'}</p>
                  )}
                </div>
              )}
            </div>
          </section>
        </div>
      </div>
    </div>
  );
}

