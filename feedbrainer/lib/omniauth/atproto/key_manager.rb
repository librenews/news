module OmniAuth
  module Atproto
    class KeyManager
      KEY_FILE = Rails.root.join("config", "bluesky_client.key")

      def self.current_private_key
        @current_private_key ||= load_or_generate_key
      end

      def self.current_jwk
        key = current_private_key
        # Convert EC key to JWK format (ES256)
        # Note: This is a simplified JWK generation for EC P-256
        {
          kty: "EC",
          crv: "P-256",
          x: Base64.urlsafe_encode64(key.public_key.to_bn.to_s(2)[1, 32], padding: false),
          y: Base64.urlsafe_encode64(key.public_key.to_bn.to_s(2)[33, 32], padding: false),
          use: "sig",
          alg: "ES256",
          kid: "bluesky-client-key-1"
        }
      end

      private

      def self.load_or_generate_key
        if File.exist?(KEY_FILE)
          OpenSSL::PKey::EC.new(File.read(KEY_FILE))
        else
          key = OpenSSL::PKey::EC.generate("prime256v1")
          File.write(KEY_FILE, key.to_pem)
          key
        end
      end
    end
  end
end
