from flask import Flask
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
import os

db = SQLAlchemy()

def create_app(test_config=None):
    app = Flask(__name__, instance_relative_config=True)
    
    # Configuration
    app.config.from_mapping(
        SECRET_KEY='dev-key-change-in-production',
        DATABASE_URL=os.environ.get('DATABASE_URL', 'sqlite:///logs.db'),
        SQLALCHEMY_DATABASE_URI=os.environ.get('DATABASE_URL', 'sqlite:///logs.db'),
        SQLALCHEMY_TRACK_MODIFICATIONS=False,
        LOG_DATA_PATH=os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../data/logs')
    )
    
    if test_config:
        app.config.from_mapping(test_config)
    
    # Enable CORS for React frontend
    CORS(app, origins=['http://localhost:3000'])
    
    # Initialize extensions
    db.init_app(app)
    
    # Register blueprints
    from app.views import logs_bp
    app.register_blueprint(logs_bp)
    
    # Create tables
    with app.app_context():
        db.create_all()
    
    return app
