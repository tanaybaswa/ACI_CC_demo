#!/bin/bash

# Check for the correct number of arguments
if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <location> <name> <templatefilename>"
    exit 1
fi

location="$1"
name="$2"
filename="$3"

# Create the JSON template using a heredoc
cat << EOF > $filename.json
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "containerGroupName": {
      "defaultValue": "$name",
      "type": "String",
      "metadata": {
        "description": "Attested KMS with SKR sidecar"
      }
    }
  },
  "resources": [
    {
      "type": "Microsoft.ContainerInstance/containerGroups",
      "apiVersion": "2022-10-01-preview",
      "name": "[parameters('containerGroupName')]",
      "location": "$location",
      "properties": {
        "containers": [
          {
            "name": "skr-sidecar-container",
            "properties": {
              "command": [
                "/skr.sh"
              ],
              "image": "docker.io/tanaybaswa/skr:latest",
              "resources": {
                "requests": {
                  "cpu": 1,
                  "memoryInGB": 1
                }
              },
              "ports": [
                {
                  "port": 8080
                }
              ]
            }
          },
          {
            "name": "kms",
            "properties": {
              "image": "docker.io/tanaybaswa/attestedkms:latest",
              "resources": {
                "requests": {
                  "cpu": 1,
                  "memoryInGB": 1
                }
              },
              "ports": [
                {
                  "port": 80
                }
              ]
            }
          }
        ],
        "osType": "Linux",
        "sku": "confidential",
        "confidentialComputeProperties": {
          "ccePolicy": ""
        },
        "ipAddress": {
          "type": "Public",
          "ports": [
            {
              "protocol": "tcp",
              "port": 80
            }
          ]
        }
      }
    }
  ],
  "outputs": {
    "containerIPv4Address": {
      "type": "String",
      "value": "[reference(resourceId('Microsoft.ContainerInstance/containerGroups/', parameters('containerGroupName'))).ipAddress.ip]"
    }
  }
}
EOF

echo "Template file '$filename.json' created successfully."
