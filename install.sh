#!/bin/bash
REPO_OWNER="andrei-ctn"
REPO_NAME="test"
BRANCH="main"

PATHS=(
    "/auth"
)

DEST_DIR="$PWD"

download_file() {
    local file_path="$1"
    local dest_path="$DEST_DIR/$file_path"
    mkdir -p "$(dirname "$dest_path")"

    local url="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$BRANCH/$file_path"

    curl -s -L "$url" -o "$dest_path"
}

download_directory() {
    local dir_path="$1"

    local api_url="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/$dir_path?ref=$BRANCH"
    local response
    response=$(curl -s "$api_url")

    echo "$response" | grep '"type": "file"' > /dev/null
    if [ $? -ne 0 ]; then
        echo "Warning: $dir_path is empty or not accessible."
        return
    fi

    echo "$response" | grep '"download_url":' | while read -r line; do
        local file_url
        file_url=$(echo "$line" | sed -E 's/.*"download_url": "(.*)".*/\1/')

        local rel_path="${file_url#https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$BRANCH/}"
        local dest_path="$DEST_DIR/$rel_path"
        mkdir -p "$(dirname "$dest_path")"

        curl -s -L "$file_url" -o "$dest_path"
    done
}


for path in "${PATHS[@]}"; do

    api_url="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/$path?ref=$BRANCH"
    type=$(curl -s "$api_url" | grep '"type":' | head -n1 | sed -E 's/.*"type": "(.*)".*/\1/')

    if [ "$type" == "file" ]; then
        download_file "$path"
    elif [ "$type" == "dir" ]; then
        download_directory "$path"
    else
        echo "Warning: $path does not exist."
    fi
done

echo "Selected files and directories have been copied to $DEST_DIR."
