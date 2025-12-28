# CPE Validator - Validate CPE format and NVD compatibility
require 'faraday'
require 'json'

class CPEValidator
  # CPE 2.3 format: cpe:2.3:part:vendor:product:version:...
  CPE_REGEX = %r{^cpe:2\.3:[aho]:[^:]+:[^:]+:[^:]+}

  # Validate CPE syntax
  def self.valid_format?(cpe_string)
    return false if cpe_string.nil? || cpe_string.empty?
    cpe_string =~ CPE_REGEX
  end

  # Parse CPE string into components
  def self.parse(cpe_string)
    return nil unless valid_format?(cpe_string)
    parts = cpe_string.split(':')
    {
      part: parts[2],        # a (application), o (OS), h (hardware)
      vendor: parts[3],
      product: parts[4],
      version: parts[5],
      full: cpe_string
    }
  end

  # Check if CPE matches a pattern (supports *)
  def self.matches_pattern?(cpe_string, pattern)
    return false unless valid_format?(cpe_string)
    regex_pattern = Regexp.new(pattern.gsub('*', '.*'))
    cpe_string =~ regex_pattern
  end

  # Known vendor mappings (for common Nix packages)
  KNOWN_VENDOR_MAPPINGS = {
    'glibc' => 'gnu',
    'bash' => 'gnu',
    'gcc' => 'gnu',
    'coreutils' => 'gnu',
    'openssl' => 'openssl',
    'python' => 'python',
    'nodejs' => 'nodejs',  # Note: NVD uses 'nodejs' for Node.js project
    'node' => 'nodejs'
  }.freeze

  # Get expected vendor for a product
  def self.expected_vendor(product)
    KNOWN_VENDOR_MAPPINGS[product.downcase]
  end

  # Validate against NVD (network call - slow, use with @network tag)
  def self.validate_against_nvd(cpe_string)
    parsed = parse(cpe_string)
    return nil unless parsed

    NVDValidator.new(parsed[:vendor], parsed[:product], parsed[:version])
  end

  # NVD API validator (network-based)
  class NVDValidator
    NVD_API_BASE = 'https://services.nvd.nist.gov/rest/json/cpes/2.0'

    attr_reader :vendor, :product, :version

    def initialize(vendor, product, version)
      @vendor = vendor
      @product = product
      @version = version
      @nvd_response = nil
    end

    def vendor_exists?(expected_vendor, expected_product)
      # Query NVD API for CPE existence
      # This is a slow operation - tagged with @network
      query_nvd(expected_vendor, expected_product)
      # Check if response contains matching CPE
      @nvd_response && @nvd_response['products'] && !@nvd_response['products'].empty?
    end

    private

    def query_nvd(vendor, product)
      # Note: This is a simplified implementation
      # Real implementation should:
      # - Add API key authentication
      # - Implement rate limiting
      # - Cache results (use VCR gem)
      # - Handle errors gracefully

      return @nvd_response if @nvd_response # Simple cache

      begin
        # NVD API query for CPE match
        # Format: /rest/json/cpes/2.0?cpeMatchString=cpe:2.3:a:vendor:product:*
        cpe_pattern = "cpe:2.3:a:#{vendor}:#{product}:*"

        conn = Faraday.new(url: NVD_API_BASE) do |f|
          f.adapter Faraday.default_adapter
        end

        response = conn.get do |req|
          req.params['cpeMatchString'] = cpe_pattern
          req.options.timeout = 10
        end

        @nvd_response = JSON.parse(response.body) if response.success?
      rescue Faraday::Error, JSON::ParserError => e
        # Network/parsing error - return nil
        nil
      end

      @nvd_response
    end
  end
end
