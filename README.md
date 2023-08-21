# Nomad Single "Cluster" on gridscale infrastructure

Get up and running a single "cluster" (meaning one node which is server and client at once) with Nomad on a [gridscale.io](https://gridscale.io) infrastructure. As you can guess this is a setup for some small web projects only, even it should not be too hard to extend it to a real cluster with additional nomad clients once.

**Features:**
* Single node nomad cluster with consul - ideal for small projects on a single server
* Fabio Loadbalancer, automatically configuring loadbalancing from your domain to the nomad job (You have to set `tags` in your job definition (see `jobs/matomo.hcl` as an example or google for "nomad fabio urlprefix"))
* Automatic managed Let's encrypt SSL certificates by aleff
* Deploy and forget - your stuff is just running on your domain


## Install on gridscale

### Requirements

* Paid account on [my.gridscale.io](https://my.gridscale.io)
* API Token with write access and User-UUID (get both via the gridscale panel: Panel -> UserIcon -> API-Tokens)
* SSH-Key uploaded to the gridscale panel
* Terraform installed (e.g. `brew install terraform` on mac)


### Let's go

* Clone this repo if you haven't.
* Within the `gridscale` directory run `terraform init`
* Set variables in `gridscale/terraform.tfvars`: 
  * `gridscale_uuid` (gridscale User-UUID you get it from gridscale Panel -> UserIcon -> API-Tokens when you create new API token (write access))
  * `gridscale_token` (gridscale API token you get it from gridscale Panel -> UserIcon -> API-Tokens when you create new API token (write access))
  * `sshkey_uuid` (UUID of an SSH key which you should upload to gridscale Panel -> UserIcon -> SSH-Keys)
  * `publicnet_uuid` (UUID of the network named "Public Network" in the gridscale panel)
* **PLEASE NOTE** if you make changes to scripts in `shared/config`: These were downloaded from GitHub during the installation process. So you have to provide them with your changes somewhere else and change the URLs in `shared/data-scripts/user-data-server.sh`
* run `terraform apply`

### Authorize to nomad from your workstation

After terraform is ready perform this on your workstation:

```
export NOMAD_ADDR=$(terraform output -raw nomad_ip)

nomad acl bootstrap | \
  grep -i secret | \
  awk -F "=" '{print $2}' | \
  xargs > nomad-management.token

export NOMAD_TOKEN=$(cat nomad-management.token)
```

This will create the first Nomad Token for you as an admin and stores it in an environment variable.

#### Verify connectivity
```
 nomad node status
```
Should display something except an error.

#### Authorize to the web UI
```
nomad ui -authenticate
```
This will open your browser with the nomad web UI, sending a token which will authorize your browser to the UI.


## Deploying Apps
Your "cluster" should be working now. Time to deploy first apps.

First we need another token, cause we don't want to use our first token with those high permissions.

### Add the dev policy:

We add a new policy, only allowing things that Dev's will do (deploy apps)
`nomad acl policy apply developer policies/app-dev.policy.hcl`

More information on policies: https://developer.hashicorp.com/nomad/tutorials/access-control/access-control-create-policy

### Create token (e.g. for CI/CD)

`nomad acl token create -name="github actions" -global=true -policy=developer -type=client | tee app-dev.token`

To get the secret, which you will need to deploy jobs (and that you may store to the github secret vault): `awk '/Secret/ {print $4}' app-dev.token`

### HTTP API
You can also use the HTTP API to deploy jobs in json format (easier for Github Actions, just post a job JSON with curl)

Useful command to get a JSON-job definition out of a hcl job definition:
`nomad job run -output jobs/nginx.hcl`


## Useful apps shipped with this repo

### fabio

To have a loadbalancer, which will route incoming HTTP(s) requests to the right nomad job, you need [fabio](https://fabiolb.net): Deploy it:

`nomad job run jobs/fabio.hcl`

### aleff

you may also want to deploy the [aleff](https://aleff.dev) job, which will automatical manage let's encrypt certificates for your domains for you:

`nomad job run  -var email_address="<YOUR_EMAIL_ADDRESS>" -var nomad_token="<NOMAD_DEVELOPER_TOKEN>" jobs/aleff.hcl`


### MariaDB
You can also install mariaDB server (I use **one** for all my apps) by `nomad job run jobs/mariadb.hcl`
This will store data in the persistent volume `volume1` which is created with the terraform script

I currently have no good solution to seed the DB, so I use the **Exec** function of the nomad UI on the database job, after it's deployed, install curl, download the dump from somewhere and import it...

### Matomo
As self hosted tracking tool I use matomo. It will use the MariaDB installed on the previous step via nomad service discovery. But matomo has a caveat that it needs to create a `config.ini.php` with it's setup wizzard the first time, and if this file is not there it will always start it's setup wizzard.
Therefore matomo needs also a persistent volume, and I use the "matomo" volume for this, which is also created when you used the terraform script of this repo. When you first browse to your matomo instance, you will just have to click through the setup. All the database stuff is prefilled as you give it to the following command (available variables see `jobs/matomo.hcl`).

`nomad job run -var db_pass=<YOUR_DATABASE_PASSWORD> -var matomo_url=<URL TO YOUR MATOMO INSTALLATIONY> jobs/matomo.hcl`

#### Archiver
Don't know a better way to setup the archiver cron, so I made a periodic nomad batch job which just CURLs the cron via the matomo web URL. So install it do

`nomad job run -var token_auth=<API_TOKEN_GENERATED_WITH_ADMIN_USER> -var matomo_url=<URL TO YOUR MATOMO INSTALLATIONY> jobs/matomo_archive.hcl`

it will archive at 4AM every day



## Thoughts on security
You should restrict access to the fabio UI on port 9998 via gridscale firewall settings of the server (in server details click on the green "Activated" next to the "Public Network").

The nomad UI (Port 4646) could also be restricted, even it is protected by nomad itselt (auth with nomad token required).
