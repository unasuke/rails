require 'tempfile'

begin
  require 'aws-sdk-s3'
rescue LoadError
  warn "aws-sdk-s3 gem not found"
  raise
end

module ActiveSupport
  module Cache
    class S3CacheStore < Store
      def initialize(options = nil)
        super(options)

        access_key_id = options[:access_key_id] || ENV['AWS_ACCESS_KEY_ID']
        secret_access_key = options[:secret_access_key] || ENV['AWS_SECRET_ACCESS_KEY']
        region = options[:region] || ENV['AWS_DEFAULT_REGION']
        endpoint = options[:endpoint]
        @bucket = options[:bucket]

        if @bucket.nil? || @bucket.empty?
          raise ArgumentError, "Bucket name not specified"
        end

        Aws.config.update(
            force_path_style: true
        )
        @client = Aws::S3::Client.new(
          {
            access_key_id: 'minioadmin' || access_key_id,
            secret_access_key: 'minioadmin' || secret_access_key,
            region: region,
            endpoint: endpoint,
            force_path_style: true
          }
        )
      end

      private

      def read_entry(key, options)
        raw = options&.fetch(:raw, false)
        resp = @client.get_object(
          {
            bucket: @bucket,
            key: key
          })
        deserialize_entry(resp.body.read, raw: raw)
      rescue Aws::S3::Errors::NoSuchKey
        nil
      end

      def write_entry(key, entry, raw: false, **options)
        serialized_entry = serialize_entry(entry, raw: raw)

        if serialized_entry.is_a?(String) || serialized_entry.is_a?(File)
          resp = @client.put_object(
            {
              bucket: @bucket,
              key: key,
              body: serialized_entry
            })
        else
          Tempfile.open do |f|
            f.write(entry)
            f.rewind
            resp = @client.put_object(
              {
                bucket: @bucket,
                key: key,
                body: f
              })
          end
        end
      end

      def delete_entry(key, options)
        @client.delete_object(
          {
            bucket: @bucket,
            key: key
          }
        )
      end

      def serialize_entry(entry, raw: false)
        if raw
          entry.value.to_s
        else
          super(entry)
        end
      end

      def deserialize_entry(payload, raw: false)
        if payload && raw
          Entry.new(payload, compress: false)
        else
        super(payload)
        end
      end
    end
  end
end
