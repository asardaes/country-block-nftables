FROM alpine:latest
RUN apk --update --no-cache add curl nftables
COPY main.sh /main.sh
ENTRYPOINT ["/main.sh"]
