#!/bin/bash

dnf update -y
dnf install -y python3-pip mariadb105 amazon-cloudwatch-agent
pip3 install flask pymysql boto3
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent

mkdir -p /opt/rdsapp
touch /opt/rdsapp/app.log
chmod 666 /opt/rdsapp/app.log
chmod 755 /opt/rdsapp

cat >/opt/rdsapp/app.py <<'PY'
import json
import os
import boto3
import pymysql
import logging
from flask import Flask, request

REGION = os.environ.get("AWS_REGION", "ap-northeast-1")
SECRET_ID = os.environ.get("SECRET_ID", "lab-1a/rds/mysql")

secrets = boto3.client("secretsmanager", region_name=REGION)
cloudwatch = boto3.client("cloudwatch", region_name=REGION)
ssm = boto3.client("ssm", region_name=REGION)

#configure logging
logging.basicConfig(
    filename='/opt/rdsapp/app.log',
    level=logging.ERROR,
    format='%(asctime)s ERROR: %(message)s'
)

def emit_db_error():
    try:
        cloudwatch.put_metric_data(
            Namespace="Lab/RDSApp",
            MetricData=[{
                'MetricName': 'DBConnectionErrors',
                'Value': 1.0,
                'Unit': 'Count'
            }]
        )
    except Exception as e:
        logging.error(f"Failed to emit CloudWatch metric: {e}")

def get_db_creds():
    param_resp = ssm.get_parameter(Name="lab/db/endpoint")
    db_host = param_resp['Parameter']['Value']
    secret_resp = secrets.get_secret_value(SecretId=SECRET_ID)
    s = json.loads(resp["SecretString"])
    s["host"] = db_host
    return s

def get_conn():
    try:
        c = get_db_creds()
        conn = pymysql.connect(
            host=c["host"],
            user=c["username"],
            password=c["password"],
            port=int(c.get("port", 3306)),
            database="labdb",
            autocommit=True
        )
        return conn
    except Exception as e:
        # This is the "Failure Message" your CLI command is looking for
        logging.error(f"DATABASE CONNECTIVITY FAILURE: {str(e)}")
        emit_db_error()
        raise e



app = Flask(__name__)

@app.route("/")
def home():
    return "Welcome to the RDS Notes App! Use /init to initialize the database, /add?note=yournote to add a note, and /list to list notes."

@app.route("/init")
def init_db():
    c = get_db_creds()
    conn = pymysql.connect(host=c["host"], user=c["username"], password=c["password"], autocommit=True)
    cur = conn.cursor()
    cur.execute("CREATE DATABASE IF NOT EXISTS labdb;")
    cur.execute("USE labdb;")
    cur.execute("CREATE TABLE IF NOT EXISTS notes (id INT AUTO_INCREMENT PRIMARY KEY, note VARCHAR(255) NOT NULL);")
    cur.close()
    conn.close()
    return "Initialized labdb + notes table via SSM Endpoint."

@app.route("/add", methods=["POST", "GET"])
def add_note():
    note = request.args.get("note", "").strip()
    if not note: return "Missing note param", 400
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("INSERT INTO notes(note) VALUES(%s);", (note,))
    cur.close(); conn.close()
    return f"Inserted note: {note}"

@app.route("/list")
def list_notes():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT id, note FROM notes ORDER BY id DESC;")
    rows = cur.fetchall()
    cur.close(); conn.close()
    out = "<h3>Notes</h3><ul>"
    for r in rows: out += f"<li>{r[0]}: {r[1]}</li>"
    return out + "</ul>"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
PY

cat >/etc/systemd/system/rdsapp.service <<'SERVICE'
[Unit]
Description=EC2 to RDS Notes App
After=network.target

[Service]
WorkingDirectory=/opt/rdsapp
Environment=SECRET_ID=lab-1a/rds/mysql
Environment=AWS_REGION=ap-northeast-1
ExecStart=/usr/bin/python3 /opt/rdsapp/app.py
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/opt/rdsapp/app.log",
            "log_group_name": "/aws/ec2/lab-rds-app",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

# Start the agent with the config
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

systemctl daemon-reload
systemctl enable rdsapp
systemctl start rdsapp