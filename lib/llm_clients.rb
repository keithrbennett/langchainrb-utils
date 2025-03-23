require 'langchain'
require 'ostruct'
require 'logger'
require 'json'
require 'net/http'

class LlmClients
  class << self
    def create_anthropic = Langchain::LLM::Anthropic.new(api_key: ENV['ANTHROPIC_API_KEY'])
    
    def create_deepseek
      llm = Langchain::LLM::OpenAI.new(
        api_key: ENV['DEEPSEEK_API_KEY'],
        default_options: {
          chat_model: "deepseek-reasoner"
        }
      )
    
      # Kludge to use OpenAI class for DeepSeek API
      llm.instance_variable_get(:@client).instance_variable_set(
        :@uri_base, 
        "https://api.deepseek.com/v1"
      )
    
      llm
    end

    def create_gemini
      llm = Langchain::LLM::GoogleGemini.new(
        api_key: ENV['GEMINI_API_KEY'],
        default_options: {
          chat_model: "gemini-2.0-flash"
        }
      )
      
      # Monkey patch the http_post method to add logging while preserving original functionality
      def llm.http_post(url, params)
        puts "\nGemini API Request:"
        puts "URL: #{url}"
        puts "Payload:"
        puts JSON.pretty_generate(params)
        puts "\n"
        
        http = Net::HTTP.new(url.hostname, url.port)
        http.use_ssl = url.scheme == "https"
        http.set_debug_output(Langchain.logger) if Langchain.logger.debug?

        request = Net::HTTP::Post.new(url)
        request.content_type = "application/json"
        request.body = params.to_json

        response = http.request(request)

        JSON.parse(response.body)
      end
      
      llm
    end

    def create_ollama = Langchain::LLM::Ollama.new
    
    def create_openai = Langchain::LLM::OpenAI.new(api_key: ENV['OPENAI_API_KEY'])
          
    def create(name)
      public_send("create_#{name}")
    end

    def call_llm(llm, prompt)
      message = if llm.is_a?(Langchain::LLM::GoogleGemini)
        { role: "user", parts: [{ text: prompt }] }
      else
        { role: "user", content: prompt }
      end
      
      response = llm.chat(messages: [message])
    end
  end
end 