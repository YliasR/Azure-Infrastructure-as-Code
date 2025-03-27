# Azure Infrastructure as Code

## Diagram

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

Now we’ll create a repository on azure where we will push our image to azure

