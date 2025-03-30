# Azure Infrastructure as Code



## Step by step guide:

### The docker file:
First we will create our docker file that will create a container image with our web app based on flask.
(See the dockerfile inside the repo)
After writing the docker file we then use the docker build command on the terminal:
```
docker build -t aziac .
```
![cli](https://i.imgur.com/yQNKPJD.png )


### Azure CLI

Now we’ll create an azure container registry on azure where we will push our image to.

First create a resource group using the following command
``` az group create --name AzureIac --location eastus ```
###### You can if you want choose a different name and location.
![resourcegroup](https://i.imgur.com/Rtn6pAQ.png)

next we'll create the acr:
```az acr create --resource-group AzureIac --name oefaziac --sku Basic```
note that the name for the acr needs to be unique, and make sure that the resource group is the same as teh one you made previously!
![acr](https://i.imgur.com/nEwAAmC.png)
###### output is too big to show completly, but this a sample of what it'll show.

Now we must login into the acr using: ``` az acr login --name oefaziac ```
![loginacr](https://i.imgur.com/ohxtJMc.png)


before we push our image we need to tag it with the full name of the registry, to get that name use this command:
```az acr show --name oefaziac --query loginServer --output table```
![tagname](https://i.imgur.com/i2bTsmG.png)

tag the image: ```docker tag aziac oefaziac.azurecr.io/aziac:v1```
###### don't forget to use your own chosen names which could be different from mine
then push: ``` docker push oefaziac.azurecr.io/aziac:v1 ```
![docker push](https://i.imgur.com/PwWmPwu.png)
you can verify that the image was pushed to the right registery using this command ``` az acr repository list --name aziac --output table```

after completing these steps, we can move on to deploying the image!


### Deploying an image to azure container instances

#### Logs
first lets create a log analytics workspace, by running
```az monitor log-analytics workspace create --resource-group AzureIac --workspace-name aziaclog --location eastus --sku PerGB2018```
this creates the workspace inside our resource group.
![logs](https://i.imgur.com/4s3ZL0S.png)
in the output you will se an "id" we need this for the deployment command.

Before deploying we need to create a bicep file, the bicep file contains the instructions to create the container instance, the subnet, and the network security group.
##### (see main.bicep file inside the repository )



Deploy with this command, note the logs workspace id, this is the id that you were given when creating your log analytics workspace.
```   az deployment group create --resource-group AzureIac --template-file main.bicep --parameters registryPassword="YOUR PASSWORD"                                       
 ```