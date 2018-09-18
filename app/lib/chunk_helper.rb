module ChunkHelper
  module_function

  JOIN_STRING = "\n".freeze

  def to_chunk(strings)
    flattened = strings.join JOIN_STRING
    compressed = Zlib::Deflate.deflate flattened
    Base64.encode64 compressed
  end

  def from_chunk(chunk)
    unencoded = Base64.decode64 chunk
    decompressed = Zlib::Inflate.inflate unencoded

    decompressed
      .split(JOIN_STRING)
      .map(&:presence)
      .compact
  end
end
