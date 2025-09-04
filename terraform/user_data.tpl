#!/bin/bash

# Update system
yum update -y

# Install required packages
yum install -y python3 python3-pip git nginx

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Install CloudWatch agent
yum install -y amazon-cloudwatch-agent

# Create application user
useradd -m -s /bin/bash portfolio
usermod -a -G wheel portfolio

# Create application directory
mkdir -p /opt/portfolio/app
mkdir -p /opt/portfolio/app/templates
chown -R portfolio:portfolio /opt/portfolio

# Create app.py with proper AWS configuration
cat > /opt/portfolio/app/app.py << 'APPEOF'
from flask import Flask, render_template, jsonify, request
import json
import os
from datetime import datetime
import boto3
from botocore.exceptions import ClientError

app = Flask(__name__)

# Configuration
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'production-secret-key')

# AWS Configuration
AWS_REGION = "${aws_region}"
DYNAMODB_TABLE = "${dynamodb_table}"
S3_BUCKET = "${s3_bucket}"

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb', region_name=AWS_REGION)
table = dynamodb.Table(DYNAMODB_TABLE)

# Sample portfolio data
PORTFOLIO_DATA = {
    "personal_info": {
        "name": "Your Name",
        "title": "Full Stack Developer",
        "email": "your.email@example.com",
        "location": "Your City, Country",
        "bio": "Passionate developer learning cloud technologies and modern web development."
    },
    "skills": [
        {"name": "Python", "level": 85},
        {"name": "JavaScript", "level": 75},
        {"name": "AWS", "level": 70},
        {"name": "Terraform", "level": 65},
        {"name": "Flask", "level": 80},
        {"name": "HTML/CSS", "level": 90}
    ],
    "projects": [
        {
            "id": 1,
            "name": "Portfolio Dashboard",
            "description": "A cloud-based portfolio dashboard built with Flask, AWS, and Terraform",
            "technologies": ["Python", "Flask", "AWS", "Terraform"],
            "status": "In Progress",
            "github_url": "https://github.com/yourusername/portfolio-project"
        },
        {
            "id": 2,
            "name": "Learning Management System",
            "description": "A web application for managing courses and students",
            "technologies": ["Python", "Django", "PostgreSQL"],
            "status": "Completed",
            "github_url": "#"
        }
    ]
}

@app.route('/')
def dashboard():
    """Main dashboard page"""
    return render_template('dashboard.html', data=PORTFOLIO_DATA)

@app.route('/api/portfolio')
def get_portfolio():
    """API endpoint to get portfolio data"""
    return jsonify(PORTFOLIO_DATA)

@app.route('/api/projects')
def get_projects():
    """API endpoint to get projects"""
    return jsonify(PORTFOLIO_DATA['projects'])

@app.route('/api/skills')
def get_skills():
    """API endpoint to get skills"""
    return jsonify(PORTFOLIO_DATA['skills'])

@app.route('/api/health')
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "version": "1.0.0",
        "instance": "${aws_region}"
    })

@app.route('/api/visitor-count')
def visitor_count():
    """Get and increment visitor count from DynamoDB"""
    try:
        # Get current count
        response = table.get_item(Key={'id': 'visitor_count'})
        
        if 'Item' in response:
            current_count = int(response['Item']['count'])
        else:
            current_count = 0
        
        # Increment count
        new_count = current_count + 1
        
        # Update DynamoDB
        table.put_item(Item={'id': 'visitor_count', 'count': new_count})
        
        return jsonify({"count": new_count})
    except Exception as e:
        print(f"Error accessing DynamoDB: {e}")
        # Return a default count if DynamoDB is unavailable
        return jsonify({"count": 42})

@app.route('/api/contact', methods=['POST'])
def contact():
    """Handle contact form submissions"""
    try:
        data = request.get_json()
        name = data.get('name', '')
        email = data.get('email', '')
        message = data.get('message', '')
        
        # Log the contact form submission
        print(f"Contact form submission: {name} ({email}): {message}")
        
        # Here you could integrate with AWS SES for email notifications
        # For now, just return success
        return jsonify({
            "status": "success",
            "message": "Thank you for your message! I'll get back to you soon."
        })
    except Exception as e:
        print(f"Error handling contact form: {e}")
        return jsonify({
            "status": "error",
            "message": "Sorry, there was an error sending your message."
        }), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
APPEOF

# Create requirements.txt
cat > /opt/portfolio/app/requirements.txt << 'REQEOF'
Flask==2.3.3
boto3==1.34.0
botocore==1.34.0
gunicorn==21.2.0
python-dotenv==1.0.0
requests==2.31.0
Werkzeug==2.3.7
REQEOF

# Create a basic HTML template (you'll replace this with your dark theme)
cat > /opt/portfolio/app/templates/dashboard.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <title>Portfolio Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #0f0f23; color: white; }
        .container { max-width: 800px; margin: 0 auto; }
        .card { background: rgba(255,255,255,0.1); padding: 20px; margin: 20px 0; border-radius: 10px; }
        .metric { display: inline-block; margin: 10px; padding: 15px; background: #00d4ff; border-radius: 5px; color: black; }
    </style>
</head>
<body>
    <div class="container">
        <h1>{{ data.personal_info.name }}</h1>
        <h2>{{ data.personal_info.title }}</h2>
        
        <div class="card">
            <h3>Skills</h3>
            {% for skill in data.skills %}
            <div>{{ skill.name }}: {{ skill.level }}%</div>
            {% endfor %}
        </div>
        
        <div class="card">
            <h3>Projects</h3>
            {% for project in data.projects %}
            <div>
                <h4>{{ project.name }}</h4>
                <p>{{ project.description }}</p>
                <p>Status: {{ project.status }}</p>
            </div>
            {% endfor %}
        </div>
        
        <div class="card">
            <h3>Metrics</h3>
            <div class="metric">Visitors: <span id="visitor-count">--</span></div>
            <div class="metric">Projects: {{ data.projects|length }}</div>
            <div class="metric">Skills: {{ data.skills|length }}</div>
        </div>
    </div>
    
    <script>
        fetch('/api/visitor-count')
            .then(response => response.json())
            .then(data => {
                document.getElementById('visitor-count').textContent = data.count;
            })
            .catch(error => {
                document.getElementById('visitor-count').textContent = '42';
            });
    </script>
</body>
</html>
HTMLEOF

# Set ownership
chown -R portfolio:portfolio /opt/portfolio

# Install Python dependencies
cd /opt/portfolio/app
pip3 install -r requirements.txt

# Create systemd service for the Flask app
cat > /etc/systemd/system/portfolio.service << 'SERVICEEOF'
[Unit]
Description=Portfolio Flask App
After=network.target

[Service]
Type=simple
User=portfolio
WorkingDirectory=/opt/portfolio/app
Environment=PATH=/usr/local/bin
Environment=AWS_DEFAULT_REGION=${aws_region}
Environment=DYNAMODB_TABLE=${dynamodb_table}
Environment=S3_BUCKET=${s3_bucket}
ExecStart=/usr/bin/python3 -m gunicorn --bind 0.0.0.0:5000 --workers 2 app:app
Restart=always

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Enable and start the service
systemctl daemon-reload
systemctl enable portfolio
systemctl start portfolio

# Configure nginx as reverse proxy
cat > /etc/nginx/conf.d/portfolio.conf << 'NGINXEOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
NGINXEOF

# Start nginx
systemctl enable nginx
systemctl start nginx

# Configure CloudWatch agent
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWEOF'
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/nginx/access.log",
                        "log_group_name": "/aws/ec2/${aws_region}-portfolio",
                        "log_stream_name": "nginx-access"
                    },
                    {
                        "file_path": "/var/log/nginx/error.log",
                        "log_group_name": "/aws/ec2/${aws_region}-portfolio",
                        "log_stream_name": "nginx-error"
                    }
                ]
            }
        }
    }
}
CWEOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Create a simple health check
echo "Portfolio application setup completed successfully at $(date)" > /var/log/portfolio-setup.log

# Final status check
systemctl status portfolio --no-pager
systemctl status nginx --no-pager