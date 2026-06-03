import json
import os

import requests

API_KEY = "api_here"

response = requests.get(
    url="https://openrouter.ai/api/v1/key",
    headers={"Authorization": f"Bearer {API_KEY}"},
    timeout=20,
)

print("Status:", response.status_code)
try:
    print(json.dumps(response.json(), indent=2))
except Exception:
    print(response.text)
