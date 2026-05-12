/**
 * Timezone utilities for centralized IST (Indian Standard Time) handling
 * All datetime operations should use IST timezone consistently across the application
 */

// IST timezone offset: UTC+5:30 (in minutes)
const IST_OFFSET_MINUTES = 5 * 60 + 30; // 330 minutes

/**
 * Get current datetime in IST timezone
 * @returns Date object representing current time in IST
 */
export function getISTNow(): Date {
  const now = new Date();
  // Convert UTC to IST by adding offset
  const istTime = new Date(now.getTime() + IST_OFFSET_MINUTES * 60 * 1000);
  return istTime;
}

/**
 * Convert a date string (ISO format) to IST Date object
 * @param dateString - ISO format date string (e.g., "2024-01-15T00:00:00" or "2024-01-15T00:00:00Z")
 * @returns Date object in IST
 */
export function parseToIST(dateString: string): Date {
  if (!dateString) {
    throw new Error('Invalid date string');
  }

  // Parse the date string
  let date: Date;
  if (dateString.includes('Z') || dateString.includes('+') || dateString.includes('-', 10)) {
    // ISO format with timezone
    date = new Date(dateString);
  } else {
    // Assume it's in IST if no timezone specified
    // Parse as local time and adjust to IST
    date = new Date(dateString);
  }

  // If the date string doesn't have timezone info, treat it as IST
  if (!dateString.includes('Z') && !dateString.includes('+') && !dateString.includes('-', 10)) {
    // Adjust to IST by subtracting local offset and adding IST offset
    const localOffset = date.getTimezoneOffset() * 60 * 1000;
    const istOffset = IST_OFFSET_MINUTES * 60 * 1000;
    date = new Date(date.getTime() - localOffset + istOffset);
  } else {
    // Date has timezone info, convert to IST
    const utcTime = date.getTime();
    const istTime = utcTime + IST_OFFSET_MINUTES * 60 * 1000;
    date = new Date(istTime);
  }

  return date;
}

/**
 * Format date in IST to ISO string
 * @param date - Date object (will be treated as IST)
 * @returns ISO format string
 */
export function formatISTISO(date: Date): string {
  if (!date) {
    return '';
  }

  // Convert to IST and format
  const istTime = new Date(date.getTime() + IST_OFFSET_MINUTES * 60 * 1000);
  return istTime.toISOString();
}

/**
 * Format date in IST for display
 * @param date - Date object (will be treated as IST)
 * @param options - Intl.DateTimeFormatOptions
 * @returns Formatted string
 */
export function formatISTForDisplay(
  date: Date,
  options: Intl.DateTimeFormatOptions = {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    timeZone: 'Asia/Kolkata',
  }
): string {
  if (!date) {
    return '';
  }

  return new Intl.DateTimeFormat('en-IN', {
    ...options,
    timeZone: 'Asia/Kolkata',
  }).format(date);
}

/**
 * Get IST timezone string
 * @returns IST timezone identifier
 */
export function getISTTimezone(): string {
  return 'Asia/Kolkata';
}

/**
 * Convert UTC date to IST
 * @param utcDate - Date object in UTC
 * @returns Date object in IST
 */
export function utcToIST(utcDate: Date): Date {
  const utcTime = utcDate.getTime();
  const istTime = utcTime + IST_OFFSET_MINUTES * 60 * 1000;
  return new Date(istTime);
}

/**
 * Convert IST date to UTC
 * @param istDate - Date object in IST
 * @returns Date object in UTC
 */
export function istToUTC(istDate: Date): Date {
  const istTime = istDate.getTime();
  const utcTime = istTime - IST_OFFSET_MINUTES * 60 * 1000;
  return new Date(utcTime);
}

/**
 * Format date as YYYY-MM-DD in IST timezone (for date comparisons)
 * This ensures dates are compared correctly without timezone shifts
 * @param date - Date object (will be treated as IST)
 * @returns Date string in YYYY-MM-DD format
 */
export function formatISTDateString(date: Date): string {
  if (!date) {
    return '';
  }

  // Format date in IST timezone to avoid timezone shifts
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  
  return formatter.format(date);
}

