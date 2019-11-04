#!/bin/sh

set -e

updateBody () {
  if [[ $SOURCE_BRANCH =~ ^[a-zA-Z]+\-[[:digit:]]+ ]]; then
    TICKET=$(echo $SOURCE_BRANCH | sed -n 's/^([a-zA-Z]+\-[[:digit:]])+).*/\1/p')
    PR_BODY="$1\n\n[${TICKET^^}]"
  fi;

  return PR_BODY
}

if [[ -z "$GITHUB_TOKEN" ]]; then
  echo "Set the GITHUB_TOKEN environment variable."
  exit 1
fi

SOURCE_BRANCH=${GITHUB_REF/refs\/heads\//}  # Remove branch prefix

case $SOURCE_BRANCH in
"development")
  DESTINATION_BRANCH="staging"
  ;;
"staging")
  DESTINATION_BRANCH="master"
  ;;
esac

# Github actions no longer auto set the username and GITHUB_TOKEN
git remote set-url origin "https://$GITHUB_ACTOR:$GITHUB_TOKEN@github.com/$GITHUB_REPOSITORY"

# Pull all branches references down locally so subsequent commands can see them
git fetch origin '+refs/heads/*:refs/heads/*'

if [ "$(git rev-parse --revs-only "$SOURCE_BRANCH")" = "$(git rev-parse --revs-only "$DESTINATION_BRANCH")" ]; then
  echo "Source and destination branches are the same."
  exit 0
fi

# Do not proceed if there are no file differences, this avoids PRs with just a merge commit and no content
LINES_CHANGED=$(git diff --name-only "$DESTINATION_BRANCH" "$SOURCE_BRANCH" | wc -l | awk '{print $1}')
if [[ "$LINES_CHANGED" = "0" ]]; then
  echo "No file changes detected between source and destination branches."
  exit 0
fi

# Workaround for `hub` auth error https://github.com/github/hub/issues/2149#issuecomment-513214342
export GITHUB_USER="$GITHUB_ACTOR"

# Find existing PR
PR_NUM=$(hub pr list --head $DESTINATION_BRANCH --base $SOURCE_BRANCH --format "%I")

if [ $PR_NUM ]; then
  # If we have an existing PR, update it.
  PR_BODY=updateBody $(hub pr list --head $DESTINATION_BRANCH --base $SOURCE_BRANCH --format "%b")

  COMMAND="hub api \
    repos/${GITHUB_REPOSITORY}/pulls/${PR_NUM} \
    --method PATCH \
    --raw-field \"body=${PR_BODY}\" \
    "

else
  # If we don't have a PR, create it.
  PR_BODY=updateBody "\#\# Automated Deploy Pull Request"

  COMMAND="hub pull-request \
    --base $DESTINATION_BRANCH \
    --head $SOURCE_BRANCH \
    --no-edit \
    --message \"${DESTINATION_BRANCH^} ← ${SOURCE_BRANCH^}\" \
    --mesage \"$PR_BODY\" \
    --labels \"deploy\" \
    --assign \"$GITHUB_ACTOR\" \
    "
fi

echo "$COMMAND"
sh -c "$COMMAND"
