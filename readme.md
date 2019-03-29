This project demonstrates a way to build and test locally between an Oracle database and a Tomcat application incorporating Hashicorp Vault to hold configuration information securely. 

We add the complexity of how to distribute secrets and configuration to the deployed application as well. 

The project explores a "halfway" solution to configuration of endpoints and configuration in general.  We could redesign our applications to make Vault HTTP API querries as they run to get what they need.  However, many applications already use "property" files.  We will build the property files from vault-cli queries, construct the property files, and put them into the containers which are calling upon them.  Again, this is not THE solution, but an easy to follow example to get you started thinking about how Vault can be used.

Vault is a tool for securely accessing secrets. A secret is anything that you want to tightly control access to, such as API keys, passwords, certificates, and more. Vault provides a unified interface to any secret, while providing tight access control and recording a detailed audit log. More details can be found at https://github.com/hashicorp/vault/

When Vault is initialized, it returns information that must be parsed and used to start secure communication with the server.  Here's one example of what that looks like:
```bash
Unseal Key 1: DOXxsjv2HHapimfs3t5cGY4bXmZ8RrCGjS5aXvAk2quc
Unseal Key 2: 5T2qXgYyW/gVn/LOcR2W5qM7L6R/qwLIxEZQBxAkLCdP
Unseal Key 3: wx7R67AdFRwvNiVVmdLa80zOGQpr58SuLfTGWDh5ABXa
Unseal Key 4: T40OYWh/MguyGZUQ+txYlZGttkB8elUUpdnbPHvjxRxA
Unseal Key 5: qFeJt3vn3d/E2xu5j5haFABDIn4h42XndF7joUZRfbbj

Initial Root Token: s.ftOpsnDSijMPmwbzkm8CG8tV

Vault initialized with 5 key shares and a key threshold of 3. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 3 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated master key. Without at least 3 key to
reconstruct the master key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
```

In this example, we run the vault client from the Docker container itself.  Normally, one would install vault locally to make the interactions easier.  But doing it this way allows us to use Vault without an installation other than Docker.

```bash
./build_1_create_integration_test_environment.sh
```
1. Bring up a Vault server.  We are running in a container locally, but the container can run anywhere.  In production, there would be a single Vault instance addressable behind the firewall that all applications will use.
2. Bring up an Oracle database.  We are running in a container locally, but the container can run anywhere.
3. Bring up a Tomcat server.  We are running in a container locally, but the container can run anywhere.
4. Send off Oracle related secrets to the Vault server.
5. Construct a properties file for running Liquibase to establish the database from Vault information.
6. Create the test database by running Liquibase.

```bash
./build_2_run_integration_tests.sh
```
1. Compile the war for Tomcat to run.  
2. Construct a properties file for configuring the war to run on Tomcat (it says where the database is and gives connection information).  Deploy it (by copy) to the war.  Note that we have to talk to Vault again for Oracle secrets.
3. Run a smoke test to make sure everything is wired together correctly.
4. Construct a configuration file to point the test program to the web service to test.
5. Run the test program (a Cucumber regression test).

```bash
./build_destroy_integration_test_environment.sh
```
1. Tear down the containers we put together.

The next step is to deploy the containers on AWS through Terraform'ed infrastructure.  Each AWS EC2 instance will run Docker and we will simply deploy the containers to them using DockerHub to hold the images we create from the containers.