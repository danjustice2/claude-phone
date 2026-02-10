FROM andrius/asterisk:latest

# Install python3 for config generation
RUN apk add --no-cache python3

# Copy base config files
COPY config/modules.conf /etc/asterisk/modules.conf
COPY config/asterisk.conf /etc/asterisk/asterisk.conf
COPY config/logger.conf /etc/asterisk/logger.conf

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
