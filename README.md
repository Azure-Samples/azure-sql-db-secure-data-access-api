---
page_type: sample
languages:
- python
- tsql
- sql
products:
- azure
- vs-code
- azure-sql-database
description: "Creating API to securely access data using Row Level Security"
urlFragment: "azure-sql-db-secure-data-access-api"
---

# Creating API to securely access data using Azure SQL Row Level Security

<!-- 
Guidelines on README format: https://review.docs.microsoft.com/help/onboard/admin/samples/concepts/readme-template?branch=master

Guidance on onboarding samples to docs.microsoft.com/samples: https://review.docs.microsoft.com/help/onboard/admin/samples/process/onboarding?branch=master

Taxonomies for products and languages: https://review.docs.microsoft.com/new-hope/information-architecture/metadata/taxonomies?branch=master
-->

An API should allow its users to securely access the data in the database used by the API itself. At the same time it also must assure that data is protected and secured from those users who doesn't have enough authorization. This is even more important when creating multi-tenant applications.

Azure SQL offers an amazing feature to secure data at the database level, so that all the burden of taking care of such important and critical effort is done automatically by the database engine, so that the API code can be cleaner and easier to maintain and evolve. Not to mention better performances and improved efficiency as data will not leave the database at all, if the user has not the correct permissions.

This repo guides you to the creation of a API solution, deployable in Azure, that take advantage of Azure SQL Row Level Security to create secure API using Python, Flask and JWT. The same approach could be used with .NET or any other language that allows you to connect to Azure SQL.

A detailed video on how this sample work is available here:

https://youtu.be/Qpv8ke8ZuQ8

The sample simulate an authenticated user by passing in the JWT token (that you'll generate using the `pyjwt` tool) the hashed User Id. From a security point of view you want to make sure that a user can access only to his own data (or to the data s/he has been authorized to). 

## Install Sample Database

In order to run this sample, you need a Azure SQL database to use. If you already have one that can be used as a developer playground you can used that. Make sure create all the needed objects by executing the script:

`./sql/00-SetupRLS.sql`

Otherwise you can restore the `rls_sample` database by using the 

`./sql/rls_sample.bacpac`. If you already know how to restore a database, great!, go on and once restore is done move on to next section. Otherwise, or if you want some scripts to help, use the following link:

[How To Restore Database](https://github.com/yorek/azure-sql-db-samples#restore-wideworldimporters-database)

If you need any help in executing the SQL script, you can find a Quickstart here: [Quickstart: Use Azure Data Studio to connect and query Azure SQL database](https://docs.microsoft.com/en-us/sql/azure-data-studio/quickstart-sql-database)

## Run sample locally

Make sure you have Python 3.7 installed on your machine. Clone this repo in a directory on our computer and then create a [virtual environment](https://www.youtube.com/watch?v=_eczHOiFMZA&list=PLlrxD0HtieHhS8VzuMCfQD4uJ9yne1mE6&index=34). For example:

```bash
virtualenv venv --python C:\Python37\
```

then activate the created virtual environment. For example, on Windows:

```powershell
.\venv\Scripts\activate
```

and then install all the required packages:

```bash
pip install -r requirements
```

The connections string is not saved in the python code for security reasons, so you need to assign it to an environment variable in order to run the sample successfully. You also want to enable [development environment](https://flask.palletsprojects.com/en/1.1.x/config/#environment-and-debug-features) for Flask:

Linux:

```bash
export FLASK_ENV="development"
export SQLAZURECONNSTR_RLS="<your-connection-string>"
```

Windows:

```powershell
$Env:FLASK_ENV="development"
$Env:SQLAZURECONNSTR_RLS="<your-connection-string>"
```

Your connection string is something like:

```
DRIVER={ODBC Driver 17 for SQL Server};SERVER=<your-server-name>.database.windows.net;DATABASE=<your-database-name>;UID=MiddleTierUser;PWD=a987REALLY#$%TRONGpa44w0rd;
```

Just replace `<your-server-name>` and `<your-database-name>` with the correct values for your environment.

To run and test the Python REST API local, just run

```bash
flask run
```

Python will start the HTTP server and when everything is up and running you'll see something like

```text
 * Running on http://127.0.0.1:5000/ (Press CTRL+C to quit)
```

Using a REST Client (like [Insomnia](https://insomnia.rest/), [Postman](https://www.getpostman.com/) or curl), you can now call your API. The API requires a Bearer Token that contains the Hashed User Id of the user you want to simulate:

|User|Hashed Id|
|---|---|
|Jane Dean|6134311589|
|John Doe|1225328053|

the definition of who can see what is stored in the `rls.SensitiveDataPermissions` table.

To generate the Bearer Token you can use the `pyjwt` that is automatically installed by the `pyjwt` python package. Use the key `mySUPERs3cr3t` to sign the JWT message.

Linux:

```bash
export token=`pyjwt --key=mySUPERs3cr3t encode iss=me exp=+600 user-hash-id=1225328053`
curl -s -H "Authorization: Bearer ${token}" -X GET http://localhost:5000/sensitive-data/more  | jq .
```

Windows:

```powershell
$token = pyjwt --key=mySUPERs3cr3t encode iss=me exp=+600 user-hash-id=1225328053
(Invoke-WebRequest -Uri http://localhost:5000/sensitive-data/more -Method GET -Headers @{"Authorization"="Bearer $token"}).Content
```

and you'll get info on Customer 123:

```json
[
    {
        "Id": 1,
        "FirstName": "Jane",
        "LastName": "Dean",
        "EvenMore": [...]
    },
    {
        "Id": 2,
        "FirstName": "John",
        "LastName": "Doe",
        "EvenMore": [...]
    }
]
```

As you can see, data for both users is returned, even if you are invoking the API using a specific User. This is because the Row Level Security feature is *disabled*.

## Enable Row Level Security

To enable to Row Level Security Policy execute the following code in the sample database:

```sql
alter security policy rls.SensitiveDataPolicy with (state = on)
```

If you try to access the same API again, you'll now see only the data for the user you are simulating:

```json
[    
    {
        "Id": 2,
        "FirstName": "John",
        "LastName": "Doe",
        "EvenMore": [...]
    }
]
```

## Debug from Visual Studio Code

Debugging from Visual Studio Code is fully supported. Make sure you create an `.env` file the look like the following one (making sure you add your connection string)

```
FLASK_ENV="development"
SQLAZURECONNSTR_RLS=""
```

and you'll be good to go.

## Deploy to Azure

Now that your REST API solution is ready, it's time to deploy it on Azure so that anyone can take advantage of it. A detailed article on how you can that that is here:

- [Deploying Python web apps to Azure App Services](https://medium.com/@GeekTrainer/deploying-python-web-apps-to-azure-app-services-413cc16d4d68)
- [Quickstart: Create a Python app in Azure App Service on Linux](https://docs.microsoft.com/en-us/azure/app-service/containers/quickstart-python?tabs=bash)

The only thing you have do in addition to what explained in the above articles is to add the connection string to the Azure Web App configuration. Using AZ CLI, for example:

```bash
appName="azure-sql-db-secure-data-access-api"
resourceGroup="my-resource-group"

az webapp config connection-string set \
    -g $resourceGroup \
    -n $appName \
    --settings RLS=$SQLAZURECONNSTR_RLS \
    --connection-string-type=SQLAzure
```

Just make sure you correctly set `$appName` and `$resourceGroup` to match your environment and also that the variable `$SQLAZURECONNSTR_RLS` as also been set, as mentioned in section "Run sample locally". An example of a full script that deploy the REST API is available here: `azure-deploy.sh`.

Please note that connection string are accessible as environment variables from Python when running on Azure, *but they are prefixed* as documented here:

https://docs.microsoft.com/en-us/azure/app-service/configure-common#connection-strings

That's why the Python code in the sample look for `SQLAZURECONNSTR_RLS` but the Shell script write the `RLS` connection string name.

## Learn more

https://techcommunity.microsoft.com/t5/azure-sql-database/building-rest-api-with-python-flask-and-azure-sql/ba-p/1056637
https://github.com/Azure-Samples/azure-sql-db-python-rest-api

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.