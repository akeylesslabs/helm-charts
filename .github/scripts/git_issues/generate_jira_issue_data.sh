#!/usr/bin/env bash

# Github issues Epic key
jira_fields='{"customfield_10014": "ASM-7343", "priority": {"name": "Highest", "id": "1"}}'

git_issue_event_name=$(echo "$GITHUB_CONTEXT" | jq '.event_name' --raw-output)
git_issue_event_action=$(echo "$GITHUB_CONTEXT" | jq '.event.action' --raw-output)
repository=$(echo "$GITHUB_CONTEXT" | jq '.repository' --raw-output)
git_user=$(echo "$GITHUB_CONTEXT" | jq '.actor' --raw-output)
git_issue_id=$(echo "$GITHUB_CONTEXT" | jq '.event.issue.id' --raw-output)
git_issue_title=$(echo "$GITHUB_CONTEXT" | jq '.event.issue.title' --raw-output)
git_issue_body=$(echo "$GITHUB_CONTEXT" | jq '.event.issue.body' --raw-output)
git_issue_url=$(echo "$GITHUB_CONTEXT" | jq '.event.issue.html_url' --raw-output)
git_issue_created_at=$(echo "$GITHUB_CONTEXT" | jq '.event.issue.created_at' --raw-output)
git_issue_updated_at=$(echo "$GITHUB_CONTEXT" | jq '.event.issue.updated_at' --raw-output)
git_issue_comment_url=$(echo "$GITHUB_CONTEXT" | jq '.event.comment.html_url' --raw-output)
git_issue_comment_body=$(echo "$GITHUB_CONTEXT" | jq '.event.comment.body' --raw-output)
git_issue_comment_created_at=$(echo "$GITHUB_CONTEXT" | jq '.event.comment.created_at' --raw-output)
git_issue_labels=$(echo "$GITHUB_CONTEXT" | jq '.event.issue.labels[].name' --raw-output)

git_issue_labels_list=()
while IFS='' read -r line; do git_issue_labels_list+=("$line"); done < <(echo "${git_issue_labels}")
if [[ "${git_issue_labels_list[*]}" == *"ASM"* ]]; then
  akeyless_jira_issue=$(echo "${git_issue_labels_list[*]}" | grep -e "ASM" )
  echo "Jira issue exist: ${akeyless_jira_issue}"
  jira_issue_exist="true"
else
  echo "No Jira issue label found"
  jira_issue_exist="false"
fi

echo "Generating Jira issue summary"
jira_issue_summary="Github Issue: ${git_issue_title}"
echo "Jira issue summary: ${jira_issue_summary}"

if [[ "${git_issue_event_name}" == "issues" ]]; then
  if [[ ${git_issue_event_action} == "opened" ]]; then
    echo "Generating new jira issue description"
    JIRA_EVENT_DESCRIPTION="*Issue Title:* ${git_issue_title}
    *Repository:* ${repository}
    *Git Issue id:* ${git_issue_id}
    *Git User:* ${git_user}
    *Git issue Description:*
    ${git_issue_body}
    *Git Issue Creation Time:* ${git_issue_created_at}
    *Git Issue URL:* ${git_issue_url}"

  elif [[ ${git_issue_event_action} == "closed" ]]; then
    echo "Closing ${akeyless_jira_issue} jira issue description"
    JIRA_EVENT_DESCRIPTION="*Git Issue has been closed*
    *Git issue closed by:* ${git_user}
    *Git Issue Update Time:* ${git_issue_updated_at}
    *Git Issue URL:* ${git_issue_url}"
  fi
elif [[ ${git_issue_event_name} == "issue_comment" ]]; then
  echo "Generation new comment on jira issue ${akeyless_jira_issue}"
  JIRA_EVENT_DESCRIPTION="*Git Issue has new comment*
  *Git User:* ${git_user}
  *Git issue comment:*
  ${git_issue_comment_body}
  *Git Issue Comment Creation Time:* ${git_issue_comment_created_at}
  *Git Issue Comment URL:* ${git_issue_comment_url}"
fi

delimiter="$(openssl rand -hex 8)"
echo "jira_description<<${delimiter}" >> "$GITHUB_ENV"
echo "${JIRA_EVENT_DESCRIPTION//$/%0A}" >> "$GITHUB_ENV"
echo "${delimiter}" >> "$GITHUB_ENV"

echo "jira_issue_summary=${jira_issue_summary}" >> "$GITHUB_ENV"
echo "akeyless_jira_issue=${akeyless_jira_issue}" >> "$GITHUB_ENV"
echo "jira_issue_exist=${jira_issue_exist}" >> "$GITHUB_ENV"
echo "jira_fields=${jira_fields}" >> "$GITHUB_ENV"