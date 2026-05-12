#!/bin/bash
# Production Deployment Script for Telangana Congress Communication App
# This script sets up the production environment and starts the application

set -e  # Exit on any error

echo "🚀 Starting Production Deployment for Telangana Congress API"

# Configuration
APP_NAME="telangana-congress-api"
APP_DIR="/opt/$APP_NAME"
SERVICE_USER="www-data"
LOG_DIR="/var/log/$APP_NAME"
PID_DIR="/var/run/$APP_NAME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root for security reasons"
   exit 1
fi

# Create necessary directories
print_status "Creating application directories..."
sudo mkdir -p $APP_DIR
sudo mkdir -p $LOG_DIR
sudo mkdir -p $PID_DIR
sudo mkdir -p $APP_DIR/logs
sudo mkdir -p $APP_DIR/uploads

# Set proper permissions
sudo chown -R $SERVICE_USER:$SERVICE_USER $APP_DIR
sudo chown -R $SERVICE_USER:$SERVICE_USER $LOG_DIR
sudo chown -R $SERVICE_USER:$SERVICE_USER $PID_DIR

# Copy application files
print_status "Copying application files..."
sudo cp -r . $APP_DIR/
sudo chown -R $SERVICE_USER:$SERVICE_USER $APP_DIR

# Install Python dependencies
print_status "Installing Python dependencies..."
cd $APP_DIR
sudo -u $SERVICE_USER python3 -m pip install --user -r requirements.txt

# Set up environment
print_status "Setting up environment configuration..."
if [ ! -f $APP_DIR/.env ]; then
    sudo -u $SERVICE_USER cp env_production.txt $APP_DIR/.env
    print_warning "Please edit $APP_DIR/.env with your production settings"
fi

# Initialize database
print_status "Initializing database..."
sudo -u $SERVICE_USER python3 -c "
from app import create_app, db
app = create_app()
with app.app_context():
    db.create_all()
    print('Database initialized successfully')
"

# Create systemd service file
print_status "Creating systemd service..."
sudo tee /etc/systemd/system/$APP_NAME.service > /dev/null <<EOF
[Unit]
Description=Telangana Congress Communication API
After=network.target

[Service]
Type=exec
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/.local/bin:/usr/local/bin:/usr/bin:/bin
Environment=FLASK_ENV=production
ExecStart=$APP_DIR/.local/bin/gunicorn --config wsgi.py wsgi:application
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$APP_NAME

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$APP_DIR $LOG_DIR $PID_DIR

[Install]
WantedBy=multi-user.target
EOF

# Create nginx configuration
print_status "Creating nginx configuration..."
sudo tee /etc/nginx/sites-available/$APP_NAME > /dev/null <<EOF
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req zone=api burst=20 nodelay;

    location / {
        proxy_pass http://127.0.0.1:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # Static files
    location /static/ {
        alias $APP_DIR/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Uploads
    location /uploads/ {
        alias $APP_DIR/uploads/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Health check
    location /api/health {
        proxy_pass http://127.0.0.1:80;
        access_log off;
    }
}
EOF

# Enable nginx site
sudo ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
sudo nginx -t

# Create logrotate configuration
print_status "Setting up log rotation..."
sudo tee /etc/logrotate.d/$APP_NAME > /dev/null <<EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $SERVICE_USER $SERVICE_USER
    postrotate
        systemctl reload $APP_NAME
    endscript
}
EOF

# Enable and start services
print_status "Enabling and starting services..."
sudo systemctl daemon-reload
sudo systemctl enable $APP_NAME
sudo systemctl start $APP_NAME
sudo systemctl reload nginx

# Check service status
print_status "Checking service status..."
sleep 5
if systemctl is-active --quiet $APP_NAME; then
    print_status "✅ $APP_NAME service is running"
else
    print_error "❌ $APP_NAME service failed to start"
    sudo systemctl status $APP_NAME
    exit 1
fi

# Test the API
print_status "Testing API endpoint..."
if curl -f -s http://localhost/api/health > /dev/null; then
    print_status "✅ API health check passed"
else
    print_error "❌ API health check failed"
    exit 1
fi

print_status "🎉 Production deployment completed successfully!"
print_status "API is available at: http://your-domain.com"
print_status "Health check: http://your-domain.com/api/health"
print_status "API docs: http://your-domain.com/docs/"
print_warning "Don't forget to:"
print_warning "1. Update DNS records to point to this server"
print_warning "2. Configure SSL certificates for HTTPS"
print_warning "3. Update the .env file with production values"
print_warning "4. Set up database backups"
print_warning "5. Configure monitoring and alerting"


