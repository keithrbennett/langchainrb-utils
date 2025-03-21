#!/usr/bin/env ruby

require 'anthropic'
require 'awesome_print'
require 'langchain'
require 'openai'
require 'pry'
require 'reline'

def open_ai_llm = Langchain::LLM::OpenAI.new(api_key: ENV['OPENAI_API_KEY'])
def anthopic_llm = Langchain::LLM::Anthropic.new(api_key: ENV['ANTHROPIC_API_KEY'])
def ollama_llm = Langchain::LLM::Ollama.new

def deepseek_llm
  llm = Langchain::LLM::OpenAI.new(
    api_key: ENV['DEEPSEEK_API_KEY'],
    default_options: {
      chat_model: "deepseek-reasoner"  # Changed to model_name parameter
    }
  )

  # Kludge to use OpenAI class for DeepSeek API
  llm.instance_variable_get(:@client).instance_variable_set(
    :@uri_base, 
    "https://api.deepseek.com/v1"
  )

  llm
end

def call_llm(llm, prompt)
  response = llm.chat(messages: [{ role: "user", content: prompt }])
end

def report_llm_response(llm, prompt, response)
  puts <<~HEREDOC

    ---------------------------------------
    LLM: #{llm.class.name}
    Model: #{llm.defaults[:chat_model]}

    Your prompt was:
    #{prompt}

    The LLM answer was:
    #{response.chat_completion}

    The LLM's raw response was:
    #{response.raw_response.awesome_inspect}
    ---------------------------------------

    Would you like to run the pry interactive shell (REPL) to inspect the response (y/N)?
  HEREDOC

  if Reline.readline("> ", true).upcase == 'Y'
    puts "Ok, press Ctrl+D to exit."
    binding.pry
  end

  response
end

def main
  prompt = ARGV.join(' ')

  # Specify which LLMs to use:
  llms = [open_ai_llm, anthopic_llm, ollama_llm, deepseek_llm]
  # llms = [ollama_llm, deepseek_llm]
  # llms = [ollama_llm]

  # This will call each model sequentially:
  # llms.each { |llm| call_llm(llm, prompt) }

  # This will call all models in parallel:
  threads = llms.map do |llm| 
    Thread.new do
      response = call_llm(llm, prompt)
      [llm, response]
    end
  end

  threads.each(&:join)
  responses = threads.map(&:value)
  responses.each { |llm, response| report_llm_response(llm, prompt, response) }
end

main
