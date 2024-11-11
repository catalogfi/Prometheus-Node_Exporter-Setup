import json
import urllib3
from urllib3.exceptions import HTTPError

# Create a PoolManager instance for making requests
http = urllib3.PoolManager()

# Function to create a data source with enhanced logging
def create_data_source(grafana_url, token, data_source_name, data_source_uid, data_source_url, basic_auth_password, basic_auth_user):
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    data_source_payload = {
        "name": data_source_name,
        "type": "prometheus",
        "url": data_source_url,
        "access": "proxy",
        "basicAuth": True,
        "basicAuthUser": basic_auth_user,
        "secureJsonData": {
            "basicAuthPassword": basic_auth_password
        },
        "jsonData": {
            "timeInterval": "5s"
        },
        "uid": data_source_uid
    }

    try:
        response = http.request(
            'POST',
            f"{grafana_url}/api/datasources",
            headers=headers,
            body=json.dumps(data_source_payload)
        )

        # Log the response status and body for debugging
        print("Data Source Creation Response Status:", response.status)
        print("Data Source Creation Response Body:", response.data.decode('utf-8'))

        # Check for a successful response (HTTP status 200 or 201)
        if response.status in [200, 201]:
            return response
        else:
            print("Error creating data source:", response.data.decode('utf-8'))
            return None

    except HTTPError as e:
        print(f"Failed to create data source: {e}")
        return None


def create_dashboard(grafana_url, token, data_source_uid, dashboard_title, dashboard_description):
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    try:
        # Load the JSON template and update title, description, and data source UID
        with open('dashboard.json', 'r') as file:
            dashboard_data = json.load(file)

        dashboard_data["dashboard"]["title"] = dashboard_title
        dashboard_data["dashboard"]["description"] = dashboard_description

        # Replace the data source placeholder with the actual UID
        json_str = json.dumps(dashboard_data)
        json_str = json_str.replace("${DS_PROMETHEUS}", data_source_uid)
        updated_dashboard_json = json.loads(json_str)

        # Make the request to create the dashboard
        response = http.request(
            'POST',
            f"{grafana_url}/api/dashboards/db",
            headers=headers,
            body=json.dumps(updated_dashboard_json)
        )

        # Log response status and body for debugging
        print("Dashboard Creation Response Status:", response.status)
        print("Dashboard Creation Response Body:", response.data.decode('utf-8'))

        # Check if creation was successful (HTTP 200 or 201)
        if response.status in [200, 201]:
            return response
        else:
            print("Error creating dashboard:", response.data.decode('utf-8'))
            return None

    except Exception as e:
        print(f"Failed to create dashboard: {e}")
        return None


# Lambda handler function
def lambda_handler(event, context):
    try:
        print(f"Received event: {event}")  # Log the received event for debugging
        data = json.loads(event['body'])
        
        # Ensure all required fields are present
        required_fields = [
            "data_source_name", "data_source_uid", "data_source_url",
            "dashboard_title", "dashboard_description",
            "basic_auth_user", "basic_auth_password",
            "grafana_url", "grafana_token"
        ]
        
        for field in required_fields:
            if field not in data:
                return {
                    "statusCode": 400,
                    "body": json.dumps({
                        "status": "error",
                        "message": f"Missing required field: {field}"
                    })
                }

        # Assign variables from the data
        data_source_name = data["data_source_name"]
        data_source_uid = data["data_source_uid"]
        data_source_url = data["data_source_url"]
        dashboard_title = data["dashboard_title"]
        dashboard_description = data["dashboard_description"]
        basic_auth_password = data["basic_auth_password"]
        basic_auth_user = data["basic_auth_user"]
        grafana_url = data["grafana_url"]
        grafana_token = data["grafana_token"]

        # Create the data source
        data_source_response = create_data_source(grafana_url, grafana_token, data_source_name, data_source_uid, data_source_url, basic_auth_password, basic_auth_user)
        
        if data_source_response and data_source_response.status == 200:
            # Create the dashboard
            dashboard_response = create_dashboard(grafana_url, grafana_token, data_source_uid, dashboard_title, dashboard_description)
            if dashboard_response and dashboard_response.status == 200:
                return {
                    "statusCode": 201,
                    "body": json.dumps({
                        "status": "success",
                        "message": "Dashboard successfully created!",
                        "response": json.loads(dashboard_response.data.decode('utf-8'))
                    })
                }
            else:
                return {
                    "statusCode": 500,
                    "body": json.dumps({
                        "status": "error",
                        "message": "Failed to create dashboard."
                    })
                }
        else:
            return {
                "statusCode": 500,
                "body": json.dumps({
                    "status": "error",
                    "message": "Failed to create data source."
                })
            }
    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "body": json.dumps({
                "status": "error",
                "message": "Invalid JSON format."
            })
        }
    except Exception as e:
        print(f"Error: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({
                "status": "error",
                "message": str(e)  # Return the error message for debugging
            })
        }