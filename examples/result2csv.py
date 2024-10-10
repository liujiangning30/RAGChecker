import os
import json
import codecs
import argparse
import pandas as pd


def convert_to_table(results_file):
    if not os.path.exists(results_file):
        return [[domain, None, None]] * 12
    with codecs.open(results_file, 'r', 'utf-8') as fr:
        data = json.load(fr)
        if not data["metrics"]["overall_metrics"]:
            return [[domain, None, None]] * 12
        formatted_data = [
            [domain, "overall-precision", data["metrics"]["overall_metrics"]["precision"]],
            [domain, "overall-recall", data["metrics"]["overall_metrics"]["recall"]],
            [domain, "overall-f1", data["metrics"]["overall_metrics"]["f1"]],
            [domain, "retriever-claim_recall", data["metrics"]["retriever_metrics"]["claim_recall"]],
            [domain, "retriever-context_precision", data["metrics"]["retriever_metrics"]["context_precision"]],
            [domain, "generator-context_utilization", data["metrics"]["generator_metrics"]["context_utilization"]],
            [domain, "generator-noise_sensitivity_in_relevant", data["metrics"]["generator_metrics"]["noise_sensitivity_in_relevant"]],
            [domain, "generator-noise_sensitivity_in_irrelevant", data["metrics"]["generator_metrics"]["noise_sensitivity_in_irrelevant"]],
            [domain, "generator-hallucination", data["metrics"]["generator_metrics"]["hallucination"]],
            [domain, "generator-self_knowledge", data["metrics"]["generator_metrics"]["self_knowledge"]],
            [domain, "generator-faithfulness", data["metrics"]["generator_metrics"]["faithfulness"]],
            [None, None, None]
        ]
    return formatted_data


if __name__ == '__main__':
    parser = argparse.ArgumentParser()

    # Model related options
    parser.add_argument('--root_dir', type=str, default='data/eval/crud/internlm2_5-7b-chat', help="File of prediction data being converted.")
    parser.add_argument('--domains', type=str, default='Summary ContinueWriting HalluModified QuestAnswer1Doc QuestAnswer2Docs QuestAnswer3Docs', help="Domains of prediction data being converted.")
    parser.add_argument('--results_file_pattern', type=str, default='results_{domain}_from_colbert_use_gt_ctx1_5_psgs.json', help="Pattern of file of data being converted.")
    parser.add_argument('--output_file', type=str, default='results_from_colbert_use_gt_ctx1_5_psgs.csv', help="File of converted data to be saved.")
    args = parser.parse_args()

    results_root_dir = args.root_dir
    results_file_pattern = args.results_file_pattern
    domains = args.domains.split()

    results = []
    for domain in domains:
        results_file = os.path.join(results_root_dir, f'{domain}/eval', results_file_pattern.format(domain=domain))
        formatted = convert_to_table(results_file)
        results.extend(formatted)
    df = pd.DataFrame(results, columns=['task', 'metric', 'value'])
    df.to_csv(os.path.join(results_root_dir, args.output_file), index=False)