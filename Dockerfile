FROM herrdermails/expression-service

RUN apt-get update
RUN apt-get install -y jq

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
