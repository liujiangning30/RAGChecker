#!/bin/bash
benchmark=$1
domain=$2
inject_negative_ctx=$3

model_name=$4
model_path=$5
tp=$6
num_models=$8

output_dir=$7

HOME=/cpfs01/user/liujiangning
DLC_PATH="/cpfs01/shared/public/dlc"
DATA_SOURCES="d-t6eho1vza1mhowio6z,d-art86a2ch022326902,d-ink8qcii9xtjb8nnhv,d-werawxl4rqlqxjzy1c,d-y44jni7lmuiup5bfs7,d-lx4svuc2asrio1608t"

DLC_CONFIG_PATH=${DLC_CONFIG_PATH:-"${HOME}/.dlc/config"}

# WORKERSPACE_ID=${WORKERSPACE_ID:-5366}
# RESOURCE_ID=${RESOURCE_ID:-"quota12hhgcm8cia"}
WORKERSPACE_ID=${WORKERSPACE_ID:-28276}
RESOURCE_ID=${RESOURCE_ID:-"quota1qk1wjqdctk"}

PRIORITY=${PRIORITY:-1}
WORKER_COUNT=${WORKER_COUNT:-1}
WORKER_GPU=${WORKER_GPU:-$((${num_models} * ${tp}))}
WORKER_CPU=${WORKER_CPU:-$((16 * ${tp}))}
WORKER_MEMORY=${WORKER_MEMORY:-400Gi}
SHELL_ENV=${SHELL_ENV:-"zsh"}
WORKER_IMAGE=${WORKER_IMAGE:-"pjlab-wulan-acr-registry-vpc.cn-wulanchabu.cr.aliyuncs.com/pjlab-eflops/liukuikun:cu121-ubuntu22-lkk-0513-rc6"}

TASK_CMD="cd /cpfs02/llm/shared/public/liujiangning/work/MindSearchEval/RAGChecker && chmod +x scripts/run_eval.sh && ./scripts/run_eval.sh ${domain} ${inject_negative_ctx} ${model_name} ${model_path} ${tp} ${output_dir} ${num_models}"

JOB_NAME="eval-judge-$model_name-$benchmark-$domain"

${DLC_PATH} submit pytorchjob --config ${DLC_CONFIG_PATH} \
--name $JOB_NAME \
--resource_id ${RESOURCE_ID} \
--data_sources ${DATA_SOURCES} \
--workspace_id $WORKERSPACE_ID \
--workers $WORKER_COUNT \
--worker_cpu $WORKER_CPU \
--worker_gpu ${WORKER_GPU} \
--worker_memory $WORKER_MEMORY \
--worker_image ${WORKER_IMAGE} \
--worker_shared_memory 200Gi \
--priority ${PRIORITY} \
--command  "${TASK_CMD}"