#!/bin/bash

benchmark=crud
# domains=(Summary ContinueWriting HalluModified QuestAnswer2Docs QuestAnswer3Docs)
domains=(Summary ContinueWriting HalluModified QuestAnswer1Doc QuestAnswer2Docs QuestAnswer3Docs)
inject_negative_ctx=true

benchmark=rag-qa-arena
domains=(recreation)
# domains=(lifestyle recreation technology science writing)

infer_model_name=internlm2_5-7b-chat
infer_model_path=/cpfs02/llm/shared/public/zhaoqian/ckpt/7B/240623/P-volc_internlm2_5_boost1_7B_FT_merge_boost_bbh_v2
infer_model_type=InternLM
infer_tp=1

# infer_model_name=Qwen2.5-7B-Instruct
# infer_model_path=/cpfs01/shared/public/llmeval/model_weights/hf_hub/models--Qwen--Qwen2.5-7B-Instruct/snapshots/52e20a6f5f475e5c8f6a8ebda4ae5fa6b1ea22ac
infer_model_name=Qwen2.5-72B-Instruct
infer_model_path=/cpfs01/shared/public/llmeval/model_weights/hf_hub/models--Qwen--Qwen2.5-72B-Instruct/snapshots/d3d951150c1e5848237cd6a7ad11df4836aee842
infer_tp=4

# infer_model_name=internlm2_5-7b-chat-MindSearch-RAG-d0924rc1
# infer_model_path=/cpfs02/llm/shared/public/liujiangning/ckpt/exps/MindSearch-RAG/aliyun_internlm2_5_boost1_7B_FT_s1_20240621rc11_s2_MindSearch-RAG-d0924rc1_0_hf

eval_model_name=Llama-3-70B-Instruct
eval_model_path=/cpfs01/shared/public/llmeval/model_weights/hf_hub/models--meta-llama--Meta-Llama-3-70B-Instruct/snapshots/1480bb72e06591eb87b0ebe2c8853127f9697bae
eval_tp=4
num_eval_models=2

# 定义timestamp变量
# TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")
TIMESTAMP=2024-10-09-20-58-45
output_dir="/cpfs02/llm/shared/public/liujiangning/work/MindSearchEval/RAGChecker/output/${benchmark}/${infer_model_name}/${TIMESTAMP}"

for i in "${!domains[@]}"; do
    {
        bash scripts/dlc_run_infer.sh ${benchmark} ${domains[i]} ${inject_negative_ctx} ${infer_model_name} ${infer_model_path} ${infer_model_type} ${infer_tp} "${output_dir}/${domains[i]}"

        # 基于infer.log中`Infer Finished!`消息启动评测任务
        log_file="${output_dir}/${domains[i]}/log/infer.log"
        while true; do
            if [[ -f "$log_file" ]] && grep -q "Infer Finished!" "$log_file"; then
                echo "推理完成，启动评测任务..."
                break
            fi
            sleep 2
        done

        bash scripts/dlc_run_eval.sh ${benchmark} ${domains[i]} ${inject_negative_ctx} ${eval_model_name} ${eval_model_path} ${eval_tp} ${output_dir}/${domains[i]} ${num_eval_models}

        # 基于eval.log中`Eval Finished!`消息判断评测任务是否结束
        log_file="${output_dir}/${domains[i]}/log/eval.log"
        while true; do
            if [[ -f "$log_file" ]] && grep -q "Eval Finished!" "$log_file"; then
                echo "评测完成，结束任务..."
                break
            fi
            sleep 2
        done
    } &
done

# 等待所有后台任务完成
wait

if [[ "$inject_negative_ctx" == "true" ]]; then
    inject_negative_ctx_flag=1
else
    inject_negative_ctx_flag=0
fi

python examples/result2csv.py --root_dir ${output_dir} --domains "${domains}" --results_file_pattern results_{domain}_use_gt_ctx1_inject_negative_ctx${inject_negative_ctx_flag}_psgs.json --output_file results_use_gt_ctx1_inject_negative_ctx${inject_negative_ctx_flag}_psgs.csv