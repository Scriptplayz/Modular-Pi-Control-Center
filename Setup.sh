#!/bin/bash
# =====================================================
# 🧠 Modular Pi Control Center - One-Command Setup
# Author: Henry Jenkins
# =====================================================

set -e

echo "🚀 Starting Modular Pi setup..."

# --- 1️⃣ Update & base packages ---
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-flask unzip git curl

# --- 2️⃣ Install Docker ---
if ! command -v docker &>/dev/null; then
  echo "🐳 Installing Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  sudo usermod -aG docker $USER
fi

# --- 3️⃣ Create project folders ---
mkdir -p /home/$USER/custom_app /home/$USER/minecraft_data
chmod -R 777 /home/$USER/custom_app /home/$USER/minecraft_data

# --- 4️⃣ Install Flask + dependencies ---
pip3 install flask werkzeug

# --- 5️⃣ Download Modular Pi Control Center ---
cd /home/$USER
cat > control_center.py <<'EOF'
from flask import Flask, render_template_string, request, redirect, url_for
import os, subprocess

UPLOAD_FOLDER = f"/home/{os.getenv('USER')}/custom_app"
HTML = """<!DOCTYPE html><html><head><title>Pi Control Center</title>
<style>
body{font-family:sans-serif;background:#0f0f0f;color:#fff;text-align:center}
button{padding:12px 20px;margin:10px;border-radius:10px;border:none;cursor:pointer;
font-size:16px;background:#333;color:white}
.mode{background:#1c1c1c;border:1px solid #333;display:inline-block;
padding:20px;border-radius:12px;width:220px;margin:10px}
</style></head><body>
<h1>🧠 Pi Modular Control Center</h1>
<form method='POST'>
<div class='mode'><h3>Minecraft Server</h3><button name='mode' value='minecraft'>Launch</button></div>
<div class='mode'><h3>Python Web Server</h3><button name='mode' value='pythonapp'>Launch</button></div>
<div class='mode'><h3>Run Custom Python App</h3><button name='mode' value='run_custom'>Run App</button></div>
<div class='mode'><h3>Media / NAS</h3><button name='mode' value='nas'>Launch</button></div>
<div class='mode'><h3>?? Mystery Mode ??</h3><button name='mode' value='mystery'>Launch</button></div>
<div class='mode'><h3>Idle / Stop</h3><button name='mode' value='idle'>Stop</button></div>
</form><hr style='margin:30px 0;border:1px solid #333'>
<h2>📤 Upload Custom Python App</h2>
<form method='POST' action='/upload' enctype='multipart/form-data'>
<input type='file' name='file'><br>
<button type='submit'>Upload & Save</button>
</form>
<p>Upload a ZIP containing app.py and templates/static folders.</p>
</body></html>"""

app = Flask(__name__)

@app.route("/", methods=["GET","POST"])
def home():
    if request.method=="POST":
        mode=request.form.get("mode")

        if mode == "run_custom":
            os.system("pkill -f custom_app/app.py || true")
            os.system(f"nohup python3 {UPLOAD_FOLDER}/app.py >/home/{os.getenv('USER')}/custom_app.log 2>&1 &")
            return "<h2>✅ Custom Python app launched!</h2><a href='/'>Back</a>"

        with open("/boot/active_mode.txt","w") as f:f.write(mode)
        subprocess.run(["sudo","reboot"])
        return f"<h1>Switching to {mode} mode... rebooting!</h1>"

    return render_template_string(HTML)

@app.route("/upload",methods=["POST"])
def upload():
    file=request.files["file"]
    if not file:return redirect(url_for("home"))
    path=os.path.join(UPLOAD_FOLDER,"app.zip")
    file.save(path)
    subprocess.run(["unzip","-o",path,"-d",UPLOAD_FOLDER])
    return "<h2>✅ Upload successful! Reboot and choose 'Python Web Server' mode.</h2>"

if __name__=="__main__":
    app.run(host="0.0.0.0",port=8080)
EOF

# --- 6️⃣ systemd service for control center ---
sudo tee /etc/systemd/system/control_center.service > /dev/null <<EOF
[Unit]
Description=Pi Control Center Web UI
After=network.target

[Service]
ExecStart=/usr/bin/python3 /home/$USER/control_center.py
Restart=always
User=$USER
WorkingDirectory=/home/$USER
StandardOutput=append:/home/$USER/control_center.log
StandardError=append:/home/$USER/control_center.log
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable control_center
sudo systemctl restart control_center

echo "✅ Modular Pi Control Center installed!"
echo "🌐 Access it at: http://$(hostname -I | awk '{print $1}'):8080"
echo "📦 Upload custom apps or run Minecraft from the dashboard."
echo "Reboot once to finalize Docker permissions."
