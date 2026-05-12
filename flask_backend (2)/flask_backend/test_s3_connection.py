"""
Test script to verify S3 connection and bucket access
Run this to test your AWS credentials and bucket setup
"""

import os
import sys
import boto3
from botocore.exceptions import ClientError, NoCredentialsError
from dotenv import load_dotenv

# Load environment variables from .env
load_dotenv()

def test_credentials():
    """Test if AWS credentials are configured"""
    print("=" * 60)
    print("Testing AWS S3 Connection")
    print("=" * 60)
    print()
    
    # Get credentials from environment
    aws_key = os.getenv('AWS_ACCESS_KEY_ID')
    aws_secret = os.getenv('AWS_SECRET_ACCESS_KEY')
    aws_region = os.getenv('AWS_REGION', 'us-east-1')
    bucket_name = os.getenv('S3_BUCKET_NAME', 'TGTS_Media')
    
    print("Configuration:")
    print(f"  AWS Region: {aws_region}")
    print(f"  Bucket Name: {bucket_name}")
    print(f"  Access Key ID: {aws_key[:10] + '...' if aws_key else 'NOT SET'}")
    print(f"  Secret Key: {'✓ SET' if aws_secret else '✗ NOT SET'}")
    print()
    
    # Check if credentials are set
    if not aws_key or not aws_secret:
        print("✗ ERROR: AWS credentials not found in environment variables")
        print()
        print("Please make sure your .env file contains:")
        print("  AWS_ACCESS_KEY_ID=your_access_key")
        print("  AWS_SECRET_ACCESS_KEY=your_secret_key")
        print("  AWS_REGION=us-east-1")
        print("  S3_BUCKET_NAME=TGTS_Media")
        return False
    
    print("✓ Credentials found in environment")
    print()
    
    # Test connection
    try:
        print("Testing AWS connection...")
        s3_client = boto3.client(
            's3',
            aws_access_key_id=aws_key,
            aws_secret_access_key=aws_secret,
            region_name=aws_region
        )
        
        # Test by listing buckets (basic permission test)
        print("  Attempting to list S3 buckets...")
        response = s3_client.list_buckets()
        print(f"  ✓ Successfully connected to AWS!")
        print(f"  ✓ Found {len(response['Buckets'])} bucket(s) in your account")
        print()
        
    except NoCredentialsError:
        print("  ✗ ERROR: Invalid AWS credentials")
        print("  Please check your AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY")
        return False
    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == 'SignatureDoesNotMatch':
            print("  ✗ ERROR: Invalid AWS credentials (signature mismatch)")
            print("  Please verify your AWS_SECRET_ACCESS_KEY")
            return False
        elif error_code == 'InvalidAccessKeyId':
            print("  ✗ ERROR: Invalid AWS Access Key ID")
            print("  Please verify your AWS_ACCESS_KEY_ID")
            return False
        else:
            print(f"  ✗ ERROR: {error_code}")
            print(f"  {e.response['Error']['Message']}")
            return False
    except Exception as e:
        print(f"  ✗ ERROR: {str(e)}")
        return False
    
    # Test bucket access
    print("Testing bucket access...")
    try:
        # Check if bucket exists
        print(f"  Checking if bucket '{bucket_name}' exists...")
        s3_client.head_bucket(Bucket=bucket_name)
        print(f"  ✓ Bucket '{bucket_name}' exists and is accessible")
        print()
        
        # Check folder structure
        print("Checking folder structure...")
        folders_to_check = ['photos/', 'videos/']
        
        for folder in folders_to_check:
            try:
                # Try to list objects in folder
                response = s3_client.list_objects_v2(
                    Bucket=bucket_name,
                    Prefix=folder,
                    MaxKeys=1
                )
                print(f"  ✓ Folder '{folder}' exists")
            except ClientError as e:
                if e.response['Error']['Code'] == '404':
                    print(f"  ⚠ Folder '{folder}' not found (will be created on first upload)")
                else:
                    print(f"  ✗ Error checking folder '{folder}': {e}")
        
        print()
        
        # Test write permissions
        print("Testing write permissions...")
        test_key = 'test_connection.txt'
        test_content = b'Connection test file - safe to delete'
        
        try:
            s3_client.put_object(
                Bucket=bucket_name,
                Key=test_key,
                Body=test_content,
                Metadata={'test': 'true'}
            )
            print(f"  ✓ Successfully uploaded test file to bucket")
            
            # Clean up test file
            s3_client.delete_object(Bucket=bucket_name, Key=test_key)
            print(f"  ✓ Successfully deleted test file (cleanup)")
            print()
            
        except ClientError as e:
            print(f"  ✗ ERROR: Cannot write to bucket")
            print(f"  Error: {e.response['Error']['Message']}")
            print(f"  Please check bucket permissions")
            return False
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == '404':
            print(f"  ✗ Bucket '{bucket_name}' does not exist")
            print()
            print("Next steps:")
            print("  1. Run: python setup_s3_bucket.py")
            print("  2. Or create the bucket manually in AWS Console")
            return False
        elif error_code == '403':
            print(f"  ✗ Access denied to bucket '{bucket_name}'")
            print("  Please check:")
            print("    - Bucket exists")
            print("    - IAM permissions allow access")
            print("    - Bucket policy allows your user")
            return False
        else:
            print(f"  ✗ ERROR: {error_code}")
            print(f"  {e.response['Error']['Message']}")
            return False
    
    except Exception as e:
        print(f"  ✗ ERROR: {str(e)}")
        return False
    
    # Success!
    print("=" * 60)
    print("✓ All tests passed!")
    print("=" * 60)
    print()
    print("Your S3 connection is working correctly!")
    print()
    print("Next steps:")
    print("  1. Make sure S3_USE_LOCAL_STORAGE=false in your .env file")
    print("  2. Restart your Flask server")
    print("  3. Test uploading media from admin dashboard")
    print()
    
    return True

if __name__ == '__main__':
    success = test_credentials()
    sys.exit(0 if success else 1)

