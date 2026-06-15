{
  "apiKey": "<API_KEY>",
  "baseUrl": "https://api.atlassian.com",
  "logLevel": "INFO",
  "globalArgs": [],
  "globalFlags": {
    "api_url": "https://icinga2-master.neteyelocal:5665",
    "user": "neteye-jsm-opsgenie",
    "password": "<ICINGA2 API PASSWORD>",
    "insecure": "false"
  },
  "actionMappings": {
    "Create": {
      "filepath": "/home/jsm/jec/scripts/jec_action_executor.py",
      "sourceType": "local",
      "env": [],
      "stdout": "/home/jsm/jec/output/output.txt"
    },
    "Acknowledge": {
      "filepath": "/home/jsm/jec/scripts/jec_action_executor.py",
      "sourceType": "local",
      "env": [],
      "stdout": "/home/jsm/jec/output/output.txt"
    },
    "AddNote": {
      "filepath": "/home/jsm/jec/scripts/jec_action_executor.py",
      "sourceType": "local",
      "env": [],
      "stdout": "/home/jsm/jec/output/output.txt"
    },
    "TakeOwnership": {
      "filepath": "/home/jsm/jec/scripts/jec_action_executor.py",
      "sourceType": "local",
      "env": [],
      "stdout": "/home/jsm/jec/output/output.txt"
    },
    "AssignOwnership": {
      "filepath": "/home/jsm/jec/scripts/jec_action_executor.py",
      "sourceType": "local",
      "env": [],
      "stdout": "/home/jsm/jec/output/output.txt"
    },
    "UnAcknowledge": {
      "filepath": "/home/jsm/jec/scripts/jec_action_executor.py",
      "sourceType": "local",
      "env": [],
      "stdout": "/home/jsm/jec/output/output.txt"
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