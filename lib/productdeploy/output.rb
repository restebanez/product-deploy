module ProductDeploy
    class Output
      def messages
        @messages ||= []
      end
    
      def puts(message)
        messages << message
      end
      
      def print(message)
          if messages.empty?
              messages << message
          else
              # append to the last element
              messages[messages.size-1] = "#{messages.last}#{message}"
          end
          
      end
    end
end