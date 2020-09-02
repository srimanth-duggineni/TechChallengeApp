# Servian DevOps Tech Challenge - Tech Challenge App - Solution

## Overview

This document provides all the details required for configuring the application in AWS ennvironment
It takes sometime to configure everything but once done, a single git push to master branch is all required to get the changes live. Hands free!

This is the high level overview of the pipeline

1. We make a push to the master branch
2. Github hooks trigger CodePipeline pipeline
3. It trigger a build configured in CodeBuild
4. CodeBuild pulls the Github master branch, looks at the buildspec.yml file and builds a docker image
5. CodeBuild pushes the docker image to ECR
6. CodePipeline then update the ECS Fargate deployment task with a new task definintion
7. ECS injects environment variables required to authenticate to RDS into the container by talking to AWS SSM Parameter Store
8. Few minutes later, you should be able to see your applicaiton changes by accessing the ALB's DNS

## Configuration

### Fork this repository

CodeBuild and CodePipeline needs access to Github. So, please fork this repo to get started

### Create RDS Instance

1. Go to AWS Console RDS dashboard
2. Click on create RDS with followinf configurations
    1. Choose PostgreSQL as the database engine
    2. Choose FreeTier as template
    3. Choose a master username and password of your choice and remember them, we are gonna use them later to store them in AWS SSM Parameter Store
3. Under Additional connectivity configuration. Set the public access to 'Yes'. Note: This should not be done in real life. Only setting this to yes for ease of configuration to demo
4. Disable Auto Storage Scaling
5. Leave everything else as is and click on create database
6. Wait for few minutes until database status comes to 'Available' state
7. Click on the DB identifier and take a note of the DB endpoint DNS name
8. Make sure to allow traffic from anywhere in the default security group of the RDS. We should not do this in real life but until the assessment is finished. Keep the traffic coming in.

### Create SSM Store Parameters

Go to AWS SSM Parameter Store and create three parameters named

1. VTT_DBUSER with the RDS master username
2. VTT_DBHOST with the RDS DNS endpoint
3. VTT_DBPASSWORD with the RDS master password

### Create Roles

Now we need to create 2 roles

#### Role to let ECS to get RDS Secrets from SSM Parameter Store

1. Goto AWS IAM Console
2. Create a Role with 'AWS Service' as trusted entity, 'Elastic Container Service' as service and 'Elastic Container Service Task' as use case and click 'Next: Permissions'
3. Select 'AmazonSSMReadOnlyAccess' and 'AmazonECSTaskExecutionRolePolicy' as policies. Click Next. Leave the tags as empty. Click next
4. Enter the role name to something like 'ECSRoleForDeployment'

#### Role to let CodeBuild upload images to ECR

1. Goto AWS IAM Console
2. Create a Role with 'AWS Service' as trusted entity, 'CodeBuild' as service and 'CodeBuild' as use case and click 'Next: Permissions'
3. Select 'AmazonEC2ContainerRegistryFullAccess' as policy. Click Next. Leave the tags as empty. Click next
4. Enter the role name to something like 'CodeBuildToUploadToECR'

### Configure ECR

1. Goto AWS ECR Console
2. Create an ECR repository with the name 'servian-todo-app'. This name is used in buildspec.yml file to do not use another name
3. Leave everything as default and create the repository

### Configure CodeBuild

1. Goto AWS CodeBuild Console
2. Create a build project with any project name
3. Choose Github as your repository
4. Authenticate with OAuth
5. Choose Public Repository and enter 'https://github.com/srimanth-duggineni/TechChallengeApp'
6. Choose 'Managed image', Ubuntu as Operating System, 'Standard' Runtime, Image as 'aws/codebuild/standard:3.0' and tick 'Privileged' box
7. Click on 'Existing Service Role' and choose 'CodeBuildToUploadToECR'
8. Choose 'Use a buildspec file'. Leave the buildspec name empty
9. Leave everything as is and click on 'Create build project'
10. Click on 'Start build', leave everything as is and click on 'Start build'
11. Wait for few minutes and once the build is succeeded, goto ECR
12. Click on the repository name and copy the value of the 'Image URI'

### Configure ECS Fargate

1. Goto AWS ECS Fargate Console
2. Click on 'Get Started' or Goto
   1. https://{{region-console-url}}/ecs/home?region={{availability-zone-id}}#/firstRun
   2. Example - https://ap-south-1.console.aws.amazon.com/ecs/home?region=ap-south-1#/firstRun
3. Choose Container definition as custom and click on configure
4. Set the container name as 'todo-app'
5. Paste the 'Image URI' value you configured
6. Set the soft limit to 512MiB and container port as 3000
7. Expand 'Advanced container configuration', scroll down to 'Environment variables'
8. Add 3 keys with names as VTT_DBHOST, VTT_DBUSER and VTT_DBPASSWORD
9.  Open the 'Value' dropdown and choose 'ValueFrom' and enter the value  
   1.  arn:aws:ssm:{{availability-zone-id}}:{{accountnumber-without-hiphens}}:parameter/VTT_DBHOST
   2.  arn:aws:ssm:{{availability-zone-id}}:{{accountnumber-without-hiphens}}:parameter/VTT_DBUSER
   3.  arn:aws:ssm:{{availability-zone-id}}:{{accountnumber-without-hiphens}}:parameter/VTT_DBPASSWORD
10. Example: arn:aws:ssm:us-east-1:697450186428:parameter/VTT_DBHOST
11. Click on 'Update', then click edit on 'Task definition'
12. Choose 'Task execution role' as 'ECSRoleForDeployment', click on 'Save' and then click on Next
13. Choose 'Load balancer type' as Application Load Balancer and click 'Next'
14. Choose the name as 'todo-cluster' and click on 'Next'
15. Review the settings and click 'Create'
16. Wait for few minutes until the setup is done and goto EC2 Console
17. Goto Application Load Balancer. and copy the DNS name, paste it in new browser tab, add the port number as 3000 and hit enter
18. You should see the application up and running

### Configure CodePipeline

1. Goto AWS CodePipeline console
2. Click on 'Create pipeline'
3. Enter a pipeline name of your choice, enter a role name of your choic and click 'Next'
4. Choose Github as source provider. Connect to Github
5. Choose repo and branch of your choice and choose Github Webhooks and click 'Next'
6. Choose the CodeBuild project we have previously setup and click 'Next'
7. Choose 'Deploy provider' as ECS and fill the details with what we configured before in ECS
8. Click 'Create pipeline' and watch the pipeline being built for the first time

From the next time, a commit to master repo will trigger the pipeline and changes should be live within <10 mins

## Potential Improvements

1. Automate the provisioning part using Terraform/CloudFormation
2. Configure DR and HA for RDS and ECS
3. Better network security by creating VPC Endpoint Services


Thanks!