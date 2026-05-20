# Systemd Service (Auto-Start) for Finapp Backend

## 1) Create service file
Create a new file at:
- /etc/systemd/system/finapp.service

Paste this content (edit paths and user):

[Unit]
Description=Finapp FastAPI Backend
After=network.target

[Service]
Type=simple
User=YOUR_USER
WorkingDirectory=%h/proj/finappmobile
Environment="PATH=%h/proj/finappmobile/.venv/bin"
ExecStart=%h/proj/finappmobile/.venv/bin/python -m uvicorn backend.fastapi_app:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target

## 2) Enable and start
Run these commands:
- sudo systemctl daemon-reload
- sudo systemctl enable finapp
- sudo systemctl start finapp
- sudo systemctl status finapp

## 3) Logs
Check logs with:
- sudo journalctl -u finapp -f

## 4) Notes
- Replace YOUR_USER with your Linux username.
- Do NOT use ~ in systemd unit files. Use absolute paths, or %h for the home directory.
- If your project is NOT in %h/proj/finappmobile, replace the paths with your actual location.
- If you use a different venv path, update Environment and ExecStart accordingly.
