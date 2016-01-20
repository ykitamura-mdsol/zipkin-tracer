module ZipkinTracer
  class TraceClient
    ENV_REQUEST_ID = 'action_dispatch.request_id'.freeze
    LOCAL_COMPONENT = 'lc'.freeze
    STRING_TYPE = 'STRING'.freeze

    def initialize(env)
      @request_id = env && env[ENV_REQUEST_ID]
    end

    def trace(key = caller_locations(1).first.label)  # set caller method name if "key" is missing
      if block_given?
        record "Start: #{key}"
        yield self
        record "End: #{key}"
      end
    end

    def record(key)
      TraceClientCollection.add_annotation(@request_id, Trace::Annotation.new(key, Trace.default_endpoint)) if @request_id
    end

    def record_binary(key, value)
      TraceClientCollection.add_annotation(@request_id, Trace::BinaryAnnotation.new(key, value, STRING_TYPE, Trace.default_endpoint)) if @request_id
    end

    def record_local_component(value)
      record_binary(LOCAL_COMPONENT, value)
    end
  end


  class TraceClientCollection
    HEADER_REQUEST_ID = 'X-Request-Id'.freeze
    LIFE_SPAN = 10

    @annotations = {}

    def self.add_annotation(request_id, annotaion)
      @annotations[request_id] ||= {}
      @annotations[request_id][:updated_at] = DateTime.now
      @annotations[request_id][:items] ||= []
      @annotations[request_id][:items] << annotaion
    end

    def self.record_and_clear(headers)
      request_id = headers[HEADER_REQUEST_ID]
      annotations(request_id).each do |annotation|
        yield(annotation)
      end
      clear(request_id)
    end

    def self.annotations(request_id)
      (@annotations[request_id] && @annotations[request_id][:items]) || []
    end

    def self.clear(request_id)
      @annotations.delete(request_id)
      @annotations.delete_if {|key, value| value[:updated_at] < LIFE_SPAN.minute.ago }  # trush garbage
    end
  end
end
