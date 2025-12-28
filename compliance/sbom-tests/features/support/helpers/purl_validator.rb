# PURL Validator - Validate Package URL format and syntax
class PURLValidator
  # PURL specification: pkg:<type>/<namespace>/<name>@<version>
  PURL_REGEX = %r{^pkg:[a-z][a-z0-9+.-]*/.+}

  # Validate PURL format
  def self.valid_format?(purl)
    return false if purl.nil? || purl.empty?
    purl =~ PURL_REGEX
  end

  # Parse PURL into components
  def self.parse(purl)
    return nil unless valid_format?(purl)

    # Extract type
    type_part = purl.split(':')[1]
    type = type_part.split('/')[0]

    # Extract name and version
    parts = purl.split('@')
    version = parts.last if parts.length > 1

    # Extract name (everything between type/ and @version)
    name_with_namespace = purl.split("#{type}/")[1]
    name_with_namespace = name_with_namespace.split('@')[0] if name_with_namespace

    # Try to split namespace and name
    name_parts = name_with_namespace&.split('/') || []
    if name_parts.length > 1
      namespace = name_parts[0..-2].join('/')
      name = name_parts.last
    else
      namespace = nil
      name = name_parts.first
    end

    {
      type: type,
      namespace: namespace,
      name: name,
      version: version,
      full: purl
    }
  end

  # Extract PURL type (ecosystem)
  def self.type(purl)
    return nil unless valid_format?(purl)
    purl.split(':')[1].split('/')[0]
  end

  # Check if PURL is for a specific ecosystem
  def self.ecosystem?(purl, ecosystem)
    type(purl) == ecosystem
  end

  # Validate NPM scoped package PURL
  def self.valid_npm_scoped?(purl)
    return false unless ecosystem?(purl, 'npm')
    # Scoped packages: pkg:npm/@scope/name@version
    purl.include?('/@') && purl.count('@') >= 2
  end

  # Validate NPM unscoped package PURL
  def self.valid_npm_unscoped?(purl)
    return false unless ecosystem?(purl, 'npm')
    # Unscoped packages: pkg:npm/name@version
    !purl.include?('/@') && purl.count('@') == 1
  end
end
