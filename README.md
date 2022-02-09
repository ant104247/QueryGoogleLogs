# RunQueryOnGoogleLogs

**First Thing First, you must download google cloud SDK to your laptop and execute "gcloud" and use your neo4j email accout to authenticate**

**you need to make sure you get the correct dbid**

**you need to create log/ directory manually before running the script**

**you need to create time.gcp-ql file before you execute the script**
example:- if you are using Pacific Standard Time, you need to put -0800 at the end of the timestamp
timestamp>="2021-11-14T23:55:00-0800"
timestamp<="2021-11-15T00:05:00-0800"

**if AuraDB running on AWS**
./1downloadQueryFromGCPLogs.sh --dbid {{dbid}} -f filter-queries.gcp-ql -t time.gcp-ql --project aws-aura-iralogix

**If AuraDB running on GCP**
./1downloadQueryFromGCPLogs.sh  -t time.gcp-ql -f filter-queries.gcp-ql --project neo4j-cloud --dbid 

After successfully executed the 1st scirpt, you will get your query log json file. 

then you need to execute the 2nd script to import the json file into your local neo4j databae
2LoadLogToNeo4jDB.cypher


After step 1 and 2, you can draft you own search statement, You can use 3 as an example and start point.
3queryQueryLog.cypher
