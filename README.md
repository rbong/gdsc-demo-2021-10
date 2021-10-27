# GDSC Demo October 2021

These instructions assume a Linux platform.

**WARNING**: this demo project requires a GCP account with billing enabled.
It's not recommended to do this if you're unfamiliar with GCP.
If you do run this project, [delete the project](https://cloud.google.com/resource-manager/docs/creating-managing-projects#shutting_down_projects) once you are done testing.
Do not share your service account key, password, or any other sensitive details with anyone.

**WARNING**: these instructions will change your domain's name servers to Google Cloud DNS.
It's not recommended that you follow these instructions if you use your domain for anything else.
It's not recommended to try for a custom setup unless if you're familiar with DNS.

## Deploy Setup

All infrastructure is deployed using [Terraform](https://www.terraform.io/).

### Deploy Prerequisites

  - You must have a registered domain name
  - [Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
  - [Install the Google Cloud SDK](https://cloud.google.com/sdk/install)
  - [Enable billing for your project](https://cloud.google.com/billing/docs/how-to/modify-project)
  - [Create a service account key](https://cloud.google.com/iam/docs/creating-managing-service-account-keys)
    - Give the service account key the "owner" role
    - Store the key at `service-key.json` in this directory

### GCP Project Setup

Follow these links to activate the folowing resource APIs (if not already enabled):
  - [Cloud Storage](https://console.cloud.google.com/apis/library/storage-component.googleapis.com)
  - [Compute Engine API](https://console.cloud.google.com/apis/library/compute.googleapis.com)
  - [Cloud DNS API](https://console.cloud.google.com/apis/library/dns.googleapis.com)
  - [Cloud Functions API](https://console.cloud.google.com/apis/library/cloudfunctions.googleapis.com)
  - [Cloud Build API](https://console.cloud.google.com/apis/library/cloudbuild.googleapis.com)
  - [Cloud Run API](https://console.cloud.google.com/apis/library/run.googleapis.com)
  - [Cloud Run Admin API](https://console.cloud.google.com/apis/library/run.googleapis.com)
  - [Cloud Endpoints API](https://console.cloud.google.com/apis/library/endpoints.googleapis.com)
  - [Cloud Error Reporting API](https://console.cloud.google.com/apis/library/clouderrorreporting.googleapis.com)
  - [Cloud Resource Manager API](https://console.cloud.google.com/marketplace/product/google/cloudresourcemanager.googleapis.com)
  - [Service Management API](https://console.cloud.google.com/apis/library/servicemanagement.googleapis.com)
  - [Service Control API](https://console.cloud.google.com/apis/library/servicecontrol.googleapis.com)
  - [IAM Service Account Credentials API](https://console.cloud.google.com/apis/library/iamcredentials.googleapis.com)
  - [IAM API](https://console.cloud.google.com/apis/library/iam.googleapis.com)

To set up the backend resources:
  - [Create a Firestore database](https://firebase.google.com/docs/firestore/quickstart)
    - Create in Native mode

To set up the frontend resources:
  - [Create a DNS zone](https://console.cloud.google.com/net-services/dns/zones/new/create)
    - Come up with a unique Zone name for your zone
    - Use the DNS name of your domain, ex. `gdscapp.xyz`
    - Make the zone public
    - Otherwise, keep defaults

To set up Terraform resources:
  - [Create a bucket](https://console.cloud.google.com/storage/create-bucket) to store Terraform state
    - Come up with a unique name
    - Disable public access
    - Otherwise, keep defaults

To set up the app:
  - Use your domain name for the `API_URL` in `./app/.env`
    - ex. if your domain name is `gdscapp.xyz`, change `API_URL` to `https://api.gdscapp.xyz`

### Domain Setup

  - [Change your domain's name servers to Google Cloud DNS](https://cloud.google.com/dns/docs/update-name-servers)
    - You can check the propagation with `dig -t NS gdscapp.xyz`, where `gdscapp.xyz` is the name of your domain
  - [Verify your domain name](https://www.google.com/webmasters/verification/verification)
    - You must also add the service account email as an owner

### Terraform Setup

To set up the parameters you created before:
  - Add your Terraform bucket to `backend.tfvars`
  - Add your domain name and zone name to `main.tfvars`

To initialize Terraform for the first time:
  - Run `terraform init -backend-config=backend.tfvars` from this directory

You will have to re-initialize in some cases when you make changes to the Terraform config.

From this point forward, no infrastructure is managed manually.
It is instead automatically created by Terraform.
You must, however, build before you can deploy.

## Building

### Build Prerequisites

  - [Install Yarn](https://classic.yarnpkg.com/en/docs/install)

### Build Instructions

Run the following script to build the app and API:

```sh
./scripts/build.sh
```

If you make any changes, run the script again.

## Deploying

### First Time Deploying

You must do a targetted deploy the first time you deploy.

```sh
terraform apply -var-file=main.tfvars -target=google_cloud_run_domain_mapping.api
```

Enter "yes" after reviewing the changes.

After deploying successfully for the first time, you can deploy normally.

### Deploying Normally

```sh
terraform apply -var-file=main.tfvars
```

Enter "yes" after reviewing the changes.

It may take some time for the site to become available for the first time, even after Terraform completes.
