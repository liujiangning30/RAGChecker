import yaml
import argparse


if __name__ == '__main__':

    parser = argparse.ArgumentParser()

    # Model related options
    parser.add_argument('--model_name', default='Llama-3-70B-Instruct', help="Name of the model to use, such as Llama-3-70B-Instruct")
    parser.add_argument('--port', type=int, default=23333, help="Port of first client deployed.")
    parser.add_argument('--clients', type=int, default=1, help="Number of clients deployed.")
    args = parser.parse_args()

    config = {
        'model_list': []
    }
    for i in range(args.clients):
        port = args.port + i
        config['model_list'].append(
            {
                'model_name': args.model_name,
                'litellm_params': {
                    'model': f'openai/{args.model_name}',
                    'api_base': f'http://127.0.0.1:{port}/v1/',
                    'api_key': 'sk-1234'
                }
            }
        )

    with open('examples/config.yaml', 'w') as file:
        yaml.dump(config, file, default_flow_style=False, allow_unicode=True)