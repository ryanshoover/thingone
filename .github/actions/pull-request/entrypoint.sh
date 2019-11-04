#!/bin/sh

set -e

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
  echo "UPDATING\n\n"
  # If we have an existing PR, update it.
  SOURCE_HASH=$(hub pr list --head $SOURCE_BRANCH --base $DESTINATION_BRANCH --format "%sB")
  DESTINATION_HASH=$(hub pr list --head $SOURCE_BRANCH --base $DESTINATION_BRANCH --format "%sH")
  PRS=$( git log --oneline --grep="Merge pull request" $SOURCE_HASH..$DESTINATION_HASH | grep -o "#[[:digit:]]*" )
  PR_BODY="## Automated Deploy Pull Request\n\n$PRS"
  echo $PR_BODY

  COMMAND="hub api \
    repos/${GITHUB_REPOSITORY}/pulls/${PR_NUM} \
    --method PATCH \
    --raw-field \"body=${PR_BODY}\" \
    "

else
  echo "CREATING\n\n"
  # If we don't have a PR, create it.
  SOURCE_HASH=$(hub pr list --head $SOURCE_BRANCH --base $DESTINATION_BRANCH --format "%sB")
  DESTINATION_HASH=$(hub pr list --head $SOURCE_BRANCH --base $DESTINATION_BRANCH --format "%sH")
  PRS=$( git log --oneline --grep="Merge pull request" $SOURCE_HASH..$DESTINATION_HASH | grep -o "#[[:digit:]]*" )

  COMMAND="hub pull-request \
    --base $DESTINATION_BRANCH \
    --head $SOURCE_BRANCH \
    --no-edit \
    --message \"${DESTINATION_BRANCH} ← ${SOURCE_BRANCH}\" \
    --message \"## Automated Deploy Pull Request\" \
    --mesage \"$PRS\" \
    --labels \"deploy\" \
    --assign \"$GITHUB_ACTOR\""

  echo "$COMMAND"
fi

echo "$COMMAND"
sh -c "$COMMAND"
