#!/bin/bash
# ga - Generate a Conventional Commits style commit message using the Anthropic API,
# confirm, and commit changes

# Ensure ANTHROPIC_API_KEY is set
if [[ -z "$ANTHROPIC_API_KEY" ]]; then
  echo "Error: ANTHROPIC_API_KEY environment variable not set." >&2
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

# Function to generate commit message using the Anthropic API (Claude)
generate_commit_message() {
  response=$(curl -s -X POST "https://api.anthropic.com/v1/messages" \
    --header "x-api-key: $ANTHROPIC_API_KEY" \
    --header "anthropic-version: 2023-06-01" \
    --header "content-type: application/json" \
    --data "$(jq -n --arg diff "$diff" '{
      model: "claude-3-7-sonnet-latest",
      max_tokens: 1200,
      messages: [
        {role: "user", content: ("Analyze the following git diff and generate a commit message using the Conventional Commits style. Respond with ONLY the git commit message and no other text. Use dot points for conciseness in the body. Follow these guidelines:

1. **Header**:
   - Begin with a commit type. Common types include:
     - **feat**: Introduces a new feature
     - **fix**: Patches a bug
     - **docs**: Documentation changes
     - **style**: Code formatting, white-space, etc.
     - **refactor**: Code changes that neither fix a bug nor add a feature
     - **perf**: Performance improvements
     - **test**: Adding or updating tests
     - **chore**: Maintenance tasks
   - Optionally include a scope in parentheses (e.g., `feat(parser):`).
   - Follow with a concise, imperative description of the change.

2. **Body (Optional)**:
   - Provide additional context, motivation, or details about the change if necessary.
   - Explain what was changed and why.

3. **Footer (Optional)**:
   - Include notes on breaking changes (e.g., start with `BREAKING CHANGE:`) or reference issues (e.g., `Closes #123`).

Git diff:\n\n" + $diff )}
      ]
    }')")

  commit_message=$(echo "$response" | jq -r '.content | map(.text) | join("\n")')

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
