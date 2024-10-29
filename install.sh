#!/bin/bash

REPO_OWNER="andrei-ctn"
REPO_NAME="test"
BRANCH="main"

PATHS=(
    "auth"
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

    if echo "$response" | grep -q 'API rate limit exceeded'; then
        echo "Error: GitHub API rate limit exceeded."
        exit 1
    fi

    if echo "$response" | grep -q '"message": "Not Found"'; then
        echo "Error: $dir_path not found in the repository."
        exit 1
    fi

    local items
    items=$(echo "$response" | jq -r '.[] | @base64')

    for item in $items; do
        _jq() {
            echo "${item}" | base64 --decode | jq -r "${1}"
        }

        local type
        type=$(_jq '.type')

        if [ "$type" == "file" ]; then
            local file_url
            file_url=$(_jq '.download_url')
            local rel_path=$(_jq '.path')
            local dest_path="$DEST_DIR/$rel_path"
            mkdir -p "$(dirname "$dest_path")"

            curl -s -L "$file_url" -o "$dest_path"
            echo "Downloaded: $rel_path"
        elif [ "$type" == "dir" ]; then
            local sub_path
            sub_path=$(_jq '.path')
            download_directory "$sub_path"
        fi
    done
}


for path in "${PATHS[@]}"; do

    path="${path#/}"

    api_url="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/$path?ref=$BRANCH"
    response=$(curl -s "$api_url")

    if echo "$response" | grep -q 'API rate limit exceeded'; then
        echo "Error: GitHub API rate limit exceeded."
        exit 1
    fi

    if echo "$response" | grep -q '"message": "Not Found"'; then
        echo "Error: $path not found in the repository."
        continue
    fi

    type=$(echo "$response" | jq -r '.type // empty')
    if [ "$type" == "file" ]; then
        download_file "$path"
    elif [ "$type" == "dir" ]; then
        download_directory "$path"
    else
        echo "Warning: $path does not exist or is not accessible."
    fi
done

echo "Selected files and directories have been copied to $DEST_DIR."
