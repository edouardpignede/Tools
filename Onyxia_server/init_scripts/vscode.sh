#!/bin/bash

# Parses the argument from the onyxia init 
FULL_NAME="$1" # eg. "BETSAKA/training"
SERV_FOLD="$2"
PROJ_NAME="${FULL_NAME##*/}" 
WORK_DIR="/home/onyxia/work/${PROJ_NAME}" 
REPO_URL="https://${GIT_PERSONAL_ACCESS_TOKEN}@github.com/${FULL_NAME}.git" 

# Clone git repo
git clone "$REPO_URL" "$WORK_DIR"

# Copy files from s3
mc cp -r "s3/${SERV_FOLD}/${PROJ_NAME}" /home/onyxia/work/

# --- UV AND PYTHON ENVIRONMENT SETUP ---
PROJECT_FILE="${WORK_DIR}/pyproject.toml"
if [ -f "$PROJECT_FILE" ]; then
    echo "Found pyproject.toml. Initializing with uv..."
    cd "$WORK_DIR" || exit
    uv sync --frozen --no-cache
    echo "source ${WORK_DIR}/.venv/bin/activate" >> ~/.bashrc
    PYTHON_INTERPRETER="${WORK_DIR}/.venv/bin/python"
else
    PYTHON_INTERPRETER="/usr/bin/python3"
fi

# --- VSCODE WORKSPACE SETTINGS (Local) ---
LOCAL_SETTINGS_DIR="${WORK_DIR}/.vscode"
mkdir -p "$LOCAL_SETTINGS_DIR"

cat > "${LOCAL_SETTINGS_DIR}/settings.json" <<END_JSON
{
    "python.defaultInterpreterPath": "$PYTHON_INTERPRETER",
    "python.terminal.activateEnvInCurrentTerminal": true,
    "workbench.panel.defaultLocation": "right",
    "editor.rulers": [80, 100, 120],
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true
}
END_JSON

# --- VSCODE GLOBAL SETTINGS (User) ---
SETTINGS_FILE="${HOME}/.local/share/code-server/User/settings.json"
mkdir -p "$(dirname "$SETTINGS_FILE")"
if [ ! -f "$SETTINGS_FILE" ]; then echo "{}" > "$SETTINGS_FILE"; fi

# Removed comments from inside the jq command to prevent syntax errors
jq '. + {
    "workbench.panel.defaultLocation": "right",
    "workbench.editor.openSideBySideDirection": "down",
    "editor.rulers": [80, 100, 120],
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,
    "terminal.integrated.cursorStyle": "line",
    "terminal.integrated.cursorBlinking": true,
    "github.chat.extensionUnification.enabled": false,
    "cSpell.enabled": false,
    "r.plot.useHttpgd": true,
    "flake8.args": ["--max-line-length=100", "--ignore=E251,E303,E265,E226,E501"],
    "[python]": {
        "editor.defaultFormatter": "charliermarsh.ruff",
        "editor.formatOnSave": true,
        "editor.codeActionsOnSave": {
            "source.fixAll.ruff": "explicit",
            "source.organizeImports.ruff": "explicit"
        }
    },
    "python.linting.flake8Enabled": false,
    "python.linting.enabled": true
}' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

# --- INSTALL VSCODE EXTENSIONS ---
code-server --install-extension oderwat.indent-rainbow
code-server --install-extension yzhang.markdown-all-in-one

# COPILOT 
copilotVersion="1.129.0"
copilotChatVersion="0.20.0" 
wget -q --retry-on-http-error=429 https://marketplace.visualstudio.com/_apis/public/gallery/publishers/GitHub/vsextensions/copilot/${copilotVersion}/vspackage -O copilot.vsix.gz
wget -q --retry-on-http-error=429 https://marketplace.visualstudio.com/_apis/public/gallery/publishers/GitHub/vsextensions/copilot-chat/${copilotChatVersion}/vspackage -O copilot-chat.vsix.gz
gzip -d copilot.vsix.gz 
gzip -d copilot-chat.vsix.gz 
code-server --install-extension copilot.vsix
code-server --install-extension copilot-chat.vsix
rm copilot.vsix copilot-chat.vsix

# Final ownership fix
chown -R onyxia:users "$WORK_DIR"

echo "Initialization complete. Project ready in $WORK_DIR"
