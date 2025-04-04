#!/bin/bash
# ga - Generate a Conventional Commits style commit message using the Anthropic API,
# confirm, and commit staged changes only

# Ensure ANTHROPIC_API_KEY is set
if [[ -z "$ANTHROPIC_API_KEY" ]]; then
  echo -e "\033[1;31mError: ANTHROPIC_API_KEY environment variable not set.\033[0m" >&2
  exit 1
fi

# Ensure jq is installed
if ! command -v jq >/dev/null 2>&1; then
  echo -e "\033[1;31mError: jq is required but not installed. Please install jq.\033[0m" >&2
  exit 1
fi

# Get the staged git diff
diff=$(git diff --staged)
if [[ -z "$diff" ]]; then
  echo -e "\033[1;33mNo staged changes to commit.\033[0m"
  exit 0
fi

# Compute a continuous line for formatting based on terminal width
cols=$(tput cols 2>/dev/null)
if [[ -z "$cols" ]]; then
  cols=80
fi
line=$(printf '%*s' "$cols" | tr ' ' '─')

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
        {role: "user", content: ("Analyze the following git diff and generate a commit message using the Conventional Commits style. Respond with ONLY the git commit message and no other text. Use dot points for conciseness in the body. Follow these guidelines:\n\n1. **Header**:\n   - Begin with a commit type. Common types include:\n     - **feat**: Introduces a new feature\n     - **fix**: Patches a bug\n     - **docs**: Documentation changes\n     - **style**: Code formatting, white-space, etc.\n     - **refactor**: Code changes that neither fix a bug nor add a feature\n     - **perf**: Performance improvements\n     - **test**: Adding or updating tests\n     - **chore**: Maintenance tasks\n   - Optionally include a scope in parentheses (e.g., `feat(parser):`).\n   - Follow with a concise, imperative description of the change.\n\n2. **Body (Optional)**:\n   - Provide additional context, motivation, or details about the change if necessary.\n   - Explain what was changed and why.\n\n3. **Footer (Optional)**:\n   - Include notes on breaking changes (e.g., start with `BREAKING CHANGE:`) or reference issues (e.g., `Closes #123`).\n\nGit diff:\n\n" + $diff )}
      ]
    }')")

  commit_message=$(echo "$response" | jq -r '.content | map(.text) | join("\n")')

  if [[ -z "$commit_message" || "$commit_message" == "null" ]]; then
    echo -e "\033[1;31mFailed to generate commit message.\033[0m" >&2
    exit 1
  fi

  echo "$commit_message"
}

# Generate initial commit message
commit_message=$(generate_commit_message)

# Confirmation loop
while true; do
  echo ""
  echo -e "\033[1;34mGenerated commit message:\033[0m"
  echo -e "\033[1;34m$line\033[0m"
  # Indent each line of the commit message by 4 spaces
  indented_commit=$(echo "$commit_message" | sed 's/^/    /')
  echo -e "\033[1;32m$indented_commit\033[0m"
  echo -e "\033[1;34m$line\033[0m"
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
      echo -e "\033[1;33mCommit canceled.\033[0m"
      exit 0
      ;;
    * )
      echo -e "\033[1;33mPlease enter y, r, or n.\033[0m"
      ;;
  esac
done
