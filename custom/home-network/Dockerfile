# Custom Nuclei Docker image for home network scanning
FROM projectdiscovery/nuclei:latest

# Install additional tools for multi-VLAN networking
RUN apk add --no-cache \
    jq \
    curl \
    iproute2 \
    iputils \
    vlan

# Create necessary directories
RUN mkdir -p /home/nuclei/scripts /home/nuclei/results /home/nuclei/config

# Set working directory
WORKDIR /home/nuclei

# Default command
CMD ["/home/nuclei/scripts/multi-vlan-scan.sh"]