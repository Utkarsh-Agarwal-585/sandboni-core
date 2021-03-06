SLEEP_TIME=2
SONAR_INSTANCE="https://sonarcloud.io"

if [ -z "SONAR_PROJECT_KEY" ]; then
   echo "QG Script --> No SonarCloud project key"
   exit 1
fi

tasks=$(curl -s -u $SONAR_TOKEN: $SONAR_INSTANCE/api/ce/activity?component=${SONAR_PROJECT_KEY}&type=REPORT)
ce_task_id=$(echo $tasks | jq -r '.tasks[0].id')
echo "QG Script --> Task id ${ce_task_id}"

if [ -z "$ce_task_id" ]; then
   echo "QG Script --> No task id found"
   exit 1
fi

wait_for_success=true

while [ "${wait_for_success}" = "true" ]
do
  ce_status=$(curl -s -u "${SONAR_TOKEN}": "${SONAR_INSTANCE}"/api/ce/task?id=${ce_task_id} | jq -r .task.status)

  echo "QG Script --> Status of SonarCloud task is ${ce_status}"

  if [ "${ce_status}" = "CANCELLED" ]; then
    echo "QG Script --> SonarCloud job has been cancelled - exiting with error"
    exit 1
  fi

  if [ "${ce_status}" = "FAILED" ]; then
    echo "QG Script --> SonarCloud job has failed - exiting with error"
    exit 1
  fi

  if [ "${ce_status}" = "SUCCESS" ]; then
    echo "QG Script --> SonarCloud job has succeeded"
    wait_for_success=false
  fi

  sleep "${SLEEP_TIME}"

done

ce_analysis_id=$(curl -s -u $SONAR_TOKEN: $SONAR_INSTANCE/api/ce/task?id=$ce_task_id | jq -r .task.analysisId)
echo "QG Script --> Using analysis id of ${ce_analysis_id}"

# get the status of the quality gate for this analysisId
qg_status=$(curl -s -u $SONAR_TOKEN: $SONAR_INSTANCE/api/qualitygates/project_status?analysisId="${ce_analysis_id}" | jq -r .projectStatus.status)
echo "QG Script --> Quality Gate status is ${qg_status}"

if [ "${qg_status}" != "OK" ]; then
  echo "QG Script --> Quality gate is not OK - exiting with error"
  exit 1
fi