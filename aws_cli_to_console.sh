#!/bin/bash
#
# The MIT License
#
# Copyright (c) 2019 Cam Maxwell (cameron.maxwell@gmail.com)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

set -e

usage(){
    echo "Usage: ${0} <IAM_ROLE_ARN> [MFA_SERIAL_ARN] [CHROME_THEME_ID]"
}

rawurlencode() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="${c}" ;;
            * )               printf -v o '%%%02x' "'$c"
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}

iniparser () {                              # Sourced from https://gist.github.com/splaspood/1473761
    fixed_file=$(cat $1 | sed 's/ = /=/g')   # fix ' = ' to be '='
    IFS=$'\n' && ini=( $fixed_file )         # convert to line-array
    ini=( ${ini[*]//;*/} )                   # remove comments
    ini=( ${ini[*]/#[/\}$'\n'cfg.section.} ) # set section prefix
    ini=( ${ini[*]/%]/ \(} )                 # convert text2function (1)
    ini=( ${ini[*]/=/=\( } )                 # convert item to array
    ini=( ${ini[*]/%/ \)} )                  # close array parenthesis
    ini=( ${ini[*]/%\( \)/\(\) \{} )         # convert text2function (2)
    ini=( ${ini[*]/%\} \)/\}} )              # remove extra parenthesis
    ini[0]=''                                # remove first element
    ini[${#ini[*]} + 1]='}'                  # add the last brace
    eval "$(echo "${ini[*]}")"               # eval the result
}

# Checking dependencies
command -v jq >/dev/null 2>&1 || die "jq is required but not installed. Aborting. See https://stedolan.github.io/jq/download/"
command -v aws >/dev/null 2>&1 || die "aws cli is required but not installed. Aborting. See https://docs.aws.amazon.com/cli/latest/userguide/installing.html"

ROLE="${1}"
if [ "${ROLE}x" == "x" ]; then
    usage
    exit 1;
fi

MFA_SERIAL="${2}"
if [ "${MFA_SERIAL}x" != "x" ] ; then
    read -p "MFA: " MFA_CODE
    MFA_OPT="--serial-number ${MFA_SERIAL} --token-code ${MFA_CODE}"
fi

SESSION_NAME="$(aws sts get-caller-identity  | jq -r .Arn | cut -f5- -d: | tr -cs 'a-zA-Z0-9\n' '-'  | tail -c 40)$(echo ${ROLE} | md5 | cut -c10)"
#SESSION_NAME=
echo "SESSION_NAME: ${SESSION_NAME}"

echo Assuming IAM Role
SESSION=$( aws sts assume-role --role-arn ${ROLE} --role-session-name ${SESSION_NAME} ${MFA_OPT} --query '{"sessionId":Credentials.AccessKeyId,"sessionKey":Credentials.SecretAccessKey,"sessionToken":Credentials.SessionToken}')

echo Getting Signin Token
SIGNINTOKEN=$( echo -n $SESSION  | tr -d '\n' \
                                | sed -e 's/ //g'  -e 's/{/%7B/g' -e 's/}/%7D/g' \
                                -e 's/"/%22/g' -e 's/,/%2C/g' -e 's/\//%2F/g' \
                                -e 's/:/%3A/g' -e 's/=/%3D/g' -e 's/+/%2B/g' \
                                | xargs printf '%s%s' "https://signin.aws.amazon.com/federation?Action=getSigninToken&Session=" \
                                | xargs curl -s \
                                | sed -e 's/.*:"\(.*\)".*/\1/' \
                                | xargs printf '%s' '' )

DESTINATION=$(rawurlencode "https://console.aws.amazon.com/" )

URL="https://signin.aws.amazon.com/federation?Action=login&Issuer=${WHOAMI}&SigninToken=${SIGNINTOKEN}&Destination=${DESTINATION}"

# Standard open
#open ${URL}
echo "Configuring distinct Chrome profile"

# Tricky chrome open using a different app session for each console login.
SESSION_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/sessions/${SESSION_NAME}"
if [ ! -d ${SESSION_DIR} ] ; then
    mkdir -p "${SESSION_DIR}"
    touch "${SESSION_DIR}/First Run"
fi


PLUGIN_ID="${3}"
if [ "${PLUGIN_ID}x" != "x" ] ; then
    # Now im just showing off
    mkdir -p "/tmp/${SESSION_NAME}/External Extensions"
    cat >> "/tmp/${SESSION_NAME}/External Extensions/${PLUGIN_ID}.json" <<EOF
    {
    "external_update_url": "https://clients2.google.com/service/update2/crx"
    }
EOF
fi

echo -en "Opening Console URL:\n\n    ${URL}\n\n"
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --user-data-dir="${SESSION_DIR}" "${URL}" > /dev/null 2>&1 &
