import json
import boto3
import requests
import os

# AWS clients
dynamodb = boto3.client('dynamodb')
ses = boto3.client('ses')

# reCAPTCHA secret key
recaptcha_secret = os.getenv('RECAPTCHA_KEY')

def lambda_handler(event, context):
    try:
        domain = event['headers'].get('CfDomain')

        # Query DynamoDB for the email address associated with the domain
        response = dynamodb.get_item(
            TableName='DomainToEmailTable',
            Key={
                'Host': {'S': domain}
            }
        )
        
        if 'Item' not in response:
            return {
                'statusCode': 401,
                'body': json.dumps({'message': f'Domain not authorised.'})
            }

        recipient_email = response['Item']['EmailAddress']['S']
        sender_email = response['Item']['SenderEmailAddress']['S']

        # Parse form data from the request body
        body = json.loads(event['body'])
        name = body['name']
        name = body['telephone']
        email = body['email']
        message = body['message']
        recaptcha_token = body['recaptcha_response']

        # Verify reCAPTCHA
        recaptcha_url = 'https://www.google.com/recaptcha/api/siteverify'
        recaptcha_payload = {
            'secret': recaptcha_secret,
            'response': recaptcha_token
        }
        recaptcha_response = requests.post(recaptcha_url, data=recaptcha_payload)
        recaptcha_result = recaptcha_response.json()

        # Check reCAPTCHA verification
        if not recaptcha_result.get('success'):
            return {
                'statusCode': 400,
                'body': json.dumps({'message': 'reCAPTCHA verification failed'})
            }

        # Prepare and send email using SES
        subject = "New Contact Form Submission"
        body_text = f"Name: {name}\nEmail: {email}\nMessage: {message}"

        email_params = {
            'Source': sender_email,
            'Destination': {
                'ToAddresses': [recipient_email],
            },
            'Message': {
                'Subject': {
                    'Data': subject
                },
                'Body': {
                    'Text': {
                        'Data': body_text
                    }
                }
            }
        }

        ses.send_email(**email_params)

        return {
            'statusCode': 201,
            'body': json.dumps({'message': 'Form submitted successfully!'})
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'message': f'Error processing the request.'})
        }
