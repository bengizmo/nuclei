#!/bin/bash
# Setup Home Assistant entities for Nuclei scanner

echo "Setting up Home Assistant integration..."
echo ""
echo "Add the following to your Home Assistant configuration.yaml:"
echo ""
cat <<'EOF'
# Nuclei Scanner Integration
input_text:
  nuclei_status:
    name: Nuclei Status
    initial: idle
    icon: mdi:shield-search

input_datetime:
  nuclei_last_scan:
    name: Last Nuclei Scan
    has_date: true
    has_time: true
    icon: mdi:clock-outline

input_number:
  nuclei_findings:
    name: Nuclei Findings
    min: 0
    max: 999
    step: 1
    icon: mdi:alert

sensor:
  - platform: template
    sensors:
      nuclei_scanner:
        friendly_name: "Nuclei Security Scanner"
        value_template: "{{ states('input_text.nuclei_status') }}"
        icon_template: >
          {% if states('input_text.nuclei_status') == 'alert' %}
            mdi:shield-alert
          {% elif states('input_text.nuclei_status') == 'scanning' %}
            mdi:shield-sync
          {% else %}
            mdi:shield-check
          {% endif %}
        attribute_templates:
          last_scan: "{{ as_timestamp(states('input_datetime.nuclei_last_scan')) | timestamp_custom('%Y-%m-%d %H:%M:%S') }}"
          findings_count: "{{ states('input_number.nuclei_findings') | int }}"
          status_message: >
            {% if states('input_text.nuclei_status') == 'alert' %}
              Security issues detected
            {% elif states('input_text.nuclei_status') == 'scanning' %}
              Scan in progress
            {% else %}
              No issues found
            {% endif %}

automation:
  - alias: "Nuclei Scanner Alert"
    trigger:
      - platform: state
        entity_id: sensor.nuclei_scanner
        to: 'alert'
    action:
      - service: notify.notify
        data:
          title: "Security Alert"
          message: "Nuclei scanner found {{ state_attr('sensor.nuclei_scanner', 'findings_count') }} security issues!"
      - service: persistent_notification.create
        data:
          title: "Nuclei Security Scan"
          message: "Security scan detected {{ state_attr('sensor.nuclei_scanner', 'findings_count') }} issues. Check the logs for details."

  - alias: "Nuclei Daily Scan"
    trigger:
      - platform: time
        at: "03:00:00"
    action:
      - service: rest_command.trigger_nuclei_scan

rest_command:
  trigger_nuclei_scan:
    url: "http://YOUR_NAS_IP:8123/api/webhook/nuclei_trigger_scan"
    method: POST

EOF

echo ""
echo "After adding this configuration:"
echo "1. Restart Home Assistant"
echo "2. Create a Long-Lived Access Token in HA"
echo "3. Set the token in your .env file as HOME_ASSISTANT_API_TOKEN"
echo "4. Replace YOUR_NAS_IP with your actual NAS IP (192.168.10.163)"

echo ""
echo "To test the integration:"
echo "  docker exec nuclei-scanner /home/nuclei/scripts/scan-with-ha.sh"