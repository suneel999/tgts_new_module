import { useState, useEffect, useLayoutEffect, useRef } from "react";
import { Image, Video, UploadCloud, CheckCircle, AlertCircle, Eye, X, Edit, Trash2, Globe, EyeOff } from "lucide-react";
import { mediaService } from "../../services/mediaService";
import type { MediaItem } from "../../services/mediaService";
import { getVideoThumbnail } from "../../utils/videoThumbnail";
import { translationService } from "../../services/translationService";
import GeographicAccessSelector, { type GeographicAccessData } from "../../components/GeographicAccessSelector";
import { 
  getCachedMediaStats, 
  setCachedMediaStats, 
  incrementCachedCount, 
  decrementCachedCount,
  updateCachedCountOnPublishChange 
} from "../../utils/mediaStatsCache";

export default function MediaManagement() {
  const [mediaItems, setMediaItems] = useState<MediaItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [showUploadModal, setShowUploadModal] = useState(false);
  const [mediaType, setMediaType] = useState<'photo' | 'video'>('photo');
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [titleEn, setTitleEn] = useState("");
  const [titleTe, setTitleTe] = useState("");
  const [isPublished, setIsPublished] = useState(true);
  const [selectedAccessLevel, setSelectedAccessLevel] = useState<"public" | "cadre" | "admin">("public");
  const [geographicAccess, setGeographicAccess] = useState<GeographicAccessData>({
    districtIds: [],
    mandalIds: [],
    assemblyConstituencyIds: [],
    parliamentaryConstituencyIds: [],
    postToAll: true,
  });
  const [uploading, setUploading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  // Initialize with a function to read from cache on mount
  // This runs synchronously during component initialization
  const [totalMedia, setTotalMedia] = useState(() => {
    const cached = getCachedMediaStats();
    const count = cached?.total_count ?? 0;
    console.log('Initializing totalMedia from cache:', count, cached);
    return count;
  });
  const [totalPhotos, setTotalPhotos] = useState(() => {
    const cached = getCachedMediaStats();
    const count = cached?.photo_count ?? 0;
    console.log('Initializing totalPhotos from cache:', count, cached);
    return count;
  });
  const [totalVideos, setTotalVideos] = useState(() => {
    const cached = getCachedMediaStats();
    const count = cached?.video_count ?? 0;
    console.log('Initializing totalVideos from cache:', count, cached);
    return count;
  });
  const [selectedMedia, setSelectedMedia] = useState<MediaItem | null>(null);
  const [activeFilter, setActiveFilter] = useState<'photo' | 'video' | null>(null);
  const [editingMedia, setEditingMedia] = useState<MediaItem | null>(null);
  const [editTitleEn, setEditTitleEn] = useState("");
  const [editTitleTe, setEditTitleTe] = useState("");
  const [editIsPublished, setEditIsPublished] = useState(false);
  const [editSelectedAccessLevel, setEditSelectedAccessLevel] = useState<"public" | "cadre" | "admin">("public");
  const [editGeographicAccess, setEditGeographicAccess] = useState<GeographicAccessData>({
    districtIds: [],
    mandalIds: [],
    assemblyConstituencyIds: [],
    parliamentaryConstituencyIds: [],
    postToAll: true,
  });
  const [deletingMedia, setDeletingMedia] = useState<MediaItem | null>(null);
  const [processing, setProcessing] = useState<string | null>(null);
  const [videoThumbnails, setVideoThumbnails] = useState<Map<string, string | null>>(new Map());
  const thumbnailCacheRef = useRef<Map<string, string | null>>(new Map());

  // Track if Telugu fields were manually edited
  const titleTeManualEdit = useRef(false);
  const editTitleTeManualEdit = useRef(false);

  // Convert selected level to array including all lower levels
  const getAccessLevelsArray = (level: "public" | "cadre" | "admin"): Array<"public" | "cadre" | "admin"> => {
    switch (level) {
      case "admin":
        return ["public", "cadre", "admin"];
      case "cadre":
        return ["public", "cadre"];
      case "public":
      default:
        return ["public"];
    }
  };

  // Get the highest access level from an array
  const getHighestAccessLevel = (levels: Array<"public" | "cadre" | "admin">): "public" | "cadre" | "admin" => {
    if (levels.includes("admin")) return "admin";
    if (levels.includes("cadre")) return "cadre";
    return "public";
  };

  // Reset to page 1 when filter changes
  useEffect(() => {
    setCurrentPage(1);
  }, [activeFilter]);

  // Load media when page or filter changes
  useEffect(() => {
    loadMedia();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentPage, activeFilter]);

  // Use useLayoutEffect to set from cache before first paint
  useLayoutEffect(() => {
    const cached = getCachedMediaStats();
    if (cached) {
      console.log('Setting counts from cache:', cached);
      // Update state synchronously before paint
      setTotalMedia(cached.total_count);
      setTotalPhotos(cached.photo_count);
      setTotalVideos(cached.video_count);
    } else {
      console.log('No cache found');
    }
  }, []);

  // Load totals once on mount - refresh from API
  useEffect(() => {
    // Always refresh from API to get latest data
    loadTotals();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Auto-translate Title English to Telugu (upload form)
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

  // Auto-translate Title English to Telugu (edit form)
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

  // Extract thumbnails for videos without thumbnails
  useEffect(() => {
    const extractThumbnails = async () => {
      const videosWithoutThumbnails = mediaItems.filter(
        item => item.type === 'video' && (!item.thumbnail || item.thumbnail.trim() === '')
      );

      for (const video of videosWithoutThumbnails) {
        // Skip if we're already processing or have cached this thumbnail
        if (thumbnailCacheRef.current.has(video.url)) {
          continue;
        }

        // Mark as processing
        thumbnailCacheRef.current.set(video.url, null);

        try {
          const thumbnail = await getVideoThumbnail(video.url, thumbnailCacheRef.current);
          if (thumbnail) {
            setVideoThumbnails(prev => {
              const newMap = new Map(prev);
              newMap.set(video.url, thumbnail);
              return newMap;
            });
          }
        } catch (error) {
          console.error(`Failed to extract thumbnail for video ${video.url}:`, error);
          thumbnailCacheRef.current.set(video.url, null);
        }
      }
    };

    if (mediaItems.length > 0) {
      extractThumbnails();
    }
  }, [mediaItems]);

  const loadTotals = async () => {
    try {
      // Use the new stats endpoint for better performance
      const stats = await mediaService.getMediaStats();
      
      // Only update if stats are not all zeros (backend might return 0 if not initialized)
      // If all zeros, try fallback method to get actual counts
      if (stats.total_count === 0 && stats.photo_count === 0 && stats.video_count === 0) {
        console.log('Stats endpoint returned all zeros, trying fallback method...');
        // Try fallback method to get actual counts
        try {
          const [allResponse, photosResponse, videosResponse] = await Promise.all([
            mediaService.getMedia({ page: 1, per_page: 1 }),
            mediaService.getMedia({ page: 1, per_page: 1, type: 'photo' }),
            mediaService.getMedia({ page: 1, per_page: 1, type: 'video' }),
          ]);
          const fallbackStats = {
            total_count: allResponse.total,
            photo_count: photosResponse.total,
            video_count: videosResponse.total,
          };
          
          // Only use fallback if it has non-zero values
          if (fallbackStats.total_count > 0 || fallbackStats.photo_count > 0 || fallbackStats.video_count > 0) {
            // Update state immediately
            setTotalMedia(fallbackStats.total_count);
            setTotalPhotos(fallbackStats.photo_count);
            setTotalVideos(fallbackStats.video_count);
            setCachedMediaStats(fallbackStats);
            return;
          }
        } catch (fallbackErr) {
          console.error("Failed to load totals with fallback method:", fallbackErr);
        }
      }
      
      // Use stats from endpoint (even if zeros, as that might be accurate)
      console.log('Updating counts from API:', stats);
      setTotalMedia(stats.total_count);
      setTotalPhotos(stats.photo_count);
      setTotalVideos(stats.video_count);
      
      // Update cache with fresh data
      setCachedMediaStats(stats);
    } catch (err) {
      console.error("Failed to load totals:", err);
      // Fallback to old method if stats endpoint fails
      try {
        const [allResponse, photosResponse, videosResponse] = await Promise.all([
          mediaService.getMedia({ page: 1, per_page: 1 }),
          mediaService.getMedia({ page: 1, per_page: 1, type: 'photo' }),
          mediaService.getMedia({ page: 1, per_page: 1, type: 'video' }),
        ]);
        const fallbackStats = {
          total_count: allResponse.total,
          photo_count: photosResponse.total,
          video_count: videosResponse.total,
        };
        // Update state immediately
        setTotalMedia(fallbackStats.total_count);
        setTotalPhotos(fallbackStats.photo_count);
        setTotalVideos(fallbackStats.video_count);
        
        // Update cache with fallback data
        setCachedMediaStats(fallbackStats);
      } catch (fallbackErr) {
        console.error("Failed to load totals with fallback method:", fallbackErr);
      }
    }
  };

  // Handle Escape key to close modals
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
        if (e.key === 'Escape') {
        if (selectedMedia) {
          setSelectedMedia(null);
        } else if (editingMedia) {
          setEditingMedia(null);
          setEditTitleEn("");
          setEditTitleTe("");
          setEditIsPublished(false);
          setEditSelectedAccessLevel("public");
          setEditGeographicAccess({
            districtIds: [],
            mandalIds: [],
            assemblyConstituencyIds: [],
            parliamentaryConstituencyIds: [],
            postToAll: true,
          });
          setError(null);
          editTitleTeManualEdit.current = false; // Reset manual edit flag
        } else if (deletingMedia) {
          setDeletingMedia(null);
          setError(null);
        }
      }
    };
    window.addEventListener('keydown', handleEscape);
    return () => window.removeEventListener('keydown', handleEscape);
  }, [selectedMedia, editingMedia, deletingMedia]);

  const loadMedia = async () => {
    try {
      setLoading(true);
      const filters: { page: number; per_page: number; type?: 'photo' | 'video' } = {
        page: currentPage,
        per_page: 12,
      };
      if (activeFilter) {
        filters.type = activeFilter;
      }
      const response = await mediaService.getMedia(filters);
      setMediaItems(response.media);
      setTotalPages(response.pages);
    } catch (err) {
      console.error("Failed to load media:", err);
    } finally {
      setLoading(false);
    }
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      // Validate file type
      if (mediaType === 'photo') {
        if (!file.type.startsWith('image/')) {
          setError('Please select an image file');
          return;
        }
      } else if (mediaType === 'video') {
        if (!file.type.startsWith('video/')) {
          setError('Please select a video file');
          return;
        }
        // Validate video file size (1GB max)
        const maxSize = 1024 * 1024 * 1024; // 1GB
        if (file.size > maxSize) {
          setError(`Video file is too large. Maximum file size is 1GB. Your file is ${(file.size / (1024 * 1024 * 1024)).toFixed(2)}GB.`);
          e.target.value = '';
          return;
        }
      }
      setSelectedFile(file);
      setError(null);
    }
  };

  const handleUpload = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!selectedFile) {
      setError("Please select a file");
      return;
    }

    setUploading(true);
    setError(null);

    try {
      const result = await mediaService.uploadMedia(selectedFile, {
        type: mediaType,
        title_en: titleEn,
        title_te: titleTe || titleEn,
        is_published: isPublished,
        access_level: getAccessLevelsArray(selectedAccessLevel),
        districtIds: geographicAccess.postToAll ? undefined : (geographicAccess.districtIds.length > 0 ? geographicAccess.districtIds : undefined),
        mandalIds: geographicAccess.postToAll ? undefined : (geographicAccess.mandalIds.length > 0 ? geographicAccess.mandalIds : undefined),
        assemblyConstituencyIds: geographicAccess.postToAll ? undefined : (geographicAccess.assemblyConstituencyIds.length > 0 ? geographicAccess.assemblyConstituencyIds : undefined),
        parliamentaryConstituencyIds: geographicAccess.postToAll ? undefined : (geographicAccess.parliamentaryConstituencyIds.length > 0 ? geographicAccess.parliamentaryConstituencyIds : undefined),
      });

      console.log('Upload result:', result);
      setSuccess(true);
      
      // Update cache immediately if published (optimistic update)
      if (isPublished) {
        incrementCachedCount(mediaType);
        // Update state immediately for instant UI feedback
        if (mediaType === 'photo') {
          setTotalPhotos(prev => prev + 1);
        } else {
          setTotalVideos(prev => prev + 1);
        }
        setTotalMedia(prev => prev + 1);
      }
      
      // Clear form
      setTimeout(() => {
        setSelectedFile(null);
        setTitleEn("");
        setTitleTe("");
        setIsPublished(true);
        setSelectedAccessLevel("public");
        setGeographicAccess({
          districtIds: [],
          mandalIds: [],
          assemblyConstituencyIds: [],
          parliamentaryConstituencyIds: [],
          postToAll: true,
        });
        setShowUploadModal(false);
        setSuccess(false);
        titleTeManualEdit.current = false; // Reset manual edit flag
        loadMedia(); // Reload media list
        loadTotals(); // Reload totals to sync with server
      }, 2000);

    } catch (err: any) {
      console.error("Failed to upload media:", err);
      console.error("Error details:", err.response?.data);
      setError(err.response?.data?.message || err.message || "Failed to upload media. Please try again.");
    } finally {
      setUploading(false);
    }
  };

  const handleFilterClick = (filter: 'photo' | 'video' | null) => {
    setActiveFilter(filter === activeFilter ? null : filter);
  };

  const handleEdit = (item: MediaItem) => {
    setEditingMedia(item);
    setEditTitleEn(item.title.en);
    setEditTitleTe(item.title.te);
    setEditIsPublished(item.isPublished);
    
    // Pre-populate access level - get the highest level from the array
    let accessLevelsArray: Array<"public" | "cadre" | "admin"> = ["public"];
    if (item.access_level) {
      if (Array.isArray(item.access_level)) {
        accessLevelsArray = item.access_level as Array<"public" | "cadre" | "admin">;
      } else if (typeof item.access_level === 'string') {
        try {
          const parsed = JSON.parse(item.access_level);
          accessLevelsArray = Array.isArray(parsed) ? parsed as Array<"public" | "cadre" | "admin"> : ["public"];
        } catch {
          accessLevelsArray = ["public"];
        }
      }
    }
    setEditSelectedAccessLevel(getHighestAccessLevel(accessLevelsArray));
    
    // Pre-populate geographic access data
    const getArrayValue = (value: any): number[] => {
      if (value === null || value === undefined) return [];
      if (Array.isArray(value)) {
        return value.filter((id: any) => id != null && !isNaN(Number(id))).map((id: any) => Number(id));
      }
      return [];
    };
    
    const districtIds = getArrayValue(item.districtIds);
    const mandalIds = getArrayValue(item.mandalIds);
    const assemblyConstituencyIds = getArrayValue(item.assemblyConstituencyIds);
    const parliamentaryConstituencyIds = getArrayValue(item.parliamentaryConstituencyIds);
    
    // Check if there are any geographic restrictions
    const hasGeographicRestrictions = 
      districtIds.length > 0 ||
      mandalIds.length > 0 ||
      assemblyConstituencyIds.length > 0 ||
      parliamentaryConstituencyIds.length > 0;
    
    setEditGeographicAccess({
      districtIds: districtIds,
      mandalIds: mandalIds,
      assemblyConstituencyIds: assemblyConstituencyIds,
      parliamentaryConstituencyIds: parliamentaryConstituencyIds,
      postToAll: !hasGeographicRestrictions,
    });
    
    setError(null);
    setSuccess(false);
    editTitleTeManualEdit.current = false; // Reset manual edit flag when opening edit
  };

  const handleSaveEdit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingMedia) return;

    if (!editTitleEn.trim()) {
      setError("Title (English) is required");
      return;
    }

    setProcessing(editingMedia.id);
    setError(null);

    try {
      const wasPublished = editingMedia.isPublished;
      await mediaService.updateMedia(editingMedia.id, {
        title_en: editTitleEn,
        title_te: editTitleTe || editTitleEn,
        is_published: editIsPublished,
        access_level: getAccessLevelsArray(editSelectedAccessLevel),
        districtIds: editGeographicAccess.postToAll ? undefined : (editGeographicAccess.districtIds.length > 0 ? editGeographicAccess.districtIds : undefined),
        mandalIds: editGeographicAccess.postToAll ? undefined : (editGeographicAccess.mandalIds.length > 0 ? editGeographicAccess.mandalIds : undefined),
        assemblyConstituencyIds: editGeographicAccess.postToAll ? undefined : (editGeographicAccess.assemblyConstituencyIds.length > 0 ? editGeographicAccess.assemblyConstituencyIds : undefined),
        parliamentaryConstituencyIds: editGeographicAccess.postToAll ? undefined : (editGeographicAccess.parliamentaryConstituencyIds.length > 0 ? editGeographicAccess.parliamentaryConstituencyIds : undefined),
      });

      // Update cache if publish status changed
      if (wasPublished !== editIsPublished) {
        updateCachedCountOnPublishChange(editingMedia.type, wasPublished, editIsPublished);
        // Update state immediately
        if (editIsPublished && !wasPublished) {
          // Being published
          if (editingMedia.type === 'photo') {
            setTotalPhotos(prev => prev + 1);
          } else {
            setTotalVideos(prev => prev + 1);
          }
          setTotalMedia(prev => prev + 1);
        } else if (!editIsPublished && wasPublished) {
          // Being unpublished
          if (editingMedia.type === 'photo') {
            setTotalPhotos(prev => Math.max(0, prev - 1));
          } else {
            setTotalVideos(prev => Math.max(0, prev - 1));
          }
          setTotalMedia(prev => Math.max(0, prev - 1));
        }
      }

      setSuccess(true);
      setTimeout(() => {
        setEditingMedia(null);
        setEditTitleEn("");
        setEditTitleTe("");
        setEditIsPublished(false);
        setEditSelectedAccessLevel("public");
        setEditGeographicAccess({
          districtIds: [],
          mandalIds: [],
          assemblyConstituencyIds: [],
          parliamentaryConstituencyIds: [],
          postToAll: true,
        });
        setSuccess(false);
        editTitleTeManualEdit.current = false; // Reset manual edit flag
        loadMedia();
        loadTotals();
      }, 1500);
    } catch (err: any) {
      console.error("Failed to update media:", err);
      setError(err.response?.data?.message || err.message || "Failed to update media. Please try again.");
    } finally {
      setProcessing(null);
    }
  };

  const handlePublish = async (item: MediaItem) => {
    setProcessing(item.id);
    setError(null);
    setSuccess(false);

    try {
      await mediaService.publishMedia(item.id);
      
      // Update cache immediately (optimistic update)
      updateCachedCountOnPublishChange(item.type, false, true);
      // Update state immediately
      if (item.type === 'photo') {
        setTotalPhotos(prev => prev + 1);
      } else {
        setTotalVideos(prev => prev + 1);
      }
      setTotalMedia(prev => prev + 1);
      
      setSuccess(true);
      setTimeout(() => {
        setSuccess(false);
        loadMedia();
        loadTotals();
      }, 1500);
    } catch (err: any) {
      console.error("Failed to publish media:", err);
      setError(err.response?.data?.message || err.message || "Failed to publish media. Please try again.");
    } finally {
      setProcessing(null);
    }
  };

  const handleUnpublish = async (item: MediaItem) => {
    setProcessing(item.id);
    setError(null);
    setSuccess(false);

    try {
      await mediaService.unpublishMedia(item.id);
      
      // Update cache immediately (optimistic update)
      updateCachedCountOnPublishChange(item.type, true, false);
      // Update state immediately
      if (item.type === 'photo') {
        setTotalPhotos(prev => Math.max(0, prev - 1));
      } else {
        setTotalVideos(prev => Math.max(0, prev - 1));
      }
      setTotalMedia(prev => Math.max(0, prev - 1));
      
      setSuccess(true);
      setTimeout(() => {
        setSuccess(false);
        loadMedia();
        loadTotals();
      }, 1500);
    } catch (err: any) {
      console.error("Failed to unpublish media:", err);
      setError(err.response?.data?.message || err.message || "Failed to unpublish media. Please try again.");
    } finally {
      setProcessing(null);
    }
  };

  const handleDeleteConfirm = async () => {
    if (!deletingMedia) return;

    setProcessing(deletingMedia.id);
    setError(null);
    setSuccess(false);

    try {
      const wasPublished = deletingMedia.isPublished;
      await mediaService.deleteMedia(deletingMedia.id);
      
      // Update cache immediately if it was published (optimistic update)
      if (wasPublished) {
        decrementCachedCount(deletingMedia.type);
        // Update state immediately
        if (deletingMedia.type === 'photo') {
          setTotalPhotos(prev => Math.max(0, prev - 1));
        } else {
          setTotalVideos(prev => Math.max(0, prev - 1));
        }
        setTotalMedia(prev => Math.max(0, prev - 1));
      }
      
      setSuccess(true);
      setTimeout(() => {
        setDeletingMedia(null);
        setSuccess(false);
        loadMedia();
        loadTotals();
      }, 1500);
    } catch (err: any) {
      console.error("Failed to delete media:", err);
      setError(err.response?.data?.message || err.message || "Failed to delete media. Please try again.");
    } finally {
      setProcessing(null);
    }
  };

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-xl sm:text-2xl font-semibold">Media Gallery</h1>
          <p className="text-xs sm:text-sm text-gray-500">Manage photos and videos</p>
        </div>
        <button 
          onClick={() => setShowUploadModal(true)}
          className="flex items-center justify-center gap-2 px-4 py-2 rounded-md bg-orange-500 text-white hover:bg-orange-600 transition-colors text-sm sm:text-base"
        >
          <UploadCloud className="w-4 h-4" />
          Upload Media
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <button
          onClick={() => handleFilterClick(null)}
          className={`bg-white rounded-lg shadow-card p-4 transition-all hover:shadow-lg ${
            activeFilter === null ? 'ring-2 ring-orange-500' : ''
          }`}
        >
          <div className="flex items-center gap-3">
            <div className={`p-2 rounded-lg ${
              activeFilter === null ? 'bg-orange-100' : 'bg-blue-100'
            }`}>
              <Image className={`w-5 h-5 ${
                activeFilter === null ? 'text-orange-600' : 'text-blue-600'
              }`} />
            </div>
            <div>
              <div className="text-2xl font-semibold">{totalMedia}</div>
              <div className="text-sm text-gray-500">Total Media</div>
            </div>
          </div>
        </button>
        <button
          onClick={() => handleFilterClick('photo')}
          className={`bg-white rounded-lg shadow-card p-4 transition-all hover:shadow-lg cursor-pointer ${
            activeFilter === 'photo' ? 'ring-2 ring-orange-500' : ''
          }`}
        >
          <div className="flex items-center gap-3">
            <div className={`p-2 rounded-lg ${
              activeFilter === 'photo' ? 'bg-orange-100' : 'bg-green-100'
            }`}>
              <Image className={`w-5 h-5 ${
                activeFilter === 'photo' ? 'text-orange-600' : 'text-green-600'
              }`} />
            </div>
            <div>
              <div className="text-2xl font-semibold">{totalPhotos}</div>
              <div className="text-sm text-gray-500">Photos</div>
            </div>
          </div>
        </button>
        <button
          onClick={() => handleFilterClick('video')}
          className={`bg-white rounded-lg shadow-card p-4 transition-all hover:shadow-lg cursor-pointer ${
            activeFilter === 'video' ? 'ring-2 ring-orange-500' : ''
          }`}
        >
          <div className="flex items-center gap-3">
            <div className={`p-2 rounded-lg ${
              activeFilter === 'video' ? 'bg-orange-100' : 'bg-purple-100'
            }`}>
              <Video className={`w-5 h-5 ${
                activeFilter === 'video' ? 'text-orange-600' : 'text-purple-600'
              }`} />
            </div>
            <div>
              <div className="text-2xl font-semibold">{totalVideos}</div>
              <div className="text-sm text-gray-500">Videos</div>
            </div>
          </div>
        </button>
      </div>

      {/* Media Grid */}
      <div className="bg-white rounded-lg shadow-card p-4">
        {loading ? (
          <div className="text-center py-12">
            <div className="animate-spin w-8 h-8 border-4 border-orange-500 border-t-transparent rounded-full mx-auto"></div>
            <p className="mt-2 text-gray-500">Loading media...</p>
          </div>
        ) : mediaItems.length === 0 ? (
          <div className="text-center py-12">
            <Image className="w-16 h-16 text-gray-300 mx-auto mb-4" />
            <p className="text-gray-500">No media items yet. Upload your first one!</p>
          </div>
        ) : (
          <>
            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
              {mediaItems.map((item) => (
                <div key={item.id} className="group relative rounded-lg overflow-hidden border hover:shadow-lg transition-shadow">
                  {item.type === 'photo' ? (
                    <img 
                      src={item.thumbnail || item.url} 
                      alt={item.title.en}
                      className="w-full h-48 object-cover cursor-pointer"
                      onClick={() => setSelectedMedia(item)}
                    />
                  ) : (
                    <div 
                      className="w-full h-48 bg-gray-800 flex items-center justify-center relative cursor-pointer"
                      onClick={() => setSelectedMedia(item)}
                    >
                      <Video className="w-12 h-12 text-white z-10" />
                      {(item.thumbnail && item.thumbnail.trim() !== '') || videoThumbnails.get(item.url) ? (
                        <img 
                          src={videoThumbnails.get(item.url) || item.thumbnail} 
                          alt={item.title.en}
                          className="absolute inset-0 w-full h-full object-cover opacity-50"
                          onError={() => {
                            // If thumbnail fails to load, try extracting it
                            if (!videoThumbnails.has(item.url)) {
                              getVideoThumbnail(item.url, thumbnailCacheRef.current).then(thumbnail => {
                                if (thumbnail) {
                                  setVideoThumbnails(prev => {
                                    const newMap = new Map(prev);
                                    newMap.set(item.url, thumbnail);
                                    return newMap;
                                  });
                                }
                              });
                            }
                          }}
                        />
                      ) : (
                        <div className="absolute inset-0 bg-gray-700" />
                      )}
                    </div>
                  )}
                  <div className="p-3">
                    <div className="font-medium text-sm truncate">{item.title.en}</div>
                    <div className="text-xs text-gray-500">{item.title.te}</div>
                    <div className="flex items-center justify-between mt-2">
                      <span className={`text-xs px-2 py-1 rounded ${
                        item.isPublished ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600'
                      }`}>
                        {item.isPublished ? 'Published' : 'Draft'}
                      </span>
                      <div className="flex gap-1">
                        <button 
                          onClick={() => setSelectedMedia(item)}
                          className="p-1 hover:bg-gray-100 rounded"
                          title="View"
                          disabled={processing === item.id}
                        >
                          <Eye className="w-4 h-4 text-gray-600" />
                        </button>
                        <button 
                          onClick={() => handleEdit(item)}
                          className="p-1 hover:bg-blue-100 rounded"
                          title="Edit"
                          disabled={processing === item.id}
                        >
                          <Edit className="w-4 h-4 text-blue-600" />
                        </button>
                        {item.isPublished ? (
                          <button 
                            onClick={() => handleUnpublish(item)}
                            className="p-1 hover:bg-yellow-100 rounded"
                            title="Unpublish"
                            disabled={processing === item.id}
                          >
                            <EyeOff className="w-4 h-4 text-yellow-600" />
                          </button>
                        ) : (
                          <button 
                            onClick={() => handlePublish(item)}
                            className="p-1 hover:bg-green-100 rounded"
                            title="Publish"
                            disabled={processing === item.id}
                          >
                            <Globe className="w-4 h-4 text-green-600" />
                          </button>
                        )}
                        <button 
                          onClick={() => {
                            setDeletingMedia(item);
                            setError(null);
                            setSuccess(false);
                          }}
                          className="p-1 hover:bg-red-100 rounded"
                          title="Delete"
                          disabled={processing === item.id}
                        >
                          <Trash2 className="w-4 h-4 text-red-600" />
                        </button>
                      </div>
                    </div>
                    {processing === item.id && (
                      <div className="mt-2 text-xs text-gray-500 flex items-center gap-1">
                        <div className="animate-spin w-3 h-3 border-2 border-orange-500 border-t-transparent rounded-full"></div>
                        Processing...
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="flex items-center justify-center gap-2 mt-6">
                <button
                  onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                  disabled={currentPage === 1}
                  className="px-3 py-1 rounded border disabled:opacity-50"
                >
                  Previous
                </button>
                <span className="text-sm text-gray-600">
                  Page {currentPage} of {totalPages}
                </span>
                <button
                  onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                  disabled={currentPage === totalPages}
                  className="px-3 py-1 rounded border disabled:opacity-50"
                >
                  Next
                </button>
              </div>
            )}
          </>
        )}
      </div>

      {/* Upload Modal */}
      {showUploadModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 overflow-y-auto">
          <div className="bg-white rounded-lg shadow-xl w-full max-w-3xl p-4 sm:p-6 my-auto">
            <h2 className="text-lg sm:text-xl font-semibold mb-4">Upload Media</h2>

            {/* Success Message */}
            {success && (
              <div className="mb-4 bg-green-50 border border-green-200 rounded-lg p-3 flex items-center gap-2">
                <CheckCircle className="w-5 h-5 text-green-600" />
                <span className="text-green-900">Media uploaded successfully!</span>
              </div>
            )}

            {/* Error Message */}
            {error && (
              <div className="mb-4 bg-red-50 border border-red-200 rounded-lg p-3 flex items-center gap-2">
                <AlertCircle className="w-5 h-5 text-red-600" />
                <span className="text-red-900">{error}</span>
              </div>
            )}

            <form onSubmit={handleUpload} className="space-y-4">
              {/* Media Type */}
              <div>
                <label className="text-sm font-medium">Media Type</label>
                <div className="flex gap-2 mt-1">
                  <button
                    type="button"
                    onClick={() => setMediaType('photo')}
                    className={`flex-1 flex items-center justify-center gap-2 px-4 py-2 rounded-md border ${
                      mediaType === 'photo' ? 'bg-orange-50 border-orange-500 text-orange-700' : 'bg-white'
                    }`}
                  >
                    <Image className="w-4 h-4" />
                    Photo
                  </button>
                  <button
                    type="button"
                    onClick={() => setMediaType('video')}
                    className={`flex-1 flex items-center justify-center gap-2 px-4 py-2 rounded-md border ${
                      mediaType === 'video' ? 'bg-orange-50 border-orange-500 text-orange-700' : 'bg-white'
                    }`}
                  >
                    <Video className="w-4 h-4" />
                    Video
                  </button>
                </div>
              </div>

              {/* File Upload */}
              <div>
                <label className="text-sm font-medium">Select File *</label>
                <label className="mt-1 block h-32 rounded-md border-2 border-dashed flex flex-col items-center justify-center text-gray-600 cursor-pointer hover:bg-gray-50">
                  <UploadCloud className="w-8 h-8 mb-2" />
                  <span className="text-sm">{selectedFile ? selectedFile.name : 'Click to select file'}</span>
                  <span className="text-xs text-gray-500 mt-1">
                    {mediaType === 'photo' ? 'PNG, JPG up to 10MB' : 'MP4, MOV up to 100MB'}
                  </span>
                  <input
                    type="file"
                    accept={mediaType === 'photo' ? 'image/*' : 'video/*'}
                    className="hidden"
                    onChange={handleFileSelect}
                  />
                </label>
              </div>

              {/* Title English */}
              <div>
                <label className="text-sm font-medium">Title (English) *</label>
                <input
                  type="text"
                  className="mt-1 w-full px-3 py-2 rounded-md border bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                  placeholder="Enter title in English"
                  value={titleEn}
                  onChange={(e) => setTitleEn(e.target.value)}
                />
              </div>

              {/* Title Telugu */}
              <div>
                <label className="text-sm font-medium">Title (Telugu)</label>
                <input
                  type="text"
                  className="mt-1 w-full px-3 py-2 rounded-md border bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                  placeholder="తెలుగులో శీర్షికను నమోదు చేయండి (Auto-translated)"
                  value={titleTe}
                  onChange={(e) => {
                    setTitleTe(e.target.value);
                    titleTeManualEdit.current = true;
                  }}
                />
              </div>

              {/* Access Level */}
              <div className="border-t pt-4 mt-4">
                <label className="text-sm font-medium">Access Level <span className="text-red-500">*</span></label>
                <p className="text-xs text-gray-500 mb-2">Select the minimum access level required (higher levels include lower levels)</p>
                <select
                  value={selectedAccessLevel}
                  onChange={(e) => setSelectedAccessLevel(e.target.value as "public" | "cadre" | "admin")}
                  className="mt-1 w-full px-3 py-2 rounded-md border bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                  disabled={uploading}
                >
                  <option value="public">Public</option>
                  <option value="cadre">Cadre</option>
                  <option value="admin">Admin</option>
                </select>
                <p className="text-xs text-gray-500 mt-1">
                  Selected: <span className="font-medium capitalize">{selectedAccessLevel}</span> 
                  {selectedAccessLevel !== "public" && ` (includes: ${getAccessLevelsArray(selectedAccessLevel).join(", ")})`}
                </p>
                {selectedAccessLevel === "cadre" && (
                  <div className="mt-2 p-2 bg-blue-50 rounded-md border border-blue-200">
                    <p className="text-xs text-blue-700">
                      <strong>Hierarchy Note:</strong> Cadre content follows the 10-level party hierarchy. 
                      When created by a cadre user in the mobile app, geographic scope is auto-determined 
                      by their cadre level. Admin-created content uses the geographic settings below.
                    </p>
                  </div>
                )}
              </div>

              {/* Geographic Access Control */}
              <div className="border-t pt-4 mt-4">
                <h3 className="text-sm font-semibold text-gray-900 mb-3">Geographic Access Control</h3>
                <p className="text-xs text-gray-500 mb-3">Select who can see this media based on their location</p>
                <GeographicAccessSelector
                  value={geographicAccess}
                  onChange={setGeographicAccess}
                  disabled={uploading}
                />
              </div>

              {/* Published Status */}
              <div className="flex items-center gap-2 border-t pt-4">
                <input
                  type="checkbox"
                  id="isPublished"
                  checked={isPublished}
                  onChange={(e) => setIsPublished(e.target.checked)}
                  className="rounded border-gray-300"
                />
                <label htmlFor="isPublished" className="text-sm">Publish immediately</label>
              </div>

              {/* Actions */}
              <div className="flex gap-2 pt-4">
                <button
                  type="button"
                  onClick={() => {
                    setShowUploadModal(false);
                    setSelectedFile(null);
                    setTitleEn("");
                    setTitleTe("");
                    setSelectedAccessLevel("public");
                    setError(null);
                    titleTeManualEdit.current = false; // Reset manual edit flag
                  }}
                  className="flex-1 px-4 py-2 rounded-md border hover:bg-gray-50"
                  disabled={uploading}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={uploading || !selectedFile}
                  className="flex-1 px-4 py-2 rounded-md bg-orange-500 text-white hover:bg-orange-600 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {uploading ? 'Uploading...' : 'Upload'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Edit Modal */}
      {editingMedia && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 overflow-y-auto">
          <div className="bg-white rounded-lg shadow-xl w-full max-w-lg p-4 sm:p-6 my-auto">
            <h2 className="text-lg sm:text-xl font-semibold mb-4">Edit Media</h2>

            {/* Success Message */}
            {success && (
              <div className="mb-4 bg-green-50 border border-green-200 rounded-lg p-3 flex items-center gap-2">
                <CheckCircle className="w-5 h-5 text-green-600" />
                <span className="text-green-900">Media updated successfully!</span>
              </div>
            )}

            {/* Error Message */}
            {error && (
              <div className="mb-4 bg-red-50 border border-red-200 rounded-lg p-3 flex items-center gap-2">
                <AlertCircle className="w-5 h-5 text-red-600" />
                <span className="text-red-900">{error}</span>
              </div>
            )}

            <form onSubmit={handleSaveEdit} className="space-y-4">
              {/* Title English */}
              <div>
                <label className="text-sm font-medium">Title (English) *</label>
                <input
                  type="text"
                  className="mt-1 w-full px-3 py-2 rounded-md border bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                  placeholder="Enter title in English"
                  value={editTitleEn}
                  onChange={(e) => setEditTitleEn(e.target.value)}
                  disabled={processing === editingMedia.id}
                />
              </div>

              {/* Title Telugu */}
              <div>
                <label className="text-sm font-medium">Title (Telugu)</label>
                <input
                  type="text"
                  className="mt-1 w-full px-3 py-2 rounded-md border bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                  placeholder="తెలుగులో శీర్షికను నమోదు చేయండి (Auto-translated)"
                  value={editTitleTe}
                  onChange={(e) => {
                    setEditTitleTe(e.target.value);
                    editTitleTeManualEdit.current = true;
                  }}
                  disabled={processing === editingMedia.id}
                />
              </div>

              {/* Access Level */}
              <div className="border-t pt-4 mt-4">
                <label className="text-sm font-medium">Access Level <span className="text-red-500">*</span></label>
                <p className="text-xs text-gray-500 mb-2">Select the minimum access level required (higher levels include lower levels)</p>
                <select
                  value={editSelectedAccessLevel}
                  onChange={(e) => setEditSelectedAccessLevel(e.target.value as "public" | "cadre" | "admin")}
                  className="mt-1 w-full px-3 py-2 rounded-md border bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                  disabled={processing === editingMedia.id}
                >
                  <option value="public">Public</option>
                  <option value="cadre">Cadre</option>
                  <option value="admin">Admin</option>
                </select>
                <p className="text-xs text-gray-500 mt-1">
                  Selected: <span className="font-medium capitalize">{editSelectedAccessLevel}</span> 
                  {editSelectedAccessLevel !== "public" && ` (includes: ${getAccessLevelsArray(editSelectedAccessLevel).join(", ")})`}
                </p>
                {editSelectedAccessLevel === "cadre" && editingMedia.creatorCadreLevel && (
                  <div className="mt-2 p-2 bg-indigo-50 rounded-md border border-indigo-200">
                    <p className="text-xs text-indigo-700">
                      <strong>Creator Cadre Level:</strong> {editingMedia.creatorCadreLevel} — 
                      This content&apos;s visibility is governed by the creator&apos;s hierarchy level and geographic scope.
                    </p>
                  </div>
                )}
              </div>

              {/* Geographic Access Control */}
              <div className="border-t pt-4 mt-4">
                <h3 className="text-sm font-semibold text-gray-900 mb-3">Geographic Access Control</h3>
                <p className="text-xs text-gray-500 mb-3">Select who can see this media based on their location</p>
                <GeographicAccessSelector
                  value={editGeographicAccess}
                  onChange={setEditGeographicAccess}
                  disabled={processing === editingMedia.id}
                />
              </div>

              {/* Published Status */}
              <div className="flex items-center gap-2 border-t pt-4">
                <input
                  type="checkbox"
                  id="editIsPublished"
                  checked={editIsPublished}
                  onChange={(e) => setEditIsPublished(e.target.checked)}
                  className="rounded border-gray-300"
                  disabled={processing === editingMedia.id}
                />
                <label htmlFor="editIsPublished" className="text-sm">Published</label>
              </div>

              {/* Actions */}
              <div className="flex gap-2 pt-4">
                <button
                  type="button"
                  onClick={() => {
                    setEditingMedia(null);
                    setEditTitleEn("");
                    setEditTitleTe("");
                    setEditIsPublished(false);
                    setEditSelectedAccessLevel("public");
                    setEditGeographicAccess({
                      districtIds: [],
                      mandalIds: [],
                      assemblyConstituencyIds: [],
                      parliamentaryConstituencyIds: [],
                      postToAll: true,
                    });
                    setError(null);
                    editTitleTeManualEdit.current = false; // Reset manual edit flag
                  }}
                  className="flex-1 px-4 py-2 rounded-md border hover:bg-gray-50"
                  disabled={processing === editingMedia.id}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={processing === editingMedia.id || !editTitleEn.trim()}
                  className="flex-1 px-4 py-2 rounded-md bg-orange-500 text-white hover:bg-orange-600 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {processing === editingMedia.id ? 'Saving...' : 'Save Changes'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {deletingMedia && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg shadow-xl w-full max-w-md p-4 sm:p-6">
            <h2 className="text-lg sm:text-xl font-semibold mb-4 text-red-600">Delete Media</h2>

            {/* Success Message */}
            {success && (
              <div className="mb-4 bg-green-50 border border-green-200 rounded-lg p-3 flex items-center gap-2">
                <CheckCircle className="w-5 h-5 text-green-600" />
                <span className="text-green-900">Media deleted successfully!</span>
              </div>
            )}

            {/* Error Message */}
            {error && (
              <div className="mb-4 bg-red-50 border border-red-200 rounded-lg p-3 flex items-center gap-2">
                <AlertCircle className="w-5 h-5 text-red-600" />
                <span className="text-red-900">{error}</span>
              </div>
            )}

            <div className="mb-6">
              <p className="text-gray-700 mb-2">
                Are you sure you want to permanently delete this media item?
              </p>
              <div className="bg-gray-50 rounded-lg p-3">
                <div className="font-medium text-sm">{deletingMedia.title.en}</div>
                {deletingMedia.title.te && (
                  <div className="text-xs text-gray-500 mt-1">{deletingMedia.title.te}</div>
                )}
                <div className="text-xs text-gray-500 mt-2">
                  Type: {deletingMedia.type === 'photo' ? 'Photo' : 'Video'}
                </div>
              </div>
              <p className="text-sm text-red-600 mt-3 font-medium">
                ⚠️ This action cannot be undone. The file will be permanently deleted.
              </p>
            </div>

            <div className="flex gap-2">
              <button
                type="button"
                onClick={() => {
                  setDeletingMedia(null);
                  setError(null);
                }}
                className="flex-1 px-4 py-2 rounded-md border hover:bg-gray-50"
                disabled={processing === deletingMedia.id}
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleDeleteConfirm}
                disabled={processing === deletingMedia.id}
                className="flex-1 px-4 py-2 rounded-md bg-red-500 text-white hover:bg-red-600 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {processing === deletingMedia.id ? 'Deleting...' : 'Delete Permanently'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Media Preview Modal */}
      {selectedMedia && (
        <div 
          className="fixed inset-0 bg-black bg-opacity-90 flex items-center justify-center z-50 p-2 sm:p-4"
          onClick={() => setSelectedMedia(null)}
        >
          <div className="relative max-w-7xl max-h-[90vh] w-full flex flex-col">
            <button
              onClick={() => setSelectedMedia(null)}
              className="absolute top-2 right-2 sm:top-6 sm:right-6 p-2 bg-black bg-opacity-50 rounded-full text-white hover:bg-opacity-70 transition-colors z-10"
              title="Close"
            >
              <X className="w-5 h-5 sm:w-6 sm:h-6" />
            </button>
            {/* Title at top for videos */}
            {selectedMedia.type === 'video' && (
              <div 
                className="mb-4 bg-black bg-opacity-50 rounded-lg p-4 text-white"
                onClick={(e) => e.stopPropagation()}
              >
                <div className="font-semibold text-lg">{selectedMedia.title.en}</div>
                {selectedMedia.title.te && (
                  <div className="text-sm text-gray-300 mt-1">{selectedMedia.title.te}</div>
                )}
              </div>
            )}
            <div className="flex-1 flex items-center justify-center min-h-0">
              {selectedMedia.type === 'photo' ? (
                <img
                  src={selectedMedia.url}
                  alt={selectedMedia.title.en}
                  className="max-w-full max-h-full object-contain rounded-lg mx-auto"
                  onClick={(e) => e.stopPropagation()}
                />
              ) : (
                <video
                  src={selectedMedia.url}
                  controls
                  className="max-w-full max-h-full rounded-lg mx-auto"
                  onClick={(e) => e.stopPropagation()}
                >
                  Your browser does not support the video tag.
                </video>
              )}
            </div>
            {/* Title at bottom for images */}
            {selectedMedia.type === 'photo' && (
              <div 
                className="mt-4 bg-black bg-opacity-50 rounded-lg p-4 text-white"
                onClick={(e) => e.stopPropagation()}
              >
                <div className="font-semibold text-lg">{selectedMedia.title.en}</div>
                {selectedMedia.title.te && (
                  <div className="text-sm text-gray-300 mt-1">{selectedMedia.title.te}</div>
                )}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

