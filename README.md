# multi-chrome-aws-console

What Is It?
===
This is a simple wrapper for chrome to create a new running instance of the app as a new session, so you can work across multiple AWS account consoles simultaneously.

Each session's settings are persistent, so you can have different themes/plugins.

Lets say you are working with two AWS accounts - yours, and a customers, and you are doing some work around IAM identity federation. 

You are doing dev work in your AWS account, the customer has given you short-lived IAM User credentials for deployment, and you want to validate the experience of federated users. With a single browser, you can have a normal session and an incognito session (whose settings are not saved).

How to use it?
===
It's a bash wrapper for some complex AWS CLI commands, so there are many options.

I wrap it up in handler scripts in `/usr/local/bin/console_xyz` as follows:

```
CMD="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/aws_cli_to_console.sh"
export AWS_DEFAULT_PROFILE=cams-sekrit-profile-name
${CMD} arn:aws:iam:123456789012:role/target-role-to-assum ERMAGERD8642007 echjomhoplepodjjaaohelfnlnoelhgd
```