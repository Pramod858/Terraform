#!/bin/bash

# Get instance ID
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# Get subnet ID
SUBNET_ID=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/$(curl -s http://169.254.169.254/latest/meta-data/mac)/subnet-id)

# Create HTML file
cat <<EOF > index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Instance Information</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
        }
        h1 {
            color: #333;
        }
        p {
            margin-bottom: 10px;
        }
    </style>
</head>
<body>
    <h1>Instance Information</h1>
    <p><strong>Instance ID:</strong> $INSTANCE_ID</p>
    <p><strong>Subnet ID:</strong> $SUBNET_ID</p>
</body>
</html>
EOF

# Start a simple web server to serve the HTML file
nohup python3 -m http.server 80 &
