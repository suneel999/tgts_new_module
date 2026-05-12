import { useState, useEffect, useRef } from "react";
import { Megaphone, UploadCloud, CheckCircle, AlertCircle, X, Edit, Trash2, List, Plus, Eye, EyeOff, MapPin, Users } from "lucide-react";
import { adminService, type NewsItem } from "../../services/adminService";
import { mediaService } from "../../services/mediaService";
import { translationService } from "../../services/translationService";
import GeographicAccessSelector, { type GeographicAccessData } from "../../components/GeographicAccessSelector";
import { districtsService, type District, type Mandal } from "../../services/districtsService";
import { constituencyService, type ParliamentaryConstituency } from "../../services/constituencyService";

const audienceTypes = ["All Members", "Cadre Only", "Public"] as const;
type ViewMode = "create" | "list";

type LinkItem = {
  platform: string;
  url: string;
};

const socialMediaPlatforms = [
  "Facebook",
  "Twitter",
  "Instagram",
  "YouTube",
  "LinkedIn",
  "WhatsApp",
  "Telegram",
  "Other"
] as const;

const newsCategories = [
  "Announcement",
  "General",
  "Events",
  "Technology",
  "Policy",
  "Politics",
  "Social",
  "Other"
] as const;

export default function ContentPush() {
  const [viewMode, setViewMode] = useState<ViewMode>("list");
  const [newsItems, setNewsItems] = useState<NewsItem[]>([]);
  const [loadingNews, setLoadingNews] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalNews, setTotalNews] = useState(0);
  
  // Create form state
  const [audience, setAudience] = useState<(typeof audienceTypes)[number]>("All Members");
  const [category, setCategory] = useState<(typeof newsCategories)[number]>("Announcement");
  const [titleEn, setTitleEn] = useState("");
  const [titleTe, setTitleTe] = useState("");
  const [descEn, setDescEn] = useState("");
  const [descTe, setDescTe] = useState("");
  const [fileName, setFileName] = useState<string>("");
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [geographicAccess, setGeographicAccess] = useState<GeographicAccessData>({
    districtIds: [],
    mandalIds: [],
    assemblyConstituencyIds: [],
    parliamentaryConstituencyIds: [],
    postToAll: true,
  });
  const [links, setLinks] = useState<LinkItem[]>([{ platform: "Facebook", url: "" }]);

  // Edit form state
  const [editingNews, setEditingNews] = useState<NewsItem | null>(null);
  const [editCategory, setEditCategory] = useState<(typeof newsCategories)[number]>("Announcement");
  const [editTitleEn, setEditTitleEn] = useState("");
  const [editTitleTe, setEditTitleTe] = useState("");
  const [editDescEn, setEditDescEn] = useState("");
  const [editDescTe, setEditDescTe] = useState("");
  const [editImageFile, setEditImageFile] = useState<File | null>(null);
  const [editImagePreview, setEditImagePreview] = useState<string | null>(null);
  const [editFileName, setEditFileName] = useState<string>("");
  const [editImageRemoved, setEditImageRemoved] = useState(false);
  const [editIsPublished, setEditIsPublished] = useState(false);
  const [editGeographicAccess, setEditGeographicAccess] = useState<GeographicAccessData>({
    districtIds: [],
    mandalIds: [],
    assemblyConstituencyIds: [],
    parliamentaryConstituencyIds: [],
    postToAll: true,
  });
  const [editLinks, setEditLinks] = useState<LinkItem[]>([{ platform: "Facebook", url: "" }]);
  const [updating, setUpdating] = useState(false);
  const [deletingNews, setDeletingNews] = useState<NewsItem | null>(null);
  const [processing, setProcessing] = useState<string | null>(null);

  // Track if Telugu fields were manually edited
  const titleTeManualEdit = useRef(false);
  const descTeManualEdit = useRef(false);
  const editTitleTeManualEdit = useRef(false);
  const editDescTeManualEdit = useRef(false);

  // Location data for displaying publication details
  const [districts, setDistricts] = useState<District[]>([]);
  const [mandals, setMandals] = useState<Mandal[]>([]);
  const [parliamentaryConstituencies, setParliamentaryConstituencies] = useState<ParliamentaryConstituency[]>([]);
  const [assemblyConstituencies, setAssemblyConstituencies] = useState<any[]>([]);

  const estimatedReach = 15428; // placeholder to match screenshot

  // Load news items
  useEffect(() => {
    if (viewMode === "list") {
      loadNews();
    }
  }, [viewMode, currentPage]);

  // Load location data for displaying publication details
  useEffect(() => {
    const loadLocationData = async () => {
      try {
        const [districtsData, constituenciesData] = await Promise.all([
          districtsService.getDistricts({ state: 'Telangana', is_active: true }),
          constituencyService.getConstituencies({ state: 'Telangana', is_active: true }),
        ]);
        setDistricts(districtsData);
        setParliamentaryConstituencies(constituenciesData);
      } catch (error) {
        console.error('Failed to load location data:', error);
      }
    };
    loadLocationData();
  }, []);

  // Load mandals and assembly constituencies when needed
  useEffect(() => {
    const loadMandalsAndAssembly = async () => {
      if (newsItems.length === 0) return;
      
      try {
        // Collect all unique district IDs from news items
        const districtIds = new Set<number>();
        const parliamentIds = new Set<number>();
        
        newsItems.forEach(news => {
          news.districtIds?.forEach(id => districtIds.add(id));
          news.parliamentaryConstituencyIds?.forEach(id => parliamentIds.add(id));
        });

        // Load mandals for all districts
        if (districtIds.size > 0) {
          const allMandals: Mandal[] = [];
          for (const districtId of districtIds) {
            try {
              const mandalsForDistrict = await districtsService.getMandalsForDistrict(districtId, { is_active: true });
              allMandals.push(...mandalsForDistrict);
            } catch (error) {
              console.error(`Failed to load mandals for district ${districtId}:`, error);
            }
          }
          // Remove duplicates
          const uniqueMandals = Array.from(new Map(allMandals.map(m => [m.id, m])).values());
          setMandals(uniqueMandals);
        }

        // Load assembly constituencies for all parliamentary constituencies
        if (parliamentIds.size > 0) {
          const allAssembly: any[] = [];
          for (const parliamentId of parliamentIds) {
            try {
              const assemblyForParliament = await constituencyService.getAssemblyConstituencies({
                parliamentary_constituency_id: parliamentId,
                is_active: true,
              });
              allAssembly.push(...assemblyForParliament);
            } catch (error) {
              console.error(`Failed to load assembly constituencies for parliament ${parliamentId}:`, error);
            }
          }
          // Remove duplicates
          const uniqueAssembly = Array.from(new Map(allAssembly.map(a => [a.id, a])).values());
          setAssemblyConstituencies(uniqueAssembly);
        }
      } catch (error) {
        console.error('Failed to load mandals and assembly constituencies:', error);
      }
    };

    if (newsItems.length > 0) {
      loadMandalsAndAssembly();
    }
  }, [newsItems]);

  // Auto-translate Title English to Telugu
  useEffect(() => {
    if (!titleEn || titleTeManualEdit.current) {
      return;
    }
    
    const debouncedTranslate = translationService.createDebouncedTranslator(800);
    const currentTitleEn = titleEn;
    
    debouncedTranslate(currentTitleEn, (translated) => {
      if (!titleTeManualEdit.current) {
        setTitleTe(translated);
      }
    });
  }, [titleEn]);

  // Auto-translate Description English to Telugu
  useEffect(() => {
    if (!descEn || descTeManualEdit.current) {
      return;
    }
    
    const debouncedTranslate = translationService.createDebouncedTranslator(800);
    const currentDescEn = descEn;
    
    debouncedTranslate(currentDescEn, (translated) => {
      if (!descTeManualEdit.current) {
        setDescTe(translated);
      }
    });
  }, [descEn]);

  // Auto-translate Edit Title English to Telugu
  useEffect(() => {
    if (!editTitleEn || editTitleTeManualEdit.current) {
      return;
    }
    
    const debouncedTranslate = translationService.createDebouncedTranslator(800);
    const currentTitleEn = editTitleEn;
    
    debouncedTranslate(currentTitleEn, (translated) => {
      if (!editTitleTeManualEdit.current) {
        setEditTitleTe(translated);
      }
    });
  }, [editTitleEn]);

  // Auto-translate Edit Description English to Telugu
  useEffect(() => {
    if (!editDescEn || editDescTeManualEdit.current) {
      return;
    }
    
    const debouncedTranslate = translationService.createDebouncedTranslator(800);
    const currentDescEn = editDescEn;
    
    debouncedTranslate(currentDescEn, (translated) => {
      if (!editDescTeManualEdit.current) {
        setEditDescTe(translated);
      }
    });
  }, [editDescEn]);

  // Create and cleanup image preview URL
  useEffect(() => {
    if (imageFile) {
      const objectUrl = URL.createObjectURL(imageFile);
      setImagePreview(objectUrl);

      // Cleanup function to revoke the object URL
      return () => URL.revokeObjectURL(objectUrl);
    } else {
      setImagePreview(null);
    }
  }, [imageFile]);

  // Create and cleanup edit image preview URL
  useEffect(() => {
    if (editImageFile) {
      const objectUrl = URL.createObjectURL(editImageFile);
      setEditImagePreview(objectUrl);

      // Cleanup function to revoke the object URL
      return () => URL.revokeObjectURL(objectUrl);
    } else if (editingNews?.image) {
      setEditImagePreview(editingNews.image);
    } else {
      setEditImagePreview(null);
    }
  }, [editImageFile, editingNews]);

  // Load news items
  const loadNews = async () => {
    setLoadingNews(true);
    setError(null);
    try {
      const response = await adminService.getAllNews({
        page: currentPage,
        per_page: 20,
      });
      setNewsItems(response.news);
      setTotalPages(response.pages);
      setTotalNews(response.total);
    } catch (err: any) {
      console.error("Failed to load news:", err);
      setError(err.response?.data?.message || "Failed to load news. Please try again.");
    } finally {
      setLoadingNews(false);
    }
  };

  // Remove uploaded image
  const removeImage = () => {
    setImageFile(null);
    setFileName("");
    setImagePreview(null);
    // Reset the file input
    const fileInput = document.getElementById('content-image') as HTMLInputElement;
    if (fileInput) fileInput.value = '';
  };

  // Remove edit uploaded image
  const removeEditImage = () => {
    setEditImageFile(null);
    setEditFileName("");
    setEditImagePreview(null);
    setEditImageRemoved(true);
    // Reset the file input
    const fileInput = document.getElementById('edit-content-image') as HTMLInputElement;
    if (fileInput) fileInput.value = '';
  };

  // Open edit modal
  const handleEdit = (news: NewsItem) => {
    setEditingNews(news);
    // Set category - capitalize first letter to match our category options
    const newsCategory = news.category ? news.category.charAt(0).toUpperCase() + news.category.slice(1).toLowerCase() : "Announcement";
    setEditCategory((newsCategories.includes(newsCategory as any) ? newsCategory : "Announcement") as typeof newsCategories[number]);
    setEditTitleEn(news.title.en);
    setEditTitleTe(news.title.te);
    setEditDescEn(news.description.en);
    setEditDescTe(news.description.te);
    setEditIsPublished(news.isPublished);
    setEditImagePreview(news.image || null);
    setEditImageFile(null);
    setEditFileName("");
    setEditImageRemoved(false);
    setEditGeographicAccess({
      districtIds: news.districtIds || [],
      mandalIds: news.mandalIds || [],
      assemblyConstituencyIds: news.assemblyConstituencyIds || [],
      parliamentaryConstituencyIds: news.parliamentaryConstituencyIds || [],
      postToAll: !news.districtIds?.length && !news.mandalIds?.length && !news.assemblyConstituencyIds?.length && !news.parliamentaryConstituencyIds?.length,
    });
    // Load links from news item
    setEditLinks((news as any).links && Array.isArray((news as any).links) && (news as any).links.length > 0 
      ? (news as any).links 
      : [{ platform: "Facebook", url: "" }]);
    editTitleTeManualEdit.current = false;
    editDescTeManualEdit.current = false;
  };

  // Add a new link
  const addLink = () => {
    setLinks([...links, { platform: "Facebook", url: "" }]);
  };

  // Remove a link
  const removeLink = (index: number) => {
    setLinks(links.filter((_, i) => i !== index));
  };

  // Update a link
  const updateLink = (index: number, field: keyof LinkItem, value: string) => {
    const updatedLinks = [...links];
    updatedLinks[index] = { ...updatedLinks[index], [field]: value };
    setLinks(updatedLinks);
  };

  // Add a new edit link
  const addEditLink = () => {
    setEditLinks([...editLinks, { platform: "Facebook", url: "" }]);
  };

  // Remove an edit link
  const removeEditLink = (index: number) => {
    setEditLinks(editLinks.filter((_, i) => i !== index));
  };

  // Update an edit link
  const updateEditLink = (index: number, field: keyof LinkItem, value: string) => {
    const updatedLinks = [...editLinks];
    updatedLinks[index] = { ...updatedLinks[index], [field]: value };
    setEditLinks(updatedLinks);
  };

  // Handle update news
  const handleUpdateNews = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingNews) return;

    setUpdating(true);
    setError(null);
    setSuccess(false);

    try {
      // Prepare links - filter out empty ones
      const validEditLinks = editLinks.filter(link => link.url && link.url.trim());

      const payload: any = {
        title_en: editTitleEn,
        title_te: editTitleTe.trim() || editTitleEn,
        description_en: editDescEn || editTitleEn,
        description_te: editDescTe.trim() || editDescEn || editTitleEn,
        is_published: editIsPublished,
        category: editCategory.toLowerCase(),
        districtIds: editGeographicAccess.postToAll ? undefined : (editGeographicAccess.districtIds.length > 0 ? editGeographicAccess.districtIds : undefined),
        mandalIds: editGeographicAccess.postToAll ? undefined : (editGeographicAccess.mandalIds.length > 0 ? editGeographicAccess.mandalIds : undefined),
        assemblyConstituencyIds: editGeographicAccess.postToAll ? undefined : (editGeographicAccess.assemblyConstituencyIds.length > 0 ? editGeographicAccess.assemblyConstituencyIds : undefined),
        parliamentaryConstituencyIds: editGeographicAccess.postToAll ? undefined : (editGeographicAccess.parliamentaryConstituencyIds.length > 0 ? editGeographicAccess.parliamentaryConstituencyIds : undefined),
        // Add links
        links: validEditLinks.length > 0 ? validEditLinks : undefined,
      };

      // Handle image upload/removal
      if (editImageFile) {
        // New image uploaded - just upload to S3, don't create MediaItem record
        try {
          console.log("Uploading news image to S3:", editImageFile.name);
          
          // Upload directly to S3 in 'news' folder - returns URL without creating MediaItem
          const uploadResult = await mediaService.uploadFile(editImageFile, 'photo', "news");
          
          payload.image_url = uploadResult.url;
          console.log("News image uploaded successfully:", uploadResult.url);
        } catch (uploadErr) {
          console.error("Image upload failed:", uploadErr);
          setError("Failed to upload image. News will be updated without new image.");
        }
      } else if (editImageRemoved) {
        // Image was removed - set to null to clear it
        payload.image_url = null;
      } else if (editingNews.image) {
        // Preserve existing image if no changes were made
        payload.image_url = editingNews.image;
      }

      await adminService.updateNewsItem(editingNews.id, payload);

      setSuccess(true);
      setTimeout(() => {
        setEditingNews(null);
        setEditTitleEn("");
        setEditTitleTe("");
        setEditDescEn("");
        setEditDescTe("");
        setEditImageFile(null);
        setEditImagePreview(null);
        setEditFileName("");
        setEditImageRemoved(false);
        setEditIsPublished(false);
        setEditGeographicAccess({
          districtIds: [],
          mandalIds: [],
          assemblyConstituencyIds: [],
          parliamentaryConstituencyIds: [],
          postToAll: true,
        });
        setEditLinks([{ platform: "Facebook", url: "" }]);
        editTitleTeManualEdit.current = false;
        editDescTeManualEdit.current = false;
        setSuccess(false);
        loadNews();
      }, 1500);
    } catch (err: any) {
      console.error("Failed to update news:", err);
      setError(err.response?.data?.message || "Failed to update news. Please try again.");
    } finally {
      setUpdating(false);
    }
  };

  // Handle delete news
  const handleDeleteConfirm = async () => {
    if (!deletingNews) return;

    setProcessing(deletingNews.id);
    setError(null);
    setSuccess(false);

    try {
      await adminService.deleteNewsItem(deletingNews.id);
      setSuccess(true);
      setTimeout(() => {
        setDeletingNews(null);
        setSuccess(false);
        loadNews();
      }, 1500);
    } catch (err: any) {
      console.error("Failed to delete news:", err);
      setError(err.response?.data?.message || "Failed to delete news. Please try again.");
    } finally {
      setProcessing(null);
    }
  };

  // Map audience to roles
  const getRolesFromAudience = () => {
    if (audience === "All Members") return ["public", "cadre", "admin"];
    if (audience === "Cadre Only") return ["cadre", "admin"];
    if (audience === "Public") return ["public"];
    return [];
  };

  // Helper function to get location names from IDs
  const getLocationNames = (news: NewsItem) => {
    const locations: string[] = [];
    
    // Check if published to all (no geographic restrictions)
    const hasGeographicRestrictions = 
      (news.districtIds && news.districtIds.length > 0) ||
      (news.mandalIds && news.mandalIds.length > 0) ||
      (news.assemblyConstituencyIds && news.assemblyConstituencyIds.length > 0) ||
      (news.parliamentaryConstituencyIds && news.parliamentaryConstituencyIds.length > 0);

    if (!hasGeographicRestrictions) {
      locations.push("All Locations");
      return locations;
    }

    // Get district names
    if (news.districtIds && news.districtIds.length > 0) {
      const districtNames = news.districtIds
        .map(id => {
          const district = districts.find(d => d.id === id);
          return district?.name_en || `District #${id}`;
        });
      if (districtNames.length > 0) {
        const displayText = districtNames.length > 3 
          ? `${districtNames.slice(0, 3).join(", ")} +${districtNames.length - 3} more`
          : districtNames.join(", ");
        locations.push(`Districts: ${displayText}`);
      }
    }

    // Get mandal names
    if (news.mandalIds && news.mandalIds.length > 0) {
      const mandalNames = news.mandalIds
        .map(id => {
          const mandal = mandals.find(m => m.id === id);
          return mandal?.name_en || `Mandal #${id}`;
        });
      if (mandalNames.length > 0) {
        const displayText = mandalNames.length > 3 
          ? `${mandalNames.slice(0, 3).join(", ")} +${mandalNames.length - 3} more`
          : mandalNames.join(", ");
        locations.push(`Mandals: ${displayText}`);
      }
    }

    // Get parliamentary constituency names
    if (news.parliamentaryConstituencyIds && news.parliamentaryConstituencyIds.length > 0) {
      const parliamentNames = news.parliamentaryConstituencyIds
        .map(id => {
          const parliament = parliamentaryConstituencies.find(p => p.id === id);
          return parliament?.name_en || `Parliament #${id}`;
        });
      if (parliamentNames.length > 0) {
        const displayText = parliamentNames.length > 3 
          ? `${parliamentNames.slice(0, 3).join(", ")} +${parliamentNames.length - 3} more`
          : parliamentNames.join(", ");
        locations.push(`Parliamentary Constituencies: ${displayText}`);
      }
    }

    // Get assembly constituency names
    if (news.assemblyConstituencyIds && news.assemblyConstituencyIds.length > 0) {
      const assemblyNames = news.assemblyConstituencyIds
        .map(id => {
          const assembly = assemblyConstituencies.find(a => a.id === id);
          return assembly?.name_en || `Assembly #${id}`;
        });
      if (assemblyNames.length > 0) {
        const displayText = assemblyNames.length > 3 
          ? `${assemblyNames.slice(0, 3).join(", ")} +${assemblyNames.length - 3} more`
          : assemblyNames.join(", ");
        locations.push(`Assembly Constituencies: ${displayText}`);
      }
    }

    return locations.length > 0 ? locations : ["All Locations"];
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    // Reset messages
    setSuccess(false);
    setError(null);

    // Validation
    if (!titleEn.trim()) {
      setError("Title (English) is required");
      return;
    }

    setLoading(true);

    try {
      // Prepare links - filter out empty ones
      const validLinks = links.filter(link => link.url && link.url.trim());

      // Prepare the payload
      const payload: any = {
        title: titleEn,
        title_te: titleTe.trim() || titleEn, // Use English as fallback
        message: descEn || titleEn,
        description_te: descTe.trim() || descEn || titleEn, // Use English as fallback
        target_roles: getRolesFromAudience(),
        content_type: "news",
        category: category.toLowerCase(),
        // Add geographic access fields
        districtIds: geographicAccess.postToAll ? undefined : (geographicAccess.districtIds.length > 0 ? geographicAccess.districtIds : undefined),
        mandalIds: geographicAccess.postToAll ? undefined : (geographicAccess.mandalIds.length > 0 ? geographicAccess.mandalIds : undefined),
        assemblyConstituencyIds: geographicAccess.postToAll ? undefined : (geographicAccess.assemblyConstituencyIds.length > 0 ? geographicAccess.assemblyConstituencyIds : undefined),
        parliamentaryConstituencyIds: geographicAccess.postToAll ? undefined : (geographicAccess.parliamentaryConstituencyIds.length > 0 ? geographicAccess.parliamentaryConstituencyIds : undefined),
        // Add links
        links: validLinks.length > 0 ? validLinks : undefined,
      };

      // Handle image upload - just upload to S3, don't create MediaItem record
      if (imageFile) {
        try {
          console.log("Uploading news image to S3:", imageFile.name);
          
          // Upload directly to S3 in 'news' folder - returns URL without creating MediaItem
          const uploadResult = await mediaService.uploadFile(imageFile, 'photo', "news");
          
          payload.image_url = uploadResult.url;
          console.log("News image uploaded successfully:", uploadResult.url);
        } catch (uploadErr) {
          console.error("Image upload failed:", uploadErr);
          setError("Failed to upload image. Content will be pushed without image.");
          // Continue without image
        }
      }

      // Still push the content notification
      await adminService.pushContent(payload);

      setSuccess(true);
      
      // Clear form after success
      setTimeout(() => {
        setCategory("Announcement");
        setTitleEn("");
        setTitleTe("");
        setDescEn("");
        setDescTe("");
        setFileName("");
        setImageFile(null);
        setImagePreview(null);
        setGeographicAccess({
          districtIds: [],
          mandalIds: [],
          assemblyConstituencyIds: [],
          parliamentaryConstituencyIds: [],
          postToAll: true,
        });
        setLinks([{ platform: "Facebook", url: "" }]);
        titleTeManualEdit.current = false;
        descTeManualEdit.current = false;
        setSuccess(false);
        // Reset file input
        const fileInput = document.getElementById('content-image') as HTMLInputElement;
        if (fileInput) fileInput.value = '';
        // Reload news list if in list view
        if (viewMode === "list") {
          loadNews();
        }
      }, 3000);
      
    } catch (err: any) {
      console.error("Failed to push content:", err);
      setError(err.response?.data?.message || "Failed to push content. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-xl sm:text-2xl font-semibold">News Management</h1>
          <p className="text-xs sm:text-sm text-gray-500">
            {viewMode === "create" ? "Create and publish news articles" : "Manage existing news articles"}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setViewMode(viewMode === "list" ? "create" : "list")}
            className={`flex items-center gap-2 px-4 py-2 rounded-md transition-colors text-sm sm:text-base ${
              viewMode === "list"
                ? "bg-gray-100 text-gray-700 hover:bg-gray-200"
                : "bg-orange-500 text-white hover:bg-orange-600"
            }`}
          >
            {viewMode === "list" ? (
              <>
                <Plus className="w-4 h-4" />
                Create News
              </>
            ) : (
              <>
                <List className="w-4 h-4" />
                View All News
              </>
            )}
          </button>
        </div>
      </div>

      {/* Success Message */}
      {success && (
        <div className="bg-green-50 border border-green-200 rounded-lg p-4 flex items-center gap-3">
          <CheckCircle className="w-5 h-5 text-green-600" />
          <div>
            <div className="font-medium text-green-900">News Published Successfully!</div>
            <div className="text-sm text-green-700">Your news article has been published and is now visible to members.</div>
          </div>
        </div>
      )}

      {/* Error Message */}
      {error && (
        <div className="bg-red-50 border border-red-200 rounded-lg p-4 flex items-center gap-3">
          <AlertCircle className="w-5 h-5 text-red-600" />
          <div>
            <div className="font-medium text-red-900">Error</div>
            <div className="text-sm text-red-700">{error}</div>
          </div>
        </div>
      )}

      {/* List View */}
      {viewMode === "list" && (
        <div className="space-y-4">
          {/* Stats */}
          <div className="bg-white rounded-lg shadow-card p-4">
            <div className="text-sm text-gray-600">Total News Articles</div>
            <div className="text-3xl font-semibold text-orange-600 mt-2">{totalNews}</div>
          </div>

          {/* News List */}
          {loadingNews ? (
            <div className="bg-white rounded-lg shadow-card p-8 text-center">
              <div className="animate-spin text-orange-500 text-2xl mb-2">⏳</div>
              <div className="text-gray-600">Loading news articles...</div>
            </div>
          ) : newsItems.length === 0 ? (
            <div className="bg-white rounded-lg shadow-card p-8 text-center">
              <Megaphone className="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <div className="text-gray-600">No news articles found</div>
              <button
                onClick={() => setViewMode("create")}
                className="mt-4 px-4 py-2 bg-orange-500 text-white rounded-md hover:bg-orange-600"
              >
                Create First News Article
              </button>
            </div>
          ) : (
            <div className="grid grid-cols-1 gap-4">
              {newsItems.map((news) => (
                <div key={news.id} className="bg-white rounded-lg shadow-card p-4">
                  <div className="flex flex-col sm:flex-row sm:items-start gap-4">
                    {/* Image */}
                    {news.image && (
                      <div className="flex-shrink-0">
                        <img
                          src={news.image}
                          alt={news.title.en}
                          className="w-full sm:w-32 h-32 object-cover rounded-lg"
                        />
                      </div>
                    )}
                    
                    {/* Content */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-start justify-between gap-2 mb-2">
                        <div className="flex-1 min-w-0">
                          <h3 className="font-semibold text-lg text-gray-900 truncate">
                            {news.title.en}
                          </h3>
                          <p className="text-sm text-gray-600 mt-1 line-clamp-2">
                            {news.description.en}
                          </p>
                        </div>
                        <div className="flex items-center gap-2 flex-shrink-0">
                          {news.isPublished ? (
                            <span className="px-2 py-1 text-xs bg-green-100 text-green-700 rounded-full flex items-center gap-1">
                              <Eye className="w-3 h-3" />
                              Published
                            </span>
                          ) : (
                            <span className="px-2 py-1 text-xs bg-gray-100 text-gray-700 rounded-full flex items-center gap-1">
                              <EyeOff className="w-3 h-3" />
                              Draft
                            </span>
                          )}
                        </div>
                      </div>
                      
                      {/* Publication Details */}
                      <div className="mt-3 pt-3 border-t border-gray-200">
                        <div className="flex flex-col gap-2.5">
                          {/* Audience */}
                          <div className="flex items-start gap-2">
                            <Users className="w-4 h-4 text-orange-500 mt-0.5 flex-shrink-0" />
                            <div className="flex-1 min-w-0">
                              <div className="text-xs font-semibold text-gray-700 mb-0.5">Published To:</div>
                              <div className="text-xs text-gray-600 bg-gray-50 px-2 py-1 rounded inline-block">
                                All Members
                              </div>
                            </div>
                          </div>
                          
                          {/* Geographic Locations */}
                          <div className="flex items-start gap-2">
                            <MapPin className="w-4 h-4 text-orange-500 mt-0.5 flex-shrink-0" />
                            <div className="flex-1 min-w-0">
                              <div className="text-xs font-semibold text-gray-700 mb-0.5">Published In:</div>
                              <div className="text-xs text-gray-600 space-y-1">
                                {getLocationNames(news).map((location, idx) => (
                                  <div key={idx} className="bg-gray-50 px-2 py-1 rounded">
                                    {location}
                                  </div>
                                ))}
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>

                      <div className="flex items-center justify-between mt-4">
                        <div className="text-xs text-gray-500">
                          {new Date(news.date).toLocaleDateString()}
                        </div>
                        <div className="flex items-center gap-2">
                          <button
                            onClick={() => handleEdit(news)}
                            disabled={processing === news.id}
                            className="p-2 text-blue-600 hover:bg-blue-50 rounded-md disabled:opacity-50"
                            title="Edit"
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() => setDeletingNews(news)}
                            disabled={processing === news.id}
                            className="p-2 text-red-600 hover:bg-red-50 rounded-md disabled:opacity-50"
                            title="Delete"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="flex items-center justify-center gap-2">
              <button
                onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
                disabled={currentPage === 1 || loadingNews}
                className="px-4 py-2 rounded-md border disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
              >
                Previous
              </button>
              <span className="px-4 py-2 text-sm text-gray-600">
                Page {currentPage} of {totalPages}
              </span>
              <button
                onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
                disabled={currentPage === totalPages || loadingNews}
                className="px-4 py-2 rounded-md border disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
              >
                Next
              </button>
            </div>
          )}
        </div>
      )}

      {/* Create Form */}
      {viewMode === "create" && (
      <form onSubmit={handleSubmit}>
        <div className="grid grid-cols-12 gap-6">
          {/* Left: Form */}
          <div className="col-span-8 space-y-4">
            <div className="bg-white rounded-lg shadow-card p-4 space-y-4">
            {/* Title English */}
            <div>
              <label className="text-sm font-medium">Title (English) *</label>
              <input
                className="mt-1 w-full px-3 py-2 rounded-md border bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                placeholder="Enter title in English"
                value={titleEn}
                onChange={(e) => setTitleEn(e.target.value)}
              />
            </div>

            {/* Title Telugu */}
            <div>
              <label className="text-sm font-medium">Title (Telugu) *</label>
              <input
                className="mt-1 w-full px-3 py-2 rounded-md border bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                placeholder="తెలుగులో శీర్షికను నమోదు చేయండి (Auto-translated)"
                value={titleTe}
                onChange={(e) => {
                  setTitleTe(e.target.value);
                  titleTeManualEdit.current = true;
                }}
              />
            </div>

            {/* Category */}
            <div>
              <label className="text-sm font-medium">Category *</label>
              <select
                className="mt-1 w-full px-3 py-2 rounded-md border bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                value={category}
                onChange={(e) => setCategory(e.target.value as typeof newsCategories[number])}
              >
                {newsCategories.map((cat) => (
                  <option key={cat} value={cat}>
                    {cat}
                  </option>
                ))}
              </select>
            </div>

            {/* Description English */}
            <div>
              <label className="text-sm font-medium">Description (English)</label>
              <textarea
                className="mt-1 w-full px-3 py-2 rounded-md border bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                rows={3}
                placeholder="Enter description in English"
                value={descEn}
                onChange={(e) => setDescEn(e.target.value)}
              />
            </div>

            {/* Description Telugu */}
            <div>
              <label className="text-sm font-medium">Description (Telugu)</label>
              <textarea
                className="mt-1 w-full px-3 py-2 rounded-md border bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                rows={3}
                placeholder="తెలుగులో వివరణను నమోదు చేయండి (Auto-translated)"
                value={descTe}
                onChange={(e) => {
                  setDescTe(e.target.value);
                  descTeManualEdit.current = true;
                }}
              />
            </div>

            {/* Upload Image */}
            <div>
              <label className="text-sm font-medium">Upload Image</label>
              
              {/* Upload Area - only show if no preview */}
              {!imagePreview && (
                <label
                  htmlFor="content-image"
                  className="mt-1 block h-40 rounded-md border border-dashed flex flex-col items-center justify-center text-gray-600 cursor-pointer hover:bg-gray-50"
                >
                  <UploadCloud className="w-6 h-6 mb-2" />
                  <span className="text-sm">
                    {fileName || "Click to upload or drag and drop"}
                  </span>
                  <span className="text-xs text-gray-500">PNG, JPG up to 5MB</span>
                </label>
              )}
              
              {/* Image Preview */}
              {imagePreview && (
                <div className="mt-1 relative">
                  <div className="rounded-lg border border-gray-300 overflow-hidden bg-gray-50">
                    <img
                      src={imagePreview}
                      alt="Preview"
                      className="w-full h-auto max-h-96 object-contain"
                    />
                  </div>
                  
                  {/* Image Info and Remove Button */}
                  <div className="mt-2 flex items-center justify-between bg-gray-50 p-3 rounded-md border border-gray-200">
                    <div className="flex items-center gap-2 flex-1 min-w-0">
                      <CheckCircle className="w-4 h-4 text-green-600 flex-shrink-0" />
                      <span className="text-sm text-gray-700 truncate">{fileName}</span>
                    </div>
                    <button
                      type="button"
                      onClick={removeImage}
                      className="ml-2 p-1.5 rounded-md hover:bg-red-50 text-red-600 hover:text-red-700 flex-shrink-0"
                      title="Remove image"
                    >
                      <X className="w-4 h-4" />
                    </button>
                  </div>
                  
                  {/* Change Image Button */}
                  <label
                    htmlFor="content-image"
                    className="mt-2 inline-flex items-center gap-2 px-3 py-2 text-sm rounded-md border border-gray-300 hover:bg-gray-50 cursor-pointer"
                  >
                    <UploadCloud className="w-4 h-4" />
                    Change Image
                  </label>
                </div>
              )}
              
              <input
                id="content-image"
                type="file"
                accept="image/png, image/jpeg, image/jpg, image/webp"
                className="hidden"
                onChange={(e) => {
                  const f = e.target.files?.[0];
                  if (f) {
                    // Validate file size (5MB)
                    if (f.size > 5 * 1024 * 1024) {
                      setError("Image size must be less than 5MB");
                      e.target.value = '';
                      return;
                    }
                    setFileName(f.name);
                    setImageFile(f);
                  } else {
                    setFileName("");
                    setImageFile(null);
                  }
                }}
              />
            </div>

            {/* Links Section */}
            <div>
              <label className="text-sm font-medium">Social Media & External Links</label>
              <div className="mt-2 space-y-3">
                {links.map((link, index) => (
                  <div key={index} className="flex gap-2 items-start">
                    <div className="flex-1">
                      <select
                        className="w-full px-3 py-2 rounded-md border bg-white text-gray-900 text-sm focus:outline-none focus:ring-2 focus:ring-orange-300 mb-2"
                        value={link.platform}
                        onChange={(e) => updateLink(index, 'platform', e.target.value)}
                      >
                        {socialMediaPlatforms.map((platform) => (
                          <option key={platform} value={platform}>
                            {platform}
                          </option>
                        ))}
                      </select>
                      <input
                        type="url"
                        className="w-full px-3 py-2 rounded-md border bg-white text-gray-900 text-sm focus:outline-none focus:ring-2 focus:ring-orange-300"
                        placeholder={link.platform === "Other" ? "Enter URL" : `Enter ${link.platform} URL`}
                        value={link.url}
                        onChange={(e) => updateLink(index, 'url', e.target.value)}
                      />
                    </div>
                    {links.length > 1 && (
                      <button
                        type="button"
                        onClick={() => removeLink(index)}
                        className="mt-7 p-2 text-red-600 hover:bg-red-50 rounded-md"
                        title="Remove link"
                      >
                        <X className="w-4 h-4" />
                      </button>
                    )}
                  </div>
                ))}
                <button
                  type="button"
                  onClick={addLink}
                  className="flex items-center gap-2 px-3 py-2 text-sm rounded-md border border-gray-300 hover:bg-gray-50 text-gray-700"
                >
                  <Plus className="w-4 h-4" />
                  Add Another Link
                </button>
              </div>
            </div>
          </div>

          {/* Submit */}
          <div>
            <button 
              type="submit"
              disabled={loading}
              className="flex items-center gap-2 px-4 py-3 rounded-md bg-orange-500 text-white hover:bg-orange-600 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? (
                <>
                  <span className="animate-spin">⏳</span>
                  Sending...
                </>
              ) : (
                <>
                  <Megaphone className="w-4 h-4" />
                  Publish News
                </>
              )}
            </button>
          </div>
        </div>

        {/* Right: Audience + Reach */}
        <div className="col-span-4 space-y-4">
          {/* Target Audience */}
          <div className="bg-white rounded-lg shadow-card p-4 space-y-3">
            <div className="font-medium">Target Audience</div>

            {/* Audience Type */}
            <div className="space-y-1">
              <div className="text-sm text-gray-600">Audience Type</div>
              <div className="relative">
                <select
                  className="appearance-none w-full pl-3 pr-8 py-2 rounded-md border text-sm focus:outline-none focus:ring-2 focus:ring-orange-300"
                  value={audience}
                  onChange={(e) => setAudience(e.target.value as (typeof audienceTypes)[number])}
                >
                  {audienceTypes.map((a) => (
                    <option key={a} value={a}>
                      {a}
                    </option>
                  ))}
                </select>
                <span className="absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none">▾</span>
              </div>
            </div>
          </div>

          {/* Geographic Access Control */}
          <div className="bg-white rounded-lg shadow-card p-4 space-y-3">
            <div className="font-medium">Geographic Access</div>
            <GeographicAccessSelector
              value={geographicAccess}
              onChange={setGeographicAccess}
              disabled={loading}
            />
          </div>

          {/* Estimated Reach */}
          <div className="bg-orange-50 rounded-lg shadow-card p-4">
            <div className="text-sm text-gray-700">Estimated Reach</div>
            <div className="text-3xl font-semibold text-orange-600 mt-2">{estimatedReach.toLocaleString()}</div>
            <div className="text-xs text-gray-600 mt-1">members will receive this content</div>
            </div>
          </div>
        </div>
      </form>
      )}

      {/* Edit Modal */}
      {editingNews && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg shadow-xl max-w-4xl w-full max-h-[90vh] overflow-y-auto">
            <div className="sticky top-0 bg-white border-b p-4 flex items-center justify-between">
              <h2 className="text-xl font-semibold">Edit News Article</h2>
              <button
                onClick={() => {
                  setEditingNews(null);
                  setEditTitleEn("");
                  setEditTitleTe("");
                  setEditDescEn("");
                  setEditDescTe("");
                  setEditImageFile(null);
                  setEditImagePreview(null);
                  setEditFileName("");
                  setEditImageRemoved(false);
                  setEditIsPublished(false);
                  setEditGeographicAccess({
                    districtIds: [],
                    mandalIds: [],
                    assemblyConstituencyIds: [],
                    parliamentaryConstituencyIds: [],
                    postToAll: true,
                  });
                  setEditLinks([{ platform: "Facebook", url: "" }]);
                  editTitleTeManualEdit.current = false;
                  editDescTeManualEdit.current = false;
                }}
                className="p-2 hover:bg-gray-100 rounded-md"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleUpdateNews} className="p-4 space-y-4">
              <div className="grid grid-cols-12 gap-6">
                {/* Left: Form */}
                <div className="col-span-8 space-y-4">
                  <div className="bg-gray-50 rounded-lg p-4 space-y-4">
                    {/* Title English */}
                    <div>
                      <label className="text-sm font-medium">Title (English) *</label>
                      <input
                        className="mt-1 w-full px-3 py-2 rounded-md border bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                        placeholder="Enter title in English"
                        value={editTitleEn}
                        onChange={(e) => setEditTitleEn(e.target.value)}
                        required
                      />
                    </div>

                    {/* Title Telugu */}
                    <div>
                      <label className="text-sm font-medium">Title (Telugu) *</label>
                      <input
                        className="mt-1 w-full px-3 py-2 rounded-md border bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                        placeholder="తెలుగులో శీర్షికను నమోదు చేయండి (Auto-translated)"
                        value={editTitleTe}
                        onChange={(e) => {
                          setEditTitleTe(e.target.value);
                          editTitleTeManualEdit.current = true;
                        }}
                        required
                      />
                    </div>

                    {/* Description English */}
                    <div>
                      <label className="text-sm font-medium">Description (English)</label>
                      <textarea
                        className="mt-1 w-full px-3 py-2 rounded-md border bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                        rows={3}
                        placeholder="Enter description in English"
                        value={editDescEn}
                        onChange={(e) => setEditDescEn(e.target.value)}
                      />
                    </div>

                    {/* Description Telugu */}
                    <div>
                      <label className="text-sm font-medium">Description (Telugu)</label>
                      <textarea
                        className="mt-1 w-full px-3 py-2 rounded-md border bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                        rows={3}
                        placeholder="తెలుగులో వివరణను నమోదు చేయండి (Auto-translated)"
                        value={editDescTe}
                        onChange={(e) => {
                          setEditDescTe(e.target.value);
                          editDescTeManualEdit.current = true;
                        }}
                      />
                    </div>

                    {/* Upload Image */}
                    <div>
                      <label className="text-sm font-medium">Image</label>
                      
                      {/* Current Image or Upload Area */}
                      {!editImagePreview && !editingNews.image && (
                        <label
                          htmlFor="edit-content-image"
                          className="mt-1 block h-40 rounded-md border border-dashed flex flex-col items-center justify-center text-gray-600 cursor-pointer hover:bg-gray-50"
                        >
                          <UploadCloud className="w-6 h-6 mb-2" />
                          <span className="text-sm">
                            {editFileName || "Click to upload or drag and drop"}
                          </span>
                          <span className="text-xs text-gray-500">PNG, JPG up to 5MB</span>
                        </label>
                      )}
                      
                      {/* Image Preview */}
                      {editImagePreview && (
                        <div className="mt-1 relative">
                          <div className="rounded-lg border border-gray-300 overflow-hidden bg-gray-50">
                            <img
                              src={editImagePreview}
                              alt="Preview"
                              className="w-full h-auto max-h-96 object-contain"
                            />
                          </div>
                          
                          {/* Image Info and Remove Button */}
                          <div className="mt-2 flex items-center justify-between bg-gray-50 p-3 rounded-md border border-gray-200">
                            <div className="flex items-center gap-2 flex-1 min-w-0">
                              <CheckCircle className="w-4 h-4 text-green-600 flex-shrink-0" />
                              <span className="text-sm text-gray-700 truncate">
                                {editFileName || "Current image"}
                              </span>
                            </div>
                            <button
                              type="button"
                              onClick={removeEditImage}
                              className="ml-2 p-1.5 rounded-md hover:bg-red-50 text-red-600 hover:text-red-700 flex-shrink-0"
                              title="Remove image"
                            >
                              <X className="w-4 h-4" />
                            </button>
                          </div>
                          
                          {/* Change Image Button */}
                          <label
                            htmlFor="edit-content-image"
                            className="mt-2 inline-flex items-center gap-2 px-3 py-2 text-sm rounded-md border border-gray-300 hover:bg-gray-50 cursor-pointer"
                          >
                            <UploadCloud className="w-4 h-4" />
                            Change Image
                          </label>
                        </div>
                      )}
                      
                      <input
                        id="edit-content-image"
                        type="file"
                        accept="image/png, image/jpeg, image/jpg, image/webp"
                        className="hidden"
                        onChange={(e) => {
                          const f = e.target.files?.[0];
                          if (f) {
                            if (f.size > 5 * 1024 * 1024) {
                              setError("Image size must be less than 5MB");
                              e.target.value = '';
                              return;
                            }
                            setEditFileName(f.name);
                            setEditImageFile(f);
                            setEditImageRemoved(false); // Reset removal flag if new image selected
                          } else {
                            setEditFileName("");
                            setEditImageFile(null);
                          }
                        }}
                      />
                    </div>

                    {/* Links Section */}
                    <div>
                      <label className="text-sm font-medium">Social Media & External Links</label>
                      <div className="mt-2 space-y-3">
                        {editLinks.map((link, index) => (
                          <div key={index} className="flex gap-2 items-start">
                            <div className="flex-1">
                              <select
                                className="w-full px-3 py-2 rounded-md border bg-white text-gray-900 text-sm focus:outline-none focus:ring-2 focus:ring-orange-300 mb-2"
                                value={link.platform}
                                onChange={(e) => updateEditLink(index, 'platform', e.target.value)}
                              >
                                {socialMediaPlatforms.map((platform) => (
                                  <option key={platform} value={platform}>
                                    {platform}
                                  </option>
                                ))}
                              </select>
                              <input
                                type="url"
                                className="w-full px-3 py-2 rounded-md border bg-white text-gray-900 text-sm focus:outline-none focus:ring-2 focus:ring-orange-300"
                                placeholder={link.platform === "Other" ? "Enter URL" : `Enter ${link.platform} URL`}
                                value={link.url}
                                onChange={(e) => updateEditLink(index, 'url', e.target.value)}
                              />
                            </div>
                            {editLinks.length > 1 && (
                              <button
                                type="button"
                                onClick={() => removeEditLink(index)}
                                className="mt-7 p-2 text-red-600 hover:bg-red-50 rounded-md"
                                title="Remove link"
                              >
                                <X className="w-4 h-4" />
                              </button>
                            )}
                          </div>
                        ))}
                        <button
                          type="button"
                          onClick={addEditLink}
                          className="flex items-center gap-2 px-3 py-2 text-sm rounded-md border border-gray-300 hover:bg-gray-50 text-gray-700"
                        >
                          <Plus className="w-4 h-4" />
                          Add Another Link
                        </button>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Right: Settings */}
                <div className="col-span-4 space-y-4">
                  {/* Publish Status */}
                  <div className="bg-white rounded-lg shadow-card p-4 space-y-3">
                    <div className="font-medium">Publish Status</div>
                    <label className="flex items-center gap-2 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={editIsPublished}
                        onChange={(e) => setEditIsPublished(e.target.checked)}
                        className="w-4 h-4 text-orange-500 rounded focus:ring-orange-300"
                      />
                      <span className="text-sm">Published</span>
                    </label>
                  </div>

                  {/* Geographic Access Control */}
                  <div className="bg-white rounded-lg shadow-card p-4 space-y-3">
                    <div className="font-medium">Geographic Access</div>
                    <GeographicAccessSelector
                      value={editGeographicAccess}
                      onChange={setEditGeographicAccess}
                      disabled={updating}
                    />
                  </div>
                </div>
              </div>

              {/* Actions */}
              <div className="flex items-center justify-end gap-3 pt-4 border-t">
                <button
                  type="button"
                  onClick={() => {
                    setEditingNews(null);
                    setEditTitleEn("");
                    setEditTitleTe("");
                    setEditDescEn("");
                    setEditDescTe("");
                    setEditImageFile(null);
                    setEditImagePreview(null);
                    setEditFileName("");
                    setEditIsPublished(false);
                    setEditGeographicAccess({
                      districtIds: [],
                      mandalIds: [],
                      assemblyConstituencyIds: [],
                      parliamentaryConstituencyIds: [],
                      postToAll: true,
                    });
                    setEditLinks([{ platform: "Facebook", url: "" }]);
                    editTitleTeManualEdit.current = false;
                    editDescTeManualEdit.current = false;
                  }}
                  className="px-4 py-2 rounded-md border hover:bg-gray-50"
                  disabled={updating}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={updating}
                  className="flex items-center gap-2 px-4 py-2 rounded-md bg-orange-500 text-white hover:bg-orange-600 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {updating ? (
                    <>
                      <span className="animate-spin">⏳</span>
                      Updating...
                    </>
                  ) : (
                    <>
                      <CheckCircle className="w-4 h-4" />
                      Update News
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {deletingNews && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6">
            <h2 className="text-xl font-semibold mb-4">Delete News Article</h2>
            <p className="text-gray-600 mb-6">
              Are you sure you want to delete "{deletingNews.title.en}"? This action cannot be undone.
            </p>
            <div className="flex items-center justify-end gap-3">
              <button
                onClick={() => setDeletingNews(null)}
                disabled={processing === deletingNews.id}
                className="px-4 py-2 rounded-md border hover:bg-gray-50 disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                onClick={handleDeleteConfirm}
                disabled={processing === deletingNews.id}
                className="px-4 py-2 rounded-md bg-red-500 text-white hover:bg-red-600 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {processing === deletingNews.id ? "Deleting..." : "Delete"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}