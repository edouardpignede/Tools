#!/bin/bash

# This script is exectued at onyxia pod startup to:
# - clone a github repository specified as first Onyxia init argument "user_or_org/repo"
# - copy on the pod local storage the content of the s3 folder named "projet-betsaka"
# - change VSCode main settings
# - install main VSCode extensions 

# see example of init scripts here: https://github.com/InseeFrLab/sspcloud-init-scripts/tree/main/vscode

#!/bin/bash

# Parses the argument from the onyxia init 
FULL_NAME="$1" # eg. "BETSAKA/training"
SERV_FOLD="$2"
PROJ_NAME="${FULL_NAME##*/}" 
WORK_DIR=/home/onyxia/work/${PROJ_NAME} 
REPO_URL=https://${GIT_PERSONAL_ACCESS_TOKEN}@github.com/${FULL_NAME}.git 

# Clone git repo
git clone $REPO_URL $WORK_DIR
chown -R onyxia:users $WORK_DIR

# Copy files from s3
mc cp -r s3/${SERV_FOLD}/${PROJ_NAME} /home/onyxia/work/
chown -R onyxia:users $WORK_DIR 

# --- UV AND PYTHON ENVIRONMENT SETUP ---

# 1. Check for pyproject.toml and run sync
PROJECT_FILE="${WORK_DIR}/pyproject.toml"
if [ -f "$PROJECT_FILE" ]; then
    echo "Found pyproject.toml. Initializing with uv..."
    cd "$WORK_DIR"
    
    # Ensure uv is in the path (standard on most recent Onyxia images)
    # If not, you might need: curl -LsSf https://astral.sh/uv/install.sh | sh
    
    uv sync --frozen --no-cache
    
    # 2. Force the .venv to activate in every new terminal session
    echo "source ${WORK_DIR}/.venv/bin/activate" >> ~/.bashrc
    
    # 3. Define the interpreter path for VS Code settings
    # This ensures the "Play" button and IntelliSense work immediately
    PYTHON_INTERPRETER="${WORK_DIR}/.venv/bin/python"
else
    # Fallback to system python if no project file exists
    PYTHON_INTERPRETER="/usr/bin/python3"
fi

# --- VSCODE WORKSPACE SETTINGS (Project Level) ---
# This avoids the "cannot be applied in this window" error
LOCAL_SETTINGS_DIR="${WORK_DIR}/.vscode"
mkdir -p "$LOCAL_SETTINGS_DIR"

echo "Configuring local VS Code workspace settings..."
cat <<EOF > "${LOCAL_SETTINGS_DIR}/settings.json"
{
    "python.defaultInterpreterPath": "$PYTHON_INTERPRETER",
    "python.terminal.activateEnvInCurrentTerminal": true,
    "python.analysis.extraPaths": ["$WORK_DIR"],
    "workbench.panel.defaultLocation": "right",
    "editor.rulers": [80, 100, 120],
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true
}
EOF

# --- 5. VSCODE GLOBAL SETTINGS (UI/Behavior) ---
GLOBAL_SETTINGS_FILE="${HOME}/.local/share/code-server/User/settings.json"
mkdir -p "$(dirname "$GLOBAL_SETTINGS_FILE")"
if [ ! -f "$GLOBAL_SETTINGS_FILE" ]; then echo "{}" > "$GLOBAL_SETTINGS_FILE"; fi

jq '. + {
    "workbench.editor.openSideBySideDirection": "down",
    "terminal.integrated.cursorStyle": "line",
    "terminal.integrated.cursorBlinking": true,
    "cSpell.enabled": false,
    "r.plot.useHttpgd": true
}' "$GLOBAL_SETTINGS_FILE" > "$GLOBAL_SETTINGS_FILE.tmp" && mv "$GLOBAL_SETTINGS_FILE.tmp" "$GLOBAL_SETTINGS_FILE"
# --- INSTALL VSCODE EXTENSIONS ---

code-server --install-extension oderwat.indent-rainbow
code-server --install-extension yzhang.markdown-all-in-one

# COPILOT 
copilotVersion="1.129.0"
copilotChatVersion="0.20.0" 
wget --retry-on-http-error=429 https://marketplace.visualstudio.com/_apis/public/gallery/publishers/GitHub/vsextensions/copilot/${copilotVersion}/vspackage -O copilot.vsix.gz
wget --retry-on-http-error=429 https://marketplace.visualstudio.com/_apis/public/gallery/publishers/GitHub/vsextensions/copilot-chat/${copilotChatVersion}/vspackage -O copilot-chat.vsix.gz
gzip -d copilot.vsix.gz 
gzip -d copilot-chat.vsix.gz 
code-server --install-extension copilot.vsix
code-server --install-extension copilot-chat.vsix
rm copilot.vsix copilot-chat.vsix

echo "Initialization complete. Project ready in $WORK_DIR"
