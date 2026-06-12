{
  "apiKey": "<API_KEY>",
  "baseUrl": "https://api.eu.opsgenie.com",
  "logLevel": "INFO",
  "globalArgs": [],
  "globalFlags": {
    "api_url": "https://icinga2-master.neteyelocal:5665",
    "user": "neteye-oec",
    "password": "<ICINGA2 API PASSWORD>",
    "insecure": "false"
  },
  "actionMappings": {
    "Create": {
      "filepath": "/home/opsgenie/oec/scripts/actionExecutor.py",
      "sourceType": "local",
      "env": [],
      "stdout": "/home/opsgenie/oec/output/output.txt"
    },
    "Acknowledge": {
      "filepath": "/home/opsgenie/oec/scripts/actionExecutor.py",
      "sourceType": "local",
      "env": [],
      "stdout": "/home/opsgenie/oec/output/output.txt"
    },
    "AddNote": {
      "filepath": "/home/opsgenie/oec/scripts/actionExecutor.py",
      "sourceType": "local",
      "env": [],
      "stdout": "/home/opsgenie/oec/output/output.txt"
    },
    "TakeOwnership": {
      "filepath": "/home/opsgenie/oec/scripts/actionExecutor.py",
      "sourceType": "local",
      "env": [],
      "stdout": "/home/opsgenie/oec/output/output.txt"
    },
    "AssignOwnership": {
      "filepath": "/home/opsgenie/oec/scripts/actionExecutor.py",
      "sourceType": "local",
      "env": [],
      "stdout": "/home/opsgenie/oec/output/output.txt"
    },
    "UnAcknowledge": {
      "filepath": "/home/opsgenie/oec/scripts/actionExecutor.py",
      "sourceType": "local",
      "env": [],
      "stdout": "/home/opsgenie/oec/output/output.txt"
    }
  },
  "pollerConf": {
    "pollingWaitIntervalInMillis": 100,
    "visibilityTimeoutInSec": 30,
    "maxNumberOfMessages": 10
  },
  "poolConf": {
    "maxNumberOfWorker": 12,
    "minNumberOfWorker": 4,
    "monitoringPeriodInMillis": 15000,
    "keepAliveTimeInMillis": 6000,
    "queueSize": 0
  }
}
