#!/usr/bin/env ruby

require 'awesome_print'
require 'langchain'
require 'openai'
require 'pry'
require 'reline'

prompt = ARGV.join(' ')
llm = Langchain::LLM::OpenAI.new(api_key: ENV['OPENAI_API_KEY'])
response = llm.chat(messages: [{ role: "user", content: prompt }])

puts <<~HEREDOC

  Your prompt was:
  #{prompt}

  The LLM answer was:
  #{response.completion}

  The LLM's raw response was:
  #{response.raw_response.awesome_inspect}

  Would you like to run the pry interactive shell (REPL) to inspect the response (y/N)?
HEREDOC

if upcase(Reline.readline("> ", true)) == 'Y'
  puts "Ok, press Ctrl+D to exit."
  binding.pry
end

binding.pry


