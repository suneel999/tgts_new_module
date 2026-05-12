/**
 * Utility for caching media statistics in localStorage
 */

const CACHE_KEY = 'tgts_media_stats';
const CACHE_TIMESTAMP_KEY = 'tgts_media_stats_timestamp';
const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

export type CachedMediaStats = {
  photo_count: number;
  video_count: number;
  total_count: number;
  updated_at?: string;
};

/**
 * Get cached media stats from localStorage
 */
export function getCachedMediaStats(): CachedMediaStats | null {
  try {
    const cached = localStorage.getItem(CACHE_KEY);
    const timestamp = localStorage.getItem(CACHE_TIMESTAMP_KEY);
    
    if (!cached || !timestamp) {
      return null;
    }
    
    const cacheTime = parseInt(timestamp, 10);
    const now = Date.now();
    
    // Check if cache is still valid (within 5 minutes)
    if (now - cacheTime > CACHE_DURATION) {
      // Cache expired, remove it
      localStorage.removeItem(CACHE_KEY);
      localStorage.removeItem(CACHE_TIMESTAMP_KEY);
      return null;
    }
    
    return JSON.parse(cached) as CachedMediaStats;
  } catch (error) {
    console.error('Error reading cached media stats:', error);
    return null;
  }
}

/**
 * Save media stats to localStorage cache
 */
export function setCachedMediaStats(stats: CachedMediaStats): void {
  try {
    localStorage.setItem(CACHE_KEY, JSON.stringify(stats));
    localStorage.setItem(CACHE_TIMESTAMP_KEY, Date.now().toString());
  } catch (error) {
    console.error('Error caching media stats:', error);
  }
}

/**
 * Update cached stats when media is added
 */
export function incrementCachedCount(type: 'photo' | 'video'): void {
  const cached = getCachedMediaStats();
  if (cached) {
    if (type === 'photo') {
      cached.photo_count += 1;
    } else {
      cached.video_count += 1;
    }
    cached.total_count = cached.photo_count + cached.video_count;
    setCachedMediaStats(cached);
  }
}

/**
 * Update cached stats when media is deleted
 */
export function decrementCachedCount(type: 'photo' | 'video'): void {
  const cached = getCachedMediaStats();
  if (cached) {
    if (type === 'photo') {
      cached.photo_count = Math.max(0, cached.photo_count - 1);
    } else {
      cached.video_count = Math.max(0, cached.video_count - 1);
    }
    cached.total_count = cached.photo_count + cached.video_count;
    setCachedMediaStats(cached);
  }
}

/**
 * Update cached stats when publish status changes
 */
export function updateCachedCountOnPublishChange(
  type: 'photo' | 'video',
  wasPublished: boolean,
  isNowPublished: boolean
): void {
  const cached = getCachedMediaStats();
  if (cached) {
    // Only update if status actually changed
    if (wasPublished !== isNowPublished) {
      if (isNowPublished && !wasPublished) {
        // Being published - increment
        if (type === 'photo') {
          cached.photo_count += 1;
        } else {
          cached.video_count += 1;
        }
      } else if (!isNowPublished && wasPublished) {
        // Being unpublished - decrement
        if (type === 'photo') {
          cached.photo_count = Math.max(0, cached.photo_count - 1);
        } else {
          cached.video_count = Math.max(0, cached.video_count - 1);
        }
      }
      cached.total_count = cached.photo_count + cached.video_count;
      setCachedMediaStats(cached);
    }
  }
}

/**
 * Clear the cache (useful for testing or forced refresh)
 */
export function clearMediaStatsCache(): void {
  localStorage.removeItem(CACHE_KEY);
  localStorage.removeItem(CACHE_TIMESTAMP_KEY);
}

