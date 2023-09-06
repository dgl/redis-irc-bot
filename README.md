# A redis IRC bot framework

Redis pubsub is great. How about the most simple IRC bot framework based on
that? The idea is this stays connected to IRC and your logic just sits
elsewhere, potentially multiple services, for microservice IRC action; all
communicating via Redis.

_(lol; it's just a shell script)_

At its most simple this can be used like a Redis backed
[irccat](https://github.com/irccloud/irccat). But more minimal.

You could also consider [ii](https://tools.suckless.org/ii/).

## Usage

Run this somewhere:

```cli
$ ./redis-irc-bot localhost irc.example.com disbot channel
```

Send stuff:

```cli
$ redis-cli publish channel hello
```

For receiving stuff you can subscribe to `channel:in` and do what you like,
send responses on `channel`.

## Requirements

- Redis somewhere and redis-cli on your machine
- [Stdbuf](https://www.gnu.org/software/coreutils/manual/html_node/stdbuf-invocation.html) from coreutils (because redis-cli does [strange buffering things](https://stackoverflow.com/a/66103101))
- I assume you're in the modern world, so you need a netcat with the `-c` (TLS) option and a TLS IRC server.

## Docker

You can run this via Docker:

```cli
$ docker run --init --restart=unless-stopped -d -e REDIS_HOST=my-redis -e IRC_SERVER=irc.example.com -e IRC_NICK=somebot -e IRC_CHANNEL=foo davidgl/redis-irc-bot
```

For Kubernetes, just arrange to set the environment variables correctly in your pod spec.

## Old TLS versions

Some IRC servers run old TLS versions. You can pass options to nc via the IRC sever parameter, e.g.

```
./redis-irc-bot localhost '-T protocols=legacy -T ciphers=all irc.example.com' bot channel
```

Similar is possible for Docker.

## License

[0BSD](https://dgl.cx/0bsd). No warranty.
