#####################
# Required env vars
# DT_API_URL ... Dynatrace API endpoint
# DT_API_TOKEN ... Dynatrace API token to with permission "PaaS integration - Installer download".
#
# #Optional env vars
# DT_LINUX_FLAVOR ... Some containers may use alpine based images (e.g. tomcat) which need to set DT_LINUX_FLAVOR to 'musl'
if [ -n "$DT_LINUX_FLAVOR" ] 
then
    DT_LINUX_FLAVOR="default"
fi

wget -O /tmp/installer.sh "https://${DT_API_URL}/v1/deployment/installer/agent/unix/paas-sh/latest?Api-Token=${DT_API_TOKEN}&arch=x86&flavor=${DT_LINUX_FLAVOR}" 

sh /tmp/installer.sh /home 

export LD_PRELOAD=/home/dynatrace/oneagent/agent/lib64/liboneagentproc.so

