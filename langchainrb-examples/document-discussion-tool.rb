#! /usr/bin/env ruby

# This script uploads a document such as a PDF or a repo created by 
# https://repo2txt.simplebasedomain.com/ and enables discussing that 
# document with an LLM.

require 'awesome_print'
require 'langchain'
require 'pdf-reader'
require 'faraday'
require 'optparse'
require 'json'
require 'logger'
require 'pry'

Langchain.logger = Logger.new('langchain.log')

def parse_command_line_options
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: document-discussion-tool.rb [options]"

    opts.on("-f", "--file FILE", "File to discuss (PDF or TXT)") do |f|
      options[:file] = f
    end

    opts.on("-q", "--question QUESTION", "Initial question to ask") do |q|
      options[:question] = q
    end
  end.parse!
  options
end

class DocumentLoader
  def self.load(file_path)
    raise "Please specify a file" if file_path.nil?
    puts "Loading document: #{file_path}..."

    # Use LangChain's document processors
    processor = case File.extname(file_path).downcase
    when '.pdf'
      Langchain::Processors::PDF.new
    when '.txt'
      Langchain::Processors::Text.new
    else
      raise "Unsupported file format. Please use PDF or TXT files."
    end

    # Process the document and chunk it
    content = File.open(file_path) { |file| processor.parse(file) }

    Langchain::Chunker::Text.new(
      content,
      chunk_size: 1000,
      chunk_overlap: 100,
      separator: "\n"  # Use newlines as chunk boundaries
    ).chunks
  end
end

class DocumentDiscussionTool
  def initialize(options)
    @llm = Langchain::LLM::Ollama.new
    @context = []
    @options = options
  end

  def load_document
    begin
      @context = DocumentLoader.load(@options[:file])
    rescue StandardError => e
      puts "Error loading document: #{e.message}"
      exit 1
    end
  end

  def chat
    puts "\nWelcome to Document Discussion Tool!"
    puts "Type 'exit' to quit or 'help' for commands."

    loop do
      if @options[:question]
        input = @options[:question]
        @options[:question] = nil  # Clear it so we only use it once
        puts "\nYour question:\n#{input}"
      else
        print "\nYour question: "
        input = gets.chomp
      end
      
      case input.downcase
      when 'exit'
        break
      when 'help'
        show_help
      else
        response = get_llm_response(input)
        puts "\nAI Response:"
        puts response
      end
    end
  end

  def get_llm_response(question)
    context = @context.map(&:text).join("\n\n")
    prompt = <<~PROMPT
      Context from the document:
      #{context}

      Question: #{question}

      Please answer based on the context provided above.
    PROMPT

    begin
    #   x = @llm.complete(prompt: prompt).completion
    #   x = @llm.complete(prompt: prompt)
    #   binding.pry
    #   x.completion
      @llm.complete(prompt: prompt).completion
    rescue JSON::ParserError, StandardError => e
      puts '!!!'
      puts "Error from LLM: #{e.message}"
      puts '$$$'
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
    load_document
    chat
  end
end

if __FILE__ == $0
  options = parse_command_line_options
  tool = DocumentDiscussionTool.new(options)
  tool.run
end


