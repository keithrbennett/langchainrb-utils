#!/usr/bin/env ruby

require 'anthropic'
require 'awesome_print'
require 'langchain'
require 'openai'
require 'pry'
require 'reline'
require_relative '../lib/llm_clients'

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
  if ARGV.empty?
    puts "Usage: `#{__FILE__} <prompt>`, where all args are joined with spaces."
    exit 1
  end

  prompt = ARGV.join(' ')

  # Specify which LLMs to use (comment out the ones you don't want to use):
  llms = [
    # LlmClients.create(:anthropic)?,
    # LlmClients.create(:deepseek),
    LlmClients.create(:gemini),
    LlmClients.create(:ollama),
    LlmClients.create(:openai),
  ]

  # This will call each model sequentially:
  # llms.each { |llm| call_llm(llm, prompt) }

  # This will call all models in parallel:
  threads = llms.map do |llm| 
    Thread.new do
      response = LlmClients.call_llm(llm, prompt)
      [llm, response]
    end
  end

  threads.each(&:join)
  responses = threads.map(&:value)
  responses.each { |llm, response| report_llm_response(llm, prompt, response) }
end

main
