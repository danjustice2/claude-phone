FROM andrius/asterisk:latest

# python3 is already included in andrius/asterisk base image
# Switch to root for file operations
USER root

# Copy base config files
COPY config/modules.conf /etc/asterisk/modules.conf
COPY config/asterisk.conf /etc/asterisk/asterisk.conf
COPY config/logger.conf /etc/asterisk/logger.conf

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
