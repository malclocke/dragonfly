module Dragonfly
  class FunctionManager
    
    # Exceptions
    class NotDefined < NoMethodError; end
    class UnableToHandle < NotImplementedError; end
    
    include Loggable
    
    def initialize
      @functions = {}
      @objects = []
    end
    
    def add(name, callable_obj=nil, &block)
      functions[name] ||= []
      functions[name] << (callable_obj || block)
    end

    attr_reader :functions, :objects

    def register(klass, *args, &block)
      obj = klass.new(*args)
      obj.configure(&block) if block
      obj.use_same_log_as(self) if obj.is_a?(Loggable)
      methods_to_add(obj).each do |meth|
        add meth.to_sym, obj.method(meth)
      end
      objects << obj
      obj
    end
    
    def call_last(meth, *args)
      if functions[meth.to_sym]
        functions[meth.to_sym].reverse.each do |function|
          catch :unable_to_handle do
            return function.call(*args)
          end
        end
        # If the code gets here, then none of the registered functions were able to handle the method call
        raise UnableToHandle, "None of the functions registered with #{self} were able to deal with the method call " +
          "#{meth}(#{args.map{|a| a.inspect[0..100]}.join(',')}). You may need to register one that can."
      else
        raise NotDefined, "function #{meth} not registered with #{self}"
      end
    end

    def inspect
      to_s.sub(/>$/, " with functions: #{functions.keys.map{|k| k.to_s }.sort.join(', ')} >")
    end

    private
    
    def methods_to_add(obj)
      if obj.is_a?(Configurable)
        obj.public_methods(false) -
          obj.configuration_methods.map{|meth| meth.to_method_name} -
          [:configuration_methods.to_method_name]
      else
        obj.public_methods(false)
      end
    end

  end
end
