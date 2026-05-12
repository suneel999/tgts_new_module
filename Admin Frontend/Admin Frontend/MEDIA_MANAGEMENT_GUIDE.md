# Media Management System - Complete Guide

## Overview
This guide documents the complete loop for adding, storing, and serving media (photos and videos) in the Telangana Congress Communication App.

## System Architecture

### Frontend → Backend → Storage → Serving Flow

```
User Upload → Frontend Form → API Request → Backend Upload → File Storage → Database Record → API Response → Frontend Display
```

## Components Created

### 1. Frontend Service (`src/services/mediaService.ts`)
**Purpose:** Handles all API communication for media operations

**Key Functions:**
- `getMedia(filters)` - Fetch all media with pagination
- `getMediaById(id)` - Fetch single media item
- `createMedia(data)` - Create media record
- `uploadFile(file, type)` - Upload file to server
- `uploadMedia(file, data)` - Combined upload + create operation

**Usage Example:**
```typescript
// Upload a media file with metadata
const result = await mediaService.uploadMedia(file, {
  type: 'photo',
  title_en: 'Congress Rally',
  title_te: 'కాంగ్రెస్ ర్యాలీ',
  is_published: true
});
```

### 2. Frontend Component (`src/features/media/MediaManagement.tsx`)
**Purpose:** Complete UI for media management

**Features:**
- Media gallery grid view
- Upload modal with form
- Real-time statistics (total, photos, videos)
- Pagination support
- Type selection (photo/video)
- Bilingual support (English/Telugu)
- File validation
- Success/Error notifications

**Navigation:** `/media` route in the app

### 3. Backend Upload Endpoint (`TGTS_Backend/app/routes/media.py`)
**Endpoint:** `POST /api/media/upload`

**Features:**
- File type validation (images: jpg, png, gif, webp | videos: mp4, mov, avi, webm)
- Secure filename generation with timestamp
- Automatic directory creation
- Returns file URL for database storage
- Authentication check (admin/cadre only)

**Request Format:**
```
Content-Type: multipart/form-data

file: <binary file data>
type: 'photo' | 'video'
```

**Response:**
```json
{
  "url": "/uploads/photos/20251027_162045_a1b2c3d4.jpg",
  "thumbnail_url": "/uploads/photos/20251027_162045_a1b2c3d4.jpg",
  "filename": "20251027_162045_a1b2c3d4.jpg",
  "message": "File uploaded successfully"
}
```

### 4. Backend Create Endpoint (`POST /api/media/`)
**Purpose:** Create media database record

**Request:**
```json
{
  "type": "photo",
  "url": "/uploads/photos/...",
  "thumbnail_url": "/uploads/photos/...",
  "title_en": "Congress Rally Photos",
  "title_te": "కాంగ్రెస్ ర్యాలీ ఫోటోలు",
  "is_published": true
}
```

### 5. Backend Retrieval Endpoint (`GET /api/media/`)
**Purpose:** Fetch all published media items

**Query Parameters:**
- `page` - Page number (default: 1)
- `per_page` - Items per page (default: 20, max: 100)
- `type` - Filter by 'photo' or 'video'

**Response:**
```json
{
  "media": [
    {
      "id": "uuid",
      "type": "photo",
      "url": "/uploads/photos/...",
      "thumbnail": "/uploads/photos/...",
      "title": {
        "en": "Congress Rally Photos",
        "te": "కాంగ్రెస్ ర్యాలీ ఫోటోలు"
      },
      "date": "2025-10-27T10:58:06.632937",
      "isPublished": true
    }
  ],
  "total": 3,
  "pages": 1,
  "current_page": 1
}
```

### 6. File Serving Route (`GET /uploads/<path:filename>`)
**Purpose:** Serve uploaded media files

**Configuration:**
- Location: `TGTS_Backend/uploads/`
- CORS enabled for frontend origins
- Supports both photos and videos subdirectories

## Directory Structure

```
TGTS_Backend/
├── uploads/
│   ├── .gitignore          # Ignores uploaded files
│   ├── photos/
│   │   └── .gitkeep        # Keeps directory in git
│   └── videos/
│       └── .gitkeep
```

## Complete Upload Flow

### Step-by-Step Process:

1. **User Action**
   - User clicks "Upload Media" button
   - Modal opens with upload form

2. **File Selection**
   - User selects media type (photo/video)
   - User selects file from device
   - Frontend validates file type

3. **Form Submission**
   - User enters title (English & Telugu)
   - User chooses publish status
   - User clicks "Upload"

4. **Frontend Processing**
   ```typescript
   // mediaService.uploadMedia() is called
   // 1. Upload file to backend
   const uploadResult = await uploadFile(file, type);
   
   // 2. Create database record with returned URL
   const mediaItem = await createMedia({
     type, title_en, title_te,
     url: uploadResult.url,
     thumbnail_url: uploadResult.thumbnail_url,
     is_published
   });
   ```

5. **Backend Processing**
   - Receives multipart/form-data
   - Validates file type and extension
   - Generates secure, unique filename with timestamp
   - Creates directory if needed
   - Saves file to disk
   - Returns file URL

6. **Database Storage**
   - Creates MediaItem record with:
     - UUID
     - Type (photo/video)
     - URL paths
     - Bilingual titles
     - Published status
     - Timestamps

7. **Frontend Update**
   - Shows success message
   - Reloads media gallery
   - Displays new media item

8. **Media Display**
   - Fetches media from `/api/media/`
   - Renders grid with thumbnails
   - Shows metadata (title, type, status)
   - Supports pagination

## Testing the Complete Flow

### Prerequisites:
1. Backend server running on `http://localhost:80`
2. Frontend dev server running on `http://localhost:5173`
3. Database initialized with sample data

### Test Steps:

1. **Start Backend:**
```bash
cd TGTS_Backend
python app.py
```

2. **Start Frontend:**
```bash
npm run dev
```

3. **Navigate to Media Gallery:**
   - Open browser: `http://localhost:5173`
   - Click "Media Gallery" in sidebar
   - Should see existing media items (3 sample items)

4. **Upload New Photo:**
   - Click "Upload Media" button
   - Select "Photo" type
   - Choose an image file (jpg, png, gif, webp)
   - Enter English title: "Test Upload"
   - Enter Telugu title: "టెస్ట్ అప్లోడ్"
   - Check "Publish immediately"
   - Click "Upload"
   - Wait for success message
   - Verify new item appears in gallery

5. **Upload New Video:**
   - Repeat above steps with "Video" type
   - Choose video file (mp4, mov, avi, webm)

6. **Verify File Storage:**
```bash
# Check uploaded files
ls TGTS_Backend/uploads/photos/
ls TGTS_Backend/uploads/videos/
```

7. **Test API Directly:**
```bash
# Get all media
curl http://localhost:80/api/media/

# Get photos only
curl http://localhost:80/api/media/?type=photo

# Get videos only
curl http://localhost:80/api/media/?type=video
```

8. **View Uploaded File:**
   - Click the eye icon on any media item
   - File should open in new tab
   - URL format: `http://localhost:80/uploads/photos/[filename]`

## API Endpoints Summary

| Method | Endpoint | Purpose | Auth |
|--------|----------|---------|------|
| GET | `/api/media/` | List all published media | Public |
| GET | `/api/media/:id` | Get specific media item | Public |
| POST | `/api/media/upload` | Upload media file | Admin/Cadre |
| POST | `/api/media/` | Create media record | Admin/Cadre |
| GET | `/uploads/:path` | Serve uploaded files | Public |

## Database Schema

**Table:** `media_items`

| Column | Type | Description |
|--------|------|-------------|
| id | String(50) | UUID primary key |
| type | String(10) | 'photo' or 'video' |
| url | String(500) | File URL path |
| thumbnail_url | String(500) | Thumbnail URL |
| title_en | String(200) | English title |
| title_te | String(200) | Telugu title |
| is_published | Boolean | Published status |
| created_at | DateTime | Creation timestamp |
| updated_at | DateTime | Last update timestamp |

## Security Considerations

1. **File Validation:**
   - Extension whitelist enforced
   - MIME type checking recommended for production
   - File size limits should be added

2. **Authentication:**
   - Upload requires admin/cadre role
   - Can be bypassed in testing mode
   - Re-enable for production

3. **File Storage:**
   - Files stored in local directory
   - For production: Use CDN (AWS S3, Cloudinary, etc.)
   - Implement file size limits
   - Add virus scanning

4. **CORS:**
   - Configured for localhost development
   - Update origins for production deployment

## Future Enhancements

1. **Thumbnail Generation:**
   - Auto-generate thumbnails for images
   - Extract video thumbnails from first frame

2. **Image Processing:**
   - Resize images to optimize loading
   - Support multiple sizes (small, medium, large)
   - Compress images automatically

3. **Cloud Storage:**
   - Integrate AWS S3 or similar
   - Use signed URLs for secure access
   - CDN integration for faster delivery

4. **Advanced Features:**
   - Drag-and-drop upload
   - Bulk upload support
   - Image cropping/editing
   - Video trimming
   - Media categories/tags
   - Search and filter capabilities

5. **Analytics:**
   - Track view counts
   - Download statistics
   - Popular media tracking

## Troubleshooting

### Issue: "No file provided" error
**Solution:** Ensure `Content-Type: multipart/form-data` is set in request

### Issue: Files not displaying
**Solution:** Check CORS configuration and file serving route

### Issue: Upload fails silently
**Solution:** Check browser console for errors, verify backend logs

### Issue: Media not appearing in gallery
**Solution:** Verify `is_published: true` and refresh the page

### Issue: 403 Forbidden on upload
**Solution:** Authentication required - testing mode bypasses this

## Production Deployment Checklist

- [ ] Enable authentication on upload endpoint
- [ ] Configure file size limits
- [ ] Set up CDN for file storage
- [ ] Add MIME type validation
- [ ] Implement virus scanning
- [ ] Configure proper CORS origins
- [ ] Set up backup for uploaded files
- [ ] Add rate limiting on uploads
- [ ] Monitor storage usage
- [ ] Set up file retention policies

## Support

For issues or questions:
- Check backend logs: `TGTS_Backend/app.log.error`
- Check frontend console in browser DevTools
- Verify API documentation: `http://localhost:80/docs/`

