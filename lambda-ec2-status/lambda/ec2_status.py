import boto3

def lambda_handler(event, context):
    ec2 = boto3.client("ec2")

    response = ec2.describe_instances()

    for reservation in response["Reservations"]:
        for instance in reservation["Instances"]:
            instance_id = instance["InstanceId"]
            state = instance["State"]["Name"]

            print(f"EC2: {instance_id}, State: {state}")

    return {
        "statusCode": 200,
        "body": "EC2 status check completed"
    }

