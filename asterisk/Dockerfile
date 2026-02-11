FROM andrius/asterisk:latest

# Install python3 for config generation (andrius/asterisk is Debian-based, runs as non-root)
USER root
RUN apt-get update && apt-get install -y --no-install-recommends python3 && rm -rf /var/lib/apt/lists/*

# Copy base config files
COPY config/modules.conf /etc/asterisk/modules.conf
COPY config/asterisk.conf /etc/asterisk/asterisk.conf
COPY config/logger.conf /etc/asterisk/logger.conf

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
