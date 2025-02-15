# Contact Form Microservice

This microservice processes contact form submissions for websites. Built using AWS Lambda, it performs the following tasks:

1. **Verify reCAPTCHA**: Ensures that form submissions are from humans, preventing bots.
2. **Look Up Email Address**: Queries a DynamoDB table to retrieve the email address associated with the domain of the request (via the `Host` or `Referer` header).
3. **Send Email via SES**: Uses Amazon Simple Email Service (SES) to send the form submission to the appropriate email address.

## Features

- **Dynamic Email Handling**: Can be reused by multiple websites using domain-to-email mappings stored in DynamoDB.
- **reCAPTCHA Integration**: Validates submissions to prevent spam.
- **SES Integration**: Sends emails to the right recipient via Amazon SES.
- **Terraform Deployment**: The entire infrastructure (Lambda, DynamoDB, SES, etc.) is deployed using Terraform for Infrastructure as Code (IaC).

## Architecture

- **Lambda Function**: Processes the contact form, verifies reCAPTCHA, queries DynamoDB for the email address, and sends the email via SES.
- **DynamoDB Table**: Stores domain-to-email mappings.
- **API Gateway**: Exposes an API endpoint for submitting the contact form.
- **SES**: Sends the email to the recipient.

## Requirements

To run this service, you'll need:

- **AWS Account** with permissions to use Lambda, SES, DynamoDB, and API Gateway.
- **Terraform**: Used for deploying the infrastructure.
- **Python 3.12 or higher**: For Lambda function compatibility.
- **Google reCAPTCHA Keys**: For verifying that the contact form submissions are not from bots.
  