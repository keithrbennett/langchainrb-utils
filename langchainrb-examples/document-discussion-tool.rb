#! /usr/bin/env ruby

# This script uploads a document such as a PDF or a repo created by 
# https://repo2txt.simplebasedomain.com/ and enables discussing that 
# document with an LLM.

require 'langchain'
require 'langchain/llm/ollama'
require 'langchain/embeddings/ollama'
require 'matrix'
require 'faraday'
require 'optparse'
require 'json'

class DocumentChunk
  attr_reader :content, :embedding

  def initialize(content, embedding)
    @content = content
    @embedding = Vector.elements(embedding)
  end

  def similarity_to(other_vector)
    # Cosine similarity
    dot_product = @embedding.inner_product(other_vector)
    magnitude_product = @embedding.magnitude * other_vector.magnitude
    dot_product / magnitude_product
  end
end

class DocumentLoader
  def self.load(file_path, embedder)
    raise "Please specify a file" if file_path.nil?
    
    # Use LangChain's document loaders
    loader = case File.extname(file_path).downcase
    when '.pdf'
      Langchain::Loader::PDF.new(file_path)
    when '.txt'
      Langchain::Loader::Text.new(file_path)
    else
      raise "Unsupported file format. Please use PDF or TXT files."
    end

    # Load and chunk the document
    document = loader.load
    content = document.is_a?(Array) ? document.map(&:content).join("\n") : document.content
    chunks = chunk_text(content)
    
    # Create embeddings for each chunk
    chunks.map do |chunk|
      embedding = embedder.embed_text(chunk)
      DocumentChunk.new(chunk, embedding)
    end
  end
  
  private
  
  def self.chunk_text(text, chunk_size = 1000)
    chunks = []
    position = 0
    
    while position < text.length
      chunk_end = [position + chunk_size, text.length].min
      
      if chunk_end < text.length
        last_space = text.rindex(/\s/, chunk_end)
        if last_space && last_space > position
          chunk_end = last_space
        end
      end
      
      chunks << text[position...chunk_end]
      
      position = chunk_end
      position += 1 while position < text.length && text[position] =~ /\s/
    end
    
    chunks
  end
end

class DocumentDiscussionTool
  def initialize
    @llm = Langchain::LLM::Ollama.new(model: 'llama2')
    @embedder = Langchain::Embeddings::Ollama.new(model: 'llama2')
    @context = []
    parse_options
  end

  def parse_options
    @options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: document-discussion-tool.rb [options]"

      opts.on("-f", "--file FILE", "File to discuss (PDF or TXT)") do |f|
        @options[:file] = f
      end
    end.parse!
  end

  def load_document
    begin
      @context = DocumentLoader.load(@options[:file], @embedder)
    rescue StandardError => e
      puts "Error loading document: #{e.message}"
      exit 1
    end
  end

  def chat
    puts "\nWelcome to Document Discussion Tool!"
    puts "Type 'exit' to quit or 'help' for commands."

    loop do
      print "\nYour question: "
      input = gets.chomp
      
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
    relevant_chunks = find_relevant_chunks(question)
    prompt = <<~PROMPT
      Context from the document:
      #{relevant_chunks.map(&:content).join("\n\n")}

      Question: #{question}

      Please answer based on the context provided above.
    PROMPT

    @llm.complete(prompt: prompt)
  end

  def find_relevant_chunks(question, num_chunks = 3)
    # Get embedding for the question
    question_embedding = Vector.elements(@embedder.embed_text(question))
    
    # Sort chunks by cosine similarity to question
    @context.sort_by do |chunk|
      -chunk.similarity_to(question_embedding)
    end.first(num_chunks)
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
  tool = DocumentDiscussionTool.new
  tool.run
end


