"""Status page app deployed to an AWS EC2 instance behind Nginx + HTTPS."""
import os
import socket
from datetime import datetime, timezone

from flask import Flask, jsonify, request

app = Flask(__name__)


@app.get("/")
def index():
    return (
        "<h1>Automated Cloud Deployment</h1>"
        f"<p>Served by <b>{socket.gethostname()}</b> in <b>{os.environ.get('APP_ENV', 'dev')}</b>.</p>"
        f"<p>Version {os.environ.get('APP_VERSION', 'dev')}. Scheme seen by app: {request.scheme}.</p>"
    )


@app.get("/health")
def health():
    return jsonify(status="ok", time=datetime.now(timezone.utc).isoformat())


@app.get("/api/info")
def info():
    return jsonify(
        host=socket.gethostname(),
        environment=os.environ.get("APP_ENV", "dev"),
        version=os.environ.get("APP_VERSION", "dev"),
        client_ip=request.headers.get("X-Real-IP", request.remote_addr),
        forwarded_proto=request.headers.get("X-Forwarded-Proto", "http"),
    )
