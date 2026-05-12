/**
 * Extracts the first frame from a video URL and returns it as a data URL
 * @param videoUrl - The URL of the video
 * @returns Promise that resolves to a data URL string of the thumbnail, or null if extraction fails
 */
export async function extractVideoThumbnail(videoUrl: string): Promise<string | null> {
  return new Promise((resolve) => {
    const video = document.createElement('video');
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');

    if (!ctx) {
      resolve(null);
      return;
    }

    // Set video properties
    video.crossOrigin = 'anonymous';
    video.preload = 'metadata';
    video.muted = true;
    video.playsInline = true;

    // Handle successful metadata load
    video.addEventListener('loadedmetadata', () => {
      // Set canvas dimensions to match video
      canvas.width = video.videoWidth || 400;
      canvas.height = video.videoHeight || 225;

      // Seek to the first frame (0 seconds)
      video.currentTime = 0;
    });

    // Handle when the first frame is ready
    video.addEventListener('seeked', () => {
      try {
        // Draw the current frame to canvas
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
        
        // Convert canvas to data URL (JPEG format)
        const dataUrl = canvas.toDataURL('image/jpeg', 0.8);
        resolve(dataUrl);
      } catch (error) {
        console.error('Error extracting video thumbnail:', error);
        resolve(null);
      } finally {
        // Cleanup
        video.src = '';
        video.load();
      }
    });

    // Handle errors
    video.addEventListener('error', (e) => {
      console.error('Error loading video for thumbnail extraction:', e);
      resolve(null);
    });

    // Set video source and start loading
    video.src = videoUrl;
    video.load();
  });
}

/**
 * Creates a cache key for video thumbnails
 */
export function getVideoThumbnailCacheKey(videoUrl: string): string {
  return `video_thumbnail_${videoUrl}`;
}

/**
 * Gets cached thumbnail or extracts a new one
 * @param videoUrl - The URL of the video
 * @param cache - Optional cache object to store/retrieve thumbnails
 * @returns Promise that resolves to a data URL string of the thumbnail, or null if extraction fails
 */
export async function getVideoThumbnail(
  videoUrl: string,
  cache?: Map<string, string | null>
): Promise<string | null> {
  // Check cache first
  if (cache) {
    const cached = cache.get(videoUrl);
    if (cached !== undefined) {
      return cached;
    }
  }

  // Check localStorage cache
  const cacheKey = getVideoThumbnailCacheKey(videoUrl);
  try {
    const cached = localStorage.getItem(cacheKey);
    if (cached) {
      if (cache) {
        cache.set(videoUrl, cached);
      }
      return cached;
    }
  } catch (e) {
    // localStorage might not be available or quota exceeded
    console.warn('Could not access localStorage for thumbnail cache:', e);
  }

  // Extract thumbnail
  const thumbnail = await extractVideoThumbnail(videoUrl);

  // Cache the result
  if (cache) {
    cache.set(videoUrl, thumbnail);
  }

  // Cache in localStorage (only if successful)
  if (thumbnail) {
    try {
      localStorage.setItem(cacheKey, thumbnail);
    } catch (e) {
      // localStorage might be full, ignore
      console.warn('Could not cache thumbnail in localStorage:', e);
    }
  }

  return thumbnail;
}

