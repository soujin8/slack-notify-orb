# Orb Project Template

[![CircleCI Build Status](https://circleci.com/gh/m-88888888/slack-notify-orb.svg?style=shield "CircleCI Build Status")](https://circleci.com/gh/m-88888888/slack-notify-orb) [![CircleCI Orb Version](https://badges.circleci.com/orbs/m-88888888/slack-notify-orb.svg)](https://circleci.com/orbs/registry/orb/m-88888888/slack-notify-orb) [![GitHub License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://raw.githubusercontent.com/m-88888888/slack-notify-orb/master/LICENSE) [![CircleCI Community](https://img.shields.io/badge/community-CircleCI%20Discuss-343434.svg)](https://discuss.circleci.com/c/ecosystem/orbs)

## How To Use
```
orbs:
  slack: m-88888888/slack-notify-orb@dev:first

jobs:
  build:
    working_directory: ~/$(CIRCLE_PROJECT_REPONAME)
    docker:
      - image: cimg/node:17.2.0
    steps:
      - run: exit 1
      - slack/notify:
          slack_name_mappings: '{ "<@Uxxxxxxx>": "m-88888888", "<@Uhogehoge>": "TestUser" }'
          deploy_flag: false
```

## publish
```
$ circleci orb pack src > orb.yml && circleci orb validate orb.yml && circleci orb publish orb.yml m-88888888/slack-notify-orb@1.0.0
```

