"""
S3 Service for media storage
Handles uploading files to AWS S3 or local storage as fallback
"""

import os
import re
import boto3
from botocore.exceptions import ClientError, BotoCoreError
from flask import current_app
import logging

logger = logging.getLogger(__name__)

class S3Service:
    """Service for handling S3 uploads and downloads"""
    
    def __init__(self):
        try:
            self.use_local = current_app.config.get('S3_USE_LOCAL_STORAGE', True)
            
            if not self.use_local:
                try:
                    aws_key = current_app.config.get('AWS_ACCESS_KEY_ID')
                    aws_secret = current_app.config.get('AWS_SECRET_ACCESS_KEY')
                    
                    # If AWS credentials not provided, fall back to local
                    if not aws_key or not aws_secret:
                        logger.warning("AWS credentials not configured, using local storage")
                        self.use_local = True
                    else:
                        self.s3_client = boto3.client(
                            's3',
                            aws_access_key_id=aws_key,
                            aws_secret_access_key=aws_secret,
                            region_name=current_app.config.get('AWS_REGION', 'us-east-1')
                        )
                        self.bucket_name = current_app.config.get('S3_BUCKET_NAME', 'tgts-media')
                        logger.info(f"S3 service initialized with bucket: {self.bucket_name}")
                except Exception as e:
                    logger.error(f"Failed to initialize S3 client: {str(e)}")
                    self.use_local = True
                    logger.warning("Falling back to local storage")
        except RuntimeError:
            # No Flask app context - will use local storage by default
            logger.warning("No Flask app context, defaulting to local storage mode")
            self.use_local = True
    
    def upload_file(self, file, filename, folder='media'):
        """
        Upload a file to S3 or local storage
        
        Args:
            file: File object to upload
            filename: Desired filename
            folder: Folder path in bucket or local directory
            
        Returns:
            str: URL of uploaded file
        """
        if self.use_local:
            return self._upload_local(file, filename, folder)
        else:
            return self._upload_s3(file, filename, folder)
    
    def _upload_local(self, file, filename, folder):
        """Upload file to local storage"""
        try:
            # Get upload folder from config with fallback
            upload_folder = current_app.config.get('UPLOAD_FOLDER')
            if not upload_folder:
                # Fallback to default location
                upload_folder = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), 'uploads')
                logger.warning(f"UPLOAD_FOLDER not in config, using fallback: {upload_folder}")
            
            # Create upload directory
            upload_dir = os.path.join(upload_folder, folder)
            os.makedirs(upload_dir, exist_ok=True)
            
            # Save file
            file_path = os.path.join(upload_dir, filename)
            file.save(file_path)
            
            # Generate URL
            url = f"/uploads/{folder}/{filename}"
            
            logger.info(f"File uploaded locally: {url}")
            return url
            
        except Exception as e:
            logger.error(f"Failed to upload file locally: {str(e)}")
            raise
    
    def _upload_s3(self, file, filename, folder):
        """Upload file to S3"""
        try:
            # Create key for S3
            key = f"{folder}/{filename}"
            
            # Reset file pointer
            file.seek(0)
            
            # Upload to S3
            # Note: ACL is not used as modern S3 buckets often have ACLs disabled
            # Make the bucket public via bucket policy instead
            self.s3_client.upload_fileobj(
                file,
                self.bucket_name,
                key,
                ExtraArgs={'ContentType': self._get_content_type(filename)}
            )
            
            # Generate URL
            url = f"https://{self.bucket_name}.s3.{current_app.config.get('AWS_REGION', 'us-east-1')}.amazonaws.com/{key}"
            
            logger.info(f"File uploaded to S3: {url}")
            return url
            
        except ClientError as e:
            logger.error(f"Failed to upload file to S3: {str(e)}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error uploading to S3: {str(e)}")
            raise
    
    def _get_content_type(self, filename):
        """Determine content type from filename"""
        ext = os.path.splitext(filename)[1].lower()
        content_types = {
            '.jpg': 'image/jpeg',
            '.jpeg': 'image/jpeg',
            '.png': 'image/png',
            '.gif': 'image/gif',
            '.webp': 'image/webp',
            '.mp4': 'video/mp4',
            '.mov': 'video/quicktime',
            '.avi': 'video/x-msvideo',
            '.webm': 'video/webm',
            # Document types
            '.pdf': 'application/pdf',
            '.doc': 'application/msword',
            '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            '.xls': 'application/vnd.ms-excel',
            '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            '.ppt': 'application/vnd.ms-powerpoint',
            '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            '.txt': 'text/plain',
            '.rtf': 'application/rtf',
            '.odt': 'application/vnd.oasis.opendocument.text',
            '.ods': 'application/vnd.oasis.opendocument.spreadsheet',
            '.odp': 'application/vnd.oasis.opendocument.presentation',
        }
        return content_types.get(ext, 'application/octet-stream')
    
    def list_files(self, folder=None):
        """
        List all files in S3 bucket or local storage
        
        Args:
            folder: Optional folder prefix to filter files (e.g., 'photos', 'videos')
            
        Returns:
            list: List of dictionaries with 'key', 'url', 'type' for each file
        """
        if self.use_local:
            return self._list_local_files(folder)
        else:
            return self._list_s3_files(folder)
    
    def _list_local_files(self, folder=None):
        """List files in local storage"""
        files = []
        try:
            upload_folder = current_app.config.get('UPLOAD_FOLDER')
            if not upload_folder:
                upload_folder = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), 'uploads')
            
            search_path = os.path.join(upload_folder, folder) if folder else upload_folder
            
            if not os.path.exists(search_path):
                return files
            
            for root, dirs, filenames in os.walk(search_path):
                for filename in filenames:
                    rel_path = os.path.relpath(os.path.join(root, filename), upload_folder)
                    file_path = os.path.join(root, filename)
                    
                    # Determine file type
                    ext = os.path.splitext(filename)[1].lower()
                    if ext in ['.jpg', '.jpeg', '.png', '.gif', '.webp']:
                        file_type = 'photo'
                    elif ext in ['.mp4', '.mov', '.avi', '.webm']:
                        file_type = 'video'
                    else:
                        continue  # Skip unsupported file types
                    
                    url = f"/uploads/{rel_path.replace(os.sep, '/')}"
                    files.append({
                        'key': rel_path.replace(os.sep, '/'),
                        'url': url,
                        'type': file_type,
                        'filename': filename
                    })
        except Exception as e:
            logger.error(f"Failed to list local files: {str(e)}")
        
        return files
    
    def _list_s3_files(self, folder=None):
        """List files in S3 bucket"""
        files = []
        try:
            # Determine prefixes to search
            prefixes = []
            if folder:
                prefixes.append(f"{folder}/")
            else:
                # List both photos and videos folders
                prefixes = ['photos/', 'videos/']
            
            for prefix in prefixes:
                paginator = self.s3_client.get_paginator('list_objects_v2')
                pages = paginator.paginate(Bucket=self.bucket_name, Prefix=prefix)
                
                for page in pages:
                    if 'Contents' not in page:
                        continue
                    
                    for obj in page['Contents']:
                        key = obj['Key']
                        # Skip folder markers
                        if key.endswith('/'):
                            continue
                        
                        filename = os.path.basename(key)
                        ext = os.path.splitext(filename)[1].lower()
                        
                        # Determine file type
                        if ext in ['.jpg', '.jpeg', '.png', '.gif', '.webp']:
                            file_type = 'photo'
                        elif ext in ['.mp4', '.mov', '.avi', '.webm']:
                            file_type = 'video'
                        else:
                            continue  # Skip unsupported file types
                        
                        # Generate URL
                        region = current_app.config.get('AWS_REGION', 'us-east-1')
                        url = f"https://{self.bucket_name}.s3.{region}.amazonaws.com/{key}"
                        
                        files.append({
                            'key': key,
                            'url': url,
                            'type': file_type,
                            'filename': filename
                        })
        except ClientError as e:
            logger.error(f"Failed to list S3 files: {str(e)}")
        except Exception as e:
            logger.error(f"Unexpected error listing S3 files: {str(e)}")
        
        return files
    
    def download_file(self, url):
        """
        Download file content from S3 or local storage
        
        Args:
            url: URL of the file to download
            
        Returns:
            tuple: (content_bytes, content_type, size) or (None, None, None) if failed
        """
        if self.use_local:
            return self._download_local_file(url)
        else:
            return self._download_s3_file(url)
    
    def _download_local_file(self, url):
        """Download file from local storage"""
        try:
            if url.startswith('/uploads/'):
                upload_folder = current_app.config.get('UPLOAD_FOLDER')
                if not upload_folder:
                    upload_folder = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), 'uploads')
                
                file_path = os.path.join(upload_folder, url.replace('/uploads/', ''))
                if os.path.exists(file_path):
                    with open(file_path, 'rb') as f:
                        content = f.read()
                    content_type = self._get_content_type(os.path.basename(file_path))
                    return content, content_type, len(content)
        except Exception as e:
            logger.error(f"Failed to download local file: {str(e)}")
        return None, None, None
    
    def _download_s3_file(self, url):
        """Download file from S3"""
        try:
            # Parse S3 key from URL
            if '.amazonaws.com/' in url:
                key = url.split('.amazonaws.com/')[-1]
            elif '.com/' in url:
                key = url.split('.com/')[-1]
            else:
                key = url
            
            # Download from S3
            response = self.s3_client.get_object(Bucket=self.bucket_name, Key=key)
            content = response['Body'].read()
            content_type = response.get('ContentType', self._get_content_type(key))
            size = len(content)
            
            logger.info(f"Downloaded file from S3: {key} ({size} bytes)")
            return content, content_type, size
        except ClientError as e:
            logger.error(f"Failed to download file from S3: {str(e)}")
        except Exception as e:
            logger.error(f"Unexpected error downloading from S3: {str(e)}")
        return None, None, None
    
    def delete_file(self, url):
        """
        Delete a file from storage (S3 or local)
        
        Args:
            url: URL of the file to delete
            
        Raises:
            ValueError: If URL is None or empty
            Exception: If deletion fails
        """
        if not url:
            raise ValueError("URL cannot be None or empty")
        
        if self.use_local:
            # Parse local URL
            if url.startswith('/uploads/'):
                upload_folder = current_app.config.get('UPLOAD_FOLDER')
                if not upload_folder:
                    # Fallback to default location
                    upload_folder = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), 'uploads')
                
                file_path = os.path.join(upload_folder, url.replace('/uploads/', ''))
                if os.path.exists(file_path):
                    os.remove(file_path)
                    logger.info(f"File deleted locally: {file_path}")
                else:
                    logger.warning(f"Local file not found: {file_path}")
            else:
                logger.warning(f"Invalid local URL format: {url}")
        else:
            # Parse S3 URL and delete
            try:
                # Extract S3 key from various URL formats
                key = self._extract_s3_key(url)
                
                if not key:
                    raise ValueError(f"Could not extract S3 key from URL: {url}")
                
                # Delete from S3
                self.s3_client.delete_object(Bucket=self.bucket_name, Key=key)
                logger.info(f"File deleted from S3: {key} (bucket: {self.bucket_name})")
                
            except ClientError as e:
                error_code = e.response.get('Error', {}).get('Code', 'Unknown')
                error_msg = f"Failed to delete file from S3: {error_code} - {str(e)}"
                logger.error(error_msg)
                raise Exception(error_msg) from e
            except Exception as e:
                error_msg = f"Failed to delete file from S3: {str(e)}"
                logger.error(error_msg)
                raise Exception(error_msg) from e
    
    def _extract_s3_key(self, url):
        """
        Extract S3 key from various URL formats
        
        Supports:
        - https://bucket-name.s3.region.amazonaws.com/key
        - https://bucket-name.s3-region.amazonaws.com/key
        - https://s3.region.amazonaws.com/bucket-name/key
        - https://s3-region.amazonaws.com/bucket-name/key
        - key (if already a key)
        
        Args:
            url: S3 URL or key
            
        Returns:
            str: S3 key or None if extraction fails
        """
        if not url:
            return None
        
        # If it's already just a key (no http/https), return as is
        if not url.startswith('http://') and not url.startswith('https://'):
            return url
        
        # Remove protocol
        url = url.replace('http://', '').replace('https://', '')
        
        # Escape bucket name for regex (in case it contains special characters)
        escaped_bucket = re.escape(self.bucket_name)
        
        # Try different S3 URL patterns
        patterns = [
            # Pattern: bucket-name.s3.region.amazonaws.com/key
            rf'{escaped_bucket}\.s3\.[^/]+\.amazonaws\.com/(.+)',
            # Pattern: bucket-name.s3-region.amazonaws.com/key
            rf'{escaped_bucket}\.s3-[^/]+\.amazonaws\.com/(.+)',
            # Pattern: s3.region.amazonaws.com/bucket-name/key
            r's3\.[^/]+\.amazonaws\.com/[^/]+/(.+)',
            # Pattern: s3-region.amazonaws.com/bucket-name/key
            r's3-[^/]+\.amazonaws\.com/[^/]+/(.+)',
            # Pattern: .com/key (fallback)
            r'\.com/(.+)',
            # Pattern: .amazonaws.com/key (fallback)
            r'\.amazonaws\.com/(.+)',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, url)
            if match:
                key = match.group(1)
                # Remove query parameters if any
                key = key.split('?')[0]
                return key
        
        # If no pattern matched, try to extract everything after the last /
        if '/' in url:
            return url.split('/', 1)[-1].split('?')[0]
        
        return None

# Global instance - lazy initialization
_s3_service_instance = None

def get_s3_service():
    """Get or create S3 service instance with proper Flask context"""
    # Always create fresh instance to ensure proper Flask app context
    return S3Service()

# For backward compatibility
s3_service = None  # Will be initialized lazily

