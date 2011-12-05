module ProductDeploy

    class OutputChef
      
      def puts(message)
        Chef::Log.info(message)
      end
      
      def print(message)
          Chef::Log.info(message)
      end
    end

end