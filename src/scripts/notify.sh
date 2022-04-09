#!/bin/sh
JQ_PATH=/usr/local/bin/jq

SetupEnvVars() {
    echo "BASH_ENV file: $BASH_ENV"
    if [ -f "$BASH_ENV" ]; then
        echo "Exists. Sourcing into ENV"
        # shellcheck disable=SC1090
        . $BASH_ENV
    else
        echo "Does Not Exist. Skipping file execution"
    fi
}

SetupLogs() {
    if [ -n "${SLACK_PARAM_DEBUG:-}" ]; then
        LOG_PATH="$(mktemp -d 'slack-orb-logs.XXXXXX')"
        SLACK_MSG_BODY_LOG="$LOG_PATH/payload.json"
        SLACK_SENT_RESPONSE_LOG="$LOG_PATH/response.json"

        touch "$SLACK_MSG_BODY_LOG" "$SLACK_SENT_RESPONSE_LOG"
        chmod 0600 "$SLACK_MSG_BODY_LOG" "$SLACK_SENT_RESPONSE_LOG"
    fi
}

CheckEnvVars() {
    if [ -n "${SLACK_WEBHOOK:-}" ]; then
        echo "It appears you have a Slack Webhook token present in this job."
        echo "Please note, Webhooks are no longer used for the Slack Orb (v4 +)."
        echo "Follow the setup guide available in the wiki: https://github.com/CircleCI-Public/slack-orb/wiki/Setup"
    fi
    if [ -z "${SLACK_ACCESS_TOKEN:-}" ]; then
        echo "In order to use the Slack Orb (v4 +), an OAuth token must be present via the SLACK_ACCESS_TOKEN environment variable."
        echo "Follow the setup guide available in the wiki: https://github.com/CircleCI-Public/slack-orb/wiki/Setup"
        exit 1
    fi
    # If no channel is provided, quit with error
    if [ -z "${SLACK_PARAM_CHANNEL:-}" ]; then
       echo "No channel was provided. Enter value for SLACK_DEFAULT_CHANNEL env var, or channel parameter"
       exit 1
    fi
}

BuildMessageBody() {
    # Send message
    #   If sending message, default to custom template,
    #   if none is supplied, check for a pre-selected template value.
    #   If none, error.

  if [ $DEPLOY_FLAG ] && [ "$CCI_STATUS" = "pass" ]; then TEMPLATE="\$deploy_success"
  elif [ $DEPLOY_FLAG ] && [ "$CCI_STATUS" = "fail" ]; then TEMPLATE="\$deploy_failed"
  elif [ "$CCI_STATUS" = "pass" ]; then TEMPLATE="\$build_success"
  elif [ "$CCI_STATUS" = "fail" ]; then TEMPLATE="\$build_failed"
  else echo "A template wasn't provided nor is possible to infer it based on the job status. The job status: '$CCI_STATUS' is unexpected."; exit 1
  fi

  if [ $CIRCLE_BRANCH = "develop" ]; then
    DEPLOY_DESTINATION="Staging"
  else
    DEPLOY_DESTINATION="Production"
  fi

  JSON_LENGTH=`echo $slack_name_mappings | jq length`
  SLACK_MENTION=''
  for i in `seq 0 $(expr $JSON_LENGTH - 1)`
  do
    slack_account_name=`echo $slack_name_mappings | jq ".|keys | .[${i}]"`
    github_account_name=`echo $slack_name_mappings | jq -r ".${slack_account_name}"`
    if [ $CIRCLE_USERNAME = $github_account_name ]; then
       SLACK_MENTION=`echo $slack_name_mappings | jq -r ".|keys | .[${i}]"`
    fi
  done

   # [ -z "${SLACK_PARAM_TEMPLATE:-}" ] && echo "No message template was explicitly chosen. Based on the job status '$CCI_STATUS' the template '$TEMPLATE' will be used."

   # Set latest commit messages.
   COMMIT_MESSAGE=$(git log -1 HEAD --pretty=format:%s)

   # shellcheck disable=SC2016
   T1=$(eval echo "$TEMPLATE" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/`/\\`/g')
   T2=$(eval echo \""$T1"\")
    # Insert the default channel. THIS IS TEMPORARY
    T2=$(echo "$T2" | jq ". + {\"channel\": \"$SLACK_DEFAULT_CHANNEL\"}")
    SLACK_MSG_BODY=$T2
}

PostToSlack() {
    # Post once per channel listed by the channel parameter
    #    The channel must be modified in SLACK_MSG_BODY

    # shellcheck disable=SC2001
    for i in $(eval echo \""$SLACK_PARAM_CHANNEL"\" | sed "s/,/ /g")
    do
        echo "Sending to Slack Channel: $i"
        SLACK_MSG_BODY=$(echo "$SLACK_MSG_BODY" | jq --arg channel "$i" '.channel = $channel')
        echo $SLACK_MSG_BODY
        if [ -n "${SLACK_PARAM_DEBUG:-}" ]; then
            printf "%s\n" "$SLACK_MSG_BODY" > "$SLACK_MSG_BODY_LOG"
            echo "The message body being sent to Slack can be found below. To view redacted values, rerun the job with SSH and access: ${SLACK_MSG_BODY_LOG}"
            echo "$SLACK_MSG_BODY"
        fi
        SLACK_SENT_RESPONSE=$(curl -s -f -X POST -H 'Content-type: application/json' -H "Authorization: Bearer $SLACK_ACCESS_TOKEN" --data "$SLACK_MSG_BODY" https://slack.com/api/chat.postMessage)
        
        if [ -n "${SLACK_PARAM_DEBUG:-}" ]; then
            printf "%s\n" "$SLACK_SENT_RESPONSE" > "$SLACK_SENT_RESPONSE_LOG"
            echo "The response from the API call to Slack can be found below. To view redacted values, rerun the job with SSH and access: ${SLACK_SENT_RESPONSE_LOG}"
            echo "$SLACK_SENT_RESPONSE"
        fi

        SLACK_ERROR_MSG=$(echo "$SLACK_SENT_RESPONSE" | jq '.error')
        if [ ! "$SLACK_ERROR_MSG" = "null" ]; then
            echo "Slack API returned an error message:"
            echo "$SLACK_ERROR_MSG"
            echo
            echo
            echo "View the Setup Guide: https://github.com/CircleCI-Public/slack-orb/wiki/Setup"
            if [ "$SLACK_PARAM_IGNORE_ERRORS" = "0" ]; then
                exit 1
            fi
        fi
    done
}

ORB_TEST_ENV="bats-core"
if [ "${0#*"$ORB_TEST_ENV"}" = "$0" ]; then
    SetupEnvVars
    SetupLogs
    CheckEnvVars
    . "/tmp/SLACK_JOB_STATUS"
    BuildMessageBody
    PostToSlack
fi
