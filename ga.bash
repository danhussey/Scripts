#!/bin/bash
# ga - Generate a Conventional Commits style commit message using the Claude API, confirm, and commit changes

# Ensure CLAUDE_API_KEY is set
if [[ -z "$CLAUDE_API_KEY" ]]; then
  echo "Error: CLAUDE_API_KEY environment variable not set." >&2
  exit 1
fi

# Ensure jq is installed
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not installed. Please install jq." >&2
  exit 1
fi

# Get the git diff
diff=$(git diff)
if [[ -z "$diff" ]]; then
  echo "No changes to commit."
  exit 0
fi

# Function to generate commit message using Claude API
generate_commit_message() {
  read -r -d '' prompt <<EOF
Based on the following git diff, generate a commit message in the Conventional Commits style:

$diff

Commit message:
EOF

  response=$(curl -s -X POST "https://api.anthropic.com/v1/complete" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $CLAUDE_API_KEY" \
    -d "$(jq -n --arg prompt "$prompt" '{
      model: "claude-3-5-haiku-latest",
      prompt: $prompt,
      max_tokens: 100,
      temperature: 0.7,
      stop_sequences: ["\n\n"]
  }')")
  
  commit_message=$(echo "$response" | jq -r '.completion')
  
  if [[ -z "$commit_message" || "$commit_message" == "null" ]]; then
    echo "Failed to generate commit message." >&2
    exit 1
  fi
  
  echo "$commit_message"
}

# Generate initial commit message
commit_message=$(generate_commit_message)

# Confirmation loop
while true; do
  echo ""
  echo "Generated commit message:"
  echo "--------------------------------"
  echo "$commit_message"
  echo "--------------------------------"
  echo ""
  read -p "Do you want to use this commit message? (y)es [default], (r)egenerate, or (n)o cancel: " choice
  # Default to "y" if the user presses Enter
  choice=${choice:-y}
  case "$choice" in
    y|Y )
      git commit -m "$commit_message"
      break
      ;;
    r|R )
      commit_message=$(generate_commit_message)
      ;;
    n|N )
      echo "Commit canceled."
      exit 0
      ;;
    * )
      echo "Please enter y, r, or n."
      ;;
  esac
done
