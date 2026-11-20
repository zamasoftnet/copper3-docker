#!/usr/bin/env python3
import json
import os
import posixpath
import shlex
import shutil
import subprocess
import sys
import tempfile

DEFAULT_COPPER_VERSION = "3.2.34"
FONT_EXTENSIONS = (
    '.otf', '.otc', '.ttf', '.ttc', '.pfb', '.pfa', '.woff', '.woff2',
    '.eot', '.dfont', '.fon',
)

def load_config(base_dir):
    # deploy.py is in 'deploy/' subdirectory, so configuration is up one level
    config_path = os.path.join(base_dir, 'deploy.json')
    with open(config_path, 'r') as f:
        return json.load(f)

def run_command(cmd, shell=False):
    subprocess.run(cmd, shell=shell, check=True)

def resolve_local_path(base_dir, path):
    path = os.path.expanduser(path)
    if os.path.isabs(path):
        return path
    return os.path.abspath(os.path.join(base_dir, path))

def contains_font_binary(font_dir):
    for root, _, files in os.walk(font_dir):
        if any(name.lower().endswith(FONT_EXTENSIONS) for name in files):
            return True
    return False

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    repo_root = os.path.dirname(base_dir)
    try:
        config = load_config(base_dir)
    except FileNotFoundError:
        print("Error: deploy.json not found.")
        sys.exit(1)

    host = config['host']
    user = config['user']
    dest_dir = config['dest_dir']
    key_path = config['key_path']
    version = os.environ.get('COPPER_VERSION') or config.get('version', DEFAULT_COPPER_VERSION)
    artifact_name = f"copper-pdf-{version}.tar.gz"
    artifact_path = config.get('artifact_path')
    if artifact_path:
        artifact_path = resolve_local_path(base_dir, artifact_path)
    else:
        proprietary_build_dir = config.get(
            'proprietary_build_dir',
            os.path.join(repo_root, 'proprietary', 'CopperPDF', 'build')
        )
        proprietary_build_dir = resolve_local_path(base_dir, proprietary_build_dir)
        artifact_path = os.path.join(proprietary_build_dir, artifact_name)

    print("========================================")
    print(f" Deploying to {user}@{host}:~/{dest_dir}")
    print("========================================")

    if not os.path.exists(key_path):
        print(f"Error: Key file not found at {key_path}")
        sys.exit(1)
    if not os.path.exists(artifact_path):
        print(f"Error: Product archive not found at {artifact_path}")
        print("Build it first with: cd ../proprietary/CopperPDF && ./build.sh dist1 archive")
        sys.exit(1)

    # deploy.shはrisu等の社内サーバーへフォント込みinternal imageを配備する
    # 専用経路。フォントが無いまま公開用targetへ暗黙に落ちることを許さない。
    conf_dir = os.path.join(base_dir, "conf")
    font_dir = os.path.join(conf_dir, "profiles", "fonts")
    if not os.path.isdir(font_dir) or not contains_font_binary(font_dir):
        print(f"Error: internal font payload not found under {font_dir}")
        print("Use docker-compose.yml directly when building the Noto-only distribution image.")
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
        remote_root = f"~/{dest_dir}"
        remote_docker = posixpath.join(remote_root, "docker")
        remote_build = posixpath.join(remote_root, "proprietary", "CopperPDF", "build")

        try:
            # 1. Create remote directory
            print("[1/3] Creating remote directories...")
            mkdir_cmd = "mkdir -p " + " ".join(
                shlex.quote(path) for path in [remote_docker, remote_build]
            )
            run_command(ssh_base + [target, mkdir_cmd])

            # 2. Transfer files
            print("[2/3] Transferring configuration and build files...")
            files_to_transfer = {
                "docker-compose.internal.yml": "docker-compose.yml",
                "Dockerfile": "Dockerfile",
                ".dockerignore": ".dockerignore",
            }
            for local_name, remote_name in files_to_transfer.items():
                local_path = os.path.join(base_dir, local_name)
                if os.path.exists(local_path):
                    run_command(scp_base + [local_path, f"{target}:{remote_docker}/{remote_name}"])
                else:
                    print(f"Warning: {local_name} not found locally, skipping.")
            run_command(scp_base + [artifact_path, f"{target}:{remote_build}/"])

            # Transfer conf directory
            if os.path.isdir(conf_dir):
                print("Transferring conf directory...")
                run_command(scp_base + ["-r", conf_dir, f"{target}:{remote_docker}/"])
            else:
                print("Warning: conf/ directory not found locally, skipping.")

            # 3. Start Docker service
            print("[3/3] Starting Copper PDF service...")
            # Note: Using shell=False (default), so we pass the remote command as a single argument to ssh
            start_cmd = (
                f"export COPPER_VERSION={shlex.quote(version)}; "
                f"if [ -f {shlex.quote(posixpath.join(remote_root, 'docker-compose.yml'))} ]; "
                f"then cd {shlex.quote(remote_root)} && docker compose down; fi; "
                f"cd {shlex.quote(remote_docker)} && docker compose down && docker compose up -d --build"
            )
            run_command(ssh_base + [target, start_cmd])

            print("========================================")
            print(" Deployment Complete!")
            print("========================================")

        except subprocess.CalledProcessError as e:
            print(f"\nDeployment failed during command execution.")
            sys.exit(e.returncode)

if __name__ == "__main__":
    main()
