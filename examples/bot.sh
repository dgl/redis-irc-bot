#!/usr/bin/env bash
# A bot wrapper. This makes anything that matches [a-z0-9]+ and is executable
# in the current directory into a "!" command.

# Run something like:
#   ln -s $(which uptime)
#   ./bot.sh
# Then on IRC:
#   <dg> !uptime
#   <bot> 08:31:35  up 5 days  6:10,  2 users,  load average: 0.26, 0.57, 1.02
#
# Note this trusts uptime, as "uptime(1)" itself is quite safe, but other
# commands could be used to do unexpected things. Better to use custom wrapper
# scripts that further sanity check the input provided. Also, you know, not
# deal with user input in shell scripts, but that's no fun.

set -eu
shopt -s extglob

pubsub=${1:-channel}

stdbuf -oL redis-cli -h ${REDIS_HOST} subscribe "${pubsub}:in" "${pubsub}:priv" | while read -r type; do
  read -r channel # 2nd line
  read -r message # 3rd line
  if [[ $type != message ]]; then
    continue
  fi
  prefix="${message/!*/}"
  nick="${prefix/:/}"
  text="${message/:+([^ ]) +([^ ]) +([^ ]) :/}"

  # Look for private messages
  if [[ $channel = "${pubsub}:priv" ]]; then
    if [[ ${text:0:1} = "!" ]]; then
      param="${text:1}"
    else
      param="$text"
    fi
    command="${text/ */}"
    command="${command,,?}"
    command="${command//[^a-z0-9]/}"
    params=""
    if [[ ${param/* /} != $param ]]; then
      params="${param/+([^ ]) /}"
    fi
    if [[ -n $command ]] && [[ -x $command ]]; then
      echo "$params" | nick="$nick" ./$command | sed 's/^/PRIVMSG '"$nick"' :/' | xargs -d '\n' -r -n1 -s450 redis-cli -h ${REDIS_HOST} publish ${pubsub}:raw
    fi
  # Look for "!" in channel
  elif [[ ${text:0:1} = "!" ]]; then
    param="${text:1}"
    command="${param/ */}"
    command="${command,,?}"
    command="${command//[^a-z0-9]/}"
    params=""
    if [[ ${param/* /} != $param ]]; then
      params="${param/+([^ ]) /}"
    fi
    if [[ -n $command ]] && [[ -x $command ]]; then
      echo "$params" | nick="$nick" ./$command | xargs -d '\n' -r -n1 -s450 redis-cli -h ${REDIS_HOST} publish ${pubsub}
    fi
  fi
done
