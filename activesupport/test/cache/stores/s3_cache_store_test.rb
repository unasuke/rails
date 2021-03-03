# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/cache"
require "active_support/cache/s3_cache_store"
require_relative "../behaviors"

class S3CacheStoreTest < ActiveSupport::TestCase
  attr_reader :cache_dir

  def lookup_store(options = {})
    ActiveSupport::Cache.lookup_store(:s3_cache_store, options.merge({ access_key_id: 'minioadmin ', secret_access_key: 'minioadmin', region: 'us-east-1', endpoint: 'http://127.0.0.1:9000'}))
  end

  def setup
    @bucket = SecureRandom.alphanumeric.downcase
    # @cache_dir = Dir.mktmpdir("file-store-")
    # Dir.mkdir(cache_dir) unless File.exist?(cache_dir)
    @cache = lookup_store(expires_in: 60, bucket: @bucket)
    # @peek = lookup_store(expires_in: 60)
    # @cache_with_pathname = lookup_store(cache_dir: Pathname.new(cache_dir), expires_in: 60)

    @buffer = StringIO.new
    @cache.logger = ActiveSupport::Logger.new(@buffer)
    @client = Aws::S3::Client.new(
      {
        access_key_id: 'minioadmin',
        secret_access_key: 'minioadmin',
        region: 'us-east-1',
        endpoint: 'http://127.0.0.1:9000',
        force_path_style: true
      }
    )
    unless @client.list_buckets.buckets.any? {|bucket| bucket.name == @bucket }
      @client.create_bucket(bucket: @bucket)
    end
  end

  def teardown
    if @client.list_buckets.buckets.any? {|bucket| bucket.name == @bucket }
      @client.list_objects(bucket: @bucket).contents.each do |object|
        @client.delete_object(bucket: @bucket, key: object.key)
      end
      @client.delete_bucket(bucket: @bucket)
    end
  end

  include CacheStoreBehavior
end
