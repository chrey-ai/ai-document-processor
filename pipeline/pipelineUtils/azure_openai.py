from openai import AzureOpenAI
import logging
from azure.identity import get_bearer_token_provider
from pipelineUtils.db import save_chat_message
from configuration import Configuration

config = Configuration()

def get_openai_setting(name):
    value = config.config.get(name)
    return value if value else config.get_value(name)


OPENAI_API_BASE = get_openai_setting("OPENAI_API_BASE")
OPENAI_MODEL = get_openai_setting("OPENAI_MODEL")
OPENAI_API_VERSION = get_openai_setting("OPENAI_API_VERSION")


def run_prompt(pipeline_id, system_prompt, user_prompt):
    token_provider = get_bearer_token_provider(  
        config.credential,  
        "https://cognitiveservices.azure.com/.default"  
    )  

    token = config.credential.get_token("https://cognitiveservices.azure.com/.default").token
    
    openai_client = AzureOpenAI(
        azure_ad_token=token,
        api_version = OPENAI_API_VERSION,
        azure_endpoint =OPENAI_API_BASE
    )

    logging.info(f"User Prompt: {user_prompt}")
    logging.info(f"System Prompt: {system_prompt}")

    save_chat_message(pipeline_id, "system", system_prompt)
    save_chat_message(pipeline_id, "user", user_prompt)

    try:
        response = openai_client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=[{ "role": "system", "content": system_prompt},
                {"role":"user","content":user_prompt}])
        assistant_msg = response.choices[0].message.content
        usage = {
            "prompt_tokens":   response.usage.prompt_tokens,
            "completion_tokens": response.usage.completion_tokens,
            "total_tokens":    response.usage.total_tokens,
            "model":           response.model
        }

        # 2) log the assistant’s response + usage
        save_chat_message(pipeline_id, "assistant", assistant_msg, usage)
        return assistant_msg
    
    except Exception as e:
        logging.error(f"Error calling OpenAI API: {e}")
        raise  # Re-raise to allow Durable Functions to retry


