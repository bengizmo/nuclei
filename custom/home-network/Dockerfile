# Custom Nuclei Docker image for home network scanning
FROM projectdiscovery/nuclei:latest

# Install additional tools
USER root
RUN apk add --no-cache \
    jq \
    curl \
    git \
    nmap

# Download nuclei templates
RUN nuclei -update-templates

# Create necessary directories
RUN mkdir -p /home/nuclei/scripts /home/nuclei/results /home/nuclei/config /root/.config/nuclei

# Create nuclei ignore file
RUN touch /root/.config/nuclei/.nuclei-ignore

# Set working directory
WORKDIR /home/nuclei

# Override the entrypoint and set command
ENTRYPOINT []
CMD ["sleep", "infinity"]