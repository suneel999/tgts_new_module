/**
 * Translation service for English to Telugu auto-translation
 * Uses Google Translate API (free tier) for translations
 */

const TRANSLATE_API_URL = 'https://translate.googleapis.com/translate_a/single';

export const translationService = {
  /**
   * Translate English text to Telugu
   * @param text - English text to translate
   * @returns Promise with translated Telugu text
   */
  async translateToTelugu(text: string): Promise<string> {
    if (!text || !text.trim()) {
      return '';
    }

    try {
      // Use Google Translate API (free, no API key required for basic usage)
      const response = await fetch(
        `${TRANSLATE_API_URL}?client=gtx&sl=en&tl=te&dt=t&q=${encodeURIComponent(text)}`,
        {
          method: 'GET',
          headers: {
            'Accept': 'application/json',
          },
        }
      );

      if (!response.ok) {
        throw new Error('Translation API request failed');
      }

      const data = await response.json();
      
      // Google Translate returns: [[["translated_text", ...], ...], ...]
      if (data && data[0] && data[0][0] && data[0][0][0]) {
        return data[0][0][0];
      }
      
      return text; // Fallback to original text if parsing fails
    } catch (error) {
      console.error('Translation error:', error);
      // Fallback: return original text if translation fails
      return text;
    }
  },

  /**
   * Debounced translation function to avoid too many API calls
   */
  createDebouncedTranslator(delay: number = 500) {
    let timeoutId: ReturnType<typeof setTimeout> | null = null;
    
    return (text: string, callback: (translated: string) => void) => {
      if (timeoutId) {
        clearTimeout(timeoutId);
      }
      
      timeoutId = setTimeout(async () => {
        const translated = await this.translateToTelugu(text);
        callback(translated);
      }, delay);
    };
  },
};

