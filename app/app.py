from flask import Flask, render_template, jsonify, request
import json
import os
from datetime import datetime
import boto3
from botocore.exceptions import ClientError

app = Flask(__name__)

# Configuration
app.config['SECRET_KEY'] = os.environ.get(
    'SECRET_KEY', 'dev-secret-key-change-in-production')

# AWS Configuration - Use environment variables or defaults for local dev
AWS_REGION = os.environ.get('AWS_DEFAULT_REGION', 'us-east-1')
DYNAMODB_TABLE = os.environ.get(
    'DYNAMODB_TABLE', 'portfolio-dashboard-visitor-counter')
S3_BUCKET = os.environ.get('S3_BUCKET', 'portfolio-assets-bucket')

# Try to initialize AWS clients (will fail gracefully in local dev)
try:
    dynamodb = boto3.resource('dynamodb', region_name=AWS_REGION)
    table = dynamodb.Table(DYNAMODB_TABLE)
    aws_available = True
except Exception as e:
    print(f"AWS services not available in local development: {e}")
    dynamodb = None
    table = None
    aws_available = False

# Sample portfolio data
PORTFOLIO_DATA = {
    "personal_info": {
        "name": "Your Name",
        "title": "Full Stack Developer & Cloud Enthusiast",
        "email": "your.email@example.com",
        "location": "Your City, Country",
        "bio": "Passionate developer learning cloud technologies and modern web development. Building scalable applications with Flask, AWS, and Terraform."
    },
    "skills": [
        {"name": "Python", "level": 85},
        {"name": "JavaScript", "level": 75},
        {"name": "AWS", "level": 70},
        {"name": "Terraform", "level": 65},
        {"name": "Flask", "level": 80},
        {"name": "HTML/CSS", "level": 90},
        {"name": "Docker", "level": 60},
        {"name": "Git", "level": 85}
    ],
    "projects": [
        {
            "id": 1,
            "name": "Portfolio Dashboard",
            "description": "A cloud-based portfolio dashboard built with Flask, AWS, and Terraform. Features auto-scaling, load balancing, and real-time visitor tracking.",
            "technologies": ["Python", "Flask", "AWS", "Terraform", "DynamoDB", "EC2"],
            "status": "In Progress",
            "github_url": "https://github.com/yourusername/portfolio-project"
        },
        {
            "id": 2,
            "name": "Learning Management System",
            "description": "A comprehensive web application for managing courses, students, and educational content with user authentication and progress tracking.",
            "technologies": ["Python", "Django", "PostgreSQL", "Bootstrap"],
            "status": "Completed",
            "github_url": "https://github.com/yourusername/lms-project"
        },
        {
            "id": 3,
            "name": "E-commerce API",
            "description": "RESTful API for an e-commerce platform with inventory management, order processing, and payment integration.",
            "technologies": ["Python", "FastAPI", "MongoDB", "Redis"],
            "status": "Completed",
            "github_url": "https://github.com/yourusername/ecommerce-api"
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
        "environment": "development" if app.debug else "production",
        "aws_available": aws_available
    })


@app.route('/api/visitor-count')
def visitor_count():
    """Get and increment visitor count from DynamoDB"""
    if not aws_available or not table:
        # Return mock data for local development
        return jsonify({"count": 42, "source": "mock"})

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

        return jsonify({"count": new_count, "source": "dynamodb"})
    except Exception as e:
        print(f"Error accessing DynamoDB: {e}")
        # Return a fallback count if DynamoDB is unavailable
        return jsonify({"count": 100, "source": "fallback"})


@app.route('/api/contact', methods=['POST'])
def contact():
    """Handle contact form submissions"""
    try:
        data = request.get_json()

        # Validate input
        if not data:
            return jsonify({
                "status": "error",
                "message": "No data received"
            }), 400

        name = data.get('name', '').strip()
        email = data.get('email', '').strip()
        message = data.get('message', '').strip()

        # Basic validation
        if not all([name, email, message]):
            return jsonify({
                "status": "error",
                "message": "All fields are required"
            }), 400

        if '@' not in email:
            return jsonify({
                "status": "error",
                "message": "Please provide a valid email address"
            }), 400

        # Log the contact form submission (in production, you'd save this to database or send email)
        contact_data = {
            "name": name,
            "email": email,
            "message": message,
            "timestamp": datetime.now().isoformat(),
            "ip": request.remote_addr
        }

        print(f"📧 New contact form submission:")
        print(f"   Name: {name}")
        print(f"   Email: {email}")
        print(f"   Message: {message}")
        print(f"   Time: {contact_data['timestamp']}")

        # Here you could integrate with AWS SES for email notifications
        # For now, just return success
        return jsonify({
            "status": "success",
            "message": f"Thank you {name}! Your message has been received. I'll get back to you soon at {email}."
        })

    except Exception as e:
        print(f"❌ Error handling contact form: {e}")
        return jsonify({
            "status": "error",
            "message": "Sorry, there was an error processing your message. Please try again later."
        }), 500


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({
        "status": "error",
        "message": "Endpoint not found",
        "code": 404
    }), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    return jsonify({
        "status": "error",
        "message": "Internal server error",
        "code": 500
    }), 500


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('FLASK_ENV') == 'development'

    print("🚀 Starting Portfolio Dashboard...")
    print(f"   Port: {port}")
    print(f"   Debug: {debug}")
    print(f"   AWS Available: {aws_available}")
    print(f"   Visit: http://localhost:{port}")
    print("="*50)

    app.run(host='0.0.0.0', port=port, debug=debug)
