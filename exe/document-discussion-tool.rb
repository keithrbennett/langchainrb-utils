#! /usr/bin/env ruby

# This script uploads a document such as a PDF or a repo created by 
# https://repo2txt.simplebasedomain.com/ and enables discussing that 
# document with an LLM.

require 'anthropic'
require 'awesome_print'
require 'faraday'
require 'json'
require 'langchain'
require 'logger'
require 'openai'
require 'optparse'
require 'pdf-reader'
require 'pry'

module Langchain
  module LLM
    class GoogleGemini
      def complete(prompt:, **_kwargs)
        response = chat(messages: [{ role: "user", contents: prompt }])
        OpenStruct.new(
          completion: response.chat_completion,
          raw_completion: response
        )
      end
    end
  end
end

Langchain.logger = Logger.new('langchain.log')

def parse_command_line_options
  options = { files: [] }
  OptionParser.new do |opts|
    opts.banner = "Usage: document-discussion-tool.rb [options] [file patterns...]"

    opts.on("-q", "--question QUESTION", "Initial question to ask") do |q|
      options[:question] = q
    end
  end.parse!
  
  # Handle remaining arguments as file patterns
  options[:files] = ARGV.flat_map { |pattern| Dir.glob(pattern) }
  options
end

class LlmClients
  class << self
    def create_anthropic = Langchain::LLM::Anthropic.new(api_key: ENV['ANTHROPIC_API_KEY'])
    def create_gemini    = Langchain::LLM::GoogleGemini.new(api_key: ENV['GEMINI_API_KEY'])
    def create_ollama    = Langchain::LLM::Ollama.new
    def create_openai    = Langchain::LLM::OpenAI.new(api_key: ENV['OPENAI_API_KEY'])
          
    def create_deepseek
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

    def create(name)
      public_send("create_#{name}")
    end
  end
end


class DocumentLoader
  def self.load(file_paths)
    raise "Please specify at least one file" if file_paths.empty?
    file_paths.each_with_object({}) do |path, docs|
      puts "Processing #{path}..."
      docs[path] = process_file(path)
    end
  end

  def self.process_file(file_path)
    case File.extname(file_path).downcase
    when '.pdf'
      processor = Langchain::Processors::PDF.new
      File.open(file_path) { |file| processor.parse(file) }
    when '.txt'
      File.read(file_path)
    else
      raise "Unsupported file format for #{file_path}. Please use PDF or TXT files."
    end
  end
end

class DocumentDiscussionTool
  def initialize(options)
    @llm = LlmClients.create(:ollama)
    @context = []
    @options = options
  end

  def load_document
    @context = DocumentLoader.load(@options[:files])
  end

  def chat
    puts "\nYour question:"
    loop do
      begin
        input = gets
        break if input.nil?
        
        case input.downcase
        when 'exit'
          break
        when 'help'
          show_help
        else
          response = get_llm_response(input)
          puts "\nAI Response:"
          puts response
          puts "\nYour question:"
        end
      rescue StandardError => e
        puts "Error: #{e.message}"
        puts "\nYour question:"
      end
    end
  end

  def get_llm_response(question)
    context = @context.map do |file_path, content|
      "From #{file_path}:\n#{content}"
    end.join("\n\n---\n\n")

    system_prompt = "You are a helpful assistant that answers questions about documents. Always reference which document(s) you used to find the information."
    
    begin
      puts "DEBUG: Context length: #{context.length}"
      puts "DEBUG: About to call LLM with messages:"
      messages = [
        { role: "system", content: system_prompt },
        { role: "user", content: context },
        { role: "user", content: question }
      ]
      puts messages.inspect
      
      response = @llm.chat(messages: messages)
      puts "DEBUG: Response class: #{response.class}"
      puts "DEBUG: Raw response: #{response.inspect}"
      
      response.chat_completion
    rescue StandardError => e
      puts "Error: #{e.class} - #{e.message}"
      "Sorry, there was an error getting the response. Please try again."
    end
  end

  def show_help
    puts <<~HELP
      Available commands:
      - help : Show this help message
      - exit : Exit the program
      - Any other input will be treated as a question about the document
    HELP
  end

  def run
    if @options[:question]
      response = get_llm_response(@options[:question])
      puts response
    else
      puts "\nWelcome to Document Discussion Tool!"
      puts "Type 'exit' to quit or 'help' for commands."
      chat
    end
  end
end

if __FILE__ == $0
  options = parse_command_line_options
  tool = DocumentDiscussionTool.new(options)
  tool.run
end


