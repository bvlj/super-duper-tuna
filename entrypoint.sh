#!/bin/bash
set -e

ARG_QUERY="$1"
ARG_COUNT="$2"
ARG_SRC_DIR="$3"
ARG_JAVA_CLASSPATH="$4"
ARG_GH_TOKEN="$5"

WS_DIR="/github/workspace"
ES_INPUT_DIR="$WS_DIR/$ARG_SRC_DIR"
ES_JAVA_CLASSPATH="$WS_DIR/$ARG_JAVA_CLASSPATH"

OUT_DIR="$WS_DIR/build"
ES_OUT_FILE="$OUT_DIR/activities.ndjson"
TUTOR_OUT_FILE="$OUT_DIR/issue.txt"


# Move to the project directory so that path are properly relativized
cd /github/workspace

mkdir "$OUT_DIR"

java -jar /opt/expression-service/app.jar source \
  --format=ACTIVITY \
  --count="$ARG_COUNT" \
  --query="$ARG_QUERY" \
  --java-classpath="$ES_JAVA_CLASSPATH" \
  "$ES_INPUT_DIR" > "$ES_OUT_FILE"

function create_activity {
  instance_url="https://expressiontutor.org"
  activities_file=$1
  out_file=$2

  if [ ! -r "$activities_file" ]; then
    echo "Error: \"$activities_file\" is not a readable file" 2>&1
    exit 2
  fi

  # Invoke the "lucky API" to generate an activity
  url="${instance_url}/api/activities/lucky"
  while read -r line; do
    result=$(curl -s -X POST "$url" -d "$line" -H "Content-Type: application/json")
    if [[ "$result" == *"\"success\":true"* ]]; then
      uuid=$(echo "$result" | jq ".uuid")

      expression_code=$(echo "$line" | jq ".code")
      line_number=$(echo "$line" | jq ".line")
      file_path=$(echo "$line" | jq ".path")
      file_name=$(echo "$file_path" | sed 's|^.*/||')

      gh_url="https://github.com/${GITHUB_REPOSITORY}/blob/${GITHUB_REF}/${file_path}#L${line_number}"
      et_url="${instance_url}/activity/do?task=${uuid}"

      # Create issue message
      echo "In the file ${file_name} in line ${line_number} you can find the following expression:" > "$out_file"
      echo "\`\`\`\n$expression_code\n\`\`\`\n\n${gh_url}\n" >> "$out_file"
      echo "As we have seen in class, the structure of this expression forms a tree." >> "$out_file"
      echo "Please draw the structure of this expression using expression tutor by following" >> "$out_file"
      echo "[this link](${et_url}).\n"  >> "$out_file"
      echo "Once you are done, click the Save button and paste the link as a comment to this issue." >> "$out_file"

      # Create issue
      curl -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $ARG_GH_TOKEN" \
        -H "Content-Type: application/json" \
        "https://api.github.com/repos/$GITHUB_REPOSITORY/issues" \
        -d "{\"title\": \"Expression Tutor activities\", \"body\": \"$(cat $out_file | tr '\n' ' ')\"}"
    else
      echo "Activity creation failed for $line" 2>&1
    fi
  done < "$activities_file"
}

create_activity "$ES_OUT_FILE" "$TUTOR_OUT_FILE"

