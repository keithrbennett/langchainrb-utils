#!/usr/bin/env ruby


# require "langchain"
# require "langchain/llm/ollama"
# require 'faraday'

# # Initialize the Ollama LLM
# ollama = Langchain::LLM::Ollama.new

# # Example usage
# response = ollama.complete(prompt: "what is the french word for white?")
# puts response
# exit!


require 'awesome_print'
require 'langchain'
require 'openai'
require 'pry'
require 'reline'

prompt = ARGV.join(' ')
# llm = Langchain::LLM::OpenAI.new(api_key: ENV['OPENAI_API_KEY'])
# llm = Langchain::LLM::Anthropic.new(api_key: ENV['ANTRHOPIC_API_KEY'])
llm = Langchain::LLM::Ollama.new

response = llm.chat(messages: [{ role: "user", content: prompt }])


puts <<~HEREDOC

  Your prompt was:
  #{prompt}

  The LLM answer was:
  #{response.chat_completion}

  The LLM's raw response was:
  #{response.raw_response.awesome_inspect}

  Would you like to run the pry interactive shell (REPL) to inspect the response (y/N)?
HEREDOC

if Reline.readline("> ", true).upcase == 'Y'
  puts "Ok, press Ctrl+D to exit."
  binding.pry
end


