# toggl_DBRE_Home_Assignment
This folder has the three files necessary to implement the toggl DBRE Home Assignment. **I hope I get the honor of becoming a Toggler!**

## File List   
1.  **main.tf**
    1. Contains the Infrastructure as Code (IaC) to configure the environment described in the assingnment.
    2. Configures 2 Google Compute Engines within in a Virtual Private Cloud (VPC) and a Google Cloud Storage bucket.
        1. The first Compute Engine is initialized using a startup script which installs PostgreSQL version 12 using pgbench schema. This is the primary (master) server.
        2. The second Compute Engine is initialized using a startup script which installs PostgreSQL version 12 and replicates the primary server. It also sets up a daily cron to generate a .sql.gz backup file of the replicated server and copy it into the Google Cloud Storage bucket.
        3. There is a firewall rule to allow internal traffic between the two compute engines.
        4. The Google Cloud Storage bucket is configured to auto delete the backups after 15 days. There is a retention policy to ensure the backups are not accidently deleted before 15 days.
    3. There are 2 cloud monitoring alerts which trigger in the event that the primary database:
        1. CPU Usage is above 90% OR Disk Usage is above 85%
3.  **variables.tf**
    1. Defines variables that are used in the main.tf file.  
5.  **terraform.tfvars**
    1. Recommended file where end user should assign values to the variables. _Added as a template only, will need to be modified by end user to use main.tf_ 

## Provisioning  
First, you must create a service account with role of Editor in the clean cloud project. See the following guide: https://developers.google.com/workspace/guides/create-credentials#service-account  

Second, you must create credentials for the service account you just created. This will be a downloaded .JSON file. See the following guide: https://developers.google.com/workspace/guides/create-credentials#create_credentials_for_a_service_account  

Third, you must enable Compute Engine API for the project. See the following guide:  
https://cloud.google.com/endpoints/docs/openapi/enable-api#enabling_an_api 

Next, ensure you have Terraform installed. If you do not have the Terraform CLI installed, see the following guide: https://developer.hashicorp.com/terraform/tutorials/gcp-get-started/install-cli  

Then, git clone this repo to your PC. Modify the cloned terraform.tfvars file to have the full file path to your credential .JSON file you downloaded, and the name of the project. There are a couple other variables in the variables.tf for the region and zone where the database will be hosted. They have default values in the variables.tf, but, if desired, you could override the defaults in the terraform.tfvars file.

In the terminal change directory to the location of the main.tf file that you cloned and run the following command:  
`terraform init`

If all goes well, you should see a message that reads: Terraform has been successfully initialized!  

Then, run the following command:  
`terraform apply`
  
The terminal will show the 8 resources that are planned to be created, if you agree with their configuration and would like to create the resources, then enter "yes" into the prompt.

## Conclusion
Thank you for taking the time to read the README! If you have any issues/questions please don't hesitate to reach out to me by email @ vasiliauskas.mg@gmail.com

GO TOGGL!
