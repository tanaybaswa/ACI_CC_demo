#!/bin/bash

# Check for the correct number of arguments
if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <location> <name> <templatefilename>"
    exit 1
fi

location="$1"
name="$2"
filename="$3"

./generate_template.sh $location $name $filename

registry_name='docker.io/tanaybaswa'
attestation_endpoint='sharedeus2.eus2.test.attest.azure.net'
runtime_data='eyJrZXlzIjpbeyJlIjoiQVFBQiIsImtleV9vcHMiOlsiZW5jcnlwdCJdLCJraWQiOiJOdmhmdXEyY0NJT0FCOFhSNFhpOVByME5QXzlDZU16V1FHdFdfSEFMel93Iiwia3R5IjoiUlNBIiwibiI6InY5NjVTUm15cDh6Ykc1ZU5GdURDbW1pU2VhSHB1akcyYkNfa2VMU3V6dkRNTE8xV3lyVUp2ZWFhNWJ6TW9PMHBBNDZwWGttYnFIaXNvelZ6cGlORExDbzZkM3o0VHJHTWVGUGYyQVBJTXUtUlNyek41NnF2SFZ5SXI1Y2FXZkhXay1GTVJEd0FlZnlOWVJIa2RZWWtnbUZLNDRoaFVkdGxDQUtFdjVVUXBGWmp2aDRpSTlqVkJkR1lNeUJhS1FMaGpJNVdJaC1RRzZaYTVzU3VPQ0ZNbm11eXV2TjVEZmxwTEZ6NTk1U3MtRW9CSVktTmlsNmxDdHZjR2dSLUlialVZSEFPczVhamFtVHpnZU84a3gzVkNFOUhjeUtteVVac2l5aUY2SURScDJCcHkzTkhUakl6N3Rta3BUSHg3dEhuUnRsZkUyRlV2MEI2aV9RWWxfWkE1USJ9XX0='

# Extract the public key from the openid-configuration and create a JWKS object
response=$(curl -s -o /dev/null -w "%{http_code}" -L "https://${attestation_endpoint}/certs")
if [[ $response -eq 200 ]]; then
    cert_data=$(curl -s "https://${attestation_endpoint}/certs")
    keys=$(echo $cert_data | jq -r '.keys')

    # Create a JWKS object
    jwks=()
    for key in $(echo "${keys}" | jq -r '.[] | @base64'); do
        key_data=$(echo ${key} | base64 --decode)
        x5c=$(echo $key_data | jq -r '.x5c[0]')
        if [[ ! -z "$x5c" ]]; then
            cert_pem="-----BEGIN CERTIFICATE-----\n$x5c\n-----END CERTIFICATE-----"
            # Extracting public key from PEM is non-trivial in bash, so this part is omitted for simplicity
            kid=$(echo $key_data | jq -r '.kid')
            jwks+=("$kid")
        fi
    done

    echo "JWKS object created successfully."
else
    echo "Failed to retrieve the signing keys."
fi

# # Run docker commands
docker build -t tanaybaswa/attestedkms:latest /home/tanaybaswa/code/enkryptai/key-manager/
docker push tanaybaswa/attestedkms:latest
docker save tanaybaswa/skr:latest tanaybaswa/attestedkms:latest -o $filename.tar

# # Run az command
az confcom acipolicygen -a $filename.json --tar $filename.tar

# Get the hash of the security policy
template=$(cat $filename.json)
security_policy=$(echo $template | jq -r '.resources[0].properties.confidentialComputeProperties.ccePolicy')
decoded_policy=$(echo $security_policy | base64 --decode)
sha256_hash_sum=$(echo -n "$decoded_policy" | sha256sum | awk '{print $1}')

# Print the hash
echo "hash of security policy: $sha256_hash_sum"

# Run az deployment command
az deployment group create -g cc_aci -f $filename.json

