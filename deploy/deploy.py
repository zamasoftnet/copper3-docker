#!/usr/bin/env python3
import json
import os
import shutil
import subprocess
import sys
import tempfile

def load_config():
    # deploy.py is in 'deploy/' subdirectory, so configuration is up one level
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    config_path = os.path.join(base_dir, 'deploy.json')
    with open(config_path, 'r') as f:
        return json.load(f)

def run_command(cmd, shell=False):
    subprocess.run(cmd, shell=shell, check=True)

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    try:
        config_path = os.path.join(base_dir, 'deploy.json')
        with open(config_path, 'r') as f:
            config = json.load(f)
    except FileNotFoundError:
        print("Error: deploy.json not found.")
        sys.exit(1)

    host = config['host']
    user = config['user']
    dest_dir = config['dest_dir']
    key_path = config['key_path']

    print("========================================")
    print(f" Deploying to {user}@{host}:~/{dest_dir}")
    print("========================================")

    if not os.path.exists(key_path):
        print(f"Error: Key file not found at {key_path}")
        sys.exit(1)

    # Use a temporary directory for the key to ensure cleanup
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_key = os.path.join(temp_dir, "id_ed25519")
        shutil.copy(key_path, temp_key)
        
        # Set permissions to 600 (Read/Write for owner only)
        os.chmod(temp_key, 0o600)

        # Base commands with identity key
        ssh_base = ["ssh", "-i", temp_key]
        scp_base = ["scp", "-i", temp_key]
        target = f"{user}@{host}"
        remote_dest = f"~/{dest_dir}"

        try:
            # 1. Create remote directory
            print("[1/3] Creating remote directory...")
            run_command(ssh_base + [target, f"mkdir -p {remote_dest}"])

            # 2. Transfer files
            print("[2/3] Transferring configuration and build files...")
            files_to_transfer = ["docker-compose.yml", "Dockerfile", "copper-pdf-3.2.32.tar.gz"]
            for file in files_to_transfer:
                if os.path.exists(os.path.join(base_dir, file)):
                    run_command(scp_base + [os.path.join(base_dir, file), f"{target}:{remote_dest}/"])
                else:
                    print(f"Warning: {file} not found locally, skipping.")

            # Transfer conf directory
            conf_dir = os.path.join(base_dir, "conf")
            if os.path.isdir(conf_dir):
                print("Transferring conf directory...")
                run_command(scp_base + ["-r", conf_dir, f"{target}:{remote_dest}/"])
            else:
                print("Warning: conf/ directory not found locally, skipping.")

            # 3. Start Docker service
            print("[3/3] Starting Samba service...")
            # Note: Using shell=False (default), so we pass the remote command as a single argument to ssh
            start_cmd = f"cd {remote_dest} && docker compose down && docker compose up -d --build"
            run_command(ssh_base + [target, start_cmd])

            print("========================================")
            print(" Deployment Complete!")
            print("========================================")

        except subprocess.CalledProcessError as e:
            print(f"\nDeployment failed during command execution.")
            sys.exit(e.returncode)

if __name__ == "__main__":
    main()
