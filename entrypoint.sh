#!/bin/bash
set -e

ARG_QUERY="$1"
ARG_COUNT="$2"
ARG_SRC_DIR="$3"
ARG_JAVA_CLASSPATH="$4"
ARG_GH_TOKEN="$5"

OUT_DIR="/github/workspace/build"
ES_INPUT_DIR="/github/workspace/$ARG_SRC_DIR"
ES_JAVA_CLASSPATH="/github/workspace/$ARG_JAVA_CLASSPATH"
ES_OUT_FILE="$OUT_DIR/activities.ndjson"
TUTOR_OUT_FILE="$OUT_DIR/issue.txt"

mkdir "$OUT_DIR"

java -jar /opt/expression-service/app.jar source \
  --format=ACTIVITY \
  --count="$ARG_COUNT" \
  --query="$ARG_QUERY" \
  --java-classpath="$ES_JAVA_CLASSPATH" \
  "$ES_INPUT_DIR" > "$ES_OUT_FILE"

# Clean up ndjson
sed -i -n '/^{"diagram"/p' "$ES_OUT_FILE"

function create_activity {
  instance_url="https://expressiontutor.org"
  activities_file=$1
  out_file=$2

  if [ ! -r "$activities_file" ]; then
    echo "Error: \"$activities_file\" is not a readable file" 2>&1
    exit 2
  fi

  echo "Please complete these follow-up activities on Expression Tutor:\n\n" > "$out_file"

  # Invoke the "lucky API" to generate an activity
  url="${instance_url}/api/activities/lucky"
  while read -r line; do
    result=$(curl -s -X POST "$url" -d "$line" -H "Content-Type: application/json")
    if [[ "$result" == *"\"success\":true"* ]]; then
      uuid=$(echo "${result}" | sed 's/^.*"uuid":"//')
      uuid=$(echo "${uuid}" | sed 's/"}$//')
      echo "- [ ] $instance_url/activity/do?task=$uuid" >> "$out_file"
    else
      echo "Activity creation failed for $line" 2>&1
    fi
  done < "$activities_file"
}

create_activity "$ES_OUT_FILE" "$TUTOR_OUT_FILE"

# Create issue
curl -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $ARG_GH_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/issues" \
  -d "{\"title\": \"Expression Tutor activities\", \"body\": \"$(cat $TUTOR_OUT_FILE | tr '\n' ' ')\"}"
