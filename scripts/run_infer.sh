#!/bin/bash
benchmark="$1"
domain="$2"
inject_negative_ctx="$3"

model_name="$4"
model_path="$5"
model_type="$6"
tp="$7"

output_dir="$8"

# cd /cpfs02/llm/shared/public/liujiangning/work/MindSearchEval/RAGChecker
# . /cpfs01/user/liujiangning/miniconda3/bin/activate
# conda activate mindSearchEval

if [[ "$inject_negative_ctx" == "true" ]]; then
    inject_negative_ctx_flag=1
else
    inject_negative_ctx_flag=0
fi

if [[ ${model_name} == gpt-4o* ]]; then
    template_version=v2
else
    template_version=v1
fi

log_dir="${output_dir}/log"
mkdir -p "$log_dir"
log_file="${log_dir}/infer.log"
{
    if [ ${benchmark} == "crud" ]; then
        # infer
        cd /cpfs02/llm/shared/public/liujiangning/work/MindSearchEval/CRUD_RAG
        python quick_start.py --model_name ${model_name} --model_path ${model_path} --model_type ${model_type} --tp ${tp} --task ${domain} --batch_size 256 --retrieve_top_k 8 --use_gt_ctx true --inject_negative_ctx ${inject_negative_ctx} --output_dir ${output_dir}/infer
        echo convert predictions to ragchecker input format for domain ${domain}
        python convert2ragchecker_format.py --task ${domain} --model_name ${model_name} --prediction_dir ${output_dir}/infer/docs_80k_chuncksize_128_0_top8_use_gt_ctx1_inject_negative_ctx${inject_negative_ctx_flag}_${model_type} --output_file ${output_dir}/eval/predictions_${domain}_use_gt_ctx1_inject_negative_ctx${inject_negative_ctx_flag}_psgs.json
    else
        # infer
        cd /cpfs02/llm/shared/public/liujiangning/work/MindSearchEval/rag-qa-arena
        python code/generate_responses.py --model ${model_name} --model_path ${model_path} --tp ${tp} --domain ${domain} --inference_batch_size 256 --n_passages 5 --use_gt_ctx true --inject_negative_ctx ${inject_negative_ctx} --eval_dir ${output_dir}/infer --output_file ${domain}_from_colbert --input_file /cpfs02/llm/shared/public/liujiangning/work/MindSearchEval/robustqa-acl23/output/${domain}_from_colbert_test.jsonl --template_config ans_generation_${template_version}.cfg
        echo convert predictions to ragchecker input format for domain ${domain}
        python code/convert2ragchecker_format.py --prediction_file ${output_dir}/infer/${domain}_from_colbert_use_gt_ctx1_inject_negative_ctx${inject_negative_ctx_flag}_psgs.json --output_file ${output_dir}/eval/predictions_${domain}_use_gt_ctx1_inject_negative_ctx${inject_negative_ctx_flag}_psgs.json
    fi
} > ${log_file} 2>&1 &

pid_infer=$!
wait $pid_infer
# 在`data/eval/${benchmark}/${model_name}/${TIMESTAMP}/${domain}/log/infer.log`写入`Infer Finished!`
echo "Infer Finished!" >> "$log_file"