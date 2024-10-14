def lambda_handler(event, context):
    # TODO implement
    return {
        'statusCode': 302,
        'headers': {
            'Location': 'https://hashstudiosllc.com'
        }
    }
