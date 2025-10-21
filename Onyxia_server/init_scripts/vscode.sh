#!/bin/bash

# This script is exectued at onyxia pod startup to:
# - clone a github repository specified as first Onyxia init argument "user_or_org/repo"
# - copy on the pod local storage the content of the s3 folder named "projet-betsaka"
# - change VSCode main settings
# - install main VSCode extensions 


# Parses the argument from the onyxia init 
FULL_NAME="$1" # eg. "BETSAKA/training"
SERV_FOLD="$2"
PROJ_NAME="${FULL_NAME##*/}" # then "training"
# Creation of automatic variables
WORK_DIR=/home/onyxia/work/${PROJ_NAME} # then "/home/onyxia/work/training"
REPO_URL=https://${GIT_PERSONAL_ACCESS_TOKEN}@github.com/${FULL_NAME}.git # then "github.com/BETSAKA/training"

# # Open work dir
# code-server --user-data-dir ~/.local/share/code-server --extensions-dir ~/.local/share/code-server/extensions "$WORK_DIR" &

# Clone git repo
git clone $REPO_URL $WORK_DIR
chown -R onyxia:users $WORK_DIR

# Copy files from s3
mc cp -r s3/${SERV_FOLD}/${PROJ_NAME} /home/onyxia/work/
chown -R onyxia:users $WORK_DIR # make sure users have rights to edit

# Set vscode settings
# Path to the VSCode settings.json file
# Path to the VSCode settings.json file
SETTINGS_FILE="${HOME}/.local/share/code-server/User/settings.json"

# Check if the settings.json file exists, otherwise create a new one
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "No existing settings.json found. Creating a new one."
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    echo "{}" > "$SETTINGS_FILE"  # Initialize with an empty JSON object
fi

# Add or modify Python-related settings using jq
# We will keep the comments outside the jq block, as jq doesn't support comments inside JSON.
jq '. + {
    "workbench.panel.defaultLocation": "right",
    "workbench.editor.openSideBySideDirection": "down",

    "editor.rulers": [80, 100, 120],  # Add specific vertical rulers
    "files.trimTrailingWhitespace": true,  # Automatically trim trailing whitespace
    "files.insertFinalNewline": true,  # Ensure files end with a newline

     # "terminal.integrated.enableMultiLinePasteWarning": "never",
     "terminal.integrated.cursorStyle": "line",
     "terminal.integrated.cursorBlinking": true,

     "cSpell.enabled": false,
     
    "r.plot.useHttpgd": true,
     # "r.removeLeadingComments": true,

    "flake8.args": [
        "--max-line-length=100",  # Max line length for Python linting
        "--ignore=E251"
    ]
}' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"



# INSTALL VSCODE extensions

# CONFORT EXTENSIONS -----------------
# Colorizes the indentation in front of text
code-server --install-extension oderwat.indent-rainbow
# Extensive markdown integration
code-server --install-extension yzhang.markdown-all-in-one


# COPILOT ----------------------------

# Install Copilot (Microsoft's AI-assisted code writing tool)
copilotVersion="1.129.0"
#copilotChatVersion="0.20.0" # This version is not compatible with VSCode server 1.92.2
wget --retry-on-http-error=429 https://marketplace.visualstudio.com/_apis/public/gallery/publishers/GitHub/vsextensions/copilot/${copilotVersion}/vspackage -O copilot.vsix.gz
# wget --retry-on-http-error=429 https://marketplace.visualstudio.com/_apis/public/gallery/publishers/GitHub/vsextensions/copilot-chat/${copilotChatVersion}/vspackage -O copilot-chat.vsix.gz
gzip -d copilot.vsix.gz 
# gzip -d copilot-chat.vsix.gz 
code-server --install-extension copilot.vsix
# code-server --install-extension copilot-chat.vsix
rm copilot.vsix #copilot-chat.vsix
