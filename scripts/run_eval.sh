#!/bin/bash
domain="$1"
inject_negative_ctx="$2"

model_name="$3"
model_path="$4"
tp="$5"
# num of judge server
n="$7"

output_dir="$6"

if [[ "$inject_negative_ctx" == "true" ]]; then
    inject_negative_ctx_flag=1
else
    inject_negative_ctx_flag=0
fi

# 先通过lmdeploy起judge服务，然后再起litellm服务
# {
#     export HOME=/cpfs01/user/liujiangning 
#     source ~/.bashrc
#     source activate internlm
#     lmdeploy serve api_server --model-name $model_name --model-format hf --tp ${tp} ${model_path}
# } > ${output_dir}/log/lmdeploy.log 2>&1 &
# tail -f ${output_dir}/log/lmdeploy.log | grep -q "INFO:     Uvicorn running on http://0.0.0.0:23333 (Press CTRL+C to quit)"
base_port=23333
pids_judge=()
{
    export HOME=/cpfs01/user/liujiangning 
    source ~/.bashrc
    source activate internlm
    
    for ((i=0; i<n; i++)); do
        start_gpu=$((i * tp))
        end_gpu=$((start_gpu + tp - 1))
        export CUDA_VISIBLE_DEVICES=$(seq -s, $start_gpu $end_gpu)

        port=$((base_port + i))
        {
            lmdeploy serve api_server --model-name "$model_name" --model-format hf --tp "$tp" "$model_path" --server-port "$port"
        } > "${output_dir}/log/lmdeploy_$port.log" 2>&1 &

        # 保存服务的 PID
        pids_judge[$i]=$! 
    done
} &

# 检查服务是否启动
success_count=0
for ((i=0; i<n; i++)); do
    port=$((base_port + i))
    while true; do
        if tail -n 10 "${output_dir}/log/lmdeploy_$port.log" | grep -q "INFO:     Uvicorn running on http://0.0.0.0:$port (Press CTRL+C to quit)"; then
            echo "lmdeploy 服务启动成功，端口: $port"
            success_count=$((success_count + 1))
            break
        else
            # echo "等待 lmdeploy 服务在端口 $port 启动..."
            sleep 2
        fi
    done
done
if [[ $success_count -eq $n ]]; then
    echo "所有 lmdeploy 服务已成功启动！"
fi

{
    . /cpfs01/user/liujiangning/miniconda3/bin/activate base
    conda activate mindSearchEval
    # 构造config.yaml
    python examples/construct_litellm_config.py --model_name "$model_name" --port "$base_port" --clients "$n"
    litellm --config examples/config.yaml --port 4000
} > ${output_dir}/log/litellm.log 2>&1 &

tail -f ${output_dir}/log/litellm.log | grep -q "INFO:     Uvicorn running on http://0.0.0.0:4000 (Press CTRL+C to quit)"
echo "litellm 服务启动成功"

# 保存litellm服务的PID
pid_litellm=$!

log_file="${output_dir}/log/eval.log"
{
    . /cpfs01/user/liujiangning/miniconda3/bin/activate base
    conda activate mindSearchEval
    api_key="sk-1234"
    export OPENAI_API_KEY=${api_key}
    echo eval ${domain} using Llama-3-70B-Instruct
    python -m ragchecker.cli \
        --input_path=${output_dir}/eval/predictions_${domain}_use_gt_ctx1_inject_negative_ctx${inject_negative_ctx_flag}_psgs.json \
        --output_path=${output_dir}/eval/results_${domain}_use_gt_ctx1_inject_negative_ctx${inject_negative_ctx_flag}_psgs.json \
        --extractor_name=openai/Llama-3-70B-Instruct \
        --checker_name=openai/Llama-3-70B-Instruct \
        --extractor_api_base=http://127.0.0.1:4000/v1/ \
        --checker_api_base=http://127.0.0.1:4000/v1/ \
        --batch_size_extractor=256 \
        --batch_size_checker=256 \
        --metrics all_metrics \
        --joint_check true
} > ${log_file} 2>&1 &
# 保存评测任务的PID
pid_eval=$!
wait $pid_eval
# 评测结束后，kill litellm服务和judge服务的进程pid
kill $pid_litellm
for pid in "${pids_judge[@]}"; do
    kill "$pid"
done

# 在`data/${benchmark}/${model_name}/${TIMESTAMP}/eval/${domain}/log/eval.log`写入`Eval Finished!`
echo "Eval Finished!" >> "$log_file"