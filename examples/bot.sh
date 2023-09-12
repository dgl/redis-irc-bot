#!/usr/bin/env bash
# A bot wrapper. This makes anything that matches [a-z0-9]+ and is executable
# in the current directory into a "!" command as well as some other useful
# things.

# Run something like:
#   ln -s $(which uptime)
#   ./bot.sh channel
# Then on IRC:
#   <dg> !uptime
#   <bot> 08:31:35  up 5 days  6:10,  2 users,  load average: 0.26, 0.57, 1.02
#
# Note this trusts uptime, as "uptime(1)" itself is quite safe, but other
# commands could be used to do unexpected things. Better to use custom wrapper
# scripts that further sanity check the input provided. Also, you know, not
# deal with user input in shell scripts, but that's no fun.

set -eu
shopt -s extglob nocasematch

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 channels..."
  exit 1
fi

pubsub="$1"

declare -a channels
for i in $(eval "echo {1..$#}"); do
  channel="${!i}"
  if [[ ${channel:0:1} = '#' ]]; then
    channel="${channel:1}"
  fi
  channels[$[i-1]]="$channel"
done


get_command() {
  local command="${1/ */}"
  command="${command#!}"
  command="${command,,?}"
  command="${command//[^a-z0-9]/}"
  echo "$command"
}

get_params() {
  local params=""
  if [[ ${1/* /} != $1 ]]; then
    params="${1/+([^ ]) /}"
  fi
  echo "$params"
}

my_nick="$(redis-cli -h ${REDIS_HOST} --raw get "${pubsub}:nick")"

stdbuf -oL redis-cli -h ${REDIS_HOST} subscribe \
    $(eval "echo $(printf "\"%s:in\" " "${channels[@]}")") "${pubsub}:priv" \
    | while read -r type; do
  read -r channel # 2nd line
  read -r message # 3rd line
  if [[ $type != message ]]; then
    continue
  fi

  prefix="${message/ */}"
  nick="${prefix/!*/}"
  text="${message/+([^ ]) /}"

  if [[ $channel = "${pubsub}:priv" ]]; then
    type="private"
  # Look for "!" in channel
  elif [[ ${text:0:1} = "!" ]]; then
    type="command"
  elif [[ -n $my_nick ]] && [[ ${text} = ${my_nick}[,:]\ * ]]; then
    type="addressed"
    text="${text/+([^ ]) }"
  elif [[ "${text}" = *http*(s)://[[a-z0-9]* ]]; then
    type="url"
  else
    type="text"
  fi

  command=""
  params=""
  if [[ $type = private ]] || [[ $type = command ]] || [[ $type = addressed ]]; then
    command="$(get_command "$text")"
    if [[ -x $command ]]; then
      params="$(get_params "$text")"
    else
      command="default-$type"
      params="$text"
      [[ ! -x $command ]] && continue
    fi
  else
    command="default-$type"
    params="$text"
    [[ ! -x $command ]] && continue
  fi

  if [[ $type = private ]]; then
    echo "$params" | nick="$nick" prefix="$prefix" target="private" ./$command | \
      sed -u 's/^/PRIVMSG '"$nick"' :/' | \
      xargs -d '\n' -r -n1 -s450 redis-cli -h ${REDIS_HOST} publish ${pubsub}:raw
  else
    echo "$params" | nick="$nick" prefix="$prefix" target="#${channel%:in}" ./$command | \
      xargs -d '\n' -r -n1 -s450 redis-cli -h ${REDIS_HOST} publish "${channel%:in}"
  fi
done
