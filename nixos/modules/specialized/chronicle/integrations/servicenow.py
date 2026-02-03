#!/usr/bin/env python3
import argparse
import json
import sys
import os
from pathlib import Path

INSTANCE = os.environ.get("INSTANCE", "")
AUTH_METHOD = os.environ.get("AUTH_METHOD", "oauth2")
PRIORITY = os.environ.get("PRIORITY", "3")
CATEGORY = os.environ.get("CATEGORY", "software")
ASSIGNMENT_GROUP = os.environ.get("ASSIGNMENT_GROUP", "")
INCLUDE_SCREENSHOTS = os.environ.get("INCLUDE_SCREENSHOTS", "False") == "True"
INCLUDE_LOGS = os.environ.get("INCLUDE_LOGS", "False") == "True"

class ServiceNowIntegration:
    def __init__(self):
        self.base_url = f"https://{INSTANCE}"
        self.session = None
        
    def authenticate(self):
        """Authenticate with ServiceNow"""
        print(f"Authenticating with ServiceNow ({INSTANCE})...")
        print(f"Auth method: {AUTH_METHOD}")
        
        # Simulated authentication
        print("✓ Authenticated successfully")
        
    def create_incident(self, session_file, title=None, description=None):
        """Create incident from session"""
        session_path = Path(session_file)
        if not session_path.exists():
            print(f"ERROR: Session file not found: {session_file}")
            sys.exit(1)
            
        session_data = json.loads(session_path.read_text())
        
        if not title:
            title = session_data.get('metadata', {}).get('title', 'Untitled Issue')
        if not description:
            description = session_data.get('metadata', {}).get('description', '')
        
        # Create incident data
        incident = {
            "short_description": title,
            "description": description,
            "priority": PRIORITY,
            "category": CATEGORY,
            "assignment_group": ASSIGNMENT_GROUP,
            "caller_id": session_data.get('metadata', {}).get('user', 'unknown'),
            "impact": "2",
            "urgency": "2",
        }
        
        print(f"\n=== Creating ServiceNow Incident ===")
        print(f"Title: {title}")
        print(f"Priority: {PRIORITY}")
        print(f"Category: {CATEGORY}")
        print(f"Steps: {len(session_data.get('steps', []))}")
        
        # Simulated API call
        incident_number = "INC0123456"
        print(f"\n✓ Incident created: {incident_number}")
        print(f"URL: {self.base_url}/nav_to.do?uri=incident.do?sys_id=abc123")
        
        # Handle attachments
        if INCLUDE_SCREENSHOTS:
            print("\n📎 Attaching screenshots...")
            screenshot_count = len([s for s in session_data.get('steps', []) if 'screenshot' in s])
            print(f"   Attached {screenshot_count} screenshots")
            
        if INCLUDE_LOGS:
            print("📎 Attaching system logs...")
            print("   Attached logs.txt")
        
        return incident_number
        
    def update_incident(self, incident_number, session_file):
        """Update existing incident with session data"""
        print(f"\n=== Updating Incident {incident_number} ===")
        print("✓ Incident updated successfully")
        
    def search_incidents(self, query):
        """Search for incidents"""
        print(f"\n=== Searching Incidents: '{query}' ===")
        
        # Simulated results
        results = [
            {"number": "INC0123456", "short_description": "Login issue", "state": "In Progress"},
            {"number": "INC0123457", "short_description": "App crash", "state": "New"},
        ]
        
        for incident in results:
            print(f"\n{incident['number']}: {incident['short_description']}")
            print(f"  State: {incident['state']}")
            
    def get_incident(self, incident_number):
        """Get incident details"""
        print(f"\n=== Incident Details: {incident_number} ===")
        print(f"Title: Sample Incident")
        print(f"State: In Progress")
        print(f"Priority: {PRIORITY}")
        print(f"Assigned to: John Doe")
        print(f"Created: 2026-01-02 16:00:00")
        
def main():
    parser = argparse.ArgumentParser(description="ServiceNow Integration")
    subparsers = parser.add_subparsers(dest='command', help='Commands')
    
    # Create incident
    create_parser = subparsers.add_parser('create', help='Create incident from session')
    create_parser.add_argument('session_file', help='Path to session JSON file')
    create_parser.add_argument('--title', help='Incident title')
    create_parser.add_argument('--description', help='Incident description')
    
    # Update incident
    update_parser = subparsers.add_parser('update', help='Update incident')
    update_parser.add_argument('incident_number', help='Incident number')
    update_parser.add_argument('session_file', help='Path to session JSON file')
    
    # Search incidents
    search_parser = subparsers.add_parser('search', help='Search incidents')
    search_parser.add_argument('query', help='Search query')
    
    # Get incident
    get_parser = subparsers.add_parser('get', help='Get incident details')
    get_parser.add_argument('incident_number', help='Incident number')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
        
    integration = ServiceNowIntegration()
    integration.authenticate()
    
    if args.command == 'create':
        integration.create_incident(args.session_file, args.title, args.description)
    elif args.command == 'update':
        integration.update_incident(args.incident_number, args.session_file)
    elif args.command == 'search':
        integration.search_incidents(args.query)
    elif args.command == 'get':
        integration.get_incident(args.incident_number)

if __name__ == "__main__":
    main()
