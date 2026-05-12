"""
Script to create and configure AWS S3 bucket for TGTS media storage
Run this script to set up the TGTS_Media bucket with photos and videos folders
"""

import boto3
import sys
from botocore.exceptions import ClientError

# Configuration
BUCKET_NAME = 'TGTS_Media'
REGION = 'us-east-1'  # Change to your preferred region
PHOTOS_FOLDER = 'photos/'
VIDEOS_FOLDER = 'videos/'

def create_bucket():
    """Create S3 bucket if it doesn't exist"""
    try:
        # Get AWS credentials from environment or use default profile
        s3_client = boto3.client('s3')
        
        # Check if bucket already exists
        try:
            s3_client.head_bucket(Bucket=BUCKET_NAME)
            print(f"✓ Bucket '{BUCKET_NAME}' already exists")
            return True
        except ClientError as e:
            error_code = e.response['Error']['Code']
            if error_code == '404':
                # Bucket doesn't exist, create it
                print(f"Creating bucket '{BUCKET_NAME}'...")
                
                # Create bucket
                if REGION == 'us-east-1':
                    # us-east-1 doesn't need LocationConstraint
                    s3_client.create_bucket(Bucket=BUCKET_NAME)
                else:
                    s3_client.create_bucket(
                        Bucket=BUCKET_NAME,
                        CreateBucketConfiguration={'LocationConstraint': REGION}
                    )
                
                print(f"✓ Bucket '{BUCKET_NAME}' created successfully")
                return True
            else:
                print(f"✗ Error checking bucket: {e}")
                return False
                
    except Exception as e:
        print(f"✗ Error creating bucket: {e}")
        print("\nMake sure you have:")
        print("1. AWS credentials configured (~/.aws/credentials or environment variables)")
        print("2. boto3 installed: pip install boto3")
        print("3. Proper IAM permissions for S3")
        return False

def configure_bucket_permissions():
    """Configure bucket for public read access"""
    try:
        s3_client = boto3.client('s3')
        
        # Enable public read access
        bucket_policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Sid": "PublicReadGetObject",
                    "Effect": "Allow",
                    "Principal": "*",
                    "Action": "s3:GetObject",
                    "Resource": f"arn:aws:s3:::{BUCKET_NAME}/*"
                }
            ]
        }
        
        import json
        s3_client.put_bucket_policy(
            Bucket=BUCKET_NAME,
            Policy=json.dumps(bucket_policy)
        )
        print(f"✓ Bucket policy configured for public read access")
        
    except Exception as e:
        print(f"⚠ Warning: Could not configure bucket policy: {e}")
        print("You may need to configure this manually in AWS Console")

def enable_cors():
    """Enable CORS for the bucket"""
    try:
        s3_client = boto3.client('s3')
        
        cors_configuration = {
            'CORSRules': [
                {
                    'AllowedHeaders': ['*'],
                    'AllowedMethods': ['GET', 'HEAD'],
                    'AllowedOrigins': ['*'],
                    'ExposeHeaders': ['ETag'],
                    'MaxAgeSeconds': 3000
                }
            ]
        }
        
        s3_client.put_bucket_cors(
            Bucket=BUCKET_NAME,
            CORSConfiguration=cors_configuration
        )
        print(f"✓ CORS configured for bucket")
        
    except Exception as e:
        print(f"⚠ Warning: Could not configure CORS: {e}")

def create_folder_structure():
    """Create photos and videos folders"""
    try:
        s3_client = boto3.client('s3')
        
        # Create folder structure by uploading empty files
        folders = [PHOTOS_FOLDER, VIDEOS_FOLDER]
        
        for folder in folders:
            try:
                # Check if folder already exists
                s3_client.head_object(Bucket=BUCKET_NAME, Key=folder)
                print(f"✓ Folder '{folder}' already exists")
            except ClientError as e:
                if e.response['Error']['Code'] == '404':
                    # Create folder by uploading a placeholder
                    s3_client.put_object(
                        Bucket=BUCKET_NAME,
                        Key=folder,
                        Body=b'',
                        Metadata={'purpose': 'folder-marker'}
                    )
                    print(f"✓ Folder '{folder}' created")
        
        return True
        
    except Exception as e:
        print(f"✗ Error creating folders: {e}")
        return False

def enable_versioning():
    """Enable versioning for the bucket"""
    try:
        s3_client = boto3.client('s3')
        s3_client.put_bucket_versioning(
            Bucket=BUCKET_NAME,
            VersioningConfiguration={'Status': 'Enabled'}
        )
        print(f"✓ Versioning enabled")
    except Exception as e:
        print(f"⚠ Warning: Could not enable versioning: {e}")

def main():
    """Main setup function"""
    print("=" * 60)
    print("TGTS S3 Bucket Setup")
    print("=" * 60)
    print(f"Bucket Name: {BUCKET_NAME}")
    print(f"Region: {REGION}")
    print(f"Folders: {PHOTOS_FOLDER}, {VIDEOS_FOLDER}")
    print("=" * 60)
    print()
    
    # Check AWS credentials
    try:
        session = boto3.Session()
        credentials = session.get_credentials()
        if not credentials:
            print("✗ AWS credentials not found!")
            print("\nPlease configure AWS credentials:")
            print("1. Install AWS CLI: pip install awscli")
            print("2. Run: aws configure")
            print("   Or set environment variables:")
            print("   export AWS_ACCESS_KEY_ID=your_key")
            print("   export AWS_SECRET_ACCESS_KEY=your_secret")
            sys.exit(1)
        
        print(f"✓ AWS credentials found (Access Key: {credentials.access_key[:10]}...)")
        print()
        
    except Exception as e:
        print(f"✗ Error checking AWS credentials: {e}")
        sys.exit(1)
    
    # Create bucket
    if not create_bucket():
        sys.exit(1)
    
    print()
    
    # Configure bucket
    print("Configuring bucket...")
    configure_bucket_permissions()
    enable_cors()
    enable_versioning()
    
    print()
    
    # Create folders
    print("Creating folder structure...")
    if not create_folder_structure():
        sys.exit(1)
    
    print()
    print("=" * 60)
    print("✓ Setup Complete!")
    print("=" * 60)
    print()
    print("Next steps:")
    print("1. Update your .env file with:")
    print(f"   AWS_REGION={REGION}")
    print(f"   S3_BUCKET_NAME={BUCKET_NAME}")
    print("   S3_USE_LOCAL_STORAGE=false")
    print()
    print("2. Set your AWS credentials in .env:")
    print("   AWS_ACCESS_KEY_ID=your_access_key")
    print("   AWS_SECRET_ACCESS_KEY=your_secret_key")
    print()
    print("3. Restart your Flask server")
    print()

if __name__ == '__main__':
    main()

