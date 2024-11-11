import json
import requests
from flask import Flask, request, jsonify

app = Flask(__name__)


# Function to create a data source
def create_data_source(grafana_url,token,data_source_name, data_source_uid, data_source_url,basic_auth_password,basic_auth_user):
    
    # Headers for the request
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
        response = requests.post(f"{grafana_url}/datasources", headers=headers, json=data_source_payload)
        return response
    except requests.exceptions.RequestException as e:
        print(f"Failed to create data source: {e}")
        return None

# Function to create a dashboard
def create_dashboard(grafana_url,token,data_source_uid, dashboard_title, dashboard_description):

    # Headers for the request
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    try:
        with open('dashboard.json', 'r') as file:
            dashboard_data = json.load(file)

        dashboard_data["dashboard"]["title"] = dashboard_title
        dashboard_data["dashboard"]["description"] = dashboard_description

        json_str = json.dumps(dashboard_data)
        json_str = json_str.replace("${DS_PROMETHEUS}", data_source_uid)
        updated_dashboard_json = json.loads(json_str)

        response = requests.post(f"{grafana_url}/dashboards/db", headers=headers, json=updated_dashboard_json)
        response.raise_for_status()
        return response
    except Exception as e:
        print(f"Failed to create dashboard: {e}")
        return None

# Flask route to create a dashboard
@app.route('/create_dashboard', methods=['POST'])
def create_dashboard_route():
    # Get the JSON data from the request
    data = request.json
    
    data_source_name = data.get('data_source_name')
    data_source_uid = data.get('data_source_uid')
    data_source_url = data.get('data_source_url')
    dashboard_title = data.get('dashboard_title')
    dashboard_description = data.get('dashboard_description')
    basic_auth_password = data.get('basic_auth_password')
    basic_auth_user = data.get('basic_auth_user')
    grafana_url=data.get('grafana_url')
    grafana_token=data.get('grafana_token')

    # Create the data source
    data_source_response = create_data_source(grafana_url,grafana_token,data_source_name, data_source_uid, data_source_url,basic_auth_password,basic_auth_user)
    if data_source_response:
        # Create the dashboard
        dashboard_response = create_dashboard(grafana_url,grafana_token,data_source_uid, dashboard_title, dashboard_description)
        if dashboard_response:
            return jsonify({
                "status": "success",
                "message": "Dashboard successfully created!",
                "response": dashboard_response.json()
            }), 201  # Created
        else:
            return jsonify({
                "status": "error",
                "message": "Failed to create dashboard."
            }), 500  # Internal server error
    else:
        return jsonify({
            "status": "error",
            "message": "Failed to create data source."
        }), 500  # Internal server error

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)