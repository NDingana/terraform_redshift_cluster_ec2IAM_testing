
/*
Always create your s3 bucket and dynamodb_table for backend.tf manually from console, 
because these are hightly sensitive files and you do not want that managed by terrform.
IF terraform manages them, it can easilty be accidentally deleted, which will be disastrous. 

Always use partition key as lock ID for dynamoDn
*/

terraform {
  backend "s3" {

    #Name of s3 bucket you created in console
    bucket = "daniel-dev-tfstate-09-23-2021"

    # A bucket is a container (web folder) for objects (files) stored in Amazon S3. 
    # Files are identified by a key (filename). 
    # and each object is identified by a unique user-specified key (filename).

    # bucket= folder && file_name=key && file_Content(the file itself) = object

    key = "infraLayer/infrastructure.tfstate"

    # Even though the namespace for Amazon S3 buckets is global,
    # each Amazon S3 bucket is created in a specific region that you choose.
    region = "us-east-1"

    # To lock the remote state file in S3 bucket , create a dynamodb table
    # and create a primary key 'LockID'
    # when creating the Dynamp DB table, make sure to create partition key as "LockID".
    dynamodb_table = "daniel-terraform-state-lock"

  }
}
