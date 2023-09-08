FROM nixos/nix
RUN nix-channel --update
RUN nix-env -iA nixpkgs.libressl.nc nixpkgs.redis

WORKDIR /app
COPY redis-irc-bot .
COPY README.md /

ENTRYPOINT ["/usr/bin/env", "bash", "-c"]
CMD ["/app/redis-irc-bot \"$REDIS_HOST\" \"$IRC_SERVER\" \"$IRC_NICK\" $IRC_CHANNEL"]
